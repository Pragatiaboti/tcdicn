import asyncio
import logging
import os
import random
import sys
from tcdicn import Node
from typing import List


class Controller:

    def __init__(self):
        self.node = Node()

    async def start(
            self, name: str, port: int, dport: int, wport: int,
            ttl: float, tpf: int, ttp: float,
            get_ttl: float, get_tpf: int, get_ttp: float,
            keyfile: str, groups: str, known_drones: str):

        drones = known_drones.split(",")
        logging.info("Drones to be controlled: %s", drones)

        # The labels this controller can publish to
        labels = [f"{drone}-command" for drone in drones]
        labels.append("fleet-command")

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

        # Start controller
        logging.info("Starting controller...")
        commanding_task = asyncio.create_task(
            self.start_commanding(drones, groups))
        listening_task = asyncio.create_task(
            self.start_listening(drones, groups, get_ttl, get_tpf, get_ttp))

        # Run until shutdown
        tasks = [node_task, commanding_task, listening_task]
        _, end = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        for task in end:
            task.cancel()
        await asyncio.wait(end)

    async def start_commanding(self, drones: List[str], groups: List[str]):
        commands = ["scan", "dance", "sing", "doubletime", "relax"]
        while True:
            await asyncio.sleep(random.uniform(10, 30))
            command = random.choice(commands)
            drone = random.choice(drones + ["fleet"])
            logging.info("Sent command to %s: %s", drone, command)
            for group in groups:
                await self.node.set(f"{drone}-command", command, group)

    async def start_listening(
            self, drones: List[str], groups: List[str],
            ttl: float, tpf: int, ttp: float):

        async def start_listening_drone(drone):
            tasks = set()
            label = f"{drone}-status"

            def subscribe(group):
                logging.debug("Subscribing to %s//%s...", group, label)
                tasks.add(asyncio.create_task(
                    self.node.get(label, ttl, tpf, ttp, group), name=group))

            for group in groups:
                subscribe(group)

            while True:
                done, tasks = await asyncio.wait(
                    tasks, return_when=asyncio.FIRST_COMPLETED)
                for task in done:
                    status = task.result()
                    logging.info("%s status: %s", drone, status)
                    subscribe(task.get_name())

        # Subscribe to every drone's status
        tasks = []
        for drone in drones:
            tasks.append(asyncio.create_task(start_listening_drone(drone)))
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
    get_ttp = float(os.getenv("TCDICN_GET_TTP") or 1)  # Deadline to respond
    keyfile = os.getenv("TCDICN_KEYFILE")  # Private keyfile path
    groups = os.getenv("TCDICN_GROUPS")  # Which groups to join
    verb = os.getenv("TCDICN_VERBOSITY") or "info"  # Logging verbosity
    known_drones = os.getenv("KNOWN_DRONES")  # Which drones to control
    if not name:
        sys.exit("Define controller's unique ID by setting TCDICN_ID")
    if not keyfile:
        sys.exit("Define controller's keyfile by setting TCDICN_KEYFILE")
    if not groups:
        sys.exit("Define controller's groups by setting TCDICN_GROUPS")
    if not known_drones:
        sys.exit("Define controller's drones by setting KNOWN_DRONES")

    # Logging verbosity
    verbs = {"dbug": logging.DEBUG, "info": logging.INFO, "warn": logging.WARN}
    logging.basicConfig(
        format="%(asctime)s.%(msecs)03d [%(levelname)s] %(message)s",
        level=verbs[verb], datefmt="%H:%M:%S")

    # Run controller until shutdown
    logging.info("Starting controller...")
    controller = Controller()
    await controller.start(
        name, port, dport, wport,
        ttl, tpf, ttp,
        get_ttl, get_tpf, get_ttp,
        keyfile, groups, known_drones)


if __name__ == "__main__":
    asyncio.run(main())
