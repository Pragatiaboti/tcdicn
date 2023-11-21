#!/bin/sh

hash docker openssl || exit 1
shopt -s nullglob
docker build --tag cs7ns1-18 --file ./simulations/docker/Dockerfile . || exit 1
tmp="$(mktemp --directory || exit 1)"

echo
echo "Setting up simulation..."
echo
echo '   A   '
echo '  / \  '
echo ' B - C '
echo
echo "A is a drone in group 1 with the public keys of B and C"
echo "B is an inspector in group 1 with the public keys of A and C"
echo "C is a controller in group 1 with the public keys of A and B"
echo

# Create networks and containers
docker network create --attachable cs7ns1-18-basic-ABC
docker create --name cs7ns1-18-basic-A --network cs7ns1-18-basic-ABC -e "TCDICN_ID=A" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/B.public.pem,/C.public.pem" -e "SCRIPT=drone.py" cs7ns1-18
docker create --name cs7ns1-18-basic-B --network cs7ns1-18-basic-ABC -e "TCDICN_ID=B" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/A.public.pem,/C.public.pem" -e "SCRIPT=inspector.py" cs7ns1-18
docker create --name cs7ns1-18-basic-C --network cs7ns1-18-basic-ABC -e "TCDICN_ID=C" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/A.public.pem,/B.public.pem" -e "SCRIPT=controller.py" cs7ns1-18

# Generate keypairs and distribute public keys
openssl genrsa -out "$tmp/A.pem" 2048 && openssl rsa -in "$tmp/A.pem" -pubout -out "$tmp/A.public.pem" && docker cp "$tmp/A.pem" cs7ns1-18-basic-A:/key.pem || exit 1
openssl genrsa -out "$tmp/B.pem" 2048 && openssl rsa -in "$tmp/B.pem" -pubout -out "$tmp/B.public.pem" && docker cp "$tmp/B.pem" cs7ns1-18-basic-B:/key.pem || exit 1
openssl genrsa -out "$tmp/C.pem" 2048 && openssl rsa -in "$tmp/C.pem" -pubout -out "$tmp/C.public.pem" && docker cp "$tmp/C.pem" cs7ns1-18-basic-C:/key.pem || exit 1
docker cp "$tmp/A.public.pem" cs7ns1-18-basic-B:/ || exit 1
docker cp "$tmp/A.public.pem" cs7ns1-18-basic-C:/ || exit 1
docker cp "$tmp/B.public.pem" cs7ns1-18-basic-A:/ || exit 1
docker cp "$tmp/B.public.pem" cs7ns1-18-basic-C:/ || exit 1
docker cp "$tmp/C.public.pem" cs7ns1-18-basic-A:/ || exit 1
docker cp "$tmp/C.public.pem" cs7ns1-18-basic-B:/ || exit 1

echo
echo "Run each of the following commands in different terminals to run the simulated nodes:"
echo "  docker start -a cs7ns1-18-basic-A"
echo "  docker start -a cs7ns1-18-basic-B"
echo "  docker start -a cs7ns1-18-basic-C"
echo "Use Control-C to shutdown a node, then restart it again with the same command."
echo
read -p "Press Enter to stop simulation..."

# Clean up
docker rm --force $(docker ps --all --quiet --filter "name=cs7ns1-18-basic-") 2>/dev/null
docker network rm $(docker network ls --quiet --filter "name=cs7ns1-18-basic-") 2>/dev/null
rm -r "$tmp" 2>/dev/null
