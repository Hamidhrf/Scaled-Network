#!/usr/bin/env bash
set -euo pipefail

LAB="frr01"

# ========= Node groups =========
OSPF_100=(router3 router11)
OSPF_400=(router7 router10)
OSPF_500=(router4 router5 router12)
BGPNODES=(router1 router3 router4 router7)

# All clients + edges on eth1 (your set)
CLIENTS_EDGES=(
  client1 client2 client3 client4 client5 client6 client7 client8 client9 client10
  client11 client12 client13 client14 client15 client16 client17 client18 client19 client20
  client21 client22 client23 client24 client25 client26 client27
  Edge_server1 Edge_server2 Edge_server3 Edge_server4 Edge_server5 Edge_server6 Edge_server7 Edge_server8
)

# ========= Helpers =========
container() { echo "clab-${LAB}-${1}"; }
dex() { docker exec -it "$(container "$1")" bash -lc "$2"; }

echo "== Sanity: containers present =="
ALL_NODES=("${OSPF_100[@]}" "${OSPF_400[@]}" "${OSPF_500[@]}" "${BGPNODES[@]}" "${CLIENTS_EDGES[@]}")
# de-dup set
declare -A seen; NODES=()
for n in "${ALL_NODES[@]}"; do [[ ${seen[$n]:-} ]] || { seen[$n]=1; NODES+=("$n"); }; done
for n in "${NODES[@]}"; do
  if docker inspect -f '{{.State.Status}}' "$(container "$n")" >/dev/null 2>&1; then
    printf "  %-14s %s\n" "$n" "OK"
  else
    printf "  %-14s %s\n" "$n" "MISSING"
  fi
done

echo -e "\n== clab inspect =="
containerlab inspect -t "${LAB}.clab.yml" || true   # purely informational
# Docs: containerlab inspect shows deployed labs, nodes & links
# https://containerlab.dev/cmd/inspect/

echo -e "\n== OSPF neighbors (expect FULL) =="
check_ospf() {
  local n="$1"
  echo "---- $n ----"
  dex "$n" 'vtysh -c "show ip ospf neighbor" || true'
  dex "$n" 'vtysh -c "show ip ospf neighbor" | awk "/Full/ {c++} END{print \"FULL neighbors:\",(c+0)}"'
}
for n in "${OSPF_100[@]}" "${OSPF_400[@]}" "${OSPF_500[@]}"; do check_ospf "$n"; done
# FRR vtysh + per-interface OSPF: https://docs.frrouting.org/en/latest/ospfd.html

echo -e "\n== BGP summary on BGP speakers =="
for n in "${BGPNODES[@]}"; do
  echo "---- $n ----"
  dex "$n" 'vtysh -c "show ip bgp summary" || true'
done
# vtysh basics & integrated config: https://docs.frrouting.org/en/latest/basic.html

echo -e "\n== Client route sanity (10.0.0.0/8 via eth1 gw) =="
for n in "${CLIENTS_EDGES[@]}"; do
  echo "---- $n ----"
  dex "$n" 'ip r | (grep -E "^10\.0\.0\.0/8.*dev eth1" || echo "no 10/8 route on eth1")'
done

echo -e "\n== Ping Matrix (eth1) =="
# Resolve each node's eth1 IPv4 once
declare -A IPMAP
for n in "${CLIENTS_EDGES[@]}"; do
  IPMAP["$n"]=$(docker exec "$(container "$n")" sh -lc "ip -4 -o addr show dev eth1 | awk '{print \$4}' | cut -d/ -f1 | head -n1" || true)
done

# Header row
printf "%-12s" ""
for d in "${CLIENTS_EDGES[@]}"; do printf "%-3s" "${d:0:2}"; done
echo

for src in "${CLIENTS_EDGES[@]}"; do
  printf "%-12s" "${src}:"
  for dst in "${CLIENTS_EDGES[@]}"; do
    if [[ "$src" == "$dst" ]]; then printf " - "; continue; fi
    ip="${IPMAP[$dst]}"
    if [[ -z "$ip" ]]; then printf " ? "; continue; fi
    if docker exec "$(container "$src")" ping -I eth1 -c1 -W1 "$ip" >/dev/null 2>&1; then
      printf " ✔ "
    else
      printf " ✘ "
    fi
  done
  echo
done

echo -e "\n== Optional traceroutes (if installed) =="
dex client1 'command -v traceroute >/dev/null && traceroute -n -I -w1 -q1 10.0.5.74 || echo "client1: traceroute not installed"'
dex client7  'command -v traceroute >/dev/null && traceroute -n -I -w1 -q1 10.0.2.204 || echo "client7: traceroute not installed"'

echo -e "\nDone."
