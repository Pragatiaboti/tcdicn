#!/bin/sh

tmp="/tmp/cs7ns1-18"
hash openssl scp || exit 1
rm -rf "$tmp" && mkdir -p "$tmp" || exit 1

echo
echo "Setting up local network for rasp-018..."
echo
echo '   A   B   '
echo '    \ /    '
echo ' F - X - C '
echo '    / \    '
echo '   E   D   '
echo
echo "A is a drone in group 1 with the public key of E"
echo "B is a drone in group 2 with the public key of D"
echo "C is a drone in group 1 with the public key of L"
echo "D is an inspector in group 2 with the public key of B and F"
echo "E is an inspector in group 1 with the public key of A and L"
echo "F is a controller in group 1 with the public key of L and in group 2 with the public key of D and L"
echo "X is a node and is the main node of this network"
echo

# Generate keypairs
openssl genrsa -out "$tmp/A.pem" 2048 && openssl rsa -in "$tmp/A.pem" -pubout -out "$tmp/A.pub.pem" || exit 1
openssl genrsa -out "$tmp/B.pem" 2048 && openssl rsa -in "$tmp/B.pem" -pubout -out "$tmp/B.pub.pem" || exit 1
openssl genrsa -out "$tmp/C.pem" 2048 && openssl rsa -in "$tmp/C.pem" -pubout -out "$tmp/C.pub.pem" || exit 1
openssl genrsa -out "$tmp/D.pem" 2048 && openssl rsa -in "$tmp/D.pem" -pubout -out "$tmp/D.pub.pem" || exit 1
openssl genrsa -out "$tmp/E.pem" 2048 && openssl rsa -in "$tmp/E.pem" -pubout -out "$tmp/E.pub.pem" || exit 1
openssl genrsa -out "$tmp/F.pem" 2048 && openssl rsa -in "$tmp/F.pem" -pubout -out "$tmp/F.pub.pem" || exit 1

echo
echo "Please log into rasb-36 and run ./simulations/pi/036.sh up to this point"
echo "The minimal set of public keys will then be exchanged with rasb-036 using scp"
echo
read -p "Press Enter to continue with exchange..."

# Distribute minimal set public keys
scp "$tmp/F.pub.pem" "rasb-036:$tmp" || {
	echo "WARNING: Unable to send public keys! You may need to send them to rasb-036 manually."
}

echo
echo "Run each of the following commands in different terminals to run the local nodes:"
echo "  TCDICN_PORT=33334 TCDICN_DPORT=33333 TCDICN_ID=A TCDICN_KEYFILE=\"$tmp/A.pem\" TCDICN_GROUPS=\"1:$tmp/E.pub.pem\" PYTHONPATH=. python3 applications/drone.py"
echo "  TCDICN_PORT=33335 TCDICN_DPORT=33333 TCDICN_ID=B TCDICN_KEYFILE=\"$tmp/B.pem\" TCDICN_GROUPS=\"2:$tmp/D.pub.pem\" PYTHONPATH=. python3 applications/drone.py"
echo "  TCDICN_PORT=33336 TCDICN_DPORT=33333 TCDICN_ID=C TCDICN_KEYFILE=\"$tmp/C.pem\" TCDICN_GROUPS=\"1:$tmp/L.pub.pem\" PYTHONPATH=. python3 applications/drone.py"
echo "  TCDICN_PORT=33337 TCDICN_DPORT=33333 TCDICN_ID=D TCDICN_KEYFILE=\"$tmp/D.pem\" TCDICN_GROUPS=\"2:$tmp/B.pub.pem,$tmp/F.pub.pem\" KNOWN_DRONES=\"B,G,I\" PYTHONPATH=. python3 applications/inspector.py"
echo "  TCDICN_PORT=33338 TCDICN_DPORT=33333 TCDICN_ID=E TCDICN_KEYFILE=\"$tmp/E.pem\" TCDICN_GROUPS=\"1:$tmp/A.pub.pem,$tmp/L.pub.pem\" KNOWN_DRONES=\"A,C,H\" PYTHONPATH=. python3 applications/inspector.py"
echo "  TCDICN_PORT=33339 TCDICN_DPORT=33333 TCDICN_ID=F TCDICN_KEYFILE=\"$tmp/F.pem\" TCDICN_GROUPS=\"1:$tmp/L.pub.pem 2:$tmp/D.pub.pem,$tmp/L.pub.pem\" KNOWN_DRONES=\"A,B,C,G,H,I\" PYTHONPATH=. python3 applications/controller.py"
echo "  TCDICN_PORT=33333 TCDICN_DPORT=33333 PYTHONPATH=. python3 applications/node.py"
echo
echo "If desired, start more nodes on other Raspberry Pis, which will provide redundant connectivity between 018 and 036:"
echo "  TCDICN_PORT=33333 TCDICN_DPORT=33333 PYTHONPATH=. python3 applications/node.py"
echo
echo "Prepend commands with \"TCDICN_VERBOSITY=dbug \" to get more verbose output"
echo "Prepend commands with \"TCDICN_WPORT=33340 \" to enable a debug web server on port 33340"
echo
echo "Use Control-C to shutdown a node, then restart it again with the same command."
echo
