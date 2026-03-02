# Pager Diagnostics

* **Author:** bad-antics
* **Version:** 1.0
* **Category:** General
* **Target:** WiFi Pineapple Pager
* **Firmware:** 1.0.4+

## Description

Pager Diagnostics performs a comprehensive system health check on your WiFi Pineapple Pager and generates a detailed report. Think of it as a doctor's checkup for your Pager — it examines every subsystem and flags any issues.

## Checks Performed

| Check | What It Examines |
|---|---|
| **System Info** | Kernel version, architecture, firmware version |
| **CPU & Load** | CPU model, core count, load averages |
| **Memory** | Total/used/free RAM with health thresholds |
| **Storage** | All filesystems, SD card space, root partition |
| **WiFi Interfaces** | All wireless interfaces, MAC addresses, modes |
| **Network** | Gateway, DNS, internet connectivity |
| **Temperature** | Thermal zones with warning thresholds |
| **Packages** | aircrack-ng, tcpdump, nmap, python3, curl, wget, hostapd, dnsmasq |
| **Payloads** | Count of installed payloads across all directories |
| **Processes** | Top 5 processes by memory usage |

## Health Indicators

- ✓ — Check passed, healthy
- ⚠ — Warning, needs attention
- ✗ — Component missing or failed

### Warning Thresholds

| Metric | Notice | Warning |
|---|---|---|
| Memory usage | >75% | >90% |
| SD card free space | — | <100MB |
| Temperature | >65°C | >80°C |

## Configuration

| Variable | Default | Description |
|---|---|---|
| `LOOT_DIR` | `/root/loot/diagnostics` | Report output directory |

## LED Status

| LED State | Description |
|---|---|
| SETUP | Starting diagnostics |
| SPECIAL | Running checks |
| SUCCESS | All checks passed |
| FAIL | Issues detected |

## Usage

1. Run from the Pager UI
2. Press OK to start diagnostics
3. Wait for all checks to complete (~10 seconds)
4. View summary on screen
5. Full report saved to `/root/loot/diagnostics/`

## Requirements

No special packages required — uses only standard Linux utilities available on the Pager.

## Disclaimer

This is a read-only diagnostic tool. It does not modify any system settings.

## License

MIT License - [bad-antics](https://github.com/bad-antics)
