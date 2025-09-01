#!/bin/bash

clients_and_edges=(
  client1 client2 client3 client4 client5 client6 client7 client8 client9 client10
  client11 client12 client13 client14 client15 client16 client17 client18 client19 client20
  client21 client22 client23 client24 client25 client26 client27 client28 client29 client30
  client31 client32 client33 client34 client35 client36 client37 client38 client39 client40
  client41 client42 client43 client44 client45 client46 client47 client48 client49 client50
  client51
  Edge_server1 Edge_server2 Edge_server3 Edge_server4 Edge_server5 Edge_server6 Edge_server7 Edge_server8 Edge_server9
)

echo -e "Ping Matrix (eth1):\n"

for src in "${clients_and_edges[@]}"; do
  echo -n "$src: "
  for dst in "${clients_and_edges[@]}"; do
    if [ "$src" != "$dst" ]; then
      ip=$(docker exec clab-frr01-"$dst" ip -4 addr show dev eth1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
      if docker exec clab-frr01-"$src" ping -I eth1 -c 1 -W 1 "$ip" &>/dev/null; then
        echo -n "✔ "
      else
        echo -n "✘ "
      fi
    else
      echo -n "- "
    fi
  done
  echo
done