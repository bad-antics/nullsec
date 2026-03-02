# Drone Hunter

* **Author:** bad-antics
* **Version:** 1.0
* **Category:** Reconnaissance
* **Target:** WiFi Pineapple Pager
* **Firmware:** 1.0.4+

## Description

Drone Hunter passively detects nearby drones by identifying their WiFi signatures. It uses a comprehensive database of OUI (Organizationally Unique Identifier) prefixes and SSID naming patterns to identify drones from major manufacturers:

| Manufacturer | Models Detected |
|---|---|
| DJI | Mavic, Spark, Phantom, Tello, Air, Mini |
| Parrot | Anafi, Bebop, Disco |
| Autel | EVO, EVO II, EVO Lite |
| Yuneec | Typhoon, Breeze |
| Skydio | Skydio 2, Skydio X2 |
| Holy Stone | Various consumer models |
| Syma | Various consumer models |

The payload puts the wireless interface into monitor mode and captures beacon frames, then cross-references detected MAC addresses and SSIDs against the built-in drone signature database.

## Features

- **17+ drone OUI signatures** covering all major manufacturers
- **SSID pattern matching** as secondary detection method
- **Configurable scan duration** via NUMBER_PICKER interface
- **Detailed loot logging** with manufacturer, BSSID, SSID, channel, signal strength, and encryption type
- **Clean exit handling** with automatic interface restoration
- **Pager-native UI** using PROMPT, SPINNER, and NUMBER_PICKER helpers

## Configuration

| Variable | Default | Description |
|---|---|---|
| `INTERFACE` | `wlan0` | Wireless interface to use |
| `LOOT_DIR` | `/root/loot/drone_hunter` | Where to save scan results |
| `DEFAULT_DURATION` | `30` | Default scan time in seconds |

## LED Status

| LED State | Description |
|---|---|
| SETUP | Initializing monitor mode |
| SPECIAL | Actively scanning for drone signals |
| SUCCESS | One or more drones detected |
| FAIL | No drones found or error occurred |
| CLEANUP | Restoring wireless interfaces |

## Requirements

- `aircrack-ng` suite (airmon-ng, airodump-ng)
- WiFi Pineapple Pager with monitor mode capable interface

## Usage

1. Run the payload from the Pager UI
2. Press OK on the info screen
3. Set scan duration (default: 30 seconds)
4. Wait for scan to complete
5. Review results on screen and in loot file

## Loot Output

Results are saved to `/root/loot/drone_hunter/drones_YYYYMMDD_HHMMSS.txt`:

```
════════════════════════════════════════
  DRONE HUNTER - Scan Results
════════════════════════════════════════
Date:     Wed Mar 12 14:30:00 UTC 2026
Duration: 30s

  ★ DRONE DETECTED
  Manufacturer: DJI
  BSSID:        60:60:1F:AA:BB:CC
  SSID:         Mavic-Pro-XXXX
  Channel:      6
  Signal:       -45 dBm
  Encryption:   WPA2

════════════════════════════════════════
Total Drones Found: 1
════════════════════════════════════════
```

## Disclaimer

For **authorized security auditing and research only**. Unauthorized interception of wireless communications may violate local and international laws. Users are solely responsible for compliance with all applicable laws.

## License

MIT License - [bad-antics](https://github.com/bad-antics)
