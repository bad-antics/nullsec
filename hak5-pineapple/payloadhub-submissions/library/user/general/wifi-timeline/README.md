# WiFi Timeline

* **Author:** bad-antics
* **Version:** 1.0
* **Category:** General
* **Target:** WiFi Pineapple Pager
* **Firmware:** 1.0.4+

## Description

WiFi Timeline builds a persistent historical database of all WiFi networks your Pager encounters over time. Think of it as a flight recorder for wireless environments — recording what networks existed, when they appeared, and how they changed.

Run it periodically in different locations to build a comprehensive map of wireless activity. The database persists across sessions, growing richer with every scan. View stats, browse network catalogs, and export full reports.

## Features

- **Persistent flat-file database** — survives reboots, grows over time
- **Three operation modes:** Record, View, Export
- **Automatic new vs. returning network detection**
- **Encryption type tracking** (Open, WEP, WPA2, WPA3 breakdown)
- **First seen / last seen timestamps** for every network
- **Top network ranking** by frequency of observation
- **Full report export** with complete network catalog
- **Configurable scan cycles** and intervals

## Modes

### Mode 1: Record
Performs a configurable number of scan cycles, adding all discovered networks to the persistent database. Shows count of new vs. previously-seen networks.

### Mode 2: View
Displays timeline statistics — total networks, date range, encryption breakdown, and top 10 most frequently seen networks.

### Mode 3: Export
Generates a comprehensive text report listing every unique network with its BSSID, encryption, first/last seen timestamps, and total sightings.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `INTERFACE` | `wlan0` | Wireless interface |
| `TIMELINE_DIR` | `/root/loot/wifi_timeline` | Database and report directory |
| `SCAN_INTERVAL` | `10` | Seconds per scan cycle |
| `DEFAULT_SCANS` | `12` | Number of scan cycles per session |

## LED Status

| LED State | Description |
|---|---|
| SETUP | Initializing |
| SPECIAL | Actively scanning/recording |
| SUCCESS | Operation complete |
| FAIL | Database empty / error |
| CLEANUP | Restoring interfaces |

## Requirements

- `aircrack-ng` suite (airmon-ng, airodump-ng)

## Usage

1. Run from the Pager UI
2. Choose mode: Record (1), View (2), or Export (3)
3. For Record: set number of scan cycles and wait
4. For View: browse stats on screen
5. For Export: find report in `/root/loot/wifi_timeline/`

## Database Format

The timeline database is a simple pipe-delimited text file at `/root/loot/wifi_timeline/timeline.db`:

```
TIMESTAMP|BSSID|SSID|CHANNEL|SIGNAL|ENCRYPTION
2026-03-01 14:30:00|AA:BB:CC:DD:EE:FF|HomeNet|6|-45|WPA2
2026-03-01 14:30:00|11:22:33:44:55:66|CoffeeShop|1|-62|OPN
```

## Disclaimer

For **authorized security auditing and research only**. Users are solely responsible for compliance with all applicable laws.

## License

MIT License - [bad-antics](https://github.com/bad-antics)
