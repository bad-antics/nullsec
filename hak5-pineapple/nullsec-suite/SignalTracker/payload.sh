#!/bin/bash
# Title: Signal Tracker
# Author: bad-antics
# Description: Track signal strength to locate WiFi sources
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/signaltrack"
mkdir -p "$LOOT_DIR"

PROMPT "SIGNAL TRACKER

Track WiFi signal strength
to physically locate
access points or clients.

Useful for finding hidden
devices or rogue APs.

Press OK to configure."

# Use existing monitor interface
MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

PROMPT "TRACK MODE:

1. Track Access Point
2. Track Client Device

Select on next screen."

MODE=$(NUMBER_PICKER "Mode (1=AP 2=Client):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=1 ;; esac

SPINNER_START "Quick scan..."

TEMP_DIR="/tmp/sigtrack_$$"
mkdir -p "$TEMP_DIR"
rm -f /tmp/sigtrack_*
timeout 10 airodump-ng "$MON_IF" -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
sleep 10
killall airodump-ng 2>/dev/null

SPINNER_STOP

if [ "$MODE" = "1" ]; then
    NET_COUNT=0; NETS=""
    if [ -f "$TEMP_DIR/scan-01.csv" ]; then
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
        done < "$TEMP_DIR/scan-01.csv"
    fi
    [ $NET_COUNT -eq 0 ] && { ERROR_DIALOG "No APs found!"; rm -rf "$TEMP_DIR"; exit 1; }
    PROMPT "APs FOUND: $NET_COUNT\n\n$(echo -e "$NETS")\nSelect target."
    SEL=$(NUMBER_PICKER "AP # (1-$NET_COUNT):" 1)
    eval "TARGET=\"\$BSSID_${SEL}\""
    eval "CHANNEL=\"\$CH_${SEL}\""
else
    TARGET=$(MAC_PICKER "Client MAC to track:")
    CHANNEL=$(NUMBER_PICKER "Channel:" 6)
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) CHANNEL=6 ;; esac
fi

[ -z "$TARGET" ] && { ERROR_DIALOG "No target specified!"; exit 1; }

TRACK_SECS=$(NUMBER_PICKER "Track duration (sec):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TRACK_SECS=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START TRACKING?

Target: $TARGET
Channel: $CHANNEL
Duration: ${TRACK_SECS}s

Move around to locate.
Higher signal = closer.

Press OK to track.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && { rm -rf "$TEMP_DIR"; exit 0; }

iwconfig "$MON_IF" channel "$CHANNEL" 2>/dev/null

LOG_FILE="$LOOT_DIR/track_$(date +%Y%m%d_%H%M).txt"
echo "Signal Tracking: $TARGET on CH:$CHANNEL" > "$LOG_FILE"

LOG "Tracking $TARGET on CH:$CHANNEL..."

# Track using repeated short airodump scans
ITERATIONS=$((TRACK_SECS / 3))
[ "$ITERATIONS" -lt 5 ] && ITERATIONS=5

LAST_SIGNAL=""
for i in $(seq 1 "$ITERATIONS"); do
    rm -f /tmp/sigpoll*
    timeout 2 airodump-ng "$MON_IF" -c "$CHANNEL" --bssid "$TARGET" -w /tmp/sigpoll --output-format csv 2>/dev/null &
    sleep 2
    killall airodump-ng 2>/dev/null

    SIGNAL=""
    if [ -f /tmp/sigpoll-01.csv ]; then
        SIGNAL=$(grep "$TARGET" /tmp/sigpoll-01.csv 2>/dev/null | head -1 | awk -F',' '{print $9}' | tr -d ' ')
    fi

    if [ -n "$SIGNAL" ] && [ "$SIGNAL" != "0" ]; then
        ABS_SIG=${SIGNAL#-}
        if [ "$ABS_SIG" -lt 50 ] 2>/dev/null; then
            BARS="█████ VERY CLOSE!"
        elif [ "$ABS_SIG" -lt 60 ]; then
            BARS="████░ CLOSE"
        elif [ "$ABS_SIG" -lt 70 ]; then
            BARS="███░░ MEDIUM"
        elif [ "$ABS_SIG" -lt 80 ]; then
            BARS="██░░░ FAR"
        else
            BARS="█░░░░ VERY FAR"
        fi
        LOG "${SIGNAL}dBm $BARS"
        echo "$(date +%H:%M:%S) ${SIGNAL}dBm $BARS" >> "$LOG_FILE"
        LAST_SIGNAL="$SIGNAL"
    else
        LOG "No signal..."
    fi
    rm -f /tmp/sigpoll*
done

rm -rf "$TEMP_DIR"

PROMPT "TRACKING COMPLETE

Target: $TARGET
Last Signal: ${LAST_SIGNAL:-N/A}dBm
Log: $LOG_FILE

Press OK to exit."
