# IoT Scanner

* **Author:** bad-antics
* **Version:** 1.0
* **Category:** Reconnaissance
* **Target:** WiFi Pineapple Pager
* **Firmware:** 1.0.4+

## Description

IoT Scanner discovers and fingerprints smart home and IoT devices on wireless networks. It uses a comprehensive database of 50+ OUI signatures and SSID patterns to identify devices from major manufacturers including Amazon, Google, Apple, Ring, Nest, Philips Hue, Roku, Wyze, TP-Link, and more.

The payload supports three scan modes for different operational needs — from passive beacon sniffing for stealth to active network scanning for comprehensive coverage.

## Features

- **50+ device OUI signatures** covering all major smart home brands
- **Three scan modes:** Passive (stealth), Active (network), Combined
- **Automatic device classification** by manufacturer and type
- **Network auto-detection** for active scans
- **Comprehensive loot logging** with device type, MAC, SSID, channel, signal, and IP
- **Clean error handling** with trap-based cleanup
- **Pager-native UI** with PROMPT, SPINNER, NUMBER_PICKER, TEXT_PICKER

## Supported Device Types

| Category | Brands |
|---|---|
| Smart Speakers | Amazon Echo, Google Home, Apple HomePod, Sonos |
| Cameras | Ring, Wyze, Arlo, Blink, EZVIZ |
| Smart Plugs | TP-Link Kasa/Tapo, Belkin WeMo, Wyze |
| Smart Lights | Philips Hue, LIFX, Govee |
| Streaming | Roku, Amazon Fire TV, Apple TV |
| Thermostats | Nest, ecobee |
| Locks | August, Yale |
| Vacuums | iRobot Roomba |
| Hubs | SmartThings, Wink, Insteon |
| Generic IoT | Espressif/ESP32-based devices, Tuya |

## Configuration

| Variable | Default | Description |
|---|---|---|
| `INTERFACE` | `wlan0` | Wireless interface |
| `LOOT_DIR` | `/root/loot/iot_scanner` | Loot output directory |
| `PASSIVE_DURATION` | `20` | Passive scan time in seconds |

## LED Status

| LED State | Description |
|---|---|
| SETUP | Initializing scanner |
| SPECIAL | Actively scanning |
| SUCCESS | IoT devices discovered |
| FAIL | No devices found |
| CLEANUP | Restoring interfaces |

## Scan Modes

### Mode 1: Passive
Puts the wireless interface into monitor mode and captures beacon frames. Completely stealthy — no packets are transmitted. Best for initial reconnaissance.

### Mode 2: Active
Scans the connected network using ARP or ping sweep, then checks the ARP table against the OUI database. Automatically detects the network range from the default gateway. Requires network connectivity.

### Mode 3: Combined (Default)
Runs both passive and active scans for maximum device coverage.

## Requirements

- `aircrack-ng` suite (for passive mode)
- `arp-scan` (optional, for enhanced active scanning)
- Network connectivity (for active mode)

## Loot Output

Results saved to `/root/loot/iot_scanner/iot_YYYYMMDD_HHMMSS.txt`

## Disclaimer

For **authorized security auditing and research only**. Unauthorized network scanning may violate local and international laws. Users are solely responsible for compliance.

## License

MIT License - [bad-antics](https://github.com/bad-antics)
