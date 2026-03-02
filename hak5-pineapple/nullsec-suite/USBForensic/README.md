# 🔌 USBForensic

**USB Device Forensics & History Analyzer**

Reconstruct complete USB device history from system artifacts. Detect BadUSB/Rubber Ducky attacks with built-in device fingerprinting and risk scoring.

## Features

- 🔍 **Device enumeration** — Live scan via /sys/bus/usb/devices
- 📜 **History reconstruction** — Parse syslog, journal, kern.log for USB events
- 🦆 **BadUSB detection** — Known attack device VID:PID database (Rubber Ducky, O.MG, Teensy, etc.)
- ⚠️ **Risk scoring** — Automated risk assessment per device (0-100)
- 💾 **Mount history** — Track USB storage mount points
- 📅 **Timeline** — Chronological USB connect/disconnect events
- 🔐 **Device fingerprinting** — VID:PID + serial + manufacturer hash

## Usage

```bash
# Full forensic analysis
sudo python3 usbforensic.py --full

# Show current devices with risk scores
sudo python3 usbforensic.py --current

# View USB event timeline
sudo python3 usbforensic.py --timeline

# JSON output
sudo python3 usbforensic.py --full --json
```

## Known BadUSB Device Database

| VID:PID | Device | Risk |
|---------|--------|------|
| 04d8:003f | USB Rubber Ducky (Hak5) | Critical |
| feed:1337 | O.MG Cable | Critical |
| 16c0:0486 | Teensy | High |
| 2341:8036 | Arduino Leonardo | High |
| 1d50:60fc | USBNinja Cable | Critical |
| 2b4d:1557 | USB Armory | High |

## Risk Scoring

| Score | Rating | Indicators |
|-------|--------|------------|
| 80+ | Critical | Known attack tool VID:PID |
| 40+ | High | HID + Mass Storage combo (BadUSB pattern) |
| 20+ | Medium | Unknown manufacturer HID device |
| 5+ | Low | Missing serial number |

## Requirements

- Python 3.6+
- Root recommended for full log access
- Linux with /sys and /proc

## Part of [NullSec Security Suite](https://github.com/bad-antics/nullsec-suite)
