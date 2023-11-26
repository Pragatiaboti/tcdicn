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
docker network create cs7ns1-18-basic-ABC
docker create --name cs7ns1-18-basic-A --network cs7ns1-18-basic-ABC -e "TCDICN_VERBOSITY=dbug" -e "TCDICN_ID=A" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/B.pub.pem,/C.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=drone.py" cs7ns1-18
docker create --name cs7ns1-18-basic-B --network cs7ns1-18-basic-ABC -e "TCDICN_VERBOSITY=dbug" -e "TCDICN_ID=B" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/A.pub.pem,/C.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=inspector.py" -e "KNOWN_DRONES=A" cs7ns1-18
docker create --name cs7ns1-18-basic-C --network cs7ns1-18-basic-ABC -e "TCDICN_VERBOSITY=dbug" -e "TCDICN_ID=C" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/A.pub.pem,/B.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=controller.py" -e "KNOWN_DRONES=A" cs7ns1-18

# Generate keypairs and distribute public keys
openssl genrsa -out "$tmp/A.pem" 2048 && openssl rsa -in "$tmp/A.pem" -pubout -out "$tmp/A.pub.pem" && docker cp "$tmp/A.pem" cs7ns1-18-basic-A:/key.pem || exit 1
openssl genrsa -out "$tmp/B.pem" 2048 && openssl rsa -in "$tmp/B.pem" -pubout -out "$tmp/B.pub.pem" && docker cp "$tmp/B.pem" cs7ns1-18-basic-B:/key.pem || exit 1
openssl genrsa -out "$tmp/C.pem" 2048 && openssl rsa -in "$tmp/C.pem" -pubout -out "$tmp/C.pub.pem" && docker cp "$tmp/C.pem" cs7ns1-18-basic-C:/key.pem || exit 1
docker cp "$tmp/A.pub.pem" cs7ns1-18-basic-B:/ || exit 1
docker cp "$tmp/A.pub.pem" cs7ns1-18-basic-C:/ || exit 1
docker cp "$tmp/B.pub.pem" cs7ns1-18-basic-A:/ || exit 1
docker cp "$tmp/B.pub.pem" cs7ns1-18-basic-C:/ || exit 1
docker cp "$tmp/C.pub.pem" cs7ns1-18-basic-A:/ || exit 1
docker cp "$tmp/C.pub.pem" cs7ns1-18-basic-B:/ || exit 1

echo
echo "Run each of the following commands in different terminals to run the simulated nodes:"
echo "  docker start -a cs7ns1-18-basic-A"
echo "  docker start -a cs7ns1-18-basic-B"
echo "  docker start -a cs7ns1-18-basic-C"
echo "Use Control-C to shutdown a node, then restart it again with the same command."
echo "Alternatively, run the following command to start all simulated nodes at once:"
echo "  docker start cs7ns1-18-basic-A cs7ns1-18-basic-B cs7ns1-18-basic-C"
echo "Then attach to the nodes you care about with a command like:"
echo "  docker logs --follow cs7ns1-18-basic-A"
echo "Rerun this script with \"TCDICN_VERBOSITY=dbug \" prepended to get more verbose output from containers."
echo
read -p "Press Enter to stop simulation..."

# Clean up
docker rm --force $(docker ps --all --quiet --filter "name=cs7ns1-18-basic-") 2>/dev/null
docker network rm $(docker network ls --quiet --filter "name=cs7ns1-18-basic-") 2>/dev/null
rm -r "$tmp" 2>/dev/null
