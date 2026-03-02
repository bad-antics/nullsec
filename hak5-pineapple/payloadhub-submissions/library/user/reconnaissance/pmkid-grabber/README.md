# PMKID Grabber

* **Author:** bad-antics
* **Version:** 1.0
* **Category:** Reconnaissance
* **Target:** WiFi Pineapple Pager
* **Firmware:** 1.0.4+

## Description

PMKID Grabber captures PMKID hashes from WPA2/WPA3 access points using a **clientless** technique — no deauthentication required. The PMKID is extracted directly from the AP's first EAPOL message (RSN PMKID field), making this a much stealthier alternative to traditional handshake capture.

Captured hashes are saved in hashcat mode 22000 format, ready for immediate offline cracking.

### How PMKID Capture Works

1. The Pager sends an authentication request to the target AP
2. The AP responds with EAPOL Message 1 containing the PMKID
3. The PMKID is: `HMAC-SHA1-128(PMK, "PMK Name" | AP_MAC | STA_MAC)`
4. This hash can be cracked offline without a full 4-way handshake

### Advantages Over Handshake Capture

| Feature | PMKID | 4-Way Handshake |
|---|---|---|
| Requires connected client | ❌ No | ✅ Yes |
| Requires deauth | ❌ No | Usually yes |
| Detection risk | Low | Higher |
| Single packet needed | ✅ Yes | ❌ 4 packets |
| Success depends on | AP support | Client activity |

## Features

- **Clientless capture** — no deauth, no connected clients needed
- **Scan and select targets** — browse WPA2/WPA3 networks before capturing
- **Batch capture mode** — try all detected networks at once
- **Hashcat 22000 output** — ready for immediate cracking
- **Dual capture methods** — hcxdumptool (primary) or tcpdump (fallback)
- **Per-target timeout** — configurable wait time per AP
- **Detailed logging** with success/failure per target

## Configuration

| Variable | Default | Description |
|---|---|---|
| `INTERFACE` | `wlan0` | Wireless interface |
| `LOOT_DIR` | `/root/loot/pmkid` | Loot output directory |
| `SCAN_DURATION` | `20` | Target scan time in seconds |
| `CAPTURE_TIMEOUT` | `30` | Seconds to wait per AP for PMKID |

## LED Status

| LED State | Description |
|---|---|
| SETUP | Initializing |
| SPECIAL | Scanning / capturing |
| SUCCESS | PMKIDs captured |
| FAIL | No PMKIDs obtained |
| CLEANUP | Restoring interfaces |

## Requirements

- `aircrack-ng` suite (airmon-ng, airodump-ng)
- `hcxdumptool` + `hcxpcapngtool` (recommended, from hcxtools)
- OR `tcpdump` (fallback method, pre-installed)

### Installing hcxtools (recommended)

```bash
opkg update
opkg install hcxdumptool hcxtools
```

## Usage

1. Run from the Pager UI
2. Wait for target scan to complete
3. Choose: capture all networks or select a specific target
4. Set timeout per AP (default: 30 seconds)
5. Wait for capture attempts
6. Find hashcat-ready hashes in `/root/loot/pmkid/`

## Cracking Captured Hashes

```bash
# On your cracking rig:
hashcat -m 22000 pmkid_*.22000 /path/to/wordlist.txt

# With rules:
hashcat -m 22000 pmkid_*.22000 /path/to/wordlist.txt -r /path/to/rules.rule
```

## Disclaimer

For **authorized penetration testing and security auditing only**. Capturing network authentication material without authorization is illegal. Users are solely responsible for compliance with all applicable laws.

## License

MIT License - [bad-antics](https://github.com/bad-antics)
