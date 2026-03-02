# Deauth Detector

* **Author:** bad-antics
* **Version:** 1.0
* **Category:** Reconnaissance
* **Target:** WiFi Pineapple Pager
* **Firmware:** 1.0.4+

## Description

Deauth Detector is a **defensive** WiFi monitoring payload that detects deauthentication and disassociation attacks in real-time. It monitors all WiFi channels (2.4GHz and 5GHz) for malicious management frames and alerts you immediately when an attack is detected — turning your Pineapple Pager into a pocket-sized wireless IDS.

Perfect for:
- **Red team awareness** — know when someone else is attacking the same environment
- **Blue team operations** — detect unauthorized deauth attacks on your network
- **Security auditing** — verify that WIDS/WIPS solutions are working
- **RF environment assessment** — baseline wireless attack activity in an area

## Features

- **Real-time deauth/disassoc frame detection** using tcpdump
- **Automatic channel hopping** across 2.4GHz and 5GHz bands
- **Configurable alert threshold** — set sensitivity for your environment
- **Haptic alerts** — vibration + screen notification on attack detection
- **Attack source tracking** — identifies and ranks attacker MACs
- **Comprehensive logging** with timestamps, sources, destinations, and channels
- **Adjustable monitoring duration**
- **Clean trap-based cleanup**

## Configuration

| Variable | Default | Description |
|---|---|---|
| `INTERFACE` | `wlan0` | Wireless interface |
| `LOOT_DIR` | `/root/loot/deauth_detector` | Loot output directory |
| `ALERT_THRESHOLD` | `5` | Deauth frames before alerting |
| `CHANNEL_HOP_DELAY` | `0.5` | Seconds per channel during hopping |
| `MONITOR_DURATION` | `120` | Default monitoring time in seconds |

## LED Status

| LED State | Description |
|---|---|
| SETUP | Initializing monitor mode |
| SPECIAL | Monitoring — no attacks detected |
| ATTACK | Deauth attack detected! |
| SUCCESS | Monitoring complete — environment clean |
| CLEANUP | Restoring wireless interfaces |

## Requirements

- `tcpdump` (pre-installed on Pager)
- `aircrack-ng` suite (airmon-ng)

## Usage

1. Run the payload from the Pager UI
2. Set monitoring duration (default: 120 seconds)
3. Set alert threshold (default: 5 frames)
4. The Pager will monitor all channels
5. If deauth frames exceed threshold → vibration + screen alert
6. Final summary shows total frames and top attacker MACs

## Loot Output

Results saved to `/root/loot/deauth_detector/deauth_YYYYMMDD_HHMMSS.txt`:

```
════════════════════════════════════════
  DEAUTH DETECTOR - Monitor Log
════════════════════════════════════════
Date:      Wed Mar 12 14:30:00 UTC 2026
Duration:  120s
Threshold: 5 frames

[14:30:05] DEAUTH   SRC=aa:bb:cc:dd:ee:ff  DST=ff:ff:ff:ff:ff:ff  CH=6
[14:30:05] DEAUTH   SRC=aa:bb:cc:dd:ee:ff  DST=11:22:33:44:55:66  CH=6

  ⚠ ATTACK ALERT TRIGGERED
  Primary source: aa:bb:cc:dd:ee:ff
  Channel: 6

════════════════════════════════════════
  MONITORING COMPLETE
════════════════════════════════════════
Total deauth/disassoc frames: 47
Alerts triggered: 1
════════════════════════════════════════
```

## Disclaimer

For **authorized security monitoring and auditing only**. This is a defensive/detection payload. Users are solely responsible for compliance with all applicable laws.

## License

MIT License - [bad-antics](https://github.com/bad-antics)
