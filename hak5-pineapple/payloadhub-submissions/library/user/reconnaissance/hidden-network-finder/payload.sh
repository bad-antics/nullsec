#!/bin/bash
# Title:         Hidden Network Finder
# Description:   Discover and reveal hidden/cloaked WiFi networks
# Author:        bad-antics
# Version:       1.0
# Category:      Reconnaissance
# Target:        WiFi Pineapple Pager
#
# LED State Descriptions
# SETUP     - Initializing scanner
# SPECIAL   - Scanning for hidden networks
# SUCCESS   - Hidden networks revealed
# FAIL      - No hidden networks found
# CLEANUP   - Restoring interfaces
#
# Firmware:  Tested on firmware 1.0.4+

# ============================================================================
# CONFIGURATION
# ============================================================================
INTERFACE="wlan0"
LOOT_DIR="/root/loot/hidden_finder"
SCAN_DURATION=30
PROBE_DURATION=15

# ============================================================================
# CLEANUP TRAP
# ============================================================================
cleanup() {
    [ -n "$HOP_PID" ] && kill $HOP_PID 2>/dev/null
    airmon-ng stop "${INTERFACE}mon" 2>/dev/null
    airmon-ng stop "$INTERFACE" 2>/dev/null
    rm -rf "/tmp/hidden_$$"
    LED CLEANUP
}
trap cleanup EXIT

# ============================================================================
# PAYLOAD START
# ============================================================================
LED SETUP

PROMPT "HIDDEN NETWORK FINDER

Discover cloaked WiFi
networks that hide their
SSID from normal scans.

Methods used:
1. Beacon frame analysis
   (detect <length: 0>)
2. Probe response capture
   (reveal actual SSID)
3. Client association
   correlation

Press OK to start."

DURATION=$(NUMBER_PICKER "Scan time (sec):" $SCAN_DURATION)
case $? in
    $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED)
        exit 0
        ;;
esac
[ -z "$DURATION" ] && DURATION=$SCAN_DURATION

# ============================================================================
# INITIALIZE MONITOR MODE
# ============================================================================
SPINNER_START "Enabling monitor mode..."

airmon-ng check kill 2>/dev/null
sleep 1
airmon-ng start "$INTERFACE" >/dev/null 2>&1
MON_IF="${INTERFACE}mon"
[ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

SPINNER_STOP

# ============================================================================
# PREPARE LOOT
# ============================================================================
mkdir -p "$LOOT_DIR"
LOOT_FILE="$LOOT_DIR/hidden_$(date +%Y%m%d_%H%M%S).txt"
TEMP_DIR="/tmp/hidden_$$"
mkdir -p "$TEMP_DIR"

{
    echo "════════════════════════════════════════"
    echo "  HIDDEN NETWORK FINDER - Results"
    echo "════════════════════════════════════════"
    echo "Date:     $(date)"
    echo "Duration: ${DURATION}s"
    echo "════════════════════════════════════════"
    echo ""
} > "$LOOT_FILE"

# ============================================================================
# PHASE 1: SCAN FOR ALL NETWORKS
# ============================================================================
LED SPECIAL
SPINNER_START "Phase 1: Scanning (${DURATION}s)..."

timeout "$DURATION" airodump-ng "$MON_IF" -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
SCAN_PID=$!
sleep "$DURATION"
kill $SCAN_PID 2>/dev/null
wait $SCAN_PID 2>/dev/null

SPINNER_STOP

# ============================================================================
# PHASE 2: IDENTIFY HIDDEN NETWORKS
# ============================================================================
SPINNER_START "Phase 2: Analyzing..."

HIDDEN_COUNT=0
HIDDEN_BSSIDS=""

if [ -f "$TEMP_DIR/scan-01.csv" ]; then
    # Hidden networks show up with empty SSID or <length: N> in CSV
    while IFS=',' read -r BSSID F2 F3 CHANNEL F5 SPEED PRIVACY CIPHER AUTH POWER F11 F12 F13 ESSID REST; do
        BSSID=$(echo "$BSSID" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
        ESSID_CLEAN=$(echo "$ESSID" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        CHANNEL_CLEAN=$(echo "$CHANNEL" | tr -d ' ')
        POWER_CLEAN=$(echo "$POWER" | tr -d ' ')
        PRIVACY_CLEAN=$(echo "$PRIVACY" | tr -d ' ')

        if [ -n "$BSSID" ] && echo "$BSSID" | grep -qE "^[0-9A-Fa-f]{2}:"; then
            # Check if SSID is empty or hidden
            if [ -z "$ESSID_CLEAN" ] || echo "$ESSID_CLEAN" | grep -qiE "^$|^\\\\x00" ; then
                HIDDEN_COUNT=$((HIDDEN_COUNT + 1))
                HIDDEN_BSSIDS="${HIDDEN_BSSIDS}${BSSID}|${CHANNEL_CLEAN}|${POWER_CLEAN}|${PRIVACY_CLEAN}\n"

                {
                    echo "  ◆ HIDDEN NETWORK #${HIDDEN_COUNT}"
                    echo "    BSSID:      $BSSID"
                    echo "    Channel:    $CHANNEL_CLEAN"
                    echo "    Signal:     $POWER_CLEAN dBm"
                    echo "    Encryption: $PRIVACY_CLEAN"
                    echo "    SSID:       <HIDDEN>"
                    echo ""
                } >> "$LOOT_FILE"
            fi
        fi
    done < "$TEMP_DIR/scan-01.csv"
fi

SPINNER_STOP

# ============================================================================
# PHASE 3: REVEAL SSIDS VIA PROBE RESPONSES
# ============================================================================
if [ "$HIDDEN_COUNT" -gt 0 ]; then
    PROMPT "Found $HIDDEN_COUNT hidden
networks!

Phase 3 will attempt to
reveal their SSIDs by
capturing probe responses
from connected clients.

Press OK to continue."

    LED SPECIAL
    SPINNER_START "Phase 3: Revealing SSIDs..."

    REVEALED=0

    echo -e "$HIDDEN_BSSIDS" | while IFS='|' read -r HIDDEN_MAC HIDDEN_CH HIDDEN_PWR HIDDEN_ENC; do
        [ -z "$HIDDEN_MAC" ] && continue

        # Tune to the hidden network's channel
        iwconfig "$MON_IF" channel "$HIDDEN_CH" 2>/dev/null

        # Capture probe responses for this BSSID
        REVEALED_SSID=$(timeout "$PROBE_DURATION" tcpdump -i "$MON_IF" -c 50 -l \
            "ether src $HIDDEN_MAC and (subtype probe-resp or subtype assoc-resp or subtype reassoc-resp)" \
            2>/dev/null | grep -oP 'SSID=\K[^ ]+' | head -1)

        if [ -n "$REVEALED_SSID" ] && [ "$REVEALED_SSID" != "(null)" ]; then
            REVEALED=$((REVEALED + 1))
            # Update loot file
            sed -i "/$HIDDEN_MAC/{n;n;n;n;s|<HIDDEN>|$REVEALED_SSID (REVEALED!)|}" "$LOOT_FILE"
            LOG "Revealed: $HIDDEN_MAC → $REVEALED_SSID"
        fi
    done

    SPINNER_STOP

    # Also check for client probes that might reveal the SSID
    SPINNER_START "Checking client probes..."

    # Look at the station/client section of the CSV
    if [ -f "$TEMP_DIR/scan-01.csv" ]; then
        IN_STATION_SECTION=false
        while IFS=',' read -r F1 F2 F3 F4 F5 F6 PROBED REST; do
            # Station section starts after a blank line in airodump CSV
            if echo "$F1" | grep -qE "^Station"; then
                IN_STATION_SECTION=true
                continue
            fi

            if [ "$IN_STATION_SECTION" = true ] && [ -n "$PROBED" ]; then
                PROBED_CLEAN=$(echo "$PROBED" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                STATION_BSSID=$(echo "$F2" | tr -d ' ' | tr '[:lower:]' '[:upper:]')

                # Check if this station's BSSID matches any hidden network
                if echo -e "$HIDDEN_BSSIDS" | grep -qi "$STATION_BSSID"; then
                    if [ -n "$PROBED_CLEAN" ] && [ "$PROBED_CLEAN" != "(not associated)" ]; then
                        echo "  → Client probe reveals: $PROBED_CLEAN (via $STATION_BSSID)" >> "$LOOT_FILE"
                    fi
                fi
            fi
        done < "$TEMP_DIR/scan-01.csv"
    fi

    SPINNER_STOP
fi

# ============================================================================
# RESULTS
# ============================================================================
{
    echo ""
    echo "════════════════════════════════════════"
    echo "  SCAN COMPLETE"
    echo "════════════════════════════════════════"
    echo "Hidden networks found: $HIDDEN_COUNT"
    echo "════════════════════════════════════════"
} >> "$LOOT_FILE"

if [ "$HIDDEN_COUNT" -gt 0 ]; then
    LED SUCCESS
    PROMPT "HIDDEN NETWORKS: $HIDDEN_COUNT

Found $HIDDEN_COUNT cloaked
networks in your area.

Check the loot file for
revealed SSIDs and details.

$LOOT_FILE

Press OK to exit."
else
    LED FAIL
    PROMPT "NO HIDDEN NETWORKS

No cloaked networks found
in ${DURATION}s scan.

All nearby networks are
broadcasting their SSID.

Press OK to exit."
fi

LOG "Hidden Network Finder complete. Hidden: $HIDDEN_COUNT"
