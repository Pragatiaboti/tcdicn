#!/bin/sh

hash docker openssl || exit 1
shopt -s nullglob
docker build --tag cs7ns1-18 --file ./simulations/docker/Dockerfile . || exit 1
tmp="$(mktemp --directory || exit 1)"

echo
echo "Setting up simulation..."
echo
echo '   A       D   '
echo '    \     /    '
echo ' B - X - Y - E '
echo '    /     \    '
echo '   C       F   '
echo
echo "A is a drone in group 1 with the public key of F"
echo "B is an inspector in group 2 with the public key of C"
echo "C is a controller in group 1 with the public keys of F and in group 2 with the public keys of B, D and F"
echo "D is a drone in group 2 with the public key of C"
echo "E is an inspector in group 1 with the public key of F"
echo "F is a controller in group 1 with the public keys of A, C and E and in group 2 with the public keys of C"
echo "X and Y are nodes"
echo

# Create networks and containers
docker network create cs7ns1-18-groups-AX
docker network create cs7ns1-18-groups-BX
docker network create cs7ns1-18-groups-CX
docker network create cs7ns1-18-groups-DY
docker network create cs7ns1-18-groups-EY
docker network create cs7ns1-18-groups-FY
docker network create cs7ns1-18-groups-XY
docker create --name cs7ns1-18-groups-A -e "TCDICN_ID=A" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/F.public.pem"                                             -e "SCRIPT=drone.py" cs7ns1-18
docker create --name cs7ns1-18-groups-B -e "TCDICN_ID=B" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=2:/C.public.pem"                                             -e "SCRIPT=inspector.py" cs7ns1-18
docker create --name cs7ns1-18-groups-C -e "TCDICN_ID=C" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/F.public.pem 2:/B.public.pem,/D.public.pem,/F.public.pem" -e "SCRIPT=controller.py" cs7ns1-18
docker create --name cs7ns1-18-groups-D -e "TCDICN_ID=D" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=2:/C.public.pem"                                             -e "SCRIPT=drone.py" cs7ns1-18
docker create --name cs7ns1-18-groups-E -e "TCDICN_ID=E" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/F.public.pem"                                             -e "SCRIPT=inspector.py" cs7ns1-18
docker create --name cs7ns1-18-groups-F -e "TCDICN_ID=F" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/A.public.pem,/C.public.pem,/E.public.pem 2:/C.public.pem" -e "SCRIPT=controller.py" cs7ns1-18
docker create --name cs7ns1-18-groups-X -e "SCRIPT=node.py" cs7ns1-18
docker create --name cs7ns1-18-groups-Y -e "SCRIPT=node.py" cs7ns1-18

# Generate keypairs and distribute public keys
openssl genrsa -out "$tmp/A.pem" 2048 && openssl rsa -in "$tmp/A.pem" -pubout -out "$tmp/A.public.pem" && docker cp "$tmp/A.pem" cs7ns1-18-groups-A:/key.pem || exit 1
openssl genrsa -out "$tmp/B.pem" 2048 && openssl rsa -in "$tmp/B.pem" -pubout -out "$tmp/B.public.pem" && docker cp "$tmp/B.pem" cs7ns1-18-groups-B:/key.pem || exit 1
openssl genrsa -out "$tmp/C.pem" 2048 && openssl rsa -in "$tmp/C.pem" -pubout -out "$tmp/C.public.pem" && docker cp "$tmp/C.pem" cs7ns1-18-groups-C:/key.pem || exit 1
openssl genrsa -out "$tmp/D.pem" 2048 && openssl rsa -in "$tmp/D.pem" -pubout -out "$tmp/D.public.pem" && docker cp "$tmp/D.pem" cs7ns1-18-groups-D:/key.pem || exit 1
openssl genrsa -out "$tmp/E.pem" 2048 && openssl rsa -in "$tmp/E.pem" -pubout -out "$tmp/E.public.pem" && docker cp "$tmp/E.pem" cs7ns1-18-groups-E:/key.pem || exit 1
openssl genrsa -out "$tmp/F.pem" 2048 && openssl rsa -in "$tmp/F.pem" -pubout -out "$tmp/F.public.pem" && docker cp "$tmp/F.pem" cs7ns1-18-groups-F:/key.pem || exit 1
docker cp "$tmp/A.public.pem" cs7ns1-18-groups-F:/ || exit 1
docker cp "$tmp/B.public.pem" cs7ns1-18-groups-C:/ || exit 1
docker cp "$tmp/C.public.pem" cs7ns1-18-groups-B:/ || exit 1
docker cp "$tmp/C.public.pem" cs7ns1-18-groups-D:/ || exit 1
docker cp "$tmp/C.public.pem" cs7ns1-18-groups-F:/ || exit 1
docker cp "$tmp/D.public.pem" cs7ns1-18-groups-C:/ || exit 1
docker cp "$tmp/E.public.pem" cs7ns1-18-groups-F:/ || exit 1
docker cp "$tmp/F.public.pem" cs7ns1-18-groups-A:/ || exit 1
docker cp "$tmp/F.public.pem" cs7ns1-18-groups-C:/ || exit 1
docker cp "$tmp/F.public.pem" cs7ns1-18-groups-E:/ || exit 1

echo
echo "Run each of the following commands in different terminals to run the simulated nodes:"
echo "  docker start -a cs7ns1-18-groups-A"
echo "  docker start -a cs7ns1-18-groups-B"
echo "  docker start -a cs7ns1-18-groups-C"
echo "  docker start -a cs7ns1-18-groups-D"
echo "  docker start -a cs7ns1-18-groups-E"
echo "  docker start -a cs7ns1-18-groups-F"
echo "  docker start -a cs7ns1-18-groups-X"
echo "  docker start -a cs7ns1-18-groups-Y"
echo "Use Control-C to shutdown a node, then restart it again with the same command."
echo
read -p "Press Enter to stop simulation..."

# Clean up
docker rm --force $(docker ps --all --quiet --filter "name=cs7ns1-18-groups-") 2>/dev/null
docker network rm $(docker network ls --quiet --filter "name=cs7ns1-18-groups-") 2>/dev/null
rm -r "$tmp" 2>/dev/null
