#!/usr/bin/env python3
import argparse, time, sys
from kubernetes import client, config
from prometheus_client import start_http_server, Gauge

"""
Host-run exporter that reads Kubernetes pod annotations and exposes power metrics.
Exposes only GAUGES (no energy counters):
  - pod_power_watts{namespace,pod,node,app,column}
  - node_power_watts{node}
"""

def main():
    ap = argparse.ArgumentParser(description="Expose pod/node power watts from Kubernetes pod annotations (host-run).")
    ap.add_argument("--annotation-key", default="emulator.power/watts",
                    help="Annotation key to read (default: emulator.power/watts)." )
    ap.add_argument("--port", type=int, default=9100,
                    help="HTTP port to expose metrics (default: 9100)." )
    ap.add_argument("--interval", type=float, default=2.0,
                    help="Seconds between scans (default: 2.0)." )
    ap.add_argument("--label-selector", default="app=kwok-power",
                    help="K8s label selector to filter pods (default: app=kwok-power). Use empty string for all pods." )
    ap.add_argument("--namespaces", nargs="*", default=[],
                    help="Optional list of namespaces to restrict to (default: all)." )
    args = ap.parse_args()

    # Kube config: try in-cluster, then local kubeconfig
    try:
        config.load_incluster_config()
    except Exception:
        try:
            config.load_kube_config()
        except Exception as e:
            print(f"Failed to load kube config: {e}", file=sys.stderr)
            sys.exit(1)

    v1 = client.CoreV1Api()

    g_pod  = Gauge("pod_power_watts", "Per-pod power in watts",
                   ["namespace","pod","node","app","column"])
    g_node = Gauge("node_power_watts", "Per-node power in watts", ["node"])

    start_http_server(args.port)
    sel = args.label_selector if args.label_selector else "(none)"
    print(f"[exporter] listening on :{args.port}, annotation={args.annotation_key!r}, selector={sel}", flush=True)

    while True:
        node_totals = {}
        try:
            pods = []
            if args.namespaces:
                for ns in args.namespaces:
                    pods.extend(v1.list_namespaced_pod(namespace=ns,
                                                       label_selector=(args.label_selector or None)).items)
            else:
                pods = v1.list_pod_for_all_namespaces(label_selector=(args.label_selector or None)).items
        except Exception as e:
            print(f"[exporter] error listing pods: {e}", file=sys.stderr)
            time.sleep(max(0.1, args.interval))
            continue

        for p in pods:
            ns = p.metadata.namespace or ""
            pod = p.metadata.name or ""
            node = (p.spec.node_name or "")
            labels = p.metadata.labels or {}
            app = labels.get("app", "")
            column = labels.get("kwok.power/column", "")
            ann = (p.metadata.annotations or {}).get(args.annotation_key)
            if not ann:
                continue
            try:
                watts = float(ann)
            except Exception:
                continue
            g_pod.labels(ns, pod, node, app, column).set(watts)
            node_totals[node] = node_totals.get(node, 0.0) + watts

        for node, total in node_totals.items():
            g_node.labels(node).set(total)

        time.sleep(max(0.0, args.interval))

if __name__ == "__main__":
    main()
