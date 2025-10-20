#!/usr/bin/env python3
import argparse, os, re, sys, time
import pandas as pd
from concurrent.futures import ThreadPoolExecutor, as_completed
from kubernetes import client, config
from kubernetes.client.rest import ApiException
 
IGNORE_REGEX = r'(?i)^(time|total)$|^Unnamed:.*'
 
def sanitize_name(s: str, prefix: str = "") -> str:
    import re
    s = s.strip().lower().replace(" ", "-").replace("_", "-").replace(".", "-")
    s = re.sub(r"[^a-z0-9-]", "-", s)
    s = re.sub(r"-{2,}", "-", s).strip("-")
    if not s: s = "pod"
    name = f"{prefix}{s}" if prefix else s
    return name[:63]
 
def choose_columns(df: pd.DataFrame, ignore_regex: str):
    pat = re.compile(ignore_regex)
    return [str(c) for c in df.columns if not pat.match(str(c))]
 
def load_kubeconfig():
    try:
        config.load_incluster_config()
    except Exception:
        config.load_kube_config()
 
def ensure_ns(v1, ns):
    try:
        v1.read_namespace(ns)
    except ApiException as e:
        if e.status == 404:
            v1.create_namespace(client.V1Namespace(metadata=client.V1ObjectMeta(name=ns)))
        else:
            raise
 
def ensure_pod(v1, ns, pod_name, node, image, labels, toleration_key):
    try:
        v1.read_namespaced_pod(pod_name, ns)
        return False
    except ApiException as e:
        if e.status != 404: raise
    body = client.V1Pod(
        api_version="v1",
        kind="Pod",
        metadata=client.V1ObjectMeta(
            name=pod_name,
            labels=labels,
            annotations={"emulator.power/watts":"0","emulator.power/version":"0"},
        ),
        spec=client.V1PodSpec(
            node_name=node,
            tolerations=[client.V1Toleration(key=toleration_key, effect="NoSchedule", operator="Exists")],
            containers=[client.V1Container(name="nop", image=image, image_pull_policy="IfNotPresent")],
            restart_policy="Always",
        ),
    )
    v1.create_namespaced_pod(ns, body)
    return True
 
def patch_annotations(v1, ns, pod, watts, version, key_watts, key_ver):
    body = {"metadata":{"annotations":{key_watts:str(watts), key_ver:str(version)}}}
    v1.patch_namespaced_pod(name=pod, namespace=ns, body=body)
 
def is_number(x):
    try:
        if x is None: return False
        if isinstance(x,str) and not x.strip(): return False
        v = float(x)
        return not pd.isna(v)
    except Exception:
        return False
 
def main():
    ap = argparse.ArgumentParser(description="Create pods from CSV headers and annotate watts + version atomically.")
    ap.add_argument("--csv", required=True)
    ap.add_argument("--namespace", default="demo")
    ap.add_argument("--node", required=True)
    ap.add_argument("--image", default="registry.k8s.io/pause:3.9")
    ap.add_argument("--annotation-key", default="emulator.power/watts")
    ap.add_argument("--version-key", default="emulator.power/version")
    ap.add_argument("--ignore", default=IGNORE_REGEX)
    ap.add_argument("--name-prefix", default="")
    ap.add_argument("--label-app", default="kwok-power")
    ap.add_argument("--tick", type=float, default=15.0, help="seconds between rows")
    ap.add_argument("--loop", action="store_true")
    ap.add_argument("--concurrency", type=int, default=32, help="parallel patches per batch")
    args = ap.parse_args()
 
    df = pd.read_csv(args.csv)
    cols = choose_columns(df, args.ignore)
    if not cols:
        print("No usable columns (after ignoring time/total/Unnamed).", file=sys.stderr); sys.exit(2)
 
    # build mapping column -> pod name
    mapping = {}
    used = set()
    for c in cols:
        base = sanitize_name(c, args.name_prefix)
        name = base; i = 1
        while name in used:
            sfx = f"-{i}"
            name = (base[:63-len(sfx)]) + sfx
            i += 1
        used.add(name)
        mapping[c] = name
 
    load_kubeconfig()
    v1 = client.CoreV1Api()
    ensure_ns(v1, args.namespace)
 
    # create pods if missing
    for col, pod in mapping.items():
        created = ensure_pod(
            v1, ns=args.namespace, pod_name=pod, node=args.node,
            image=args.image,
            labels={"app": args.label_app, "kwok.power/column": col},
            toleration_key="kwok.x-k8s.io/node",
        )
        print(f"{'CREATED' if created else 'EXISTS '} {args.namespace}/{pod} for column '{col}'")
 
    version = 0
    while True:
        for _, row in df.iterrows():
            version += 1
            futures = []
            with ThreadPoolExecutor(max_workers=max(1,args.concurrency)) as ex:
                for col, pod in mapping.items():
                    val = row[col] if col in row else None
                    watts = float(val) if is_number(val) else 0.0
                    futures.append(ex.submit(
                        patch_annotations, v1, args.namespace, pod, watts, version,
                        args.annotation_key, args.version_key
                    ))
                for f in as_completed(futures):
                    try: f.result()
                    except Exception as e:
                        print(f"PATCH error: {e}", file=sys.stderr)
            # finished atomic batch; exporter will pick modal 'version'
            time.sleep(max(0.0, args.tick))
        if not args.loop:
            break
 
if __name__ == "__main__":
    main()