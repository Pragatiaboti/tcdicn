import asyncio
import logging
import os
import sys
from tcdicn import Node


class Inspector:

    def __init__(self):
        self.node = Node()

    async def start(
            self, name: str, port: int, dport: int, wport: int,
            ttl: float, tpf: int, ttp: float,
            get_ttl: float, get_tpf: int, get_ttp: float,
            keyfile: str, groups: str):

        # The labels this inspector can publish to
        # TODO: {drone}-status for each drone
        labels = ["drone6-status..."]

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

        # Start inspector
        logging.info("Starting inspector...")
        monitoring_task = asyncio.create_task(
            self.start_monitoring(get_ttl, get_tpf, get_ttp))

        # Run until shutdown
        tasks = [node_task, monitoring_task]
        _, end = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        for task in end:
            task.cancel()
        await asyncio.wait(end)

    async def start_monitoring(self, ttl, tpf, ttp):
        while True:
            # TODO: subscribe to drone sensor readings from every drone
            # TODO: publish reports
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

    # Run inspector until shutdown
    inspector = Inspector()
    await inspector.start(
        name, port, dport, wport,
        ttl, tpf, ttp,
        get_ttl, get_tpf, get_ttp,
        keyfile, groups)


if __name__ == "__main__":
    asyncio.run(main())
