# WPS Auditor

* **Author:** bad-antics
* **Version:** 1.0
* **Category:** Reconnaissance
* **Target:** WiFi Pineapple Pager
* **Firmware:** 1.0.4+

## Description

WPS Auditor scans for WiFi Protected Setup (WPS) enabled access points and identifies potentially vulnerable configurations. WPS remains one of the most common attack vectors against WiFi networks — this payload helps auditors quickly identify which networks in range have WPS enabled and which may be susceptible to known attacks.

### Vulnerability Detection

| Check | Risk Level | Description |
|---|---|---|
| WPS Enabled | LOW | WPS is active but may be locked |
| WPS Unlocked | MEDIUM | WPS is active and accepting PINs |
| WPS 1.0 | HIGH | Susceptible to Pixie Dust attack |
| Vulnerable Vendor | HIGH | Router chipset has known WPS weaknesses |

### Vulnerable Vendor Database

Includes OUI signatures for historically WPS-vulnerable chipsets from: Tenda, Ralink, ASUS, TP-Link, Belkin, ZyXEL, Huawei.

## Features

- **Primary scanning with `wash`** (reaver suite) for accurate WPS detection
- **Fallback to airodump-ng** when wash is not available
- **WPS version detection** — identifies v1.0 (Pixie Dust vulnerable)
- **Lock status detection** — locked vs. unlocked WPS
- **Vendor vulnerability correlation** — cross-references OUI against known-weak chipsets
- **Risk scoring** per network (LOW/MEDIUM/HIGH)
- **Detailed loot reporting**

## Configuration

| Variable | Default | Description |
|---|---|---|
| `INTERFACE` | `wlan0` | Wireless interface |
| `LOOT_DIR` | `/root/loot/wps_auditor` | Loot output directory |
| `SCAN_DURATION` | `30` | Scan time in seconds |

## LED Status

| LED State | Description |
|---|---|
| SETUP | Initializing |
| SPECIAL | Scanning |
| ATTACK | Vulnerable WPS networks found |
| SUCCESS | WPS networks found (no vulns) |
| FAIL | No WPS networks detected |

## Requirements

- `aircrack-ng` suite (airmon-ng, airodump-ng)
- `wash` from reaver suite (optional but recommended for accurate WPS detection)

## Disclaimer

For **authorized security auditing only**. Do not attempt to exploit WPS vulnerabilities on networks you do not own or have written authorization to test.

## License

MIT License - [bad-antics](https://github.com/bad-antics)
