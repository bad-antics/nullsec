# 📊 EntropyScope

**Network Traffic Entropy Analyzer**

Detect encrypted C2 channels, data exfiltration, and covert tunnels by analyzing entropy patterns in network traffic. Identifies DNS tunneling, beaconing behavior, and suspiciously encrypted flows.

## Features

- 📈 **Shannon entropy per-flow** — Detect near-random (encrypted) traffic flows
- 🔍 **DNS tunneling detection** — High-entropy subdomains, frequency analysis, known tunnel patterns
- ⏰ **Beaconing detection** — Periodic callback pattern analysis via coefficient of variation
- 📡 **Live capture mode** — Real-time traffic monitoring with alerts
- 📦 **PCAP analysis** — Offline analysis of packet captures
- 🧮 **File entropy calculator** — Quick entropy check for any file
- 📋 **JSON + Markdown reports**

## Usage

```bash
# Analyze a PCAP file
python3 entropyscope.py pcap capture.pcap -o ./results/

# Live traffic capture (60 seconds)
sudo python3 entropyscope.py live -i eth0 -d 60

# Calculate file entropy
python3 entropyscope.py calc suspicious_file.bin
```

## Detection Capabilities

| Threat | Method |
|--------|--------|
| Encrypted C2 | High entropy flow detection (>7.2 bits/byte) |
| DNS Tunneling | Subdomain entropy, frequency, pattern matching |
| Beaconing | Inter-arrival time regularity analysis |
| Data Exfil | Large outbound flow detection |
| Covert Channels | Protocol anomaly scoring |

## Requirements

- Python 3.6+
- Root privileges for live capture
- No external dependencies

## Part of [NullSec Security Suite](https://github.com/bad-antics/nullsec-suite)
