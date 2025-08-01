# #!/bin/bash

HOSTNAME=$(hostname)
CONFIG_FILE="/ip-mapping.txt"

echo "[INIT] Configuring IP for $HOSTNAME using $CONFIG_FILE"

while read name ip gw; do
  if [ "$HOSTNAME" = "$name" ]; then
    echo "[INIT] Setting IP $ip with GW $gw on eth1"
    ip link set dev eth1 up
    ip addr flush dev eth1
    ip route flush table main
    ip addr add "$ip" dev eth1
    ip route add 10.0.0.0/8 via "$gw" dev eth1
    echo "[INIT] Done."
    exit 0
  fi
done < "$CONFIG_FILE"

echo "[INIT] No IP mapping found for $HOSTNAME"
exit 1

