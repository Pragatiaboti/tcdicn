#!/bin/sh

hash docker openssl || exit 1
shopt -s nullglob

docker build --tag cs7ns1-18 --file ./simulations/docker/Dockerfile . || exit 1
tmp="$(mktemp --directory || exit 1)"

echo
echo "Usage:"
echo
echo "[c]reate NODE TYPE      Create node of type controller, drone, inspector or node"
echo "[r]emove NODE           Remove node"
echo "[u]p NODE GROUPS...     Start node with groups as GROUP1:NODE1,NODE2 GROUP2:NODE3,NODE4"
echo "[d]own NODE             Stop node"
echo "[C]onnect NODE NODE     Create network connection between two nodes"
echo "[D]isconnect NODE NODE  Remove network connection between two nodes"
echo "[v]iew NODE             View and follow logs emitted by node"
echo "[q]uit                  Clean up and exit"
echo

while IFS=" " read -p "> " cmd arg1 arg2; do
	case "$cmd" in

		"c"|"create")
			[ "$arg2" = "controller" ] || [ "$arg2" = "drone" ] || [ "$arg2" = "inspector" ] || [ "$arg2" = "node" ] || { echo "Unknown type: $arg2"; continue; }
			docker create --env "SCRIPT=$arg2.py" --hostname "$arg1" --name "cs7ns1-18-interactive-$arg1" cs7ns1-18 || continue # TODO: envs
			[ "$arg2" != "node" ] && {
				openssl genrsa -out "$tmp/$arg1.pem" 2048 || continue
				openssl rsa -in "$tmp/$arg1.pem" -pubout -out "$tmp/$arg1.public.pem" || continue
				docker cp "$tmp/$arg1.pem" "cs7ns1-18-interactive-$arg1:/key.pem" || continue
			}
			;;

		"r"|"remove")
			docker rm "cs7ns1-18-interactive-$arg1" || continue
			rm "$tmp/$arg1.pem" "$tmp/$arg1" || continue
			;;

		"u"|"up")
			for key in "$tmp"/*.public.pem; do docker cp "$key" "cs7ns1-18-interactive-$arg1:/" || continue; done
			docker start "cs7ns1-18-interactive-$arg1" || continue
			;;

		"d"|"down")
			docker stop --time 1 "cs7ns1-18-interactive-$arg1" || continue
			;;

		"C"|"Connect")
			docker network create "cs7ns1-18-interactive-$arg1-$arg2" || continue
			docker network connect "cs7ns1-18-interactive-$arg1-$arg2" "cs7ns1-18-interactive-$arg1" || continue
			docker network connect "cs7ns1-18-interactive-$arg1-$arg2" "cs7ns1-18-interactive-$arg2" || continue
			;;

		"D"|"Disconnect")
			docker network disconnect --force "cs7ns1-18-interactive-$arg1-$arg2" "cs7ns1-18-interactive-$arg1" || continue
			docker network disconnect --force "cs7ns1-18-interactive-$arg1-$arg2" "cs7ns1-18-interactive-$arg2" || continue
			docker network rm "cs7ns1-18-interactive-$arg1-$arg2" || continue
			;;

		"v"|"view")
			docker logs "cs7ns1-18-interactive-$arg1" || continue
			;;

		"q"|"quit")
			echo "Cleaning up..."
			docker rm --force $(docker ps --all --quiet --filter "name=cs7ns1-18-interactive-") 2>/dev/null
			docker network rm $(docker network ls --quiet --filter "name=cs7ns1-18-interactive-") 2>/dev/null
			rm -r "$tmp" 2>/dev/null
			kill $(jobs -p) 2>/dev/null
			break
			;;

		"")
			;;

		*)
			echo "Unknown command: $cmd"
			;;

	esac
done
