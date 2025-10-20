#!/usr/bin/env python3
import argparse, time, sys
from collections import defaultdict, Counter
from kubernetes import client, config
from prometheus_client import start_http_server, Gauge
 
"""
Host-run exporter that reads Kubernetes pod annotations and exposes power gauges.
 
Exposed metrics:
  - pod_power_watts{namespace,pod,node,app,column,version}
  - node_power_watts{node}
 
Stability feature:
  * Each row your annotator writes has a 'version' (emulator.power/version).
  * The exporter switches a node’s total to a new version only when a quorum
    (e.g., 80%) of that node’s pods report the same version. This prevents
    “needles” caused by Prometheus scraping mid-batch while pods are partially
    updated.
"""
 
def load_kube():
    # Try in-cluster first; fall back to local kubeconfig
    try:
        config.load_incluster_config()
    except Exception:
        try:
            config.load_kube_config()
        except Exception as e:
            print(f"Failed to load kube config: {e}", file=sys.stderr)
            sys.exit(1)
 
def main():
    ap = argparse.ArgumentParser(
        description="Expose pod/node power gauges from pod annotations with quorum switching."
    )
    ap.add_argument("--annotation-key", default="emulator.power/watts",
                    help="Annotation key for watts (default: emulator.power/watts).")
    ap.add_argument("--version-key", default="emulator.power/version",
                    help="Annotation key for version (default: emulator.power/version).")
    ap.add_argument("--port", type=int, default=9100,
                    help="HTTP port to expose metrics (default: 9100).")
    ap.add_argument("--bind", default="0.0.0.0",
                    help="Bind address (default: 0.0.0.0).")
    ap.add_argument("--interval", type=float, default=0.5,
                    help="Seconds between scans (default: 0.5).")
    ap.add_argument("--label-selector", default="app=kwok-power",
                    help="Label selector to filter pods (default: app=kwok-power; empty for all pods).")
    ap.add_argument("--namespaces", nargs="*", default=[],
                    help="Optional list of namespaces to restrict to (default: all).")
    ap.add_argument("--switch-threshold", type=float, default=0.8,
                    help="Fraction [0..1] of a node's pods that must report the same version "
                         "before node total switches to that version (default: 0.8).")
    args = ap.parse_args()
 
    load_kube()
    v1 = client.CoreV1Api()
 
    # Gauges
    g_pod  = Gauge("pod_power_watts",  "Per-pod power in watts",
                   ["namespace","pod","node","app","column","version"])
    g_node = Gauge("node_power_watts", "Per-node power in watts", ["node"])
 
    # Start HTTP
    start_http_server(args.port, addr=args.bind)
    sel = args.label_selector if args.label_selector else "(none)"
    print(f"[exporter] listening on {args.bind}:{args.port}  selector={sel}  "
          f"interval={args.interval}s  switch-threshold={args.switch_threshold}", flush=True)
 
    # Keep last accepted (version,total) per node to avoid dips mid-batch
    last_good = {}  # node -> (version, total)
 
    while True:
        # 1) List pods (optionally per namespace, with selector)
        try:
            pods = []
            if args.namespaces:
                for ns in args.namespaces:
                    pods.extend(v1.list_namespaced_pod(namespace=ns,
                                                       label_selector=(args.label_selector or None)).items)
            else:
                pods = v1.list_pod_for_all_namespaces(label_selector=(args.label_selector or None)).items
        except Exception as e:
            print(f"[exporter] list pods error: {e}", file=sys.stderr)
            time.sleep(max(0.1, args.interval))
            continue
 
        # 2) Build per-node -> version -> [watts,...] and also set per-pod gauges
        per_node_versions = defaultdict(lambda: defaultdict(list))
        for p in pods:
            ns   = p.metadata.namespace or ""
            name = p.metadata.name or ""
            node = p.spec.node_name or ""
            labels = p.metadata.labels or {}
            app   = labels.get("app", "")
            col   = labels.get("kwok.power/column", "")
            ann   = (p.metadata.annotations or {})
            ver_s = ann.get(args.version_key)
            w_s   = ann.get(args.annotation_key)
            if not ver_s or not w_s:
                continue
            try:
                ver = int(float(ver_s))   # accept "12" or "12.0"
                watts = float(w_s)
            except Exception:
                continue
 
            # Per-pod gauge always reflects the latest annotation
            g_pod.labels(ns, name, node, app, col, str(ver)).set(watts)
 
            # For node totals, group by version
            per_node_versions[node][ver].append(watts)
 
        # 3) For each node, decide if we switch to the new version or keep last
        for node, versions in per_node_versions.items():
            if not versions:
                # No data for this node this cycle; keep previous gauge value
                if node in last_good:
                    g_node.labels(node).set(last_good[node][1])
                continue
 
            # Count pods per version on this node
            counts = {ver: len(vals) for ver, vals in versions.items()}
            n_total = sum(counts.values())
 
            # Pick the version with most pods (ties → highest version)
            best_ver = max(counts.items(), key=lambda kv: (kv[1], kv[0]))[0]
            best_cnt = counts[best_ver]
 
            # Compute quorum threshold (#pods). Ceil for safety.
            need = max(1, int(args.switch_threshold * n_total + 0.999))
 
            if best_cnt >= need:
                # Enough pods are on the same version → switch
                total = sum(versions[best_ver])
                g_node.labels(node).set(total)
                last_good[node] = (best_ver, total)
            else:
                # Not enough yet → keep last good total to avoid “needles”
                if node in last_good:
                    g_node.labels(node).set(last_good[node][1])
                else:
                    # first cycle ever: publish current best anyway
                    g_node.labels(node).set(sum(versions[best_ver]))
 
        time.sleep(max(0.0, args.interval))
 
if __name__ == "__main__":
    main()