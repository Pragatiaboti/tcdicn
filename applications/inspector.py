import os
import asyncio
from tcdicn import Node
import logging
import time

UNRESPONSIVE_THRESHOLD = 60  # (in seconds)
UNRESPONSIVE_CHECK_INTERVAL = 10  # (in seconds)

class DroneMonitorClient:

    def __init__(self, drones, node, ttl, tpf, ttp, group):
        self.drones = drones
        self.node = node
        self.ttl = ttl
        self.tpf = tpf
        self.ttp = ttp
        self.group = group
        self.last_msg_times = {}
        for drone in drones:
            self.last_msg_times[drone] = time.time()

    async def detect_unresponsive(self, drone):
        while True:
            # Check if a drone has not sent a message within the specified time
            if time.time() - self.last_msg_times[drone] > UNRESPONSIVE_THRESHOLD:
                # Drone is unresponsive, notify controllers
                await self.node.set(f"status-{drone}", "Unresponsive")
            await asyncio.sleep(UNRESPONSIVE_CHECK_INTERVAL)

    async def monitor_drone(self, drone):
        history_buffer = []  # Buffer to store the last 100 readings
        while True:
            # Subscribe to different types of sensor data for each drone separately
            position = await self.node.get(f"{drone}-position", self.ttl, self.tpf, self.ttp, self.group)
            temperature = await self.node.get(f"{drone}-temperature", self.ttl, self.tpf, self.ttp, self.group)
            battery = await self.node.get(f"{drone}-battery", self.ttl, self.tpf, self.ttp, self.group)

            self.last_msg_times[drone] = time.time()

            features = {
                "temperature": float(temperature),
                "battery": float(battery),
                "position": position,
            }
            history_buffer.append(features)
             # Trim the history buffer to keep only the last 100 readings
            history_buffer = history_buffer[-100:]


            # Run ML model on the last 5 minutes of collected data
            recent_data = history_buffer[-300:]  # 300 seconds = 5 minutes
            if len(recent_data) > 0:
                features_matrix = [list(features.values()) for features in recent_data]
                failure_predictions = self.model.predict(features_matrix)

                # Publish alerts based on predictions
                for idx, failure_prediction in enumerate(failure_predictions):
                    if failure_prediction == 1:
                        await self.node.set(f"status-{self.drone_id}", "Failure-alert")

            # Wait a bit before the next monitoring cycle
            await asyncio.sleep(10)

    async def monitor_drones(self):
        tasks = []
        for drone in self.drones:
            tasks.append(asyncio.create_task(self.monitor_drone(drone)))
        await asyncio.gather(*tasks)

    async def on_data(self, data, meta):
        # Update the last received message time when data is received
        await super().on_data(data, meta)

# Main Function
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
    get_ttl = float(os.getenv("TCDICN_GET_TTL") or 90)  # Forget my interest
    get_tpf = int(os.getenv("TCDICN_GET_TPF") or 2)  # Remind about my interest
    get_ttp = float(os.getenv("TCDICN_GET_TTP") or 0.5)  # Deadline to respond
    verb = os.getenv("TCDICN_VERBOSITY") or "info"  # Logging verbosity

    # Logging verbosity
    verbs = {"dbug": logging.DEBUG, "info": logging.INFO, "warn": logging.WARN}
    logging.basicConfig(
        format="%(asctime)s.%(msecs)03d [%(levelname)s] %(message)s",
        level=verbs[verb], datefmt="%H:%M:%S")

    logging.info("Starting inspected...")

    drones = ["drone06", "drone07", "drone08", "drone09", "drone10"]
    labels = [f"status-{drone}" for drone in drones]

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
    client = DroneMonitorClient(drones, node, get_ttl, get_tpf, get_ttp, group)
    client_task = asyncio.create_task(client.monitor_drones())

    # Serve debug information if requested
    if wport is not None:
        asyncio.create_task(node.serve_debug(int(wport)))

    tasks = [node_task, client_task]
    await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)

if __name__ == "__main__":
    asyncio.run(main())
