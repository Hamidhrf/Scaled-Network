
#!/usr/bin/env bash
set -Eeuo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# about container
# ──────────────────────────────────────────────────────────────────────────────
HOSTNAME="$(hostname)"
IFACE_DATA="eth1"                       # lab/data interface (10.0.x.x side)
IFACE_API="eth0"                        # Docker network interface (172.20.20.x)
CFG="/ip-mapping.txt"                   # "<node> <cidr> <gw>" lines

# k3s / liqo bits
KCFG="/etc/rancher/k3s/k3s.yaml"
LOG="/tmp/k3s.log"
CHART="/liqo-chart.tgz"                 # optional: pre-bundled chart
HUB="client26"
SHARED_DIR="/shared"
HUB_KCFG="${SHARED_DIR}/hub.kubeconfig"

# Peering allowlist (persisted in /shared/peering-config.txt)
PEERING_CONFIG_FILE="/peering-config.txt"
DEFAULT_PEERS_TO_HUB="client1 client2 client3 client4 client5 client6 client7 client8 client9 client10"

# ──────────────────────────────────────────────────────────────────────────────
# helpers
# ──────────────────────────────────────────────────────────────────────────────
log() { echo "[INIT] $*"; }
ip4_of() { ip -4 -o addr show dev "$1" | awk '{print $4}' | cut -d/ -f1; }

should_peer_to_hub() {
  local peers
  if [[ -f "$PEERING_CONFIG_FILE" ]]; then
    peers="$(cat "$PEERING_CONFIG_FILE")"
  else
    peers="$DEFAULT_PEERS_TO_HUB"
    echo "$peers" > "$PEERING_CONFIG_FILE"
  fi
  grep -Eq "(^|[[:space:]])${HOSTNAME}([[:space:]]|$)" <<<"$peers"
}

# ──────────────────────────────────────────────────────────────────────────────
# 1) Configure the data interface (eth1) from ip-mapping.txt
# ──────────────────────────────────────────────────────────────────────────────
for _ in {1..60}; do ip link show "$IFACE_DATA" &>/dev/null && break; sleep 0.5; done

NODE_IP_DATA=""
while read -r name cidr gw; do
  [[ -z "${name:-}" || "$name" =~ ^# ]] && continue
  if [[ "$HOSTNAME" == "$name" ]]; then
    ip link set "$IFACE_DATA" up
    ip addr flush dev "$IFACE_DATA" || true
    ip addr add "$cidr" dev "$IFACE_DATA"
    NODE_IP_DATA="${cidr%%/*}"
    ip link set "$IFACE_DATA" mtu 1400 || true
    ip route replace 10.0.0.0/8 via "$gw" dev "$IFACE_DATA" || true
    # keep Docker default internet route via eth0 (low metric already)
    printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
    break
  fi
done < "$CFG"

if [[ -z "$NODE_IP_DATA" ]]; then
  log "ERROR: could not find $HOSTNAME in $CFG"; exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# k3s single-node server (lean) — start if not already running
# - API is reachable on the container's "API iface" (default eth0)
# - Data plane uses flannel host-gw on the inter-client iface (default eth1)
# - TLS cert includes the API IP so other containers can use this kubeconfig
# - Traefik/metrics-server/servicelb disabled to keep it light
# ──────────────────────────────────────────────────────────────────────────────

# helper: first IPv4 of an interface
ip4_of() { ip -4 -o addr show dev "$1" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1; }

LOG="/tmp/k3s.log"
KCFG="/etc/rancher/k3s/k3s.yaml"

# pick interfaces (override earlier in the script if you want)
IFACE_API="${IFACE_API:-eth0}"   # how other containers reach this API
IFACE_DATA="${IFACE_DATA:-eth1}" # inter-client data network (flannel)

API_IP="$(ip4_of "$IFACE_API")"
NODE_IP_DATA="$(ip4_of "$IFACE_DATA")"

# fallbacks if IFACE_DATA is missing on this client
if [ -z "$NODE_IP_DATA" ]; then
  NODE_IP_DATA="$API_IP"
fi

if ! pgrep -f "k3s server" >/dev/null 2>&1; then
  # NOTE: do not delete bind-mounted dirs here; wipe them on the HOST before deploy
  export K3S_KUBECONFIG_MODE=644

  nohup k3s server \
    --node-name "$HOSTNAME" \
    --node-ip "$NODE_IP_DATA" \
    --advertise-address "$API_IP" \
    --tls-san "$API_IP" \
    --flannel-iface "$IFACE_DATA" \
    --flannel-backend host-gw \
    --disable traefik \
    --disable metrics-server \
    --disable servicelb \
    --write-kubeconfig-mode 0644 \
    --debug >"$LOG" 2>&1 &

  echo "[INIT] starting k3s (API_IP=${API_IP}, NODE_IP=${NODE_IP_DATA}, IFACES api=${IFACE_API} data=${IFACE_DATA})"
else
  echo "[INIT] k3s already running"
fi

# wait for API to listen on 6443
printf "[INIT] waiting for API (6443) ... "
for n in $(seq 1 180); do
  ss -lnt 2>/dev/null | grep -q ":6443" && { echo ok; break; }
  sleep 1
done

# wait for node Ready (first boot can take a bit)
printf "[INIT] waiting for node Ready ... "
if k3s kubectl --kubeconfig "$KCFG" wait --for=condition=Ready node --all --timeout=300s >/dev/null 2>&1; then
  echo ok
else
  echo timeout
  echo "[INIT] last 120 lines of $LOG:"
  tail -n 120 "$LOG" || true
fi

# ──────────────────────────────────────────────────────────────────────────────
# 3) HUB only: publish a reachable kubeconfig for spokes
# ──────────────────────────────────────────────────────────────────────────────
if [[ "$HOSTNAME" == "$HUB" ]]; then
  # copy and rewrite the server URL to use the container's eth0 IP:6443
  if [[ -s "$KCFG" ]]; then
    mkdir -p "$SHARED_DIR"
    sed "s#https://127.0.0.1:6443#https://${API_IP}:6443#g" "$KCFG" > "$HUB_KCFG"
    chmod 0644 "$HUB_KCFG"
    log "hub kubeconfig published at $HUB_KCFG (server=https://${API_IP}:6443)"
  else
    log "WARNING: $KCFG not found yet; hub kubeconfig not published"
  fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# 4) Install Liqo (idempotent). Use the k3s-specific installer and current flags.
#    - cluster id = hostname
#    - skip kernel check if needed; skip confirm
# ──────────────────────────────────────────────────────────────────────────────
if ! k3s kubectl -n liqo get deploy liqo-controller-manager >/dev/null 2>&1; then
  log "installing Liqo in $HOSTNAME"
  if [[ -s "$CHART" ]]; then
    liqoctl install k3s \
      --cluster-id "$HOSTNAME" \
      --disable-kernel-version-check \
      --skip-confirm \
      --kubeconfig "$KCFG" \
      --local-chart-path "$CHART"
  else
    liqoctl install k3s \
      --cluster-id "$HOSTNAME" \
      --disable-kernel-version-check \
      --skip-confirm \
      --kubeconfig "$KCFG"
  fi
else
  log "Liqo already installed"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 5) Selective peering: only clients listed in /shared/peering-config.txt
#    Use NodePort for the gateway service since there is no LoadBalancer.
# ──────────────────────────────────────────────────────────────────────────────
if [[ "$HOSTNAME" != "$HUB" ]] && should_peer_to_hub; then
  log "$HOSTNAME is configured to peer with hub $HUB"
  # wait for hub kubeconfig
  for _ in {1..180}; do [[ -s "$HUB_KCFG" ]] && break; sleep 2; done

  if ! k3s kubectl get foreignclusters.liqo.io "$HUB" >/dev/null 2>&1; then
    for attempt in {1..20}; do
      if liqoctl peer \
            --kubeconfig "$KCFG" \
            --remote-kubeconfig "$HUB_KCFG" \
            --server-service-type NodePort; then
        log "peering succeeded on attempt $attempt"
        break
      else
        log "peering attempt $attempt failed, retrying in 6s..."
        sleep 6
      fi
    done
  else
    log "already peered with $HUB"
  fi
else
  [[ "$HOSTNAME" != "$HUB" ]] && log "$HOSTNAME not in peering allowlist; skipping peering"
fi

log "done on $HOSTNAME"
