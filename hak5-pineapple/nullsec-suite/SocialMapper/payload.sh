#!/bin/bash
# Title: Social Mapper
# Author: NullSec
# Description: Map device relationships and network patterns
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/socialmap"
mkdir -p "$LOOT_DIR"

PROMPT "SOCIAL MAPPER

Map device relationships by
analyzing probe requests
and network associations.

Reveals:
- Device home networks
- Travel patterns
- Social groupings

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

DURATION=$(NUMBER_PICKER "Scan duration (sec):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START SOCIAL MAPPING?

Interface: $MON_IF
Duration: ${DURATION}s

Passive monitoring only.
No packets transmitted.

Press OK to scan.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Social mapping started..."
SPINNER_START "Observing network relationships..."

rm -f /tmp/socialmap*
timeout "$DURATION" airodump-ng "$MON_IF" --write /tmp/socialmap --output-format csv --write-interval 5 2>/dev/null &
sleep "$DURATION"
killall airodump-ng 2>/dev/null

SPINNER_STOP

MAP_FILE="$LOOT_DIR/social_$(date +%Y%m%d_%H%M).txt"
echo "=== SOCIAL NETWORK MAP - $(date) ===" > "$MAP_FILE"

AP_COUNT=0
CLIENT_COUNT=0

if [ -f /tmp/socialmap-01.csv ]; then
    echo "" >> "$MAP_FILE"
    echo "=== ACCESS POINTS ===" >> "$MAP_FILE"
    while IFS=',' read -r bssid x1 x2 channel x3 privacy x5 x6 power x7 x8 x9 x10 essid rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        [[ "$bssid" == *"Station"* ]] && break
        essid=$(echo "$essid" | sed 's/^[[:space:]]*//')
        AP_COUNT=$((AP_COUNT + 1))
        echo "  $essid ($bssid) CH:$(echo $channel | tr -d ' ')" >> "$MAP_FILE"
    done < /tmp/socialmap-01.csv

    echo "" >> "$MAP_FILE"
    echo "=== CLIENT DEVICES ===" >> "$MAP_FILE"
    IN_CLIENTS=0
    while IFS=',' read -r mac x1 x2 power packets bssid probes rest; do
        mac=$(echo "$mac" | tr -d ' ')
        [[ "$mac" == *"Station"* ]] && IN_CLIENTS=1 && continue
        [ $IN_CLIENTS -eq 0 ] && continue
        [[ ! "$mac" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        probes=$(echo "$probes" | sed 's/^[[:space:]]*//')
        bssid=$(echo "$bssid" | tr -d ' ')
        CLIENT_COUNT=$((CLIENT_COUNT + 1))
        echo "  Client: $mac" >> "$MAP_FILE"
        [ "$bssid" != "(notassociated)" ] && [ -n "$bssid" ] && echo "    Connected to: $bssid" >> "$MAP_FILE"
        [ -n "$probes" ] && echo "    Probing: $probes" >> "$MAP_FILE"
    done < /tmp/socialmap-01.csv
fi

rm -f /tmp/socialmap* 2>/dev/null

PROMPT "SOCIAL MAP COMPLETE

APs found: $AP_COUNT
Clients: $CLIENT_COUNT
Map: $MAP_FILE

Press OK to exit."
