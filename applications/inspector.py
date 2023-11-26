import asyncio
import logging
import os
import sys
from tcdicn import Node
from typing import List


class Inspector:

    def __init__(self):
        self.node = Node()

    async def start(
            self, name: str, port: int, dport: int, wport: int,
            ttl: float, tpf: int, ttp: float,
            get_ttl: float, get_tpf: int, get_ttp: float,
            keyfile: str, groups: str, known_drones: str):

        drones = known_drones.split(",")
        logging.info("Drones to be inspected: %s", drones)

        # The labels this inspector can publish to
        labels = [f"{drone}-status" for drone in drones]

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

        # Start inspector
        logging.info("Starting inspector...")
        monitoring_task = asyncio.create_task(
            self.start_monitoring(drones, groups, get_ttl, get_tpf, get_ttp))

        # Run until shutdown
        tasks = [node_task, monitoring_task]
        _, end = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        if len(end) != 0:
            for task in end:
                task.cancel()
            await asyncio.wait(end)
        logging.info("Stopped inspector")

    async def start_monitoring(
            self, drones: List[str], groups: List[str],
            ttl: float, tpf: int, ttp: float):

        async def start_monitoring_drone(drone):
            positions = []
            orientations = []
            temperatures = []
            cpu_usages = []
            batteries = []
            activity = None

            async def start_checking_drone():
                while True:
                    await asyncio.sleep(10)

                    # TODO: check drone stats:
                    # no message >3 mins
                    # position unchanged >3 mins
                    # any orientation >45
                    # temperature >80 >3 mins
                    # cpu_usage >90 >3 mins
                    # battery < 10

                    logging.info("Sending status")
                    for group in groups:
                        await self.node.set(f"{drone}-status", "TODO", group)

            async def start_monitoring_drone_group(group):
                nonlocal positions, orientations, temperatures
                nonlocal cpu_usages, batteries, activity
                tasks = set()

                def subscribe(label):
                    logging.debug("Subscribing to %s//%s...", group, label)
                    getter = self.node.get(label, ttl, tpf, ttp, group)
                    task = asyncio.create_task(getter, name=label)
                    tasks.add(task)

                # Add initial subscriptions
                subscribe(f"{drone}-position")
                subscribe(f"{drone}-orientation")
                subscribe(f"{drone}-temperature")
                subscribe(f"{drone}-cpu_usage")
                subscribe(f"{drone}-battery")
                subscribe(f"{drone}-activity")

                # Handle completed subscriptions then resubscribe
                while True:
                    done, tasks = await asyncio.wait(
                        tasks, return_when=asyncio.FIRST_COMPLETED)
                    for task in done:
                        label = task.get_name()
                        value = task.result()
                        logging.debug("Latest %s = %s", label, value)
                        if label == f"{drone}-position":
                            positions = [value] + positions[:10]
                        elif label == f"{drone}-orientation":
                            orientations = [value] + orientations[:10]
                        elif label == f"{drone}-temperature":
                            temperatures = [value] + temperatures[:10]
                        elif label == f"{drone}-cpu_usage":
                            cpu_usages = [value] + cpu_usages[:10]
                        elif label == f"{drone}-battery":
                            batteries = [value] + batteries[:10]
                        elif label == f"{drone}-activity":
                            activity = value
                        subscribe(label)

            # Subscribe in every group
            tasks = [asyncio.create_task(start_checking_drone())]
            for group in groups:
                tasks.append(asyncio.create_task(
                    start_monitoring_drone_group(group)))
            await asyncio.gather(*tasks)

        # Subscribe to every drone's sensor readings
        tasks = []
        for drone in drones:
            tasks.append(asyncio.create_task(
                start_monitoring_drone(drone)))
        await asyncio.gather(*tasks)


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
    get_ttp = float(os.getenv("TCDICN_GET_TTP") or 5)  # Deadline to respond
    keyfile = os.getenv("TCDICN_KEYFILE")  # Private keyfile path
    groups = os.getenv("TCDICN_GROUPS")  # Which groups to join
    verb = os.getenv("TCDICN_VERBOSITY") or "info"  # Logging verbosity
    known_drones = os.getenv("KNOWN_DRONES")  # Which drones to inspect
    if not name:
        sys.exit("Define inspector's unique ID by setting TCDICN_ID")
    if not keyfile:
        sys.exit("Define inspector's keyfile by setting TCDICN_KEYFILE")
    if not groups:
        sys.exit("Define inspector's groups by setting TCDICN_GROUPS")
    if not known_drones:
        sys.exit("Define inspector's drones by setting KNOWN_DRONES")

    # Logging verbosity
    verbs = {"dbug": logging.DEBUG, "info": logging.INFO, "warn": logging.WARN}
    logging.basicConfig(
        format="%(asctime)s.%(msecs)03d [%(levelname)s] %(message)s",
        level=verbs[verb], datefmt="%H:%M:%S")

    # Run inspector until shutdown
    inspector = Inspector()
    await inspector.start(
        name, port, dport, wport,
        ttl, tpf, ttp,
        get_ttl, get_tpf, get_ttp,
        keyfile, groups, known_drones)


if __name__ == "__main__":
    asyncio.run(main())
