#!/bin/sh

hash docker openssl || exit 1
shopt -s nullglob
docker build --tag cs7ns1-18 --file ./simulations/docker/Dockerfile . || exit 1
tmp="$(mktemp --directory || exit 1)"

echo
echo "Setting up simulation..."
echo
echo '   A   E   H - K - N   '
echo '  /   /   / \     / \  '
echo ' B - D - G   J - M   P '
echo '    /   / \ /   /   /  '
echo '   C   F - I   L   O   '
echo
echo "A and H are drones in group 1"
echo "B and L are drones in group 2"
echo "I and O are drones in group 3"
echo "D and M are inspectors in group 1"
echo "E and G are inspectors in group 2"
echo "F and P are inspectors in group 3"
echo "C is a controller in group 1"
echo "J is a controller in group 2"
echo "N is a controller in group 3"
echo
echo "Good luck!"
echo

# Create networks and containers
docker network create cs7ns1-18-huge-AB
docker network create cs7ns1-18-huge-BD
docker network create cs7ns1-18-huge-CD
docker network create cs7ns1-18-huge-DE
docker network create cs7ns1-18-huge-DG
docker network create cs7ns1-18-huge-FGI
docker network create cs7ns1-18-huge-GH
docker network create cs7ns1-18-huge-HJ
docker network create cs7ns1-18-huge-IJ
docker network create cs7ns1-18-huge-HK
docker network create cs7ns1-18-huge-JM
docker network create cs7ns1-18-huge-KN
docker network create cs7ns1-18-huge-LM
docker network create cs7ns1-18-huge-MN
docker network create cs7ns1-18-huge-NP
docker network create cs7ns1-18-huge-OP
docker create --name cs7ns1-18-huge-A --network cs7ns1-18-huge-AB  -e "TCDICN_ID=A" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/C.pub.pem,D.pub.pem,H.pub.pem,M.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=drone.py" cs7ns1-18
docker create --name cs7ns1-18-huge-B --network cs7ns1-18-huge-AB  -e "TCDICN_ID=B" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=2:/E.pub.pem,G.pub.pem,J.pub.pem,L.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=drone.py" cs7ns1-18
docker create --name cs7ns1-18-huge-C --network cs7ns1-18-huge-CD  -e "TCDICN_ID=C" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/A.pub.pem,D.pub.pem,H.pub.pem,M.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=controller.py" -e "KNOWN_DRONES=A,H" cs7ns1-18
docker create --name cs7ns1-18-huge-D --network cs7ns1-18-huge-BD  -e "TCDICN_ID=D" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/A.pub.pem,C.pub.pem,H.pub.pem,M.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=inspector.py" -e "KNOWN_DRONES=A,H" cs7ns1-18
docker create --name cs7ns1-18-huge-E --network cs7ns1-18-huge-DE  -e "TCDICN_ID=E" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=2:/B.pub.pem,G.pub.pem,J.pub.pem,L.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=inspector.py" -e "KNOWN_DRONES=B,L" cs7ns1-18
docker create --name cs7ns1-18-huge-F --network cs7ns1-18-huge-FGI -e "TCDICN_ID=F" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=3:/I.pub.pem,N.pub.pem,O.pub.pem,P.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=inspector.py" -e "KNOWN_DRONES=I,O" cs7ns1-18
docker create --name cs7ns1-18-huge-G --network cs7ns1-18-huge-FGI -e "TCDICN_ID=G" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=2:/B.pub.pem,E.pub.pem,J.pub.pem,L.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=inspector.py" -e "KNOWN_DRONES=B,L" cs7ns1-18
docker create --name cs7ns1-18-huge-H --network cs7ns1-18-huge-GH  -e "TCDICN_ID=H" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/A.pub.pem,C.pub.pem,D.pub.pem,M.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=drone.py" cs7ns1-18
docker create --name cs7ns1-18-huge-I --network cs7ns1-18-huge-FGI -e "TCDICN_ID=I" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=3:/F.pub.pem,N.pub.pem,O.pub.pem,P.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=drone.py" cs7ns1-18
docker create --name cs7ns1-18-huge-J --network cs7ns1-18-huge-HJ  -e "TCDICN_ID=J" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=2:/B.pub.pem,E.pub.pem,G.pub.pem,L.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=controller.py" -e "KNOWN_DRONES=B,L" cs7ns1-18
docker create --name cs7ns1-18-huge-K --network cs7ns1-18-huge-HK                                                                                                              -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=node.py" cs7ns1-18
docker create --name cs7ns1-18-huge-L --network cs7ns1-18-huge-LM  -e "TCDICN_ID=L" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=2:/B.pub.pem,E.pub.pem,G.pub.pem,J.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=drone.py" cs7ns1-18
docker create --name cs7ns1-18-huge-M --network cs7ns1-18-huge-LM  -e "TCDICN_ID=M" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=1:/A.pub.pem,C.pub.pem,D.pub.pem,H.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=inspector.py" -e "KNOWN_DRONES=A,H" cs7ns1-18
docker create --name cs7ns1-18-huge-N --network cs7ns1-18-huge-KN  -e "TCDICN_ID=N" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=3:/F.pub.pem,I.pub.pem,O.pub.pem,P.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=controller.py" -e "KNOWN_DRONES=I,O" cs7ns1-18
docker create --name cs7ns1-18-huge-O --network cs7ns1-18-huge-OP  -e "TCDICN_ID=O" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=3:/F.pub.pem,I.pub.pem,N.pub.pem,P.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=inspector.py" -e "KNOWN_DRONES=I,O" cs7ns1-18
docker create --name cs7ns1-18-huge-P --network cs7ns1-18-huge-OP  -e "TCDICN_ID=P" -e "TCDICN_KEYFILE=/key.pem" -e "TCDICN_GROUPS=3:/F.pub.pem,I.pub.pem,N.pub.pem,O.pub.pem" -e "TCDICN_VERBOSITY=$TCDICN_VERBOSITY" -e "SCRIPT=drone.py" cs7ns1-18
docker network connect cs7ns1-18-huge-BD cs7ns1-18-huge-B
docker network connect cs7ns1-18-huge-CD cs7ns1-18-huge-D
docker network connect cs7ns1-18-huge-DE cs7ns1-18-huge-D
docker network connect cs7ns1-18-huge-DG cs7ns1-18-huge-D
docker network connect cs7ns1-18-huge-DG cs7ns1-18-huge-G
docker network connect cs7ns1-18-huge-GH cs7ns1-18-huge-G
docker network connect cs7ns1-18-huge-HJ cs7ns1-18-huge-H
docker network connect cs7ns1-18-huge-HK cs7ns1-18-huge-H
docker network connect cs7ns1-18-huge-IJ cs7ns1-18-huge-I
docker network connect cs7ns1-18-huge-IJ cs7ns1-18-huge-J
docker network connect cs7ns1-18-huge-JM cs7ns1-18-huge-J
docker network connect cs7ns1-18-huge-KN cs7ns1-18-huge-K
docker network connect cs7ns1-18-huge-JM cs7ns1-18-huge-M
docker network connect cs7ns1-18-huge-MN cs7ns1-18-huge-M
docker network connect cs7ns1-18-huge-KN cs7ns1-18-huge-N
docker network connect cs7ns1-18-huge-NP cs7ns1-18-huge-N
docker network connect cs7ns1-18-huge-NP cs7ns1-18-huge-P

# Generate keypairs and distribute public keys
openssl genrsa -out "$tmp/A.pem" 2048 && openssl rsa -in "$tmp/A.pem" -pubout -out "$tmp/A.pub.pem" && docker cp "$tmp/A.pem" cs7ns1-18-huge-A:/key.pem || exit 1
openssl genrsa -out "$tmp/B.pem" 2048 && openssl rsa -in "$tmp/B.pem" -pubout -out "$tmp/B.pub.pem" && docker cp "$tmp/B.pem" cs7ns1-18-huge-B:/key.pem || exit 1
openssl genrsa -out "$tmp/C.pem" 2048 && openssl rsa -in "$tmp/C.pem" -pubout -out "$tmp/C.pub.pem" && docker cp "$tmp/C.pem" cs7ns1-18-huge-C:/key.pem || exit 1
openssl genrsa -out "$tmp/D.pem" 2048 && openssl rsa -in "$tmp/D.pem" -pubout -out "$tmp/D.pub.pem" && docker cp "$tmp/D.pem" cs7ns1-18-huge-D:/key.pem || exit 1
openssl genrsa -out "$tmp/E.pem" 2048 && openssl rsa -in "$tmp/E.pem" -pubout -out "$tmp/E.pub.pem" && docker cp "$tmp/E.pem" cs7ns1-18-huge-E:/key.pem || exit 1
openssl genrsa -out "$tmp/F.pem" 2048 && openssl rsa -in "$tmp/F.pem" -pubout -out "$tmp/F.pub.pem" && docker cp "$tmp/F.pem" cs7ns1-18-huge-F:/key.pem || exit 1
openssl genrsa -out "$tmp/G.pem" 2048 && openssl rsa -in "$tmp/G.pem" -pubout -out "$tmp/G.pub.pem" && docker cp "$tmp/G.pem" cs7ns1-18-huge-G:/key.pem || exit 1
openssl genrsa -out "$tmp/H.pem" 2048 && openssl rsa -in "$tmp/H.pem" -pubout -out "$tmp/H.pub.pem" && docker cp "$tmp/H.pem" cs7ns1-18-huge-H:/key.pem || exit 1
openssl genrsa -out "$tmp/I.pem" 2048 && openssl rsa -in "$tmp/I.pem" -pubout -out "$tmp/I.pub.pem" && docker cp "$tmp/I.pem" cs7ns1-18-huge-I:/key.pem || exit 1
openssl genrsa -out "$tmp/J.pem" 2048 && openssl rsa -in "$tmp/J.pem" -pubout -out "$tmp/J.pub.pem" && docker cp "$tmp/J.pem" cs7ns1-18-huge-J:/key.pem || exit 1
openssl genrsa -out "$tmp/K.pem" 2048 && openssl rsa -in "$tmp/K.pem" -pubout -out "$tmp/K.pub.pem" && docker cp "$tmp/K.pem" cs7ns1-18-huge-K:/key.pem || exit 1
openssl genrsa -out "$tmp/L.pem" 2048 && openssl rsa -in "$tmp/L.pem" -pubout -out "$tmp/L.pub.pem" && docker cp "$tmp/L.pem" cs7ns1-18-huge-L:/key.pem || exit 1
openssl genrsa -out "$tmp/M.pem" 2048 && openssl rsa -in "$tmp/M.pem" -pubout -out "$tmp/M.pub.pem" && docker cp "$tmp/M.pem" cs7ns1-18-huge-M:/key.pem || exit 1
openssl genrsa -out "$tmp/N.pem" 2048 && openssl rsa -in "$tmp/N.pem" -pubout -out "$tmp/N.pub.pem" && docker cp "$tmp/N.pem" cs7ns1-18-huge-N:/key.pem || exit 1
openssl genrsa -out "$tmp/O.pem" 2048 && openssl rsa -in "$tmp/O.pem" -pubout -out "$tmp/O.pub.pem" && docker cp "$tmp/O.pem" cs7ns1-18-huge-O:/key.pem || exit 1
openssl genrsa -out "$tmp/P.pem" 2048 && openssl rsa -in "$tmp/P.pem" -pubout -out "$tmp/P.pub.pem" && docker cp "$tmp/P.pem" cs7ns1-18-huge-P:/key.pem || exit 1
docker cp "$tmp/A.pub.pem" cs7ns1-18-huge-C:/ && docker cp "$tmp/A.pub.pem" cs7ns1-18-huge-D:/ && docker cp "$tmp/A.pub.pem" cs7ns1-18-huge-H:/ && docker cp "$tmp/A.pub.pem" cs7ns1-18-huge-M:/ || exit 1
docker cp "$tmp/B.pub.pem" cs7ns1-18-huge-E:/ && docker cp "$tmp/B.pub.pem" cs7ns1-18-huge-G:/ && docker cp "$tmp/B.pub.pem" cs7ns1-18-huge-J:/ && docker cp "$tmp/B.pub.pem" cs7ns1-18-huge-L:/ || exit 1
docker cp "$tmp/C.pub.pem" cs7ns1-18-huge-A:/ && docker cp "$tmp/C.pub.pem" cs7ns1-18-huge-D:/ && docker cp "$tmp/C.pub.pem" cs7ns1-18-huge-H:/ && docker cp "$tmp/C.pub.pem" cs7ns1-18-huge-M:/ || exit 1
docker cp "$tmp/D.pub.pem" cs7ns1-18-huge-A:/ && docker cp "$tmp/D.pub.pem" cs7ns1-18-huge-C:/ && docker cp "$tmp/D.pub.pem" cs7ns1-18-huge-H:/ && docker cp "$tmp/D.pub.pem" cs7ns1-18-huge-M:/ || exit 1
docker cp "$tmp/E.pub.pem" cs7ns1-18-huge-B:/ && docker cp "$tmp/E.pub.pem" cs7ns1-18-huge-G:/ && docker cp "$tmp/E.pub.pem" cs7ns1-18-huge-J:/ && docker cp "$tmp/E.pub.pem" cs7ns1-18-huge-L:/ || exit 1
docker cp "$tmp/F.pub.pem" cs7ns1-18-huge-I:/ && docker cp "$tmp/F.pub.pem" cs7ns1-18-huge-N:/ && docker cp "$tmp/F.pub.pem" cs7ns1-18-huge-O:/ && docker cp "$tmp/F.pub.pem" cs7ns1-18-huge-P:/ || exit 1
docker cp "$tmp/G.pub.pem" cs7ns1-18-huge-B:/ && docker cp "$tmp/G.pub.pem" cs7ns1-18-huge-E:/ && docker cp "$tmp/G.pub.pem" cs7ns1-18-huge-J:/ && docker cp "$tmp/G.pub.pem" cs7ns1-18-huge-L:/ || exit 1
docker cp "$tmp/H.pub.pem" cs7ns1-18-huge-A:/ && docker cp "$tmp/H.pub.pem" cs7ns1-18-huge-C:/ && docker cp "$tmp/H.pub.pem" cs7ns1-18-huge-D:/ && docker cp "$tmp/H.pub.pem" cs7ns1-18-huge-M:/ || exit 1
docker cp "$tmp/I.pub.pem" cs7ns1-18-huge-F:/ && docker cp "$tmp/I.pub.pem" cs7ns1-18-huge-N:/ && docker cp "$tmp/I.pub.pem" cs7ns1-18-huge-O:/ && docker cp "$tmp/I.pub.pem" cs7ns1-18-huge-P:/ || exit 1
docker cp "$tmp/J.pub.pem" cs7ns1-18-huge-B:/ && docker cp "$tmp/J.pub.pem" cs7ns1-18-huge-E:/ && docker cp "$tmp/J.pub.pem" cs7ns1-18-huge-G:/ && docker cp "$tmp/J.pub.pem" cs7ns1-18-huge-L:/ || exit 1
docker cp "$tmp/L.pub.pem" cs7ns1-18-huge-B:/ && docker cp "$tmp/L.pub.pem" cs7ns1-18-huge-E:/ && docker cp "$tmp/L.pub.pem" cs7ns1-18-huge-G:/ && docker cp "$tmp/L.pub.pem" cs7ns1-18-huge-J:/ || exit 1
docker cp "$tmp/M.pub.pem" cs7ns1-18-huge-A:/ && docker cp "$tmp/M.pub.pem" cs7ns1-18-huge-C:/ && docker cp "$tmp/M.pub.pem" cs7ns1-18-huge-D:/ && docker cp "$tmp/M.pub.pem" cs7ns1-18-huge-H:/ || exit 1
docker cp "$tmp/N.pub.pem" cs7ns1-18-huge-F:/ && docker cp "$tmp/N.pub.pem" cs7ns1-18-huge-I:/ && docker cp "$tmp/N.pub.pem" cs7ns1-18-huge-O:/ && docker cp "$tmp/N.pub.pem" cs7ns1-18-huge-P:/ || exit 1
docker cp "$tmp/O.pub.pem" cs7ns1-18-huge-F:/ && docker cp "$tmp/O.pub.pem" cs7ns1-18-huge-I:/ && docker cp "$tmp/O.pub.pem" cs7ns1-18-huge-N:/ && docker cp "$tmp/O.pub.pem" cs7ns1-18-huge-P:/ || exit 1
docker cp "$tmp/P.pub.pem" cs7ns1-18-huge-F:/ && docker cp "$tmp/P.pub.pem" cs7ns1-18-huge-I:/ && docker cp "$tmp/P.pub.pem" cs7ns1-18-huge-N:/ && docker cp "$tmp/P.pub.pem" cs7ns1-18-huge-O:/ || exit 1

echo
echo "Run each of the following commands in different terminals to run the simulated nodes:"
echo "  docker start -a cs7ns1-18-huge-A"
echo "  docker start -a cs7ns1-18-huge-B"
echo "  docker start -a cs7ns1-18-huge-C"
echo "  docker start -a cs7ns1-18-huge-D"
echo "  docker start -a cs7ns1-18-huge-E"
echo "  docker start -a cs7ns1-18-huge-F"
echo "  docker start -a cs7ns1-18-huge-G"
echo "  docker start -a cs7ns1-18-huge-H"
echo "  docker start -a cs7ns1-18-huge-I"
echo "  docker start -a cs7ns1-18-huge-J"
echo "  docker start -a cs7ns1-18-huge-K"
echo "  docker start -a cs7ns1-18-huge-L"
echo "  docker start -a cs7ns1-18-huge-M"
echo "  docker start -a cs7ns1-18-huge-N"
echo "  docker start -a cs7ns1-18-huge-O"
echo "  docker start -a cs7ns1-18-huge-P"
echo "Use Control-C to shutdown a node, then restart it again with the same command."
echo "Alternatively, run the following command to start all simulated nodes at once:"
echo "  docker start cs7ns1-18-huge-A cs7ns1-18-huge-B cs7ns1-18-huge-C cs7ns1-18-huge-D cs7ns1-18-huge-E cs7ns1-18-huge-F cs7ns1-18-huge-G cs7ns1-18-huge-H cs7ns1-18-huge-I cs7ns1-18-huge-J cs7ns1-18-huge-K cs7ns1-18-huge-L cs7ns1-18-huge-M cs7ns1-18-huge-N cs7ns1-18-huge-O cs7ns1-18-huge-P"
echo "Then attach to the nodes you care about with a command like:"
echo "  docker logs --follow cs7ns1-18-huge-A"
echo "Rerun this script with \"TCDICN_VERBOSITY=dbug \" prepended to get more verbose output from containers."
echo
read -p "Press Enter to stop simulation..."

# Clean up
docker rm --force $(docker ps --all --quiet --filter "name=cs7ns1-18-huge-") 2>/dev/null
docker network rm $(docker network ls --quiet --filter "name=cs7ns1-18-huge-") 2>/dev/null
rm -r "$tmp" 2>/dev/null
