#!/bin/sh

hash openssl || { echo "Sorry, OpenSSL is required to generate client keypairs"; exit 1; }

echo
echo "Depending on the scenario, you will likely want to open a couple terminal windows to see all nodes in action at once."
echo "If you are planning on running the Raspberry Pis scenario, you will need to open up 7 SSH sessions on two different Pis (such as rasp-018 and rasp-036)."
echo
echo "Choose scenario:"
echo "  [1] ./simulations/docker/basic.sh - A drone, inspector and controller"
echo "  [2] ./simulations/docker/groups.sh - 2 groups of drones and inspectors under 2 controllers"
echo "  [3] ./simulations/docker/huge.sh - 16 drones, inspectors, controllers and nodes in 3 groups"
echo "  [4] ./simulations/pi/{018,036}.sh - 2 drones, an inspector and a controller under one node on each Pi"
read -p "> " input

case "$input" in
	1|2|3) hash docker || { echo "Sorry, Docker is required for scenario 1, 2 and 3"; exit 1; };;
	4)
		echo "Choose PI script to run:"
		echo "  [1] ./simulations/pi/018.sh"
		echo "  [2] ./simulations/pi/036.sh"
		read -p "> " input
		case "$input" in
			1) input=4a;;
			2) input=4b;;
			*) echo "Unknown script. Please pick 1 or 2"; exit 1;;
		esac
		;;
	*) echo "Unknown scenario. Please pick 1, 2, 3 or 4"; exit 1;;
esac

case "$input" in
	1) ./simulations/docker/basic.sh;;
	2) ./simulations/docker/groups.sh;;
	3) ./simulations/docker/huge.sh;;
	4a) ./simulations/pi/018.sh;;
	4b) ./simulations/pi/036.sh;;
esac
