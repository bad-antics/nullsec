#!/bin/bash
# Title:         WiFi Timeline
# Description:   Record and replay a historical timeline of all WiFi networks seen over time
# Author:        bad-antics
# Version:       1.0
# Category:      General
# Target:        WiFi Pineapple Pager
#
# LED State Descriptions
# SETUP     - Initializing
# SPECIAL   - Recording / scanning
# SUCCESS   - Timeline saved / displayed
# CLEANUP   - Restoring interfaces
#
# Firmware:  Tested on firmware 1.0.4+

# ============================================================================
# CONFIGURATION
# ============================================================================
INTERFACE="wlan0"
TIMELINE_DIR="/root/loot/wifi_timeline"
DB_FILE="$TIMELINE_DIR/timeline.db"
SCAN_INTERVAL=10         # Seconds between scans
DEFAULT_SCANS=12         # Number of scan cycles (total = SCAN_INTERVAL * DEFAULT_SCANS)

# ============================================================================
# CLEANUP TRAP
# ============================================================================
cleanup() {
    airmon-ng stop "${INTERFACE}mon" 2>/dev/null
    airmon-ng stop "$INTERFACE" 2>/dev/null
    rm -rf "/tmp/timeline_$$"
    LED CLEANUP
}
trap cleanup EXIT

# ============================================================================
# DATABASE FUNCTIONS
# ============================================================================
init_db() {
    mkdir -p "$TIMELINE_DIR"
    touch "$DB_FILE"
}

# Record format: TIMESTAMP|BSSID|SSID|CHANNEL|SIGNAL|ENCRYPTION|LOCATION
record_ap() {
    local ts="$1" bssid="$2" ssid="$3" ch="$4" sig="$5" enc="$6"
    echo "${ts}|${bssid}|${ssid}|${ch}|${sig}|${enc}" >> "$DB_FILE"
}

# Get first and last seen times for a network
get_history() {
    local bssid="$1"
    FIRST_SEEN=$(grep "|${bssid}|" "$DB_FILE" | head -1 | cut -d'|' -f1)
    LAST_SEEN=$(grep "|${bssid}|" "$DB_FILE" | tail -1 | cut -d'|' -f1)
    TIMES_SEEN=$(grep -c "|${bssid}|" "$DB_FILE")
}

# ============================================================================
# PAYLOAD START
# ============================================================================
LED SETUP
init_db

PROMPT "WIFI TIMELINE v1.0

Build a historical record
of WiFi networks across
time and locations.

Modes:
1. RECORD - Scan and add
   to timeline database
2. VIEW - Browse timeline
   history and stats
3. EXPORT - Save report

Press OK to choose mode."

MODE=$(NUMBER_PICKER "Mode (1-3):" 1)
case $? in
    $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED)
        exit 0
        ;;
esac
[ -z "$MODE" ] && MODE=1

# ============================================================================
# MODE 1: RECORD
# ============================================================================
if [ "$MODE" = "1" ]; then
    CYCLES=$(NUMBER_PICKER "Scan cycles:" $DEFAULT_SCANS)
    [ -z "$CYCLES" ] && CYCLES=$DEFAULT_SCANS

    TOTAL_TIME=$((CYCLES * SCAN_INTERVAL))

    PROMPT "RECORDING

Will scan $CYCLES times
over ${TOTAL_TIME} seconds.

Networks will be added
to your timeline database.

DB: $DB_FILE

Press OK to start."

    # Initialize monitor mode
    SPINNER_START "Starting monitor mode..."
    airmon-ng check kill 2>/dev/null
    sleep 1
    airmon-ng start "$INTERFACE" >/dev/null 2>&1
    MON_IF="${INTERFACE}mon"
    [ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"
    SPINNER_STOP

    TEMP_DIR="/tmp/timeline_$$"
    mkdir -p "$TEMP_DIR"

    NEW_NETWORKS=0
    UPDATED_NETWORKS=0

    for CYCLE in $(seq 1 "$CYCLES"); do
        LED SPECIAL
        LOG "Scan $CYCLE/$CYCLES..."

        # Quick scan
        timeout "$SCAN_INTERVAL" airodump-ng "$MON_IF" -w "$TEMP_DIR/scan_${CYCLE}" --output-format csv 2>/dev/null &
        SCAN_PID=$!
        sleep "$SCAN_INTERVAL"
        kill $SCAN_PID 2>/dev/null
        wait $SCAN_PID 2>/dev/null

        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

        # Parse and record
        if [ -f "$TEMP_DIR/scan_${CYCLE}-01.csv" ]; then
            while IFS=',' read -r BSSID F2 F3 CHANNEL F5 SPEED PRIVACY CIPHER AUTH POWER F11 F12 F13 ESSID REST; do
                BSSID=$(echo "$BSSID" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
                ESSID=$(echo "$ESSID" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                CHANNEL_C=$(echo "$CHANNEL" | tr -d ' ')
                POWER_C=$(echo "$POWER" | tr -d ' ')
                PRIVACY_C=$(echo "$PRIVACY" | tr -d ' ')

                if [ -n "$BSSID" ] && echo "$BSSID" | grep -qE "^[0-9A-Fa-f]{2}:"; then
                    # Check if this is a new network
                    if ! grep -q "|${BSSID}|" "$DB_FILE" 2>/dev/null; then
                        NEW_NETWORKS=$((NEW_NETWORKS + 1))
                    else
                        UPDATED_NETWORKS=$((UPDATED_NETWORKS + 1))
                    fi

                    record_ap "$TIMESTAMP" "$BSSID" "$ESSID" "$CHANNEL_C" "$POWER_C" "$PRIVACY_C"
                fi
            done < "$TEMP_DIR/scan_${CYCLE}-01.csv"
        fi
    done

    # Count totals
    TOTAL_UNIQUE=$(cut -d'|' -f2 "$DB_FILE" | sort -u | wc -l)
    TOTAL_RECORDS=$(wc -l < "$DB_FILE")

    LED SUCCESS
    PROMPT "RECORDING COMPLETE

New networks:     $NEW_NETWORKS
Updated entries:  $UPDATED_NETWORKS

Timeline totals:
  Unique networks: $TOTAL_UNIQUE
  Total records:   $TOTAL_RECORDS

DB: $DB_FILE

Press OK to exit."

# ============================================================================
# MODE 2: VIEW TIMELINE
# ============================================================================
elif [ "$MODE" = "2" ]; then
    if [ ! -s "$DB_FILE" ]; then
        LED FAIL
        PROMPT "EMPTY TIMELINE

No records in database.
Run Record mode first.

Press OK to exit."
        exit 0
    fi

    LED SUCCESS
    TOTAL_UNIQUE=$(cut -d'|' -f2 "$DB_FILE" | sort -u | wc -l)
    TOTAL_RECORDS=$(wc -l < "$DB_FILE")
    FIRST_RECORD=$(head -1 "$DB_FILE" | cut -d'|' -f1)
    LAST_RECORD=$(tail -1 "$DB_FILE" | cut -d'|' -f1)

    # Top 10 most seen networks
    TOP_NETWORKS=$(cut -d'|' -f2,3 "$DB_FILE" | sort | uniq -c | sort -rn | head -10)

    # Encryption breakdown
    OPEN_COUNT=$(grep -c "|OPN|*$\||OPN$" "$DB_FILE" 2>/dev/null || echo 0)
    WPA2_COUNT=$(grep -c "WPA2" "$DB_FILE" 2>/dev/null || echo 0)
    WPA3_COUNT=$(grep -c "WPA3" "$DB_FILE" 2>/dev/null || echo 0)
    WEP_COUNT=$(grep -c "|WEP|" "$DB_FILE" 2>/dev/null || echo 0)

    PROMPT "TIMELINE STATS

Period: $FIRST_RECORD
     to $LAST_RECORD

Unique networks: $TOTAL_UNIQUE
Total sightings: $TOTAL_RECORDS

Encryption:
  Open: $OPEN_COUNT
  WEP:  $WEP_COUNT
  WPA2: $WPA2_COUNT
  WPA3: $WPA3_COUNT

Press OK for top networks."

    LOG "════ TOP NETWORKS ════"
    LOG "$TOP_NETWORKS"
    LOG ""
    LOG "Press any button to exit"
    WAIT_FOR_BUTTON_PRESS

# ============================================================================
# MODE 3: EXPORT REPORT
# ============================================================================
elif [ "$MODE" = "3" ]; then
    if [ ! -s "$DB_FILE" ]; then
        LED FAIL
        PROMPT "EMPTY TIMELINE

No records to export.
Run Record mode first."
        exit 0
    fi

    SPINNER_START "Generating report..."

    REPORT_FILE="$TIMELINE_DIR/report_$(date +%Y%m%d_%H%M%S).txt"
    TOTAL_UNIQUE=$(cut -d'|' -f2 "$DB_FILE" | sort -u | wc -l)
    TOTAL_RECORDS=$(wc -l < "$DB_FILE")

    {
        echo "════════════════════════════════════════"
        echo "  WIFI TIMELINE REPORT"
        echo "════════════════════════════════════════"
        echo "Generated: $(date)"
        echo "Database:  $DB_FILE"
        echo ""
        echo "Total unique networks: $TOTAL_UNIQUE"
        echo "Total observations:    $TOTAL_RECORDS"
        echo ""
        echo "─── Network Catalog ───"
        echo ""

        cut -d'|' -f2 "$DB_FILE" | sort -u | while read -r BSSID; do
            SSID=$(grep "|${BSSID}|" "$DB_FILE" | tail -1 | cut -d'|' -f3)
            ENC=$(grep "|${BSSID}|" "$DB_FILE" | tail -1 | cut -d'|' -f6)
            FIRST=$(grep "|${BSSID}|" "$DB_FILE" | head -1 | cut -d'|' -f1)
            LAST=$(grep "|${BSSID}|" "$DB_FILE" | tail -1 | cut -d'|' -f1)
            COUNT=$(grep -c "|${BSSID}|" "$DB_FILE")

            echo "  Network: ${SSID:-<hidden>}"
            echo "    BSSID:      $BSSID"
            echo "    Encryption: $ENC"
            echo "    First seen: $FIRST"
            echo "    Last seen:  $LAST"
            echo "    Sightings:  $COUNT"
            echo ""
        done

        echo "════════════════════════════════════════"
        echo "  END OF REPORT"
        echo "════════════════════════════════════════"
    } > "$REPORT_FILE"

    SPINNER_STOP
    LED SUCCESS

    PROMPT "REPORT EXPORTED

File: $REPORT_FILE

Contains full catalog of
all $TOTAL_UNIQUE networks
with timestamps and
encryption details.

Press OK to exit."
fi

LOG "WiFi Timeline complete."
