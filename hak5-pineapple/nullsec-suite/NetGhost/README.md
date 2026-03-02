# 👻 NetGhost

**Passive Network Topology Mapper**

Map your entire network without sending a single probe packet. NetGhost harvests topology data purely from existing system state — ARP caches, routing tables, DNS caches, active connections, and service discovery protocols.

## Features

- 🔇 **100% passive** — Zero active probes, completely silent
- 🗺️ **ARP cache harvest** — Discover neighbors from system ARP table
- 🛣️ **Route analysis** — Map gateways and subnets from routing table
- 🌐 **DNS cache & known_hosts** — Extract known hostnames
- 🔌 **Active connections** — Map peers from `ss -tupn`
- 📡 **mDNS/Avahi** — Discover local services via mDNS
- 🔍 **SSDP/UPnP** — Find IoT devices and media servers
- 🏭 **MAC vendor resolution** — Identify device manufacturers
- 🖥️ **OS fingerprinting** — Heuristic OS detection from TTL/OUI
- 📊 **Mermaid topology diagrams** — Visual network maps
- 📋 **JSON + Markdown reports**

## Usage

```bash
# Full passive scan
python3 netghost.py -i eth0

# Output to specific directory
python3 netghost.py -i eth0 -o ./results/

# JSON output to stdout
python3 netghost.py -i eth0 --json
```

## Requirements

- Python 3.6+
- Linux (uses /proc/net/arp, ip, ss)
- No external dependencies

## Part of [NullSec Security Suite](https://github.com/bad-antics/nullsec-suite)
