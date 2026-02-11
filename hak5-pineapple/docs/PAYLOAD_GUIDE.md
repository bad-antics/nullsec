# Payload Development Guide

## Payload Structure

Every NullSec Pineapple payload follows this structure:
```
MyPayload/
├── payload.sh    # Main executable script
├── README.md     # Documentation and usage
└── config.txt    # Optional configuration
```

## payload.sh Template

```bash
#!/bin/bash
# Title: My Payload
# Author: bad-antics
# Category: recon
# Description: Does something useful
# Version: 1.0

# Configuration
LOOT_DIR=/root/loot/my-payload
mkdir -p "$LOOT_DIR"
IFACE="wlan1mon"

# LED indicator - setting up
LED SETUP

# Check dependencies
if ! command -v airodump-ng &>/dev/null; then
    echo "[-] aircrack-ng not installed"
    LED FAIL
    exit 1
fi

# Main logic
echo "[*] Starting payload..."
LED ATTACK

# Your attack code here
airodump-ng "$IFACE" --output-format csv -w "$LOOT_DIR/scan" &
sleep 30
kill %1

# Process results
echo "[*] Processing results..."
LED SPECIAL
wc -l "$LOOT_DIR/scan-01.csv"

# Cleanup
LED CLEANUP
echo "[*] Cleaning temporary files..."

# Finish
LED FINISH
echo "[✓] Complete. Loot saved to $LOOT_DIR"
```

## LED States

```bash
LED SETUP      # Magenta solid    — Setting up
LED ATTACK     # Red solid        — Attacking
LED SPECIAL    # Cyan solid       — Special function
LED CLEANUP    # White solid      — Cleaning up
LED FINISH     # Green solid      — Done
LED FAIL       # Red blink        — Error
LED OFF        # LED off          — Stealth mode
```

## Configuration File

Optional `config.txt` for user-configurable options:
```
# Target BSSID (leave empty for all)
TARGET_BSSID=

# Channel (0 for all)
CHANNEL=0

# Duration in seconds
DURATION=60

# Output format (csv, pcap, json)
FORMAT=csv
```

## Reading Config in payload.sh

```bash
# Source config if exists
if [ -f "$(dirname "$0")/config.txt" ]; then
    source "$(dirname "$0")/config.txt"
fi

# Use with defaults
TARGET="${TARGET_BSSID:-}"
CHAN="${CHANNEL:-0}"
DUR="${DURATION:-60}"
```

## Testing

```bash
# Test on Pineapple via SSH
ssh root@172.16.42.1
cd /root/payloads/MyPayload
bash -x payload.sh   # Debug mode

# Test locally (limited without Pineapple hardware)
bash payload.sh
```

## Best Practices

1. **Always use LED indicators** — Users need visual feedback
2. **Check dependencies** — Verify required tools are installed
3. **Handle errors gracefully** — Use `set -e` or explicit checks
4. **Create loot directories** — Don't assume they exist
5. **Document everything** — Write clear README.md
6. **Support configuration** — Use config.txt for customizable options
7. **Clean up after yourself** — Remove temp files, stop background processes
8. **Use monitor mode carefully** — Always check interface availability
