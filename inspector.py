import os
import asyncio
import json
import random
import numpy as np
from tcdicn import Node
from sklearn.tree import DecisionTreeClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import time

UNRESPONSIVE_THRESHOLD = 60  # (in seconds)
UNRESPONSIVE_CHECK_INTERVAL = 10  # (in seconds)

class DroneMonitorNode(Node):
    def __init__(self, drone_id, server, label, ttp=5, ttl=30, tpf=3, get_ttl=90, get_tpf=2, get_ttp=0.5, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.drone_id = drone_id
        self.server = server
        self.label = label  # Add a label attribute
        self.ttp = ttp
        self.ttl = ttl
        self.tpf = tpf
        self.get_ttl = get_ttl
        self.get_tpf = get_tpf
        self.get_ttp = get_ttp
        self.last_received_message_time = time.time()

    async def detect_unresponsive(self):
        while True:
            # Check if a drone has not sent a message within the specified time
            if (
                self.last_received_message_time is not None
                and time.time() - self.last_received_message_time > UNRESPONSIVE_THRESHOLD
            ):
                # Drone is unresponsive, notify controllers
                await self.server.set(f"status-{self.drone_id}", "Unresponsive")
            await asyncio.sleep(UNRESPONSIVE_CHECK_INTERVAL)

    async def monitor_drones(self):
        asyncio.create_task(self.detect_unresponsive())  # Start the unresponsive detection task

        history_buffer = []  # Buffer to store the last 100 readings
        while True:
            for drone_id in self.drones:
                # Subscribe to different types of sensor data for each drone separately
                position = await self.get(f"{drone_id}-position")
                temperature = await self.get(f"{drone_id}-temperature")
                battery = await self.get(f"{drone_id}-battery")

                if temperature is not None or position is not None or battery is not None:
                    features = {
                        "temperature": float(temperature) if temperature is not None else None,
                        "battery": float(battery) if battery is not None else None,
                        "position_0": float(position[0]) if position is not None and len(position) > 0 else None,
                        "position_1": float(position[1]) if position is not None and len(position) > 1 else None,
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
                        await self.server.set(f"status-{self.drone_id}", "Failure-alert")

            # Wait a bit before the next monitoring cycle
            await asyncio.sleep(10)

    async def on_data(self, data, meta):
        # Update the last received message time when data is received
        self.last_received_message_time = time.time()
        await super().on_data(data, meta)

# Main Function
async def main():
    name = os.getenv("TCDICN_ID")  # A unique name to call me on the network
    port = int(os.getenv("TCDICN_PORT") or 33333)  # Listen on :33333
    dport = int(os.getenv("TCDICN_DPORT") or port)  # Talk to :33333
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

    # Start ICN node as a client
    node = Node()
    label = f"status-{name}"  # Use the unique name for the label
    node_task = asyncio.create_task(node.start(port, dport, ttl, tpf, client={"name": name, "labels": [], "ttp": ttp}))

    # Join every trusted client in a group
    if any([trusteds, group, keyfile]):
        if not all([trusteds, group, keyfile]):
            raise RuntimeError("Missing some group config")
        tasks = [node_task]
        for trusted in trusteds.split(","):
            name = os.path.basename(trusted)
            with open(trusted, "rb") as f:
                key = f.read()
            tasks.append(asyncio.create_task(node.join(group, name, key, [label])))
        while len(tasks) > 1:
            done, tasks = await asyncio.wait(
                tasks, return_when=asyncio.FIRST_COMPLETED)
            if node_task in done:
                return

    drones = ["drone06", "drone07", "drone08", "drone09", "drone10"]
    drone_nodes = [
        DroneMonitorNode(
            drone_id,
            node,
            label=f"status-{drone_id}",  # Use the drone ID for the label
            ttp=ttp,
            ttl=ttl,
            tpf=tpf,
            get_ttl=get_ttl,
            get_tpf=get_tpf,
            get_ttp=get_ttp
        )
        for drone_id in drones
    ]

    tasks = [node_task]
    await asyncio.gather(*tasks)

if __name__ == "__main__":
    asyncio.run(main())
