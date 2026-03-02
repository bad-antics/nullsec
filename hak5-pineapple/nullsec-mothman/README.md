# 🦇 nullsec-mothman — Network Interface Promiscuity & ARP Anomaly Detector

Part of the **nullsec freakshow** security toolkit.

## What It Does

Mothman detects network surveillance anomalies — promiscuous interfaces,
ARP spoofing, and suspicious network configurations. If something is
watching the network in the dark, mothman finds it.

## Commands

| Command | Description |
|---------|-------------|
| `mothman sighting` | Full network anomaly scan |
| `mothman wings` | Check for promiscuous interfaces |
| `mothman bridge` | Audit ARP cache for anomalies |

## Checks Performed

- **Promiscuous Mode Detection** — sysfs flags, ip link, traffic ratio heuristics
- **ARP Cache Audit** — duplicate MACs (ARP spoofing), duplicate IPs (conflicts)
- **Interface Inventory** — type classification, MAC analysis, tunnel detection
- **Traffic Anomaly** — extreme RX:TX ratios (passive sniffing indicator)
- **Spoofed MAC Detection** — locally administered bit check
- **Bridge/Tunnel Detection** — identifies virtual, bonded, and tunnel interfaces

## Install

```bash
pip install -e nullsec-mothman/
```

## License

MIT — bad-antics / nullsec 2026
