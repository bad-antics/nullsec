# Rogue AP Detector

* **Author:** bad-antics
* **Version:** 1.0
* **Category:** Reconnaissance
* **Target:** WiFi Pineapple Pager
* **Firmware:** 1.0.4+

## Description

Rogue AP Detector identifies evil twin and rogue access points in your wireless environment. It scans for duplicate SSIDs, analyzes encryption mismatches, checks signal anomalies, and compares against a configurable list of trusted networks — essentially a portable wireless intrusion detection system for your pocket.

### Detection Methods

1. **Duplicate SSID Analysis** — Finds SSIDs broadcast by multiple BSSIDs (potential evil twins)
2. **Encryption Mismatch** — Flags APs using the same SSID with different encryption levels
3. **Signal Anomaly Detection** — Unusually strong signals may indicate a nearby attacker
4. **Trusted Network Verification** — Compare discovered BSSIDs against your known-good list
5. **Open Network Flagging** — Identifies unencrypted networks as potential honeypots

### Risk Scoring

Each AP receives a risk score based on multiple factors:

| Score | Risk Level | Meaning |
|---|---|---|
| 0-19 | LOW | Normal — likely legitimate |
| 20-39 | MEDIUM | Suspicious — investigate further |
| 40-59 | HIGH | Potential rogue AP |
| 60+ | CRITICAL | Strong indicators of evil twin |

## Configuration

| Variable | Default | Description |
|---|---|---|
| `INTERFACE` | `wlan0` | Wireless interface |
| `LOOT_DIR` | `/root/loot/rogue_detector` | Loot output directory |
| `SCAN_DURATION` | `30` | Scan time in seconds |
| `TRUSTED_NETWORKS` | *(configure)* | Pipe-delimited `SSID\|BSSID` pairs |

### Configuring Trusted Networks

Edit the `TRUSTED_NETWORKS` variable at the top of payload.sh:

```bash
TRUSTED_NETWORKS="CorpWiFi|AA:BB:CC:DD:EE:FF
HomeNetwork|11:22:33:44:55:66"
```

Or configure interactively when the payload prompts you.

## LED Status

| LED State | Description |
|---|---|
| SETUP | Initializing scanner |
| SPECIAL | Scanning and analyzing |
| ATTACK | Rogue/evil twin AP detected! (+ vibration) |
| SUCCESS | Environment clean or only minor concerns |
| CLEANUP | Restoring interfaces |

## Requirements

- `aircrack-ng` suite (airmon-ng, airodump-ng)

## Usage

1. Run from the Pager UI
2. Optionally configure trusted networks
3. Set scan duration
4. Review results — rogues highlighted with risk scores

## Disclaimer

For **authorized security auditing and defense only**. This is a defensive detection payload. Users are solely responsible for compliance with all applicable laws.

## License

MIT License - [bad-antics](https://github.com/bad-antics)
