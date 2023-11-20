import asyncio
import random
import logging
import sys
import os
from tcdicn import Node

class Drone:
    def __init__(self, drone_id):
        # Initialize the drone with a unique ID and network information
        self.node = Node()  # Node instance for network communication
        self.drone_id = drone_id
        self.position = (0, 0)  # Initial position (x, y)
        self.temperature = 20  # Initial temperature in Celsius
        self.battery = 100  # Initial battery percentage
        self.altitude = 0  # Altitude
        self.speed = 0  # Speed of the drone

    async def update_sensors(self):
        # Continuously update sensor readings and publish them
        while True:

            # Simulate sensor reading changes
            self.position = (self.position[0] + random.uniform(-0.1, 0.1),
                             self.position[1] + random.uniform(-0.1, 0.1))
            self.temperature += random.uniform(-0.5, 0.5)
            self.battery -= 1
            self.altitude += random.uniform(-0.1, 0.1)
            self.speed += random.uniform(-0.1, 0.1)

            await self.node.set(f"{self.drone_id}-position", str(self.position))
            await self.node.set(f"{self.drone_id}-temperature", str(self.temperature))
            await self.node.set(f"{self.drone_id}-battery", str(self.battery))
            await self.node.set(f"{self.drone_id}-altitude", str(self.altitude))
            await self.node.set(f"{self.drone_id}-speed", str(self.speed))

            await asyncio.sleep(5)

async def main():
    name = os.getenv("TCDICN_ID")  # A unique name to call me on the network
    port = int(os.getenv("TCDICN_PORT") or 33333)  # Listen on :33333
    dport = int(os.getenv("TCDICN_DPORT") or port)  # Talk to :33333
    wport = os.getenv("TCDICN_WPORT") or None
    ttl = float(os.getenv("TCDICN_TTL") or 30)  # Forget me after 30s
    tpf = int(os.getenv("TCDICN_TPF") or 3)  # Remind peers every 30/3s
    ttp = float(os.getenv("TCDICN_TTP") or 5)  # Repeat my adverts before 5s
    keyfile = os.getenv("TCDICN_KEYFILE") or None  # Private keyfile path
    trusteds = os.getenv("TCDICN_TRUSTEDS") or None  # Trusted client paths
    group = os.getenv("TCDICN_GROUP") or None  # Which group to make/join
    verb = os.getenv("TCDICN_VERBOSITY") or "info"  # Logging verbosity

    # Logging verbosity
    verbs = {"dbug": logging.DEBUG, "info": logging.INFO, "warn": logging.WARN}
    logging.basicConfig(
        format="%(asctime)s.%(msecs)03d [%(levelname)s] %(message)s",
        level=verbs[verb], datefmt="%H:%M:%S")

    logging.info("Starting drone...")

    labels = [f"status-{name}"]

    # ICN client node called name publishes these labels and needs
    # any data propagated back in under ttp seconds at each node
    client = {"name": name, "ttp": ttp, "labels": []}

    # Load this clients private key
    if keyfile is not None:
        with open(keyfile, "rb") as f:
            client["key"] = f.read()

    # Start ICN node as a client
    node = Node()
    node_task = asyncio.create_task(node.start(port, dport, ttl, tpf, client))

    # Join every trusted client in a group
    if any([trusteds, group, keyfile]):
        if not all([trusteds, group, keyfile]):
            raise RuntimeError("Missing some group config")
        tasks = [node_task]
        for trusted in trusteds.split(","):
            name = os.path.basename(trusted)
            with open(trusted, "rb") as f:
                key = f.read()
            tasks.append(asyncio.create_task(node.join(group, name, key, labels)))
        while len(tasks) > 1:
            done, tasks = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
            if node_task in done:
                return

    # Create client
    client = Drone(name)
    client_task = asyncio.create_task(client.update_sensors())

    # Serve debug information if requested
    if wport is not None:
        asyncio.create_task(node.serve_debug(int(wport)))

    tasks = [node_task, client_task]
    await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)

if __name__ == "__main__":
    asyncio.run(main())
