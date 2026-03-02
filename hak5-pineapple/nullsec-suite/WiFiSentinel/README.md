# 📡 WiFiSentinel

**Wireless Deauthentication Monitor & Alert System**

Real-time detection of WiFi attacks including deauth floods, evil twin APs, and rogue access points. Full 802.11 frame parsing with channel hopping.

## Features

- 🚫 **Deauth flood detection** — Configurable threshold-based alerting
- 👿 **Evil Twin detection** — Multiple BSSIDs for same SSID
- 📡 **Channel hopping** — Automatic 2.4GHz channel rotation
- 📊 **Live statistics** — Frame count, AP/client tracking, FPS
- 🔍 **802.11 frame parsing** — Pure Python, no scapy dependency
- 🗺️ **AP inventory** — Build database of all visible access points
- 📋 **JSON + Markdown reports**

## Usage

```bash
# Monitor with auto channel hopping
sudo python3 wifisentinel.py -i wlan0mon

# Enable monitor mode first, then monitor
sudo python3 wifisentinel.py -i wlan0 --monitor

# Monitor for 5 minutes
sudo python3 wifisentinel.py -i wlan0mon -d 300

# Custom deauth threshold (20 per 10s window)
sudo python3 wifisentinel.py -i wlan0mon -t 20

# Fixed channel (no hopping)
sudo python3 wifisentinel.py -i wlan0mon --no-hop
```

## Prerequisites

1. WiFi adapter with **monitor mode** support
2. Put adapter in monitor mode:
```bash
sudo ip link set wlan0 down
sudo iw dev wlan0 set type monitor
sudo ip link set wlan0 up
```
Or use airmon-ng: `sudo airmon-ng start wlan0`

## Attack Detection

| Attack | Detection Method |
|--------|-----------------|
| Deauth Flood | >10 deauth frames/10s from same source |
| Disassoc Flood | >10 disassoc frames/10s from same source |
| Evil Twin | Multiple BSSIDs advertising same SSID |
| Broadcast Deauth | Deauth targeting ff:ff:ff:ff:ff:ff |

## Requirements

- Python 3.6+
- Root privileges
- Monitor mode WiFi adapter
- Linux with AF_PACKET support

## Part of [NullSec Security Suite](https://github.com/bad-antics/nullsec-suite)
