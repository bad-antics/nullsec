#!/bin/bash
# NullSec Signal Survey
# Comprehensive RF environment analysis

LOOT_DIR="/root/loot/signals"
mkdir -p "$LOOT_DIR"
OUTPUT="$LOOT_DIR/survey_$(date +%Y%m%d_%H%M%S)"

echo "[*] NullSec Signal Survey"
echo "[*] Output: $OUTPUT"

# WiFi survey
echo "=== WiFi Networks ===" > "${OUTPUT}_wifi.txt"
iw dev wlan0 scan 2>/dev/null | grep -E "SSID|signal|freq" >> "${OUTPUT}_wifi.txt"

# Bluetooth survey  
echo "=== Bluetooth Devices ===" > "${OUTPUT}_bt.txt"
timeout 30 hcitool scan 2>/dev/null >> "${OUTPUT}_bt.txt"
timeout 30 hcitool lescan 2>/dev/null >> "${OUTPUT}_bt.txt" &
sleep 35

# Channel utilization
echo "=== Channel Analysis ===" > "${OUTPUT}_channels.txt"
for ch in 1 6 11 36 40 44 48; do
    iwconfig wlan0 channel $ch 2>/dev/null
    count=$(timeout 5 tcpdump -i wlan0 -c 100 2>/dev/null | wc -l)
    echo "Channel $ch: $count packets" >> "${OUTPUT}_channels.txt"
done

echo "[+] Survey complete: $OUTPUT"
