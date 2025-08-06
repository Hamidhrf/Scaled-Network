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



#!/usr/bin/env bash
set -e

HOSTNAME=$(hostname)
CFG="/ip-mapping.txt"

###############################################################################
# 0. ── Common vars for K3s ───────────────────────────────────────────────────
###############################################################################
IFACE="eth1"                                                    # ►❶
NODE_IP=$(ip -4 -o addr show dev "$IFACE" | awk '{print $4}' | cut -d/ -f1)  # ►❶

###############################################################################
# 1. ── Network (IP + MTU 1400 + overlay + DNS + default GW) ──────────────────
###############################################################################
while read name ip gw; do
  if [ "$HOSTNAME" = "$name" ]; then
    ip link set $IFACE up
    ip addr flush dev $IFACE
    ip addr add "$ip" dev $IFACE
    ip link set $IFACE mtu 1400
    ip route add 10.0.0.0/8 via "$gw" dev $IFACE

    # keep Docker’s original default route for Internet access
    DEF_GW=$(ip route | awk '/default/ {print $3; exit}')
    ip route replace default via "$DEF_GW" dev eth0 metric 100

    # real resolver
    printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
    break
  fi
done < "$CFG"

###############################################################################
# 2. ── K3s + Liqo only for “client*” nodes ───────────────────────────────────
###############################################################################
case "$HOSTNAME" in
  client*)
    HUB="client26"
    HUB_IP="10.0.2.216"
    CHART="/liqo-chart.tgz"
    TOKEN_FILE="/shared/token"

    if [ "$HOSTNAME" = "$HUB" ]; then
      # ─── Hub: K3s server ────────────────────────────────────────────────
      if [ ! -S /run/k3s/k3s.sock ]; then
        echo "[INIT] starting K3s server on hub"
        k3s server \
          --disable traefik \
          --flannel-iface        "$IFACE" \                    # ►❷
          --advertise-address    "$NODE_IP" \                  # ►❷
          --node-ip              "$NODE_IP" \                  # ►❷
          --node-external-ip     "$NODE_IP" \                  # ►❷
          --node-name            "$HOSTNAME" \
          -v 2 >/tmp/k3s.log 2>&1 &
      fi
      # wait until API answers, then export the join-token
      until k3s kubectl get nodes >/dev/null 2>&1; do sleep 2; done
      cat /var/lib/rancher/k3s/server/node-token > "$TOKEN_FILE"

    else
      # ─── Spoke: wait up to 300 s for token, then start agent ───────────
      for _ in $(seq 1 150); do
        [ -s "$TOKEN_FILE" ] && break
        sleep 2
      done
      TOKEN=$(cat "$TOKEN_FILE" 2>/dev/null || true)
      if [ -n "$TOKEN" ] && [ ! -S /run/k3s/agent.sock ]; then
        echo "[INIT] starting K3s agent on $HOSTNAME"
        k3s agent \
          --server "https://${HUB_IP}:6443" \
          --token  "$TOKEN" \
          --flannel-iface     "$IFACE" \                       # ►❸
          --node-ip           "$NODE_IP" \                     # ►❸
          --node-external-ip  "$NODE_IP" \                     # ►❸
          --node-name         "$HOSTNAME" \
          -v 2 >/tmp/k3s.log 2>&1 &
      fi
      # wait up to 300 s for kubeconfig so Liqo can use it
      for _ in $(seq 1 150); do
        [ -f /etc/rancher/k3s/k3s.yaml ] && break
        sleep 2
      done
    fi

    # ── Install Liqo (idempotent; skips if already present) ────────────────
    if ! k3s kubectl -n liqo get deploy liqo-controller-manager \
          >/dev/null 2>&1; then
      echo "[INIT] installing Liqo on $HOSTNAME"
      if [ "$HOSTNAME" = "$HUB" ]; then
        liqoctl install k3s --cluster-id "$HOSTNAME" \
          --disable-kernel-version-check --disable-telemetry --skip-confirm \
          --kubeconfig /etc/rancher/k3s/k3s.yaml \
          --local-chart-path "$CHART"
      else
        liqoctl install k3s --cluster-id "$HOSTNAME" \
          --disable-kernel-version-check --disable-telemetry --skip-confirm \
          --kubeconfig /etc/rancher/k3s/k3s.yaml
        liqoctl peer --cluster-id "$HUB" --gateway "$HUB_IP" --skip-confirm \
          --kubeconfig /etc/rancher/k3s/k3s.yaml || true
      fi
    fi
    ;;
  *)
    echo "[INIT] $HOSTNAME is not in the client ring – skipping K3s/Liqo"
    ;;
esac

echo "[INIT] done on $HOSTNAME"
exit 0
