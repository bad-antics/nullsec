#!/bin/bash
# NullSec WiFi Probe Logger
# Captures probe requests to identify nearby devices and their preferred networks

LOOT_DIR="/root/loot/probes"
IFACE="${1:-wlan0}"

mkdir -p "$LOOT_DIR"
OUTPUT="$LOOT_DIR/probes_$(date +%Y%m%d_%H%M%S).txt"

echo "[*] NullSec Probe Logger"
echo "[*] Interface: $IFACE"
echo "[*] Output: $OUTPUT"

# Put interface in monitor mode
airmon-ng start $IFACE 2>/dev/null
IFACE="${IFACE}mon"

# Capture probe requests
tcpdump -i $IFACE -e -s 256 type mgt subtype probe-req 2>/dev/null | \
while read line; do
    MAC=$(echo "$line" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | head -1)
    SSID=$(echo "$line" | grep -oP 'Probe Request \(\K[^)]+')
    if [[ -n "$MAC" ]]; then
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        echo "$TIMESTAMP | $MAC | $SSID" | tee -a "$OUTPUT"
    fi
done
