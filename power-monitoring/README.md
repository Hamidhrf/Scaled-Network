# Power Monitoring System for Scaled-Network

A Kubernetes-based power monitoring system deployed on client27 that simulates power consumption for distributed workloads without running actual containers.

## System Context

This system runs on **client27** (10.0.2.216/27), the hub node of the Scaled-Network topology, leveraging the existing K3s infrastructure from the 73-device network simulation.

## Architecture

### Components

**KWOK Layer (Simulation)**
- Simulates Kubernetes nodes without kubelet
- Creates fake pods with power annotations
- Zero container runtime overhead

**Annotation Pipeline**
- Reads CSV power consumption data
- Updates pod annotations every 15 seconds
- Supports loop replay for continuous simulation

**Metrics Export**
- Python exporter reads annotations
- Exposes Prometheus metrics on port 19100
- Provides both pod-level and node-level aggregations

**Monitoring**
- Prometheus scrapes metrics every 2 seconds
- Stores time-series data for analysis
- Enables PromQL queries for power insights

## Simulated Nodes

| Node | Workload | Pods | Power Range | Description |
|------|----------|------|-------------|-------------|
| sn-fake | Social Network | 27 | 0.64W - 404W | Microservices (nginx, mongodb, redis, etc.) |
| sa-fake | Sentiment Analysis | 1 | Variable | ML inference workload |
| faas-fake | Serverless | Multiple | Variable | Function-as-a-Service platform |

## Installation

### Prerequisites
```bash
# Python environment
sudo apt install python3 python3-pip python3-venv
python3 -m venv ~/kwok-power
source ~/kwok-power/bin/activate
pip install pandas kubernetes prometheus_client

# KWOK installation
KWOK_REPO=kubernetes-sigs/kwok
KWOK_LATEST_RELEASE=$(curl -s "https://api.github.com/repos/${KWOK_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
kubectl apply -f "https://github.com/${KWOK_REPO}/releases/download/${KWOK_LATEST_RELEASE}/kwok.yaml"
kubectl apply -f "https://github.com/${KWOK_REPO}/releases/download/${KWOK_LATEST_RELEASE}/stage-fast.yaml"
```

### Deployment

**1. Deploy KWOK Nodes**
```bash
kubectl apply -f nodes/sn-fake.yaml
kubectl apply -f nodes/sa-fake.yaml
kubectl apply -f nodes/faas-fake.yaml

# Verify nodes
kubectl get nodes | grep fake
```

**2. Start Annotation Pipeline**
```bash
# For each node, run the annotation script
python scripts/create_pods_annotate.py \
  --csv data/EMULATION-pod_cpu_watts-SN-1Hr.csv \
  --namespace demo \
  --node sn-fake \
  --tick 15.0 \
  --loop &

# Check pods are created
kubectl get pods -n demo
```

**3. Start Metrics Exporter**
```bash
python scripts/power_exporter_host.py \
  --port 19100 \
  --interval 2.0 \
  --label-selector="app=kwok-power" &

# Test endpoint
curl http://localhost:19100/metrics | grep pod_power_watts
```

**4. Launch Prometheus**
```bash
docker run --rm --name prom --network clab -p 9090:9090 \
  -v "$(pwd)/prometheus.yaml:/etc/prometheus/prometheus.yaml:ro" \
  prom/prometheus --config.file=/etc/prometheus/prometheus.yaml

# Access UI: http://localhost:9090
```

## Usage

### Prometheus Queries

**Individual Pod Power**
```promql
pod_power_watts{node="sn-fake"}
```

**Node Total Power**
```promql
node_power_watts{node="sn-fake"}
```

**Cross-Node Comparison**
```promql
sum by (node) (pod_power_watts)
```

**Average Power Over Time**
```promql
avg_over_time(node_power_watts{node="sn-fake"}[5m])
```

**Power Distribution**
```promql
histogram_quantile(0.95, rate(pod_power_watts_bucket[5m]))
```

### Monitoring Pod Annotations
```bash
# Check pod annotations directly
kubectl get pod compose-post -n demo -o jsonpath='{.metadata.annotations.emulator\.power/watts}'

# Watch all pods
kubectl get pods -n demo -o json | jq '.items[] | {name: .metadata.name, watts: .metadata.annotations["emulator.power/watts"]}'
```

## Data Sources

### Social Network Workload (sn-fake)
- **File:** EMULATION-pod_cpu_watts-SN-1Hr.csv
- **Duration:** 65.5 minutes (263 samples)
- **Services:** 27 microservices
- **Pattern:** Startup → Sustained load → Shutdown

### Sentiment Analysis (sa-fake)
- **File:** EMULATE_pod_cpu_watts_sa.csv
- **Services:** Single ML inference service
- **Pattern:** Variable load based on request volume

### OpenFaaS (faas-fake)
- **File:** EMULATEkepler_pod_cpu_wattsopenfaas100000req.csv
- **Scenario:** 100,000 request load test
- **Pattern:** Bursty serverless function invocations

## Troubleshooting

### Race Conditions
**Symptom:** Prometheus shows power spikes exceeding CSV maximum

**Cause:** Sequential pod updates (2-6s for 27 pods) cause Prometheus to scrape during transitions

**Solution:**
- Increase scrape interval: `scrape_interval: 2s`
- Increase export interval: `--interval 2.0`
- Use version-based filtering (see advanced scripts)


### Metrics Not Appearing
```bash
# Check exporter logs
jobs | # Find job number
fg %1   # Bring to foreground to see logs

# Verify port is listening
netstat -tlnp | grep 19100

# Test metrics endpoint
curl http://localhost:19100/metrics
```

## Performance Considerations

- **Memory:** ~512MB-1GB per K3s client + 50-100MB per simulated node
- **CPU:** Minimal (<5% per annotation script, <2% per exporter)
- **Network:** ~100 Kbps per annotation script, ~10 Kbps per exporter
- **Storage:** ~2GB for client27 K3s data + negligible for KWOK

## Research Applications

- Power-aware Kubernetes scheduling
- Green computing optimization
- Infrastructure capacity planning
- Cost analysis for power-based billing
- Workload characterization
- Multi-cluster power distribution

## References

- **KWOK:** https://kwok.sigs.k8s.io/
- **Prometheus:** https://prometheus.io/
- **K3s:** https://k3s.io/
- **Full Technical Report:** [docs/TECHNICAL_REPORT.md](docs/TECHNICAL_REPORT.md)

## License

Same as parent Scaled-Network repository.

---

**Author:** Hamidreza (hamidhrf)  
**Parent Project:** [Scaled-Network](https://github.com/Hamidhrf/Scaled-Network)