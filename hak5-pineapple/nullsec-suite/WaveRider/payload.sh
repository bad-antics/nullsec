#!/bin/bash
# Title: WaveRider - Channel-hopping Pursuit
# Author: NullSec
# Description: Track a device across channels
# Category: nullsec/tracking

LOOT_DIR="/mmc/nullsec/waverider"
mkdir -p "$LOOT_DIR"

PROMPT "WAVERIDER - TARGET PURSUIT

Track a specific device
across WiFi channels.

Hops channels to follow
target and capture traffic.

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

TARGET_MAC=$(MAC_PICKER "Target MAC address:")
[ -z "$TARGET_MAC" ] && { ERROR_DIALOG "No MAC entered!"; exit 1; }

DURATION=$(NUMBER_PICKER "Track duration (sec):" 120)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=120 ;; esac

resp=$(CONFIRMATION_DIALOG "START TRACKING?

Target: $TARGET_MAC
Duration: ${DURATION}s
Interface: $MON_IF

Will hop channels to find
and capture target traffic.

Press OK to pursue.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Pursuing $TARGET_MAC..."
LOG_FILE="$LOOT_DIR/track_$(date +%Y%m%d_%H%M).log"

END_TIME=$(($(date +%s) + DURATION))
FOUND_COUNT=0

while [ $(date +%s) -lt $END_TIME ]; do
    for ch in 1 6 11 2 3 4 5 7 8 9 10; do
        [ $(date +%s) -ge $END_TIME ] && break
        iwconfig "$MON_IF" channel $ch 2>/dev/null
        if timeout 2 tcpdump -i "$MON_IF" -c 5 -q 2>/dev/null | grep -qi "$TARGET_MAC"; then
            LOG "Target on channel $ch!"
            echo "$(date +%H:%M:%S) Found on CH:$ch" >> "$LOG_FILE"
            FOUND_COUNT=$((FOUND_COUNT + 1))
            timeout 15 tcpdump -i "$MON_IF" ether host "$TARGET_MAC" -w "$LOOT_DIR/cap_ch${ch}_$(date +%s).pcap" 2>/dev/null
        fi
    done
done

PROMPT "WAVERIDER COMPLETE

Target: $TARGET_MAC
Duration: ${DURATION}s
Times found: $FOUND_COUNT
Log: $LOG_FILE

Press OK to exit."
