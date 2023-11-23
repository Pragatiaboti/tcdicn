import asyncio
import logging
import os
import random
import sys
from tcdicn import Node


class Drone:

    def __init__(self):
        self.node = Node()

    async def start(
            self, name: str, port: int, dport: int, wport: int,
            ttl: float, tpf: int, ttp: float,
            get_ttl: float, get_tpf: int, get_ttp: float,
            keyfile: str, groups: str):

        # The labels this drone can publish to
        labels = [
            f"{name}-xposition",
            f"{name}-yposition",
            f"{name}-temperature"
        ]

        # ICN client node called name publishes these labels and needs
        # any data propagated back in under ttp seconds at each node
        client = {}
        client["name"] = name
        client["ttp"] = ttp
        client["labels"] = [] if groups else labels
        if keyfile is not None:
            with open(keyfile, "rb") as f:
                client["key"] = f.read()

        # Start ICN node as a client
        logging.info("Starting ICN node...")
        node_task = asyncio.create_task(
            self.node.start(port, dport, ttl, tpf, client))
        if wport != 0:
            asyncio.create_task(self.node.serve_debug(wport))

        # Join every group by joining with each of the associated clients
        # GROUP1:CLIENT1_KEY,CLIENT2_KEY GROUP2:CLIENT3_KEY,CLIENT4_KEY
        logging.info("Joining groups...")
        group_tasks = {}
        for group in groups.split(" ") if groups else []:
            [group, public_key_files] = group.split(":")
            group_tasks[group] = []
            for public_key_file in public_key_files.split(","):
                [client, ext] = os.path.basename(public_key_file).split(".", 1)
                assert ext == "public.pem"
                with open(public_key_file, "rb") as f:
                    public_key = f.read()
                joiner = self.node.join(
                    group, client, public_key, labels, ttl, tpf, ttp)
                task = asyncio.create_task(joiner)
                group_tasks[group].append(task)

        # Wait until at least one client in every group has been joined with
        logging.info("Waiting for all groups be joined...")
        for tasks in group_tasks.values():
            done, tasks = await asyncio.wait(
                tasks + [node_task], return_when=asyncio.FIRST_COMPLETED)
            if node_task in done:
                return

        # Start drone
        logging.info("Starting drone...")
        sensors_task = asyncio.create_task(
            self.start_sensing(name))
        obeying_task = asyncio.create_task(
            self.start_obeying(get_ttl, get_tpf, get_ttp))

        # Run until shutdown
        tasks = [node_task, sensors_task, obeying_task]
        _, end = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        for task in end:
            task.cancel()
        await asyncio.wait(end)

    async def start_sensing(self, name):
       xposition = random.uniform(-1, 1)
        yposition = random.uniform(-1, 1)
        temperature = random.uniform(15, 25)
        cpu_usage = random.uniform(0, 100)
        battery_level = random.uniform(0, 100)

        while True:
            await asyncio.sleep(random.uniform(4, 6))

            # Update sensor values
            xposition += random.uniform(-0.1, 0.1)
            yposition += random.uniform(-0.1, 0.1)
            temperature += random.uniform(-0.5, 0.5)
            cpu_usage += random.uniform(-10, 10)
            battery_level -= random.uniform(0, 10)  # Assuming battery level decreases

            # Ensure battery level stays within bounds
            battery_level = max(0, min(battery_level, 100))

            # Simulate additional sensor data
            lat = random.uniform(-90, 90)
            lon = random.uniform(-180, 180)
            alt = random.uniform(0, 10000)  # Altitude in meters
            pitch = random.uniform(-90, 90)  # Pitch angle
            roll = random.uniform(-90, 90)   # Roll angle
            yaw = random.uniform(-180, 180)  # Yaw angle
            activity = random.choice(["idle", "moving", "working"])  # Activity status

            # Publish all sensor data
            await self.node.set(f"{name}-xposition", str(xposition))
            await self.node.set(f"{name}-yposition", str(yposition))
            await self.node.set(f"{name}-temperature", str(temperature))
            await self.node.set(f"{name}-cpu", str(cpu_usage))
            await self.node.set(f"{name}-battery", str(battery_level))
            await self.node.set(f"{name}-position", f"({lat}, {lon}, {alt})")
            await self.node.set(f"{name}-orientation", f"({pitch}, {roll}, {yaw})")
            await self.node.set(f"{name}-activity", activity)

    async def start_obeying(self, ttl, tpf, ttp):
        while True:
            # Subscribe to fleet and specific drone commands
            fleet_command = await self.node.get("fleet-command")
            drone_command = await self.node.get(f"{name}-command")
            print(f"New fleet command: {fleet_command}")
            print(f"New command for {name}: {drone_command}")
            
            await asyncio.sleep(float("inf"))


async def main():
    name = os.getenv("TCDICN_ID")  # A unique name to call me on the network
    port = int(os.getenv("TCDICN_PORT") or 33333)  # Listen on :33333
    dport = int(os.getenv("TCDICN_DPORT") or port)  # Talk to :33333
    wport = int(os.getenv("TCDICN_WPORT") or 0)  # Optional debug web server
    ttl = float(os.getenv("TCDICN_TTL") or 30)  # Forget me after 30s
    tpf = int(os.getenv("TCDICN_TPF") or 3)  # Remind peers every 30/3s
    ttp = float(os.getenv("TCDICN_TTP") or 5)  # Repeat my adverts before 5s
    get_ttl = float(os.getenv("TCDICN_GET_TTL") or 90)  # Forget my interest
    get_tpf = int(os.getenv("TCDICN_GET_TPF") or 2)  # Remind about my interest
    get_ttp = float(os.getenv("TCDICN_GET_TTP") or 0.5)  # Deadline to respond
    keyfile = os.getenv("TCDICN_KEYFILE") or None  # Private keyfile path
    groups = os.getenv("TCDICN_GROUPS") or ""  # Which groups to join
    verb = os.getenv("TCDICN_VERBOSITY") or "info"  # Logging verbosity
    if name is None:
        sys.exit("Please give client a unique ID by setting TCDICN_ID")

    # Logging verbosity
    verbs = {"dbug": logging.DEBUG, "info": logging.INFO, "warn": logging.WARN}
    logging.basicConfig(
        format="%(asctime)s.%(msecs)03d [%(levelname)s] %(message)s",
        level=verbs[verb], datefmt="%H:%M:%S")

    # Run drone until shutdown
    drone = Drone()
    await drone.start(
        name, port, dport, wport,
        ttl, tpf, ttp,
        get_ttl, get_tpf, get_ttp,
        keyfile, groups)


if __name__ == "__main__":
    asyncio.run(main())
