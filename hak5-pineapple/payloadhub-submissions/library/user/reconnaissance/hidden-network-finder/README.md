# Hidden Network Finder

* **Author:** bad-antics
* **Version:** 1.0
* **Category:** Reconnaissance
* **Target:** WiFi Pineapple Pager
* **Firmware:** 1.0.4+

## Description

Hidden Network Finder discovers and reveals WiFi networks that have SSID broadcasting disabled ("cloaked" or "hidden" networks). While hiding an SSID is a common (but ineffective) security measure, this payload demonstrates why it provides no real protection.

The payload uses a three-phase approach:
1. **Beacon Analysis** — Scans for access points broadcasting zero-length SSIDs
2. **Probe Response Capture** — Listens for probe responses that reveal the actual SSID
3. **Client Correlation** — Cross-references connected client probe requests to identify hidden network names

## Features

- **Three-phase detection** for maximum SSID revelation
- **Passive operation** — no active probing or injection required
- **Detailed reporting** with BSSID, channel, signal, encryption, and revealed SSID
- **Client correlation** identifies SSIDs from associated station probes
- **Configurable scan duration**
- **Clean interface restoration** via trap handler

## Configuration

| Variable | Default | Description |
|---|---|---|
| `INTERFACE` | `wlan0` | Wireless interface |
| `LOOT_DIR` | `/root/loot/hidden_finder` | Loot output directory |
| `SCAN_DURATION` | `30` | Initial scan time in seconds |
| `PROBE_DURATION` | `15` | Per-network probe response capture time |

## LED Status

| LED State | Description |
|---|---|
| SETUP | Initializing monitor mode |
| SPECIAL | Scanning / analyzing |
| SUCCESS | Hidden networks found and revealed |
| FAIL | No hidden networks detected |
| CLEANUP | Restoring interfaces |

## Requirements

- `aircrack-ng` suite (airmon-ng, airodump-ng)
- `tcpdump` (pre-installed on Pager)

## Usage

1. Run from the Pager UI
2. Set scan duration
3. Phase 1 scans for all networks
4. Phase 2 attempts to reveal hidden SSIDs via probe responses
5. Phase 3 correlates client probes
6. Results displayed and saved to loot

## Disclaimer

For **authorized security auditing only**. This payload demonstrates why SSID hiding is not a security measure. Users are solely responsible for compliance with all applicable laws.

## License

MIT License - [bad-antics](https://github.com/bad-antics)
