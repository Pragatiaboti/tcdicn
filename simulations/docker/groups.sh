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
docker create --name cs7ns1-18-groups-A --network cs7ns1-18-groups-AX -e "TCDICN_ID=A" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/F.pub.pem"                                    -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=drone.py" cs7ns1-18
docker create --name cs7ns1-18-groups-B --network cs7ns1-18-groups-BX -e "TCDICN_ID=B" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=2:/C.pub.pem"                                    -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=inspector.py" -e "KNOWN_DRONES=D" cs7ns1-18
docker create --name cs7ns1-18-groups-C --network cs7ns1-18-groups-CX -e "TCDICN_ID=C" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/F.pub.pem 2:/B.pub.pem,/D.pub.pem,/F.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=controller.py" -e "KNOWN_DRONES=A,D" cs7ns1-18
docker create --name cs7ns1-18-groups-D --network cs7ns1-18-groups-DY -e "TCDICN_ID=D" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=2:/C.pub.pem"                                    -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=drone.py" cs7ns1-18
docker create --name cs7ns1-18-groups-E --network cs7ns1-18-groups-EY -e "TCDICN_ID=E" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/F.pub.pem"                                    -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=inspector.py" -e "KNOWN_DRONES=A" cs7ns1-18
docker create --name cs7ns1-18-groups-F --network cs7ns1-18-groups-FY -e "TCDICN_ID=F" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/A.pub.pem,/C.pub.pem,/E.pub.pem 2:/C.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=controller.py" -e "KNOWN_DRONES=A,D" cs7ns1-18
docker create --name cs7ns1-18-groups-X --network cs7ns1-18-groups-XY                                                                                                                  -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=node.py" cs7ns1-18
docker create --name cs7ns1-18-groups-Y --network cs7ns1-18-groups-XY                                                                                                                  -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=node.py" cs7ns1-18
docker network connect cs7ns1-18-groups-AX cs7ns1-18-groups-X
docker network connect cs7ns1-18-groups-BX cs7ns1-18-groups-X
docker network connect cs7ns1-18-groups-CX cs7ns1-18-groups-X
docker network connect cs7ns1-18-groups-DY cs7ns1-18-groups-Y
docker network connect cs7ns1-18-groups-EY cs7ns1-18-groups-Y
docker network connect cs7ns1-18-groups-FY cs7ns1-18-groups-Y

# Generate keypairs and distribute public keys
openssl genrsa -out "$tmp/A.pem" 2048 && openssl rsa -in "$tmp/A.pem" -pubout -out "$tmp/A.pub.pem" && docker cp "$tmp/A.pem" cs7ns1-18-groups-A:/key.pem || exit 1
openssl genrsa -out "$tmp/B.pem" 2048 && openssl rsa -in "$tmp/B.pem" -pubout -out "$tmp/B.pub.pem" && docker cp "$tmp/B.pem" cs7ns1-18-groups-B:/key.pem || exit 1
openssl genrsa -out "$tmp/C.pem" 2048 && openssl rsa -in "$tmp/C.pem" -pubout -out "$tmp/C.pub.pem" && docker cp "$tmp/C.pem" cs7ns1-18-groups-C:/key.pem || exit 1
openssl genrsa -out "$tmp/D.pem" 2048 && openssl rsa -in "$tmp/D.pem" -pubout -out "$tmp/D.pub.pem" && docker cp "$tmp/D.pem" cs7ns1-18-groups-D:/key.pem || exit 1
openssl genrsa -out "$tmp/E.pem" 2048 && openssl rsa -in "$tmp/E.pem" -pubout -out "$tmp/E.pub.pem" && docker cp "$tmp/E.pem" cs7ns1-18-groups-E:/key.pem || exit 1
openssl genrsa -out "$tmp/F.pem" 2048 && openssl rsa -in "$tmp/F.pem" -pubout -out "$tmp/F.pub.pem" && docker cp "$tmp/F.pem" cs7ns1-18-groups-F:/key.pem || exit 1
docker cp "$tmp/A.pub.pem" cs7ns1-18-groups-F:/ || exit 1
docker cp "$tmp/B.pub.pem" cs7ns1-18-groups-C:/ || exit 1
docker cp "$tmp/C.pub.pem" cs7ns1-18-groups-B:/ || exit 1
docker cp "$tmp/C.pub.pem" cs7ns1-18-groups-D:/ || exit 1
docker cp "$tmp/C.pub.pem" cs7ns1-18-groups-F:/ || exit 1
docker cp "$tmp/D.pub.pem" cs7ns1-18-groups-C:/ || exit 1
docker cp "$tmp/E.pub.pem" cs7ns1-18-groups-F:/ || exit 1
docker cp "$tmp/F.pub.pem" cs7ns1-18-groups-A:/ || exit 1
docker cp "$tmp/F.pub.pem" cs7ns1-18-groups-C:/ || exit 1
docker cp "$tmp/F.pub.pem" cs7ns1-18-groups-E:/ || exit 1

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
echo "Alternatively, run the following command to start all simulated nodes at once:"
echo "  docker start cs7ns1-18-groups-A cs7ns1-18-groups-B cs7ns1-18-groups-C cs7ns1-18-groups-D cs7ns1-18-groups-E cs7ns1-18-groups-F cs7ns1-18-groups-X cs7ns1-18-groups-Y"
echo "Then attach to the nodes you care about with a command like:"
echo "  docker logs --follow cs7ns1-18-groups-A"
echo "Rerun this script with \"TCDICN_VERBOSITY=dbug \" prepended to get more verbose output from containers."
echo
read -p "Press Enter to stop simulation..."

# Clean up
docker rm --force $(docker ps --all --quiet --filter "name=cs7ns1-18-groups-") 2>/dev/null
docker network rm $(docker network ls --quiet --filter "name=cs7ns1-18-groups-") 2>/dev/null
rm -r "$tmp" 2>/dev/null
