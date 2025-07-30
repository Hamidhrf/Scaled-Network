#!/bin/sh

sudo docker exec -d clab-frr01-client1 ip link set eth1 up
sudo docker exec -d clab-frr01-client1 ip addr add 10.0.3.10/25 brd 10.0.3.127 dev eth1
sudo docker exec -d clab-frr01-client1 ip route add 10.0.0.0/8 via 10.0.3.1 dev eth1
#sudo docker exec -d clab-frr01-client1 ip route add 10.10.10.0/24 via 10.0.3.1/25 dev eth1

sudo docker exec -d clab-frr01-client2 ip link set eth1 up
sudo docker exec -d clab-frr01-client2 ip addr add 10.0.3.15/25 brd 10.0.3.127 dev eth1
sudo docker exec -d clab-frr01-client2 ip route add 10.0.0.0/8 via 10.0.3.1 dev eth1
#sudo docker exec -d clab-frr01-client2 ip route add 10.10.10.0/24 via 10.0.3.1/25 dev eth1

sudo docker exec -d clab-frr01-client3 ip link set eth1 up
sudo docker exec -d clab-frr01-client3 ip addr add 10.0.3.18/25 brd 10.0.3.127 dev eth1
sudo docker exec -d clab-frr01-client3 ip route add 10.0.0.0/8 via 10.0.3.1 dev eth1
#sudo docker exec -d clab-frr01-client3 ip route add 10.10.10.0/24 via 10.0.3.1/25 dev eth1

sudo docker exec -d clab-frr01-client4 ip link set eth1 up
sudo docker exec -d clab-frr01-client4 ip addr add 10.0.3.5/25 brd 10.0.3.127 dev eth1
sudo docker exec -d clab-frr01-client4 ip route add 10.0.0.0/8 via 10.0.3.1 dev eth1
#sudo docker exec -d clab-frr01-client4 ip route add 10.10.10.0/24 via 10.0.3.1/25 dev eth1

sudo docker exec -d clab-frr01-client5 ip link set eth1 up
sudo docker exec -d clab-frr01-client5 ip addr add 10.0.3.6/25  brd 10.0.3.127 dev eth1
sudo docker exec -d clab-frr01-client5 ip route add 10.0.0.0/8 via 10.0.3.1 dev eth1
#sudo docker exec -d clab-frr01-client5 ip route add 10.10.10.0/24 via 10.0.3.1/25 dev eth1

sudo docker exec -d clab-frr01-client6 ip link set eth1 up
sudo docker exec -d clab-frr01-client6 ip addr add 10.0.3.7/25 brd 10.0.3.127 dev eth1
sudo docker exec -d clab-frr01-client6 ip route add 10.0.0.0/8 via 10.0.3.1 dev eth1
#sudo docker exec -d clab-frr01-client6 ip route add 10.10.10.0/24 via 10.0.3.1/25 dev eth1

sudo docker exec -d clab-frr01-client27 ip link set eth1 up
sudo docker exec -d clab-frr01-client27 ip addr add 10.0.3.9/25 brd 10.0.3.127 dev eth1
sudo docker exec -d clab-frr01-client27 ip route add 10.0.0.0/8 via 10.0.3.1 dev eth1

sudo docker exec -d clab-frr01-Edge_server1 ip link set eth1 up
sudo docker exec -d clab-frr01-Edge_server1 ip addr add 10.0.3.12/25 brd 10.0.3.127 dev eth1
sudo docker exec -d clab-frr01-Edge_server1 ip route add 10.0.0.0/8 via 10.0.3.1 dev eth1
#sudo docker exec -d clab-frr01-Edge_server1 ip route add 10.10.10.0/24 via 10.0.3.1/25 dev eth1

sudo docker exec -d clab-frr01-Edge_server2 ip link set eth1 up
sudo docker exec -d clab-frr01-Edge_server2 ip addr add 10.0.3.135/25 brd 10.0.3.255 dev eth1
sudo docker exec -d clab-frr01-Edge_server2 ip route add 10.0.0.0/8 via 10.0.3.129 dev eth1
#sudo docker exec -d clab-frr01-Edge_server2 ip route add 10.10.10.0/24 via 10.0.3.1/25 dev eth1

sudo docker exec -d clab-frr01-Edge_server3 ip link set eth1 up
sudo docker exec -d clab-frr01-Edge_server3 ip addr add 10.0.5.130/25 brd 10.0.5.255 dev eth1
sudo docker exec -d clab-frr01-Edge_server3 ip route add 10.0.0.0/8 via 10.0.5.129 dev eth1
#sudo docker exec -d clab-frr01-Edge_server3 ip route add 10.10.10.0/24 via 10.0.3.1/25 dev eth1

sudo docker exec -d clab-frr01-client7 ip link set eth1 up
sudo docker exec -d clab-frr01-client7 ip addr add 10.0.5.74/26 brd 10.0.5.127 dev eth1
sudo docker exec -d clab-frr01-client7 ip route add 10.0.0.0/8 via 10.0.5.65  dev eth1
#sudo docker exec -d clab-frr01-client7 ip route add 10.10.10.0/24 via 10.0.5.65/26 dev eth1

sudo docker exec -d clab-frr01-client8 ip link set eth1 up
sudo docker exec -d clab-frr01-client8 ip addr add 10.0.5.72/26 brd 10.0.5.127 dev eth1
sudo docker exec -d clab-frr01-client8 ip route add 10.0.0.0/8 via 10.0.5.65  dev eth1
#sudo docker exec -d clab-frr01-client8 ip route add 10.10.10.0/24 via 10.0.5.65/26 dev eth1

sudo docker exec -d clab-frr01-client9 ip link set eth1 up
sudo docker exec -d clab-frr01-client9 ip addr add 10.0.5.75/26 brd 10.0.5.127 dev eth1
sudo docker exec -d clab-frr01-client9 ip route add 10.0.0.0/8 via 10.0.5.65 dev eth1
#sudo docker exec -d clab-frr01-client9 ip route add 10.10.10.0/24 via 10.0.5.65/26 dev eth1

sudo docker exec -d clab-frr01-client10 ip link set eth1 up
sudo docker exec -d clab-frr01-client10 ip addr add 10.0.5.76/26 brd 10.0.5.127 dev eth1
sudo docker exec -d clab-frr01-client10 ip route add 10.0.0.0/8 via 10.0.5.65 dev eth1
#sudo docker exec -d clab-frr01-client10 ip route add 10.10.10.0/24 via 10.0.5.65/26 dev eth1

sudo docker exec -d clab-frr01-client11 ip link set eth1 up
sudo docker exec -d clab-frr01-client11 ip addr add 10.0.5.77/26 brd 10.0.5.127 dev eth1
sudo docker exec -d clab-frr01-client11 ip route add 10.0.0.0/8 via 10.0.5.65 dev eth1
#sudo docker exec -d clab-frr01-client11 ip route add 10.10.10.0/24 via 10.0.5.65/26 dev eth1

sudo docker exec -d clab-frr01-client12 ip link set eth1 up
sudo docker exec -d clab-frr01-client12 ip addr add 10.0.5.78/26 brd 10.0.5.127 dev eth1
sudo docker exec -d clab-frr01-client12 ip route add 10.0.0.0/8 via 10.0.5.65  dev eth1
#sudo docker exec -d clab-frr01-client12 ip route add 10.10.10.0/24 via 10.0.5.65/26 dev eth1


sudo docker exec -d clab-frr01-client13 ip link set eth1 up
sudo docker exec -d clab-frr01-client13 ip addr add 10.0.5.79/26 brd 10.0.5.127 dev eth1
sudo docker exec -d clab-frr01-client13 ip route add 10.0.0.0/8 via 10.0.5.65  dev eth1
#sudo docker exec -d clab-frr01-client13 ip route add 10.10.10.0/24 via 10.0.5.65/26 dev eth1


sudo docker exec -d clab-frr01-client14 ip link set eth1 up
sudo docker exec -d clab-frr01-client14 ip addr add 10.0.5.80/26 brd 10.0.5.127 dev eth1
sudo docker exec -d clab-frr01-client14 ip route add 10.0.0.0/8 via 10.0.5.65  dev eth1
#sudo docker exec -d clab-frr01-client14 ip route add 10.10.10.0/24 via 10.0.5.65/26 dev eth1


sudo docker exec -d clab-frr01-client15 ip link set eth1 up
sudo docker exec -d clab-frr01-client15 ip addr add 10.0.5.81/26 brd 10.0.5.127 dev eth1
sudo docker exec -d clab-frr01-client15 ip route add 10.0.0.0/8 via 10.0.5.65 dev eth1
#sudo docker exec -d clab-frr01-client15 ip route add 10.10.10.0/24 via 10.0.5.65/26 dev eth1


sudo docker exec -d clab-frr01-Edge_server4 ip link set eth1 up
sudo docker exec -d clab-frr01-Edge_server4 ip addr add 10.0.5.66/26 brd 10.0.5.127 dev eth1
sudo docker exec -d clab-frr01-Edge_server4 ip route add 10.0.0.0/8 via 10.0.5.65 dev eth1
#sudo docker exec -d clab-frr01-Edge_server4 ip route add 10.10.10.0/24 via 10.0.5.65/26 dev eth1


sudo docker exec -d clab-frr01-Edge_server5 ip link set eth1 up
sudo docker exec -d clab-frr01-Edge_server5 ip addr add 10.0.1.10/25 brd 10.0.1.255 dev eth1
sudo docker exec -d clab-frr01-Edge_server5 ip route add 10.0.0.0/8 via 10.0.1.1 dev eth1
#sudo docker exec -d clab-frr01-Edge_server5 ip route add 10.10.10.0/24 via 10.0.1.1/25 dev eth1


sudo docker exec -d clab-frr01-Edge_server6 ip link set eth1 up
sudo docker exec -d clab-frr01-Edge_server6 ip addr add 10.0.4.30/25 brd 10.0.4.255 dev eth1
sudo docker exec -d clab-frr01-Edge_server6 ip route add 10.0.0.0/8 via 10.0.4.1 dev eth1
#sudo docker exec -d clab-frr01-Edge_server6 ip route add 10.10.10.0/24 via 10.0.4.1/25 dev eth1


sudo docker exec -d clab-frr01-Edge_server7 ip link set eth1 up
sudo docker exec -d clab-frr01-Edge_server7 ip addr add 10.0.2.226/27 brd 10.0.2.255 dev eth1
sudo docker exec -d clab-frr01-Edge_server7 ip route add 10.0.0.0/8 via 10.0.2.225 dev eth1
#sudo docker exec -d clab-frr01-Edge_server7 ip route add 10.10.10.0/24 via 10.0.2.225/27 dev eth1



sudo docker exec -d clab-frr01-client16 ip link set eth1 up
sudo docker exec -d clab-frr01-client16 ip addr add 10.0.2.204/27 brd 10.0.2.223 dev eth1
sudo docker exec -d clab-frr01-client16 ip route add 10.0.0.0/8 via 10.0.2.193 dev eth1
#sudo docker exec -d clab-frr01-client16 ip route add 10.10.10.0/24 via 10.0.2.193/27 dev eth1


sudo docker exec -d clab-frr01-client17 ip link set eth1 up
sudo docker exec -d clab-frr01-client17 ip addr add 10.0.2.205/27 brd 10.0.2.223 dev eth1
sudo docker exec -d clab-frr01-client17 ip route add 10.0.0.0/8 via 10.0.2.193 dev eth1
#sudo docker exec -d clab-frr01-client17 ip route add 10.10.10.0/24 via 10.0.2.193/27 dev eth1


sudo docker exec -d clab-frr01-client18 ip link set eth1 up
sudo docker exec -d clab-frr01-client18 ip addr add 10.0.2.206/27 brd 10.0.2.223 dev eth1
sudo docker exec -d clab-frr01-client18 ip route add 10.0.0.0/8 via 10.0.2.193 dev eth1
#sudo docker exec -d clab-frr01-client18 ip route add 10.10.10.0/24 via 10.0.2.193/27 dev eth1


sudo docker exec -d clab-frr01-client19 ip link set eth1 up
sudo docker exec -d clab-frr01-client19 ip addr add 10.0.2.207/27 brd 10.0.2.223 dev eth1
sudo docker exec -d clab-frr01-client19 ip route add 10.0.0.0/8 via 10.0.2.193 dev eth1
#sudo docker exec -d clab-frr01-client19 ip route add 10.10.10.0/24 via 10.0.2.193/27 dev eth1


sudo docker exec -d clab-frr01-client20 ip link set eth1 up
sudo docker exec -d clab-frr01-client20 ip addr add 10.0.2.208/27 brd 10.0.2.223 dev eth1
sudo docker exec -d clab-frr01-client20 ip route add 10.0.0.0/8 via 10.0.2.193 dev eth1
#sudo docker exec -d clab-frr01-client20 ip route add 10.10.10.0/24 via 10.0.2.193/27 dev eth1


sudo docker exec -d clab-frr01-client21 ip link set eth1 up
sudo docker exec -d clab-frr01-client21 ip addr add 10.0.2.209/27 brd 10.0.2.223 dev eth1
sudo docker exec -d clab-frr01-client21 ip route add 10.0.0.0/8 via 10.0.2.193 dev eth1
#sudo docker exec -d clab-frr01-client21 ip route add 10.10.10.0/24 via 10.0.2.193/27 dev eth1


sudo docker exec -d clab-frr01-client22 ip link set eth1 up
sudo docker exec -d clab-frr01-client22 ip addr add 10.0.2.210/27 brd 10.0.2.223 dev eth1
sudo docker exec -d clab-frr01-client22 ip route add 10.0.0.0/8 via 10.0.2.193 dev eth1
#sudo docker exec -d clab-frr01-client22 ip route add 10.10.10.0/24 via 10.0.2.193/27 dev eth1


sudo docker exec -d clab-frr01-client23 ip link set eth1 up
sudo docker exec -d clab-frr01-client23 ip addr add 10.0.2.211/27 brd 10.0.2.223 dev eth1
sudo docker exec -d clab-frr01-client23 ip route add 10.0.0.0/8 via 10.0.2.193 dev eth1
#sudo docker exec -d clab-frr01-client23 ip route add 10.10.10.0/24 via 10.0.2.193/27 dev eth1


sudo docker exec -d clab-frr01-client24 ip link set eth1 up
sudo docker exec -d clab-frr01-client24 ip addr add 10.0.2.212/27 brd 10.0.2.223 dev eth1
sudo docker exec -d clab-frr01-client24 ip route add 10.0.0.0/8 via 10.0.2.193 dev eth1
#sudo docker exec -d clab-frr01-client24 ip route add 10.10.10.0/24 via 10.0.2.193/27 dev eth1


sudo docker exec -d clab-frr01-client25 ip link set eth1 up
sudo docker exec -d clab-frr01-client25 ip addr add 10.0.2.213/27 brd 10.0.2.223 dev eth1
sudo docker exec -d clab-frr01-client25 ip route add 10.0.0.0/8 via 10.0.2.193 dev eth1
#sudo docker exec -d clab-frr01-client25 ip route add 10.10.10.0/24 via 10.0.2.193/27 dev eth1

sudo docker exec -d clab-frr01-client26 ip link set eth1 up
sudo docker exec -d clab-frr01-client26 ip addr add 10.0.2.216/27 brd 10.0.2.223 dev eth1
sudo docker exec -d clab-frr01-client26 ip route add 10.0.0.0/8 via 10.0.2.193 dev eth1

sudo docker exec -d clab-frr01-Edge_server8 ip link set eth1 up
sudo docker exec -d clab-frr01-Edge_server8 ip addr add 10.0.2.214/27 brd 10.0.2.223 dev eth1
sudo docker exec -d clab-frr01-Edge_server8 ip route add 10.0.0.0/8 via 10.0.2.193 dev eth1
#sudo docker exec -d clab-frr01-Edge_server8 ip route add 10.10.10.0/24 via 10.0.2.193/27 dev eth1

