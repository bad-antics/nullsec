# Spectrum Analyzer

* **Author:** bad-antics
* **Version:** 1.0
* **Category:** General
* **Target:** WiFi Pineapple Pager
* **Firmware:** 1.0.4+

## Description

Spectrum Analyzer provides a visual WiFi channel utilization map for both 2.4 GHz and 5 GHz bands. It scans all nearby access points, counts how many are on each channel, and generates ASCII bar charts showing congestion levels — plus recommends the best channels for your network.

Perfect for:
- **Site surveys** — understand RF congestion before deploying
- **Troubleshooting** — identify channel interference issues
- **Network planning** — find the cleanest channels for your AP
- **Pentesting prep** — map the RF environment before engagements

## Features

- **Visual bar charts** for all 2.4 GHz and 5 GHz channels
- **Congestion rating** (Minimal → Extremely High)
- **Best channel recommendation** for both bands
- **Open network counting** (potential honeypot awareness)
- **Strongest signal identification**
- **Band utilization breakdown** (2.4 vs 5 GHz distribution)
- **Full report export** with detailed channel data
- **Live LOG output** with visual charts on Pager screen

## Configuration

| Variable | Default | Description |
|---|---|---|
| `INTERFACE` | `wlan0` | Wireless interface |
| `LOOT_DIR` | `/root/loot/spectrum` | Report output directory |
| `SCAN_DURATION` | `20` | Scan time in seconds |

## LED Status

| LED State | Description |
|---|---|
| SETUP | Initializing |
| SPECIAL | Scanning spectrum |
| SUCCESS | Analysis complete |
| CLEANUP | Restoring interfaces |

## Requirements

- `aircrack-ng` suite (airmon-ng, airodump-ng)

## Example Output

```
═══ 2.4 GHz Band (24 APs) ═══

  Ch  1  ████████████░░░░░░░░ (12)
  Ch  2  ░░░░░░░░░░░░░░░░░░░░ (0)
  Ch  3  █░░░░░░░░░░░░░░░░░░░ (1)
  Ch  6  ██████████░░░░░░░░░░ (10)
  Ch 11  ██████░░░░░░░░░░░░░░ (6)

═══ 5 GHz Band (8 APs) ═══

  Ch  36 ████░░░░░░░░░░░░░░░░ (4)
  Ch  48 ██░░░░░░░░░░░░░░░░░░ (2)
  Ch 149 ██░░░░░░░░░░░░░░░░░░ (2)

═══ Recommendations ═══

  Best 2.4 GHz: Channel 11 (6 APs)
  Best 5 GHz:   Channel 44 (0 APs)
```

## Disclaimer

For **authorized security auditing and network analysis only**. This is a passive observation tool.

## License

MIT License - [bad-antics](https://github.com/bad-antics)
