#!/bin/bash
# Title: Network Mapper
# Author: NullSec
# Description: Scan and map all nearby networks
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/networkmap"
mkdir -p "$LOOT_DIR"

PROMPT "NETWORK MAPPER

Scan and catalog all
nearby WiFi networks.

Records:
- SSIDs and BSSIDs
- Channels and encryption
- Signal strength
- Connected clients

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

DURATION=$(NUMBER_PICKER "Scan duration (sec):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac

resp=$(CONFIRMATION_DIALOG "START NETWORK MAP?

Interface: $MON_IF
Duration: ${DURATION}s

Press OK to scan.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Mapping networks..."
SPINNER_START "Scanning all channels..."

rm -f /tmp/netmap*
timeout "$DURATION" airodump-ng "$MON_IF" --output-format csv -w /tmp/netmap 2>/dev/null &
sleep "$DURATION"
killall airodump-ng 2>/dev/null

SPINNER_STOP

LOG_FILE="$LOOT_DIR/map_$(date +%Y%m%d_%H%M).txt"
NET_COUNT=0

if [ -f /tmp/netmap-01.csv ]; then
    echo "=== NETWORK MAP - $(date) ===" > "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    while IFS=',' read -r bssid x1 x2 channel x3 privacy x5 x6 power x7 x8 x9 x10 essid rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        essid=$(echo "$essid" | sed 's/^[[:space:]]*//')
        channel=$(echo "$channel" | tr -d ' ')
        privacy=$(echo "$privacy" | tr -d ' ')
        power=$(echo "$power" | tr -d ' ')
        NET_COUNT=$((NET_COUNT + 1))
        printf "%-18s CH:%-3s %-10s %sdBm %s\n" "$bssid" "$channel" "$privacy" "$power" "$essid" >> "$LOG_FILE"
    done < /tmp/netmap-01.csv
fi

rm -f /tmp/netmap* 2>/dev/null

PROMPT "NETWORK MAP COMPLETE

Networks found: $NET_COUNT
Map file: $LOG_FILE

Press OK to exit."
