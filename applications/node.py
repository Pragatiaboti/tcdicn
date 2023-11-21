import asyncio
import logging
import os
from tcdicn import Node


async def main():
    port = int(os.getenv("TCDICN_PORT") or 33333)  # Listen on :33333
    dport = int(os.getenv("TCDICN_DPORT") or port)  # Talk to :33333
    wport = int(os.getenv("TCDICN_WPORT") or 0)  # Optional debug web server
    ttl = float(os.getenv("TCDICN_TTL") or 30)  # Forget me after 30s
    tpf = int(os.getenv("TCDICN_TPF") or 3)  # Remind peers every 30/3s
    verb = os.getenv("TCDICN_VERBOSITY") or "info"  # Logging verbosity

    # Logging verbosity
    verbs = {"dbug": logging.DEBUG, "info": logging.INFO, "warn": logging.WARN}
    logging.basicConfig(
        format="%(asctime)s.%(msecs)03d [%(levelname)s] %(message)s",
        level=verbs[verb], datefmt="%H:%M:%S")

    # Run node until shutdown
    logging.info("Starting ICN node...")
    node = Node()
    if wport != 0:
        asyncio.create_task(node.serve_debug(wport))
    await node.start(port, dport, ttl, tpf)


if __name__ == "__main__":
    asyncio.run(main())
