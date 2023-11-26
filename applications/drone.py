# Responsibility of Xin
import asyncio
import logging
import os
import random
import sys
from tcdicn import Node
from typing import List


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
            f"{name}-position",
            f"{name}-orientation",
            f"{name}-temperature",
            f"{name}-cpu_usage",
            f"{name}-battery",
            f"{name}-activity"
        ]

        # ICN client node called name publishes these labels and needs
        # any data propagated back in under ttp seconds at each node
        client = {}
        client["name"] = name
        client["ttp"] = ttp
        client["labels"] = []
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
        for group in groups.split(" "):
            [group, public_key_files] = group.split(":")
            group_tasks[group] = []
            for public_key_file in public_key_files.split(","):
                [client, ext] = os.path.basename(public_key_file).split(".", 1)
                assert ext == "pub.pem"
                with open(public_key_file, "rb") as f:
                    public_key = f.read()
                joiner = self.node.join(
                    group, client, public_key, labels, ttl, tpf, ttp)
                task = asyncio.create_task(joiner)
                group_tasks[group].append(task)

        # Wait until at least one client in every group has been joined with
        groups = list(group_tasks.keys())
        logging.info("Waiting for all groups be joined: %s", groups)
        for tasks in group_tasks.values():
            done, tasks = await asyncio.wait(
                tasks + [node_task], return_when=asyncio.FIRST_COMPLETED)
            if node_task in done:
                return

        # Start drone
        logging.info("Starting drone...")
        sensors_task = asyncio.create_task(
            self.start_sensing(name, groups))
        obeying_task = asyncio.create_task(
            self.start_obeying(name, groups, get_ttl, get_tpf, get_ttp))

        # Run until shutdown
        tasks = [node_task, sensors_task, obeying_task]
        _, end = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        if len(end) != 0:
            for task in end:
                task.cancel()
            await asyncio.wait(end)
        logging.info("Stopped drone")

    async def start_sensing(self, name: str, groups: List[str]):

        # Simulated sensors
        pos_lat = random.uniform(-0.01, 0.01)
        pos_lon = random.uniform(-0.01, 0.01)
        pos_alt = random.uniform(25, 75)
        ori_pit = random.uniform(0, 25)
        ori_yaw = random.uniform(0, 25)
        ori_rol = random.uniform(0, 25)
        tmp = random.uniform(25, 90)
        cpu = random.uniform(0, 100)
        batt = random.uniform(90, 100)

        # Simulated activity
        acts = ["charging", "moving", "hauling", "welding"]
        prev_act = None
        while True:
            act = random.choice(acts)

            if act != prev_act:
                logging.info(f"New activity: {act}")
                for group in groups:
                    await self.node.set(f"{name}-activity", "charging", group)
                prev_act = act
            else:
                logging.debug(f"Activity: {act}")

            await asyncio.sleep(random.uniform(10, 30))

            if act == "charging":
                tmp += random.uniform(-1.5, 0.5)
                cpu += random.uniform(-25, 25)
                batt += random.uniform(3, 3.5)

            if act == "moving":
                pos_lat += random.uniform(-0.002, 0.002)
                pos_lon += random.uniform(-0.002, 0.002)
                pos_alt += random.uniform(-20, 20)
                ori_pit = random.gauss(0, 15)
                ori_yaw = random.gauss(0, 15)
                ori_rol = random.gauss(0, 15)
                tmp += random.uniform(-1.5, 0.5)
                cpu += random.uniform(-25, 25)
                batt -= random.uniform(0.5, 1)

            if act == "hauling":
                pos_lat += random.uniform(-0.001, 0.001)
                pos_lon += random.uniform(-0.001, 0.001)
                pos_alt += random.uniform(-10, 10)
                ori_pit = random.gauss(0, 15)
                ori_yaw = random.gauss(0, 15)
                ori_rol = random.gauss(0, 15)
                tmp += random.uniform(-0.5, 0.5)
                cpu += random.uniform(-25, 25)
                batt -= random.uniform(1, 1.5)

            if act == "welding":
                tmp += random.uniform(-0.5, 2.5)
                cpu += random.uniform(-25, 25)
                batt -= random.uniform(1, 1.5)

            pos_alt = max(min(pos_alt, 100), 0)
            tmp = max(min(tmp, 90), 25)
            cpu = max(min(cpu, 100), 0)
            batt = max(min(cpu, 100), 0)

            logging.debug("Publishing sensor data...")
            for group in groups:
                pos = (pos_lat, pos_lon, pos_alt)
                ori = (ori_pit, ori_yaw, ori_rol)
                await self.node.set(f"{name}-position", str(pos), group)
                await self.node.set(f"{name}-orientation", str(ori), group)
                await self.node.set(f"{name}-temperature", str(tmp), group)
                await self.node.set(f"{name}-cpu_usage", str(cpu), group)
                await self.node.set(f"{name}-battery", str(batt), group)

    async def start_obeying(
            self, name: str, groups: List[str],
            ttl: float, tpf: int, ttp: float):

        async def start_obeying_group(group):
            tasks = set()

            def subscribe(label):
                logging.debug("Subscribing to %s//%s...", group, label)
                getter = self.node.get(label, ttl, tpf, ttp, group)
                task = asyncio.create_task(getter, name=label)
                tasks.add(task)

            # Add initial subscriptions
            subscribe(f"{name}-command")
            subscribe("fleet-command")

            try:
                # Handle completed subscriptions then resubscribe
                while True:
                    done, tasks = await asyncio.wait(
                        tasks, return_when=asyncio.FIRST_COMPLETED)
                    for task in done:
                        label = task.get_name()
                        command = task.result()
                        logging.info("New %s: %s", label, command)
                        if command == "shutdown":
                            logging.info("Stopping drone...")
                            raise asyncio.exceptions.CancelledError()
                        subscribe(label)
            except asyncio.exceptions.CancelledError:
                # Clean up remaining getter tasks
                if len(tasks) != 0:
                    for task in tasks:
                        task.cancel()
                    await asyncio.wait(tasks)

        # Subscribe to fleet and drone commands in every group
        tasks = []
        for group in groups:
            tasks.append(asyncio.create_task(start_obeying_group(group)))
        _, end = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        if len(end) != 0:
            for task in end:
                task.cancel()
            await asyncio.wait(end)


async def main():
    name = os.getenv("TCDICN_ID")  # A unique name to call me on the network
    port = int(os.getenv("TCDICN_PORT") or 33333)  # Listen on :33333
    dport = int(os.getenv("TCDICN_DPORT") or port)  # Talk to :33333
    wport = int(os.getenv("TCDICN_WPORT") or 0)  # Optional debug web server
    ttl = float(os.getenv("TCDICN_TTL") or 30)  # Forget me after 30s
    tpf = int(os.getenv("TCDICN_TPF") or 3)  # Remind peers every 30/3s
    ttp = float(os.getenv("TCDICN_TTP") or 3)  # Repeat my adverts before 3s
    get_ttl = float(os.getenv("TCDICN_GET_TTL") or 90)  # Forget my interest
    get_tpf = int(os.getenv("TCDICN_GET_TPF") or 2)  # Remind about my interest
    get_ttp = float(os.getenv("TCDICN_GET_TTP") or 0)  # Deadline to respond
    keyfile = os.getenv("TCDICN_KEYFILE")  # Private keyfile path
    groups = os.getenv("TCDICN_GROUPS")  # Which groups to join
    verb = os.getenv("TCDICN_VERBOSITY") or "info"  # Logging verbosity
    if not name:
        sys.exit("Define drone's unique ID by setting TCDICN_ID")
    if not keyfile:
        sys.exit("Define drone's keyfile by setting TCDICN_KEYFILE")
    if not groups:
        sys.exit("Define drone's groups by setting TCDICN_GROUPS")

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
