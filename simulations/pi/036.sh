#!/bin/sh

tmp="/tmp/cs7ns1-18"
hash openssl scp || exit 1
rm -rf "$tmp" && mkdir -p "$tmp" || exit 1

echo
echo "Setting up local network for rasp-036..."
echo
echo '   G   H   '
echo '    \ /    '
echo ' L - Y - I '
echo '    / \    '
echo '   K   J   '
echo
echo "G is a drone in group 2 with the public key of K"
echo "H is a drone in group 1 with the public key of J"
echo "I is a drone in group 2 with the public key of F"
echo "J is an inspector in group 1 with the public key of H and L"
echo "K is an inspector in group 2 with the public key of G and F"
echo "L is a controller in group 1 with the public key of F and in group 2 with the public key of F and J"
echo "Y is a node and is the main node of this network"
echo

# Generate keypairs
openssl genrsa -out "$tmp/G.pem" 2048 && openssl rsa -in "$tmp/G.pem" -pubout -out "$tmp/G.pub.pem" || exit 1
openssl genrsa -out "$tmp/H.pem" 2048 && openssl rsa -in "$tmp/H.pem" -pubout -out "$tmp/H.pub.pem" || exit 1
openssl genrsa -out "$tmp/I.pem" 2048 && openssl rsa -in "$tmp/I.pem" -pubout -out "$tmp/I.pub.pem" || exit 1
openssl genrsa -out "$tmp/J.pem" 2048 && openssl rsa -in "$tmp/J.pem" -pubout -out "$tmp/J.pub.pem" || exit 1
openssl genrsa -out "$tmp/K.pem" 2048 && openssl rsa -in "$tmp/K.pem" -pubout -out "$tmp/K.pub.pem" || exit 1
openssl genrsa -out "$tmp/L.pem" 2048 && openssl rsa -in "$tmp/L.pem" -pubout -out "$tmp/L.pub.pem" || exit 1

echo
echo "Please log into rasb-18 and run ./simulations/pi/018.sh up to this point"
echo "The minimal set of public keys will then be exchanged with rasb-018 using scp"
echo
read -p "Press Enter to continue with exchange..."

# Distribute minimal set public keys
scp "$tmp/L.pub.pem" "rasb-018:$tmp" || {
	echo "WARNING: Unable to send public keys! You may need to send them to rasb-018 manually."
}

echo
echo "Run each of the following commands in different terminals to run the local nodes:"
echo "  TCDICN_PORT=33334 TCDICN_DPORT=33333 TCDICN_ID=G TCDICN_KEYFILE=\"$tmp/G.pem\" TCDICN_GROUPS=\"2:$tmp/K.pub.pem\" PYTHONPATH=. python3 applications/drone.py"
echo "  TCDICN_PORT=33335 TCDICN_DPORT=33333 TCDICN_ID=H TCDICN_KEYFILE=\"$tmp/H.pem\" TCDICN_GROUPS=\"1:$tmp/J.pub.pem\" PYTHONPATH=. python3 applications/drone.py"
echo "  TCDICN_PORT=33336 TCDICN_DPORT=33333 TCDICN_ID=I TCDICN_KEYFILE=\"$tmp/I.pem\" TCDICN_GROUPS=\"2:$tmp/F.pub.pem\" PYTHONPATH=. python3 applications/drone.py"
echo "  TCDICN_PORT=33337 TCDICN_DPORT=33333 TCDICN_ID=J TCDICN_KEYFILE=\"$tmp/J.pem\" TCDICN_GROUPS=\"1:$tmp/H.pub.pem,$tmp/L.pub.pem\" KNOWN_DRONES=\"A,C,H\" PYTHONPATH=. python3 applications/inspector.py"
echo "  TCDICN_PORT=33338 TCDICN_DPORT=33333 TCDICN_ID=K TCDICN_KEYFILE=\"$tmp/K.pem\" TCDICN_GROUPS=\"2:$tmp/G.pub.pem,$tmp/F.pub.pem\" KNOWN_DRONES=\"B,G,I\" PYTHONPATH=. python3 applications/inspector.py"
echo "  TCDICN_PORT=33339 TCDICN_DPORT=33333 TCDICN_ID=L TCDICN_KEYFILE=\"$tmp/L.pem\" TCDICN_GROUPS=\"1:$tmp/F.pub.pem 2:$tmp/F.pub.pem,$tmp/J.pub.pem\" KNOWN_DRONES=\"A,B,C,G,H,I\" PYTHONPATH=. python3 applications/controller.py"
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
