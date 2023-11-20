import asyncio
import os
from dataclasses import dataclass
from typing import Optional

import tcdicn

LABELS = []


@dataclass
class Client:
    name: str
    port: int
    trust_clients: list[str]
    private_key: Optional[str] = None
    public_kay: Optional[str] = None


dport = int(os.getenv("TCDICN_DPORT") or 33333)  # Talk to :33333
ttl = int(os.getenv("TCDICN_TTL") or 30)  # Forget me after 30s
tpf = int(os.getenv("TCDICN_TPF") or 3)  # Remind peers every 30/3s
ttp = float(os.getenv("TCDICN_TTP") or 5)  # Repeat my adverts before 5s


async def main():
    clients: list[Client] = [
        Client("controller0", 33001, ['controller1', 'controller2']),
        Client("controller1", 33002, ['controller2']),
        Client("controller2", 33003, ['controller0']),
    ]
    public_keys = []
    for i in range(len(clients)):
        with open(f'keys/{clients[i].name}.pem', 'rb') as f:
            clients[i].private_key = f.read()
        with open(f'keys/{clients[i].name}', 'rb') as f:
            clients[i].public_kay = f.read()
            public_keys.append(f.read())

    other_nodes: list[tcdicn.Node] = []
    tasks = []
    for client in clients:
        node = tcdicn.Node()
        other_nodes.append(node)
        tasks.append(asyncio.create_task(node.start(client.port, dport, ttl, tpf, {
            "name": client.name, "ttp": ttp, "labels": LABELS
        })))
    await asyncio.wait(tasks)

    tasks = []
    for client, node in zip(clients, other_nodes):
        for client_name in client.trust_clients:
            tasks.append(asyncio.create_task(node.join(
                'my_cool_group', client_name, public_keys[client_name[-1]], LABELS
            )))

    await asyncio.wait(tasks)


asyncio.run(main())
