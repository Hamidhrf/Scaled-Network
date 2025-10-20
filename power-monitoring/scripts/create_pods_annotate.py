#!/usr/bin/env python3
import argparse, os, re, sys, time
from typing import List, Dict, Tuple
import pandas as pd
from kubernetes import client, config
from kubernetes.client.rest import ApiException

# Create KWOK-friendly pods from CSV column headers, then annotate power (watts).
# - Runs on the node (no Pods/YAML needed) using your kubeconfig.
# - Ignores columns named 'time' or 'total' (case-insensitive) and any 'Unnamed: *' columns.
# - Creates one pod per remaining column (sanitized to a valid pod name).
# - Replays the CSV rows in a fixed tick (ignores actual time values) and annotates power.
# - Annotation key: emulator.power/watts (customizable).


DEFAULT_IGNORE_REGEX = r'(?i)^(time|Total)$|^Unnamed:.*'

def sanitize_name(s: str, prefix: str = "") -> str:
    s = s.strip().lower()
    s = s.replace(" ", "-").replace("_", "-").replace(".", "-")
    s = re.sub(r"[^a-z0-9-]", "-", s)
    s = re.sub(r"-{2,}", "-", s).strip("-")
    if not s:
        s = "pod"
    name = f"{prefix}{s}" if prefix else s
    return name[:63]

def choose_columns(df: pd.DataFrame, ignore_regex: str) -> List[str]:
    cols = []
    pat = re.compile(ignore_regex)
    for c in df.columns:
        if pat.match(str(c)):
            continue
        cols.append(str(c))
    return cols

def load_kubeconfig():
    try:
        config.load_incluster_config()
    except Exception:
        config.load_kube_config()

def ensure_pod(api: client.CoreV1Api, *, ns: str, pod_name: str, node: str, image: str, labels: Dict[str,str], toleration_key: str):
    try:
        api.read_namespaced_pod(pod_name, ns)
        return False  # exists
    except ApiException as e:
        if e.status != 404:
            raise
    body = client.V1Pod(
        api_version="v1",
        kind="Pod",
        metadata=client.V1ObjectMeta(name=pod_name, labels=labels, annotations={"emulator.power/watts":"0"}),
        spec=client.V1PodSpec(
            node_name=node,
            tolerations=[client.V1Toleration(key=toleration_key, effect="NoSchedule", operator="Exists")],
            containers=[client.V1Container(name="nop", image=image, image_pull_policy="IfNotPresent")],
            restart_policy="Always",
        ),
    )
    api.create_namespaced_pod(ns, body)
    return True

def patch_power_annotation(api: client.CoreV1Api, ns: str, pod: str, key: str, value: float):
    body = {"metadata": {"annotations": {key: str(value)}}}
    api.patch_namespaced_pod(name=pod, namespace=ns, body=body)

def is_number(x) -> bool:
    try:
        if x is None: return False
        if isinstance(x, str) and not x.strip(): return False
        v = float(x)
        if pd.isna(v): return False
        return True
    except Exception:
        return False

def main():
    ap = argparse.ArgumentParser(description="Create pods from CSV headers and annotate power values (host-run).")
    ap.add_argument("--csv", required=True, help="Path to wide CSV (columns are services/pods).")
    ap.add_argument("--namespace", default="demo", help="Namespace to create pods in.")
    ap.add_argument("--node", required=True, help="Target KWOK fake node name to pin pods to.")
    ap.add_argument("--image", default="registry.k8s.io/pause:3.9", help="Container image (not actually run under KWOK).")
    ap.add_argument("--annotation-key", default="emulator.power/watts", help="Annotation key to write watts to.")
    ap.add_argument("--ignore", default=DEFAULT_IGNORE_REGEX, help="Regex for columns to ignore (default ignores time/total/Unnamed).")
    ap.add_argument("--name-prefix", default="", help="Optional prefix for created pod names.")
    ap.add_argument("--label-app", default="kwok-power", help="Value for label app=<label-app>.")
    ap.add_argument("--tick", type=float, default=1.0, help="Seconds to sleep between CSV rows (ignores real timestamps).")
    ap.add_argument("--create_only", action="store_true", help="Only create pods, do not annotate.")
    ap.add_argument("--annotate_only", action="store_true", help="Only annotate existing pods, do not create.")
    ap.add_argument("--loop", action="store_true", help="Loop the CSV replay forever.")
    args = ap.parse_args()

    df = pd.read_csv(args.csv)
    cols = choose_columns(df, args.ignore)
    if not cols:
        print("No columns to use after applying ignore rules.", file=sys.stderr)
        sys.exit(2)

    # Build mapping: column -> pod_name
    mapping = {}
    used = set()
    for c in cols:
        base = sanitize_name(c, args.name_prefix)
        name = base
        i = 1
        while name in used:
            suffix = f"-{i}"
            name = (base[:63-len(suffix)]) + suffix
            i += 1
        used.add(name)
        mapping[c] = name

    load_kubeconfig()
    v1 = client.CoreV1Api()

    # Create namespace if missing
    try:
        v1.read_namespace(args.namespace)
    except ApiException as e:
        if e.status == 404:
            v1.create_namespace(client.V1Namespace(metadata=client.V1ObjectMeta(name=args.namespace)))
        else:
            raise

    # Ensure pods exist (unless annotate-only)
    if  not args.annotate_only:
        for col, pod_name in mapping.items():
            created = ensure_pod(
                v1,
                ns=args.namespace,
                pod_name=pod_name,
                node=args.node,
                image=args.image,
                labels={"app": args.label_app, "kwok.power/column": sanitize_name(str(col))},
                toleration_key="kwok.x-k8s.io/node",
            )
            print(f"{'CREATED' if created else 'EXISTS '} {args.namespace}/{pod_name} for column '{col}'")

    if args.create_only:
        print("Create-only mode requested; exiting after pod creation.")
        return

    # Replay rows: annotate power for each column/pod
    while True:
        for idx, row in df.iterrows():
            for col, pod_name in mapping.items():
                val = row[col] if col in row else None
                if is_number(val):
                    try:
                        patch_power_annotation(v1, args.namespace, pod_name, args.annotation_key, float(val))
                        print(f"ANNOTATE {args.namespace}/{pod_name} = {val}")
                    except ApiException as e:
                        print(f"PATCH failed {args.namespace}/{pod_name}: {e}", file=sys.stderr)
                # else: skip non-numeric
            time.sleep(max(0.0, args.tick))
        if not args.loop:
            break

if __name__ == "__main__":
    main()
