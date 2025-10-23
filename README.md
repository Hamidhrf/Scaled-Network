# Scaled-Network: Large-Scale Containerized K3s + Liqo Multi-Cluster Network

A sophisticated containerized network topology implementing a distributed Kubernetes environment using K3s and Liqo across 73 network devices with hybrid OSPF/BGP routing.

## Overview

This project creates a large-scale network simulation featuring:
- **73 Total Devices**: 13 routers, 51 K3s clients, 9 edge servers
- **6 Network Segments**: Distributed across different switches and subnets
- **Hybrid Routing**: OSPF backbone with BGP edge routing for scalability
- **Container Orchestration**: K3s clusters with Liqo multi-cluster networking
- **Real Network Simulation**: Using FRR routers and Arista cEOS switches

## Architecture

### Network Topology

<img width="2595" height="2242" alt="topology" src="https://github.com/user-attachments/assets/2a764bc2-9d92-41d1-96b7-0880b3694819" />


### Network Segments

| Segment | Subnet | Gateway | Switch | Clients | Edge Server | Router |
|---------|--------|---------|---------|---------|-------------|--------|
| **SW1** | 10.0.3.0/25 | 10.0.3.1 | switch1 | 1-6, 27 | Edge_server1 | Router13 (BGP AS 310) |
| **SW2** | 10.0.5.64/26 | 10.0.5.65 | switch2 | 7-15 | Edge_server4 | Router5 (BGP AS 500) |
| **SW3** | 10.0.1.0/25 | 10.0.1.1 | switch3 | 36-43 | Edge_server5 | Router11 (BGP AS 110) |
| **SW4** | 10.0.4.0/25 | 10.0.4.1 | switch4 | 44-51 | Edge_server6 | Router10 (BGP AS 410) |
| **SW5** | 10.0.2.192/27 | 10.0.2.193 | switch5 | 16-26 | Edge_server8 | Router9 (OSPF) |
| **SW6** | 10.0.2.160/27 | 10.0.2.161 | switch6 | 28-35 | Edge_server9 | Router8 (OSPF) |

### Routing Architecture

**OSPF Backbone (Instance 200):**
- **Area 0.0.0.0**: Router6, Router8, Router9 (backbone area)
- **Area 1.0.0.0**: Router2, Router6 (BGP border)
- **Area 2.0.0.0**: Router9 (Switch5 + Edge_server7)
- **Area 3.0.0.0**: Router8 (Switch6)

**BGP Autonomous Systems:**
- **AS 100**: Router3 (core routing hub)
- **AS 110**: Router11 → Switch3 (clients 36-43)
- **AS 200**: Router2 (OSPF/BGP bridge)
- **AS 300**: Router1 (core routing + Edge_server2)
- **AS 310**: Router13 → Switch1 (clients 1-6, 27)
- **AS 400**: Router7 (core routing)
- **AS 410**: Router10 → Switch4 (clients 44-51)
- **AS 500**: Router4, Router5, Router12 (Switch2 + Edge_server3)

## Quick Start

### Prerequisites
- **Docker** with privileged container support
- **Containerlab** (latest version)
- **Linux host** with:
  - `/sys/fs/cgroup` access
  - Kernel modules mounted
  - Device access (`/dev`)

### 1. Deploy the Topology
```bash
# Clone the repository
git clone https://github.com/Hamidhrf/Scaled-Network.git
cd Scaled-Network

# Create required directories
mkdir -p client-data/{client1..client51}/{k3s,etc-rancher,kubelet,liqo,etc-liqo}
mkdir -p shared

# Deploy the containerlab topology
sudo containerlab deploy frr01.clab.yml

# Verify deployment
docker ps | grep clab-frr01
```

### 2. Initialize K3s Clusters
The K3s initialization happens automatically via the `client-init.sh` script mounted in each container. Monitor initialization:

```bash
# Check initialization status
docker logs clab-frr01-client26  # Hub node
docker logs clab-frr01-client1   # Spoke node

# Verify K3s is running
docker exec clab-frr01-client26 k3s kubectl get nodes
```

### 3. Verify Network Connectivity
```bash
# Run full network connectivity test
./client-ping-matrix.sh

# Check OSPF neighbors
docker exec clab-frr01-router6 vtysh -c "show ip ospf neighbor"

# Check BGP peers
docker exec clab-frr01-router1 vtysh -c "show ip bgp summary"
```

## Components

### Docker Images
- **FRR Routers**: `frrouting/frr:latest` - Advanced routing protocols
- **Arista Switches**: `testing954/ceos:4.28.0F` - Enterprise switching
- **K3s Clients**: `hamidhrf/k3s-client:v7` - Lightweight Kubernetes
- **Edge Servers**: `testing954/server1:latest` - Application servers

### Key Configuration Files

| File | Purpose |
|------|---------|
| `frr01.clab.yml` | Containerlab topology definition |
| `ip-mapping.txt` | IP address assignments for all devices |
| `scripts/client-init.sh` | K3s + Liqo initialization script |
| `peering-config.sh` | Manages K3s cluster peering relationships |
| `client-ping-matrix.sh` | Network connectivity verification |
| `router-backup.sh` | Router configuration backup utility |

### Directory Structure
```
Scaled-Network/
├── frr01.clab.yml              # Main topology file
├── ip-mapping.txt              # IP assignments
├── client-ping-matrix.sh       # Connectivity testing
├── peering-config.sh          # K3s peering management
├── router-backup.sh           # Backup utility
├── router1-13/               # Individual router configs
│   ├── daemons               # FRR daemon configuration
│   └── frr.conf             # Router-specific routing config
├── router-configs/           # Shared router configs
│   └── vtysh.conf           # VTY shell configuration
├── scripts/
│   └── client-init.sh       # K3s/Liqo initialization
├── client-data/             # Persistent K3s data
│   └── client1-51/          # Per-client storage directories
├── shared/                  # Inter-container communication
└── router-backups/         # Configuration backups
```

## K3s Multi-Cluster Setup

### Hub-Spoke Architecture
- **Hub**: client26 (10.0.2.216/27) - Central K3s cluster
- **Spokes**: Configurable subset of clients 1-51
- **Default Peering**: clients 1-10 peer with hub by default

### Liqo Multi-Cluster Networking
The setup uses Liqo for Kubernetes multi-cluster networking:
- **Cross-cluster service discovery**
- **Pod-to-pod networking across clusters**
- **Resource sharing between clusters**
- **NodePort gateway services** (no LoadBalancer required)

### Managing K3s Peering
```bash
# View current peering configuration
./peering-config.sh show

# Add a client to peer with hub
./peering-config.sh add client15

# Remove a client from peering
./peering-config.sh remove client5

# Set complete peering list
./peering-config.sh set "client1 client2 client26 client30 client40"

# Apply configuration (restarts affected containers)
./peering-config.sh apply
```

## Network Operations

### Deployment Commands
```bash
# Deploy topology
sudo containerlab deploy frr01.clab.yml

# Destroy topology
sudo containerlab destroy frr01.clab.yml

# Inspect specific container
docker exec -it clab-frr01-router1 bash
docker exec -it clab-frr01-client26 bash
```

### Router Management
```bash
# Access router configuration
docker exec clab-frr01-router8 vtysh

# View running configuration
docker exec clab-frr01-router8 vtysh -c "show running-config"

# Check OSPF neighbors
docker exec clab-frr01-router8 vtysh -c "show ip ospf neighbor"

# Check BGP status
docker exec clab-frr01-router1 vtysh -c "show ip bgp summary"
```

### Backup and Recovery
```bash
# Create timestamped backup of all router configs
./router-backup.sh

# Backup specific router
docker exec clab-frr01-router8 vtysh -c "show running-config" > router8-backup.txt
```

### Network Diagnostics
```bash
# Full connectivity matrix test
./client-ping-matrix.sh

# Test specific connectivity
docker exec clab-frr01-client1 ping 10.0.2.193

# Check routing tables
docker exec clab-frr01-router8 vtysh -c "show ip route"

# Monitor K3s cluster status
docker exec clab-frr01-client26 k3s kubectl get nodes -o wide
docker exec clab-frr01-client26 k3s kubectl get pods -A
```

### Diagnostic Commands
```bash
# Network connectivity check
for i in {1..13}; do
    echo "=== ROUTER$i ==="
    docker exec clab-frr01-router$i vtysh -c "show ip route ospf"
done

# K3s cluster health
docker exec clab-frr01-client26 k3s kubectl get nodes
docker exec clab-frr01-client26 k3s kubectl get pods -n liqo

# Container resource usage
docker stats $(docker ps --format "table {{.Names}}" | grep clab-frr01)
```

## Technical Details

### IP Address Allocation
- **Router Interconnects**: 10.0.0.0/30, 10.0.2.0/30, 10.255.x.x/31 networks
- **Client Networks**: 10.0.1.0/25, 10.0.2.160/27, 10.0.2.192/27, 10.0.3.0/25, 10.0.4.0/25, 10.0.5.64/26
- **Management Networks**: 172.20.20.0/24 (Docker bridge)
- **Loopbacks**: 10.2.1.x/32 (router IDs)

### Routing Protocol Design
**OSPF Backbone**: Provides fast convergence and loop-free routing for core infrastructure
- Area 0 (Backbone): Core router interconnects
- Area 1-3: Client network segments

**BGP Edge**: Enables policy-based routing and scalable inter-domain connectivity
- Multiple AS numbers for network segmentation
- iBGP and eBGP sessions for redundancy

### Container Requirements
**Privileged Containers**: Required for:
- Network namespace manipulation
- K3s cluster operations
- cgroup management
- Device access for container orchestration

**Persistent Storage**: Each client maintains separate directories for:
- K3s data (`/var/lib/rancher/k3s`)
- Kubernetes configuration (`/etc/rancher/k3s`)
- Kubelet data (`/var/lib/kubelet`)
- Liqo configuration and data

## Advanced Usage

### Scaling the Network
To add more clients:

1. **Update topology file**: Add new client definitions to `frr01.clab.yml`
2. **Update IP mapping**: Add entries to `ip-mapping.txt`
3. **Create data directories**: `mkdir -p client-data/client52/{k3s,etc-rancher,kubelet,liqo,etc-liqo}`
4. **Update links**: Add switch connections in topology file
5. **Redeploy**: `sudo containerlab destroy && sudo containerlab deploy`

### Customizing K3s Peering
```bash
# Configure selective peering
./peering-config.sh set "client1 client10 client20 client30 client40 client50"

# Initialize with different defaults
./peering-config.sh init

# Validate configuration before applying
./peering-config.sh validate
./peering-config.sh apply
```

### Performance Monitoring
```bash
# Monitor resource usage
watch 'docker stats $(docker ps -q --filter name=clab-frr01)'

# Check network interface statistics
docker exec clab-frr01-router8 cat /proc/net/dev

# Monitor K3s cluster resources
docker exec clab-frr01-client26 k3s kubectl top nodes
docker exec clab-frr01-client26 k3s kubectl top pods -A
```

## Power Monitoring System (client27)

Client27 serves as the deployment platform for a sophisticated power monitoring system that simulates power consumption metrics for distributed workloads using KWOK and Prometheus.

### Overview
- **3 Simulated Nodes:** sn-fake, sa-fake, openfaas-fake
- **55+ Emulated Pods:** Microservices without actual container overhead
- **Monitoring Stack:** Prometheus + Custom Python Exporters
- **Data Sources:** Historical CSV power consumption data

### Architecture

client27 (Hub Node - 10.0.2.216/27)
├── K3s Cluster (Real)
└── KWOK Simulation Layer
├── sn-fake (27 social network microservices)
├── sa-fake (sentiment analysis workload)
└── openfaas-fake (serverless functions)

### Key Features
- **Resource Efficient:** Simulates 55+ pods without container runtime overhead
- **Realistic Data:** Uses production power consumption measurements
- **Standard Tooling:** Kubernetes API + Prometheus metrics
- **Research Ready:** Enables power-aware scheduling and green computing research

### Quick Start
```bash
# On client27, setup environment
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
source ~/kwok-power/bin/activate

# Deploy KWOK fake nodes (see power-monitoring/ directory)
kubectl apply -f power-monitoring/nodes/sn-fake.yaml
kubectl apply -f power-monitoring/nodes/sa-fake.yaml
kubectl apply -f power-monitoring/nodes/openfaas-fake.yaml

# Start annotation pipeline
python power-monitoring/scripts/create_pods_annotate.py \
  --csv power-monitoring/data/EMULATION-pod_cpu_watts-SN-1Hr.csv \
  --namespace demo --node sn-fake --tick 15.0 --loop &

# Start metrics exporter
python power-monitoring/scripts/power_exporter_host.py \
  --port 19100 --interval 2.0 &

# Launch Prometheus
docker run --rm --name prom --network clab -p 9090:9090 \
  -v "$(pwd)/power-monitoring/prometheus.yaml:/etc/prometheus/prometheus.yaml:ro" \
  prom/prometheus --config.file=/etc/prometheus/prometheus.yaml
```

### Prometheus Queries
```promql
# Per-pod power consumption
pod_power_watts{node="sn-fake"}

# Node-level aggregation
node_power_watts{node="sn-fake"}

# Cross-node comparison
sum by (node) (pod_power_watts)
```

## Development Note

### Recent Changes
- **Router Configuration Cleanup**: Removed unused interfaces from router8 (eth3, eth4, eth5)
- **Routing Protocol Migration**: Converted router1 from BGP-only to hybrid OSPF/BGP
- **Connectivity Fixes**: Resolved inter-segment routing issues
- **Backup System**: Added comprehensive router configuration backup
- **Process Limits**: Fixed resource exhaustion in ping matrix testing

### Known Issues
- **Router1 Protocol**: Currently BGP-only; OSPF conversion available but not applied
- **Process Limits**: Large-scale ping testing may hit system process limits
- **Container Startup**: K3s initialization can take 2-3 minutes per container

### Performance Considerations
- **Memory Usage**: Each K3s client requires ~512MB-1GB RAM
- **CPU Usage**: Peak during initialization, steady state ~10% per client
- **Network Bandwidth**: Liqo cluster peering generates background traffic
- **Storage**: Each client requires ~2GB persistent storage

## License

This project is provided for educational and research purposes. Container images and routing software are subject to their respective licenses.

## Support

For issues related to:
- **Containerlab**: https://containerlab.dev/
- **FRRouting**: https://frrouting.org/
- **K3s**: https://k3s.io/
- **Liqo**: https://liqo.io/

## Author

Created by Hamidreza (hamidhrf) as a large-scale network simulation environment for distributed Kubernetes research and development.