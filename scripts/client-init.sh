# # #!/bin/bash

# HOSTNAME=$(hostname)
# CONFIG_FILE="/ip-mapping.txt"

# echo "[INIT] Configuring IP for $HOSTNAME using $CONFIG_FILE"

# while read name ip gw; do
#   if [ "$HOSTNAME" = "$name" ]; then
#     echo "[INIT] Setting IP $ip with GW $gw on eth1"
#     ip link set dev eth1 up
#     ip addr flush dev eth1
#     ip route flush table main
#     ip addr add "$ip" dev eth1
#     ip route add 10.0.0.0/8 via "$gw" dev eth1
#     echo "[INIT] Done."
#     exit 0
#   fi
# done < "$CONFIG_FILE"

# echo "[INIT] No IP mapping found for $HOSTNAME"
# exit 1


#!/usr/bin/env bash
# set -e

# HOSTNAME=$(hostname)
# CFG="/ip-mapping.txt"

# ###############################################################################
# # 1. ── Network (IP + MTU 1400 + overlay + DNS + default GW) ──────────────────
# ###############################################################################
# while read name ip gw; do
#   if [ "$HOSTNAME" = "$name" ]; then
#     ip link set eth1 up
#     ip addr flush dev eth1
#     ip addr add "$ip" dev eth1
#     ip link set eth1 mtu 1400
#     ip route add 10.0.0.0/8 via "$gw" dev eth1

#     # keep Docker’s original default route for Internet access
#     DEF_GW=$(ip route | awk '/default/ {print $3; exit}')
#     ip route replace default via "$DEF_GW" dev eth0 metric 100

#     # real resolver
#     printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
#     break
#   fi
# done < "$CFG"

# ###############################################################################
# # 2. ── K3s + Liqo only for “client*” nodes ───────────────────────────────────
# ###############################################################################
# case "$HOSTNAME" in
#   client*)
#     HUB="client26"
#     HUB_IP="10.0.2.216"
#     CHART="/liqo-chart.tgz"
#     TOKEN_FILE="/shared/token"

#     if [ "$HOSTNAME" = "$HUB" ]; then
#       # ─── Hub: K3s server ────────────────────────────────────────────────
#       if [ ! -S /run/k3s/k3s.sock ]; then
#         echo "[INIT] starting K3s server on hub"
#         k3s server --disable traefik --node-name "$HUB" \
#                    >/tmp/k3s.log 2>&1 &
#       fi
#       # wait until API answers, then export the join-token
#       until k3s kubectl get nodes >/dev/null 2>&1; do sleep 2; done
#       cat /var/lib/rancher/k3s/server/node-token > "$TOKEN_FILE"

#     else
#       # ─── Spoke: wait up to 300 s for token, then start agent ────────────
#       for _ in $(seq 1 150); do
#         [ -s "$TOKEN_FILE" ] && break
#         sleep 2
#       done
#       TOKEN=$(cat "$TOKEN_FILE" 2>/dev/null || true)
#       if [ -n "$TOKEN" ] && [ ! -S /run/k3s/agent.sock ]; then
#         echo "[INIT] starting K3s agent on $HOSTNAME"
#         k3s agent --server "https://${HUB_IP}:6443" --token "$TOKEN" \
#                   --node-name "$HOSTNAME" >/tmp/k3s.log 2>&1 &
#       fi
#       # wait up to 300 s for kubeconfig so Liqo can use it
#       for _ in $(seq 1 150); do
#         [ -f /etc/rancher/k3s/k3s.yaml ] && break
#         sleep 2
#       done
#     fi

#     # ── Install Liqo (idempotent; skips if already present) ────────────────
#     if ! k3s kubectl -n liqo get deploy liqo-controller-manager \
#           >/dev/null 2>&1; then
#       echo "[INIT] installing Liqo on $HOSTNAME"
#       if [ "$HOSTNAME" = "$HUB" ]; then
#         liqoctl install k3s --cluster-id "$HOSTNAME" \
#           --disable-kernel-version-check --disable-telemetry --skip-confirm \
#           --kubeconfig /etc/rancher/k3s/k3s.yaml \
#           --local-chart-path "$CHART"
#       else
#         liqoctl install k3s --cluster-id "$HOSTNAME" \
#           --disable-kernel-version-check --disable-telemetry --skip-confirm \
#           --kubeconfig /etc/rancher/k3s/k3s.yaml
#         liqoctl peer --cluster-id "$HUB" --gateway "$HUB_IP" --skip-confirm \
#           --kubeconfig /etc/rancher/k3s/k3s.yaml || true
#       fi
#     fi
#     ;;
#   *)
#     echo "[INIT] $HOSTNAME is not in the client ring – skipping K3s/Liqo"
#     ;;
# esac

# echo "[INIT] done on $HOSTNAME"
# exit 0



# #!/usr/bin/env bash
# set -e

# HOSTNAME=$(hostname)
# CFG="/ip-mapping.txt"

# ###############################################################################
# # 0. ── Common vars for K3s ───────────────────────────────────────────────────
# ###############################################################################
# IFACE="eth1"                                                    # ►❶
# NODE_IP=$(ip -4 -o addr show dev "$IFACE" | awk '{print $4}' | cut -d/ -f1)  # ►❶

# ###############################################################################
# # 1. ── Network (IP + MTU 1400 + overlay + DNS + default GW) ──────────────────
# ###############################################################################
# while read name ip gw; do
#   if [ "$HOSTNAME" = "$name" ]; then
#     ip link set $IFACE up
#     ip addr flush dev $IFACE
#     ip addr add "$ip" dev $IFACE
#     ip link set $IFACE mtu 1400
#     ip route add 10.0.0.0/8 via "$gw" dev $IFACE

#     # keep Docker’s original default route for Internet access
#     DEF_GW=$(ip route | awk '/default/ {print $3; exit}')
#     ip route replace default via "$DEF_GW" dev eth0 metric 100

#     # real resolver
#     printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
#     break
#   fi
# done < "$CFG"

# ###############################################################################
# # 2. ── K3s + Liqo only for “client*” nodes ───────────────────────────────────
# ###############################################################################
# case "$HOSTNAME" in
#   client*)
#     HUB="client26"
#     HUB_IP="10.0.2.216"
#     CHART="/liqo-chart.tgz"
#     TOKEN_FILE="/shared/token"

#     if [ "$HOSTNAME" = "$HUB" ]; then
#       # ─── Hub: K3s server ────────────────────────────────────────────────
#       if [ ! -S /run/k3s/k3s.sock ]; then
#         echo "[INIT] starting K3s server on hub"
#         k3s server \
#           --disable traefik \
#           --flannel-iface        "$IFACE" \                    # ►❷
#           --advertise-address    "$NODE_IP" \                  # ►❷
#           --node-ip              "$NODE_IP" \                  # ►❷
#           --node-external-ip     "$NODE_IP" \                  # ►❷
#           --node-name            "$HOSTNAME" \
#           -v 2 >/tmp/k3s.log 2>&1 &
#       fi
#       # wait until API answers, then export the join-token
#       until k3s kubectl get nodes >/dev/null 2>&1; do sleep 2; done
#       cat /var/lib/rancher/k3s/server/node-token > "$TOKEN_FILE"

#     else
#       # ─── Spoke: wait up to 300 s for token, then start agent ───────────
#       for _ in $(seq 1 150); do
#         [ -s "$TOKEN_FILE" ] && break
#         sleep 2
#       done
#       TOKEN=$(cat "$TOKEN_FILE" 2>/dev/null || true)
#       if [ -n "$TOKEN" ] && [ ! -S /run/k3s/agent.sock ]; then
#         echo "[INIT] starting K3s agent on $HOSTNAME"
#         k3s agent \
#           --server "https://${HUB_IP}:6443" \
#           --token  "$TOKEN" \
#           --flannel-iface     "$IFACE" \                       # ►❸
#           --node-ip           "$NODE_IP" \                     # ►❸
#           --node-external-ip  "$NODE_IP" \                     # ►❸
#           --node-name         "$HOSTNAME" \
#           -v 2 >/tmp/k3s.log 2>&1 &
#       fi
#       # wait up to 300 s for kubeconfig so Liqo can use it
#       for _ in $(seq 1 150); do
#         [ -f /etc/rancher/k3s/k3s.yaml ] && break
#         sleep 2
#       done
#     fi

#     # ── Install Liqo (idempotent; skips if already present) ────────────────
#     if ! k3s kubectl -n liqo get deploy liqo-controller-manager \
#           >/dev/null 2>&1; then
#       echo "[INIT] installing Liqo on $HOSTNAME"
#       if [ "$HOSTNAME" = "$HUB" ]; then
#         liqoctl install k3s --cluster-id "$HOSTNAME" \
#           --disable-kernel-version-check --disable-telemetry --skip-confirm \
#           --kubeconfig /etc/rancher/k3s/k3s.yaml \
#           --local-chart-path "$CHART"
#       else
#         liqoctl install k3s --cluster-id "$HOSTNAME" \
#           --disable-kernel-version-check --disable-telemetry --skip-confirm \
#           --kubeconfig /etc/rancher/k3s/k3s.yaml
#         liqoctl peer --cluster-id "$HUB" --gateway "$HUB_IP" --skip-confirm \
#           --kubeconfig /etc/rancher/k3s/k3s.yaml || true
#       fi
#     fi
#     ;;
#   *)
#     echo "[INIT] $HOSTNAME is not in the client ring – skipping K3s/Liqo"
#     ;;
# esac

# echo "[INIT] done on $HOSTNAME"
# exit 0


# #!/usr/bin/env bash
# set -euo pipefail

# HOSTNAME=$(hostname)
# CFG="/ip-mapping.txt"          # <node> <ip/mask> <gw>

# ###############################################################################
# # 0. ── Common vars
# ###############################################################################
# IFACE="eth1"                   # data-plane interface
# NODE_IP=""                     # filled after we configure $IFACE
# HUB="client26"
# HUB_IP="10.0.2.216"
# CHART="/liqo-chart.tgz"
# TOKEN_FILE="/shared/token"

# ###############################################################################
# # 1. ── Network (IP + MTU + overlay + DNS + default-GW)
# ###############################################################################
# # wait until Containerlab has attached the eth1 link
# for _ in {1..40}; do
#   ip link show "${IFACE}" &>/dev/null && break
#   sleep 0.5
# done

# while read -r name ip gw; do
#   if [[ "$HOSTNAME" == "$name" ]]; then
#     ip link set "$IFACE" up
#     ip addr flush dev "$IFACE"
#     ip addr add "$ip" dev "$IFACE"
#     NODE_IP=${ip%%/*}                       # strip “/mask”
#     ip link set "$IFACE" mtu 1400
#     ip route add 10.0.0.0/8 via "$gw" dev "$IFACE"

#     # keep Docker’s default route for Internet access
#     DEF_GW=$(ip route | awk '/default/ {print $3; exit}')
#     ip route replace default via "$DEF_GW" dev eth0 metric 100

#     # public resolvers (no immutable flag anymore)
#     printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
#     break
#   fi
# done < "$CFG"

# ###############################################################################
# # 2. ── K3s + Liqo (clients only)
# ###############################################################################
# case "$HOSTNAME" in
#   client*)
#     if [[ "$HOSTNAME" == "$HUB" ]]; then
#       # ── Hub (server) ──────────────────────────────────────────────────────
#       if [[ ! -S /run/k3s/k3s.sock ]]; then
#         echo "[INIT] starting K3s server on $HOSTNAME"
#         k3s server \
#           --disable traefik \
#           --flannel-iface "$IFACE" \
#           --advertise-address "$NODE_IP" \
#           --node-ip "$NODE_IP" \
#           --node-external-ip "$NODE_IP" \
#           --node-name "$HOSTNAME" \
#           -v 2 >/tmp/k3s.log 2>&1 &
#       fi

#       # wait for API, then publish the join-token atomically
#       until k3s kubectl get nodes >/dev/null 2>&1; do sleep 2; done
#       cp /var/lib/rancher/k3s/server/node-token "$TOKEN_FILE"
#       chmod 666 "$TOKEN_FILE"

#       # give the API a small head-start before agents rush in
#       sleep 10

#     else
#       # ── Spoke (agent) ─────────────────────────────────────────────────────
#       # wait until the hub has written the token
#       for _ in $(seq 1 150); do
#         [[ -s "$TOKEN_FILE" ]] && break
#         sleep 2
#       done

#       TOKEN="$(cat "$TOKEN_FILE" 2>/dev/null || true)"

#       # wait until the API is reachable
#       until curl -sk --max-time 2 "https://${HUB_IP}:6443/healthz" \
#               | grep -q '^ok'; do
#         sleep "$(shuf -i 1-4 -n 1)"            # random 1-4 s back-off
#       done

#       if [[ -n "$TOKEN" && ! -S /run/k3s/agent.sock ]]; then
#         echo "[INIT] starting K3s agent on $HOSTNAME"
#         k3s agent \
#           --server "https://${HUB_IP}:6443" \
#           --token "$TOKEN" \
#           --flannel-iface "$IFACE" \
#           --node-ip "$NODE_IP" \
#           --node-external-ip "$NODE_IP" \
#           --node-name "$HOSTNAME" \
#           -v 2 >/tmp/k3s.log 2>&1 &
#       fi

#       # wait up to 5 min for kubeconfig so Liqo can consume it
#       for _ in $(seq 1 150); do
#         [[ -f /etc/rancher/k3s/k3s.yaml ]] && break
#         sleep 2
#       done
#     fi

#     # ── Liqo (idempotent) ───────────────────────────────────────────────────
#     if ! k3s kubectl -n liqo get deploy liqo-controller-manager >/dev/null 2>&1; then
#       echo "[INIT] installing Liqo on $HOSTNAME"
#       if [[ "$HOSTNAME" == "$HUB" ]]; then
#         liqoctl install k3s --cluster-id "$HOSTNAME" \
#           --disable-kernel-version-check --disable-telemetry --skip-confirm \
#           --kubeconfig /etc/rancher/k3s/k3s.yaml \
#           --local-chart-path "$CHART"
#       else
#         liqoctl install k3s --cluster-id "$HOSTNAME" \
#           --disable-kernel-version-check --disable-telemetry --skip-confirm \
#           --kubeconfig /etc/rancher/k3s/k3s.yaml
#         # peer with the hub (ignore “already peered” errors)
#         liqoctl peer --cluster-id "$HUB" --gateway "$HUB_IP" --overwrite \
#           --skip-confirm --kubeconfig /etc/rancher/k3s/k3s.yaml || true
#       fi
#     fi
#     ;;
#   *)
#     echo "[INIT] $HOSTNAME is not in the client ring – skipping K3s/Liqo"
#     ;;
# esac

# echo "[INIT] done on $HOSTNAME"
# exit 0


#!/usr/bin/env bash
set -euo pipefail

HOSTNAME=$(hostname)
CFG="/ip-mapping.txt"          # <node> <ip/mask> <gw>

# ── Common vars ────────────────────────────────────────────────────────────────
IFACE="eth1"
NODE_IP=""
HUB="client26"
HUB_IP="10.0.2.216"            # (kept for reference; not used by liqoctl peer)
CHART="/liqo-chart.tgz"
KCFG="/etc/rancher/k3s/k3s.yaml"
HUB_KCFG="/shared/hub.kubeconfig"

# ── 1) Network ────────────────────────────────────────────────────────────────
for _ in {1..60}; do
  ip link show "${IFACE}" &>/dev/null && break
  sleep 0.5
done

while read -r name ip gw; do
  if [[ "$HOSTNAME" == "$name" ]]; then
    ip link set "$IFACE" up
    ip addr flush dev "$IFACE"
    ip addr add "$ip" dev "$IFACE"
    NODE_IP=${ip%%/*}
    ip link set "$IFACE" mtu 1400
    ip route add 10.0.0.0/8 via "$gw" dev "$IFACE" || true

    # keep Docker's default internet route on eth0
    DEF_GW=$(ip route | awk '/default/ {print $3; exit}')
    ip route replace default via "$DEF_GW" dev eth0 metric 100 || true

    printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
    break
  fi
done < "$CFG"

# ── 2) K3s + Liqo per client (each client is its own cluster) ────────────────
case "$HOSTNAME" in
  client*)
    # Start K3s server if not up (idempotent)
    if [[ ! -S /run/k3s/k3s.sock ]]; then
      echo "[INIT] starting K3s server on $HOSTNAME"
      k3s server \
        --disable traefik \
        --flannel-iface "$IFACE" \
        --advertise-address "$NODE_IP" \
        --node-ip "$NODE_IP" \
        --node-external-ip "$NODE_IP" \
        --node-name "$HOSTNAME" \
        -v 2 >>/tmp/k3s.log 2>&1 &
    fi

    # Wait for API + kubeconfig
    for _ in $(seq 1 180); do
      if [[ -f "$KCFG" ]] && k3s kubectl get nodes >/dev/null 2>&1; then
        break
      fi
      sleep 2
    done

    # On the HUB, publish kubeconfig for spokes
    if [[ "$HOSTNAME" == "$HUB" ]]; then
      cp -f "$KCFG" "$HUB_KCFG"
      chmod 644 "$HUB_KCFG"
    fi

    # Install Liqo once (idempotent)
    if ! k3s kubectl -n liqo get deploy liqo-controller-manager >/dev/null 2>&1; then
      echo "[INIT] installing Liqo on $HOSTNAME"
      liqoctl install k3s \
        --cluster-id "$HOSTNAME" \
        --disable-kernel-version-check \
        --disable-telemetry \
        --skip-confirm \
        --kubeconfig "$KCFG" \
        --local-chart-path "$CHART"
    fi

    # Spokes peer to the hub using remote kubeconfig (new syntax)
    if [[ "$HOSTNAME" != "$HUB" ]]; then
      # Wait for the hub kubeconfig to be published
      for _ in $(seq 1 180); do
        [[ -s "$HUB_KCFG" ]] && break
        sleep 2
      done

      # if already peered, skip
      if ! k3s kubectl get foreignclusters.liqo.io "$HUB" >/dev/null 2>&1; then
        echo "[INIT] peering $HOSTNAME -> $HUB via kubeconfig"
        for attempt in $(seq 1 60); do
          if liqoctl peer \
                --kubeconfig "$KCFG" \
                --remote-kubeconfig "$HUB_KCFG"; then
            echo "[INIT] peering succeeded on attempt $attempt"
            break
          fi
          sleep 5
        done
      fi
    fi
    ;;
  *)
    echo "[INIT] $HOSTNAME is not a client* node – skipping K3s/Liqo"
    ;;
esac

echo "[INIT] done on $HOSTNAME"
