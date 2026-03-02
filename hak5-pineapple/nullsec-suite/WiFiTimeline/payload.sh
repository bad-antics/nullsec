#!/bin/bash
# Title: WiFi Timeline
# Author: bad-antics
# Description: Build chronological timeline of wireless network activity
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/timeline"
mkdir -p "$LOOT_DIR"

PROMPT "WIFI TIMELINE

Builds a chronological map of
all wireless activity over time.

Tracks:
- AP first/last seen times
- Client associations
- Channel migrations
- Signal strength changes
- New device arrivals

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

DURATION=$(NUMBER_PICKER "Duration (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac

INTERVAL=$(NUMBER_PICKER "Sample interval (sec):" 15)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) INTERVAL=15 ;; esac

REPORT="$LOOT_DIR/timeline_$(date +%Y%m%d_%H%M).txt"
RAW_DIR="$LOOT_DIR/raw_$(date +%Y%m%d_%H%M)"
mkdir -p "$RAW_DIR"

resp=$(CONFIRMATION_DIALOG "START TIMELINE?

Duration: ${DURATION} min
Sample every: ${INTERVAL} sec
Mode: Passive monitoring

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting WiFi timeline capture..."
SPINNER_START "Building timeline..."

DURATION_SEC=$((DURATION * 60))
SAMPLES=$((DURATION_SEC / INTERVAL))
START_TIME=$(date +%s)

# Header
echo "================================================================" > "$REPORT"
echo "         NULLSEC WIFI TIMELINE REPORT                          " >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "Start: $(date)" >> "$REPORT"
echo "Duration: ${DURATION} min | Interval: ${INTERVAL}s" >> "$REPORT"
echo "" >> "$REPORT"

declare -A FIRST_SEEN
declare -A LAST_SEEN
declare -A AP_DATA
declare -A CLIENT_DATA
TOTAL_APS=0
TOTAL_CLIENTS=0
NEW_EVENTS=""

for ((s=1; s<=SAMPLES; s++)); do
    ELAPSED=$(( $(date +%s) - START_TIME ))
    [ $ELAPSED -ge $DURATION_SEC ] && break

    TIMESTAMP=$(date +%H:%M:%S)
    SNAP="/tmp/timeline_snap"
    rm -f "${SNAP}"*.csv 2>/dev/null

    # Quick 10-second scan snapshot
    timeout 10 airodump-ng wlan0 --write-interval 5 -w "$SNAP" --output-format csv 2>/dev/null

    # Parse APs
    if [ -f "${SNAP}-01.csv" ]; then
        while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lan_ip id_len essid rest; do
            bssid=$(echo "$bssid" | tr -d ' ')
            essid=$(echo "$essid" | sed 's/^ *//;s/ *$//')
            [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
            [ -z "$essid" ] && essid="<hidden>"

            key="${bssid}"
            if [ -z "${FIRST_SEEN[$key]}" ]; then
                FIRST_SEEN[$key]="$TIMESTAMP"
                NEW_EVENTS="${NEW_EVENTS}[$TIMESTAMP] NEW AP: $essid ($bssid) Ch:$channel $privacy\n"
                TOTAL_APS=$((TOTAL_APS + 1))
            fi
            LAST_SEEN[$key]="$TIMESTAMP"
            AP_DATA[$key]="$essid|$channel|$privacy|$power"
        done < "${SNAP}-01.csv"

        # Parse clients (section after empty line with Station MAC header)
        IN_CLIENTS=0
        while IFS=',' read -r mac first last power packets bssid probed rest; do
            mac=$(echo "$mac" | tr -d ' ')
            if [ "$IN_CLIENTS" -eq 0 ]; then
                [[ "$mac" == "Station MAC" ]] && IN_CLIENTS=1
                continue
            fi
            [[ ! "$mac" =~ ^[0-9A-Fa-f]{2}: ]] && continue

            if [ -z "${FIRST_SEEN[cli_$mac]}" ]; then
                FIRST_SEEN[cli_$mac]="$TIMESTAMP"
                bssid_clean=$(echo "$bssid" | tr -d ' ')
                NEW_EVENTS="${NEW_EVENTS}[$TIMESTAMP] NEW CLIENT: $mac -> $bssid_clean\n"
                TOTAL_CLIENTS=$((TOTAL_CLIENTS + 1))
            fi
            LAST_SEEN[cli_$mac]="$TIMESTAMP"
        done < "${SNAP}-01.csv"
    fi

    # Save raw snapshot
    cp "${SNAP}"*.csv "$RAW_DIR/snap_${s}.csv" 2>/dev/null

    REMAINING=$((DURATION_SEC - ELAPSED))
    LOG "Sample $s/$SAMPLES | APs:$TOTAL_APS Clients:$TOTAL_CLIENTS | ${REMAINING}s left"

    SLEEP_TIME=$((INTERVAL - 10))
    [ $SLEEP_TIME -gt 0 ] && sleep $SLEEP_TIME
done

SPINNER_STOP

# Build timeline report
echo "--- CHRONOLOGICAL EVENTS ---" >> "$REPORT"
echo "" >> "$REPORT"
echo -e "$NEW_EVENTS" >> "$REPORT"
echo "" >> "$REPORT"

echo "--- ACCESS POINTS ($TOTAL_APS) ---" >> "$REPORT"
echo "" >> "$REPORT"
for key in "${!AP_DATA[@]}"; do
    [[ "$key" == cli_* ]] && continue
    IFS='|' read -r essid ch priv pwr <<< "${AP_DATA[$key]}"
    echo "  $essid ($key)" >> "$REPORT"
    echo "    First: ${FIRST_SEEN[$key]} | Last: ${LAST_SEEN[$key]}" >> "$REPORT"
    echo "    Channel: $ch | Security: $priv | Power: $pwr" >> "$REPORT"
done

echo "" >> "$REPORT"
echo "--- CLIENTS ($TOTAL_CLIENTS) ---" >> "$REPORT"
echo "" >> "$REPORT"
for key in "${!FIRST_SEEN[@]}"; do
    [[ "$key" != cli_* ]] && continue
    mac="${key#cli_}"
    echo "  $mac | First: ${FIRST_SEEN[$key]} | Last: ${LAST_SEEN[$key]}" >> "$REPORT"
done

echo "" >> "$REPORT"
echo "End: $(date)" >> "$REPORT"
echo "Raw data: $RAW_DIR/" >> "$REPORT"
echo "================================================================" >> "$REPORT"

PROMPT "TIMELINE COMPLETE

Duration: ${DURATION} min
APs Tracked: $TOTAL_APS
Clients Tracked: $TOTAL_CLIENTS

Timeline saved:
$REPORT

Raw snapshots:
$RAW_DIR/"
