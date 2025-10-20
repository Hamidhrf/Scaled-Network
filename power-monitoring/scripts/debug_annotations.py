#!/usr/bin/env python3
# debug_annotations.py
from kubernetes import client, config
import time

config.load_kube_config()
v1 = client.CoreV1Api()

print("Monitoring pod annotations in real-time...\n")

while True:
    pods = v1.list_namespaced_pod("demo", label_selector="app=kwok-power").items
    
    total = 0.0
    zero_count = 0
    missing_count = 0
    
    print(f"\n=== {time.strftime('%H:%M:%S')} ===")
    
    for p in pods:
        name = p.metadata.name
        ann = (p.metadata.annotations or {}).get("emulator.power/watts")
        
        if ann is None:
            missing_count += 1
            print(f"  {name:30s} - MISSING ANNOTATION")
        elif ann == "0" or ann == "0.0":
            zero_count += 1
        else:
            try:
                watts = float(ann)
                total += watts
                if watts > 50:  # Only print significant values
                    print(f"  {name:30s} = {watts:6.2f}W")
            except:
                print(f"  {name:30s} = INVALID: {ann}")
    
    print(f"\n  TOTAL: {total:.2f}W  |  Zeros: {zero_count}  |  Missing: {missing_count}  |  Total pods: {len(pods)}")
    if total < 5:
        print(f"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!found bug {total} !!!!!!!!!!!!!!!!!!!!!!!!!!!")
    time.sleep(1)