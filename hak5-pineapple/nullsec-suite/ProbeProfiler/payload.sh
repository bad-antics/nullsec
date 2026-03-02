#!/bin/bash
# Title: Probe Profiler
# Author: bad-antics
# Description: Build detailed device profiles from WiFi probe requests
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/profiles"
mkdir -p "$LOOT_DIR"

PROMPT "PROBE PROFILER

Passively collect probe requests
to build device profiles.

Reveals:
- Device home/work networks
- Travel history (hotel SSIDs)
- Phone vs laptop detection
- Corporate network names
- Hidden network probes
- Device manufacturer (OUI)

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

DURATION=$(NUMBER_PICKER "Duration (minutes):" 15)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=15 ;; esac

FOCUS=$(CONFIRMATION_DIALOG "FOCUS MODE?

OK = Track specific MAC address
CANCEL = Profile all devices")

TARGET_MAC=""
if [ "$FOCUS" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    TARGET_MAC=$(TEXT_PICKER "Target MAC:" "AA:BB:CC:DD:EE:FF")
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TARGET_MAC="" ;; esac
fi

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/profiles_${TIMESTAMP}.txt"

resp=$(CONFIRMATION_DIALOG "START PROFILING?

Duration: ${DURATION} min
Mode: $([ -n \"$TARGET_MAC\" ] && echo \"Focused: $TARGET_MAC\" || echo 'All devices')
Method: 100% passive

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting probe profiler..."
SPINNER_START "Collecting probe requests..."

DURATION_SEC=$((DURATION * 60))
PROBE_RAW="/tmp/probes_raw_${TIMESTAMP}.txt"

# Capture probe requests with full details
if [ -n "$TARGET_MAC" ]; then
    timeout $DURATION_SEC tcpdump -i wlan0 -e -l "type mgt subtype probe-req and ether src $TARGET_MAC" 2>/dev/null > "$PROBE_RAW" &
else
    timeout $DURATION_SEC tcpdump -i wlan0 -e -l "type mgt subtype probe-req" 2>/dev/null > "$PROBE_RAW" &
fi
CAP_PID=$!

sleep $DURATION_SEC
kill $CAP_PID 2>/dev/null
wait $CAP_PID 2>/dev/null

SPINNER_STOP
SPINNER_START "Analyzing profiles..."

echo "================================================================" > "$REPORT"
echo "         NULLSEC PROBE PROFILER REPORT                         " >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "Time: $(date)" >> "$REPORT"
echo "Duration: ${DURATION} min" >> "$REPORT"
echo "" >> "$REPORT"

# OUI lookup table (top vendors)
oui_lookup() {
    local prefix=$(echo "$1" | tr '[:lower:]' '[:upper:]' | cut -c1-8)
    case "$prefix" in
        "00:00:0C"|"F4:CF:E2"|"00:1A:2B") echo "Cisco" ;;
        "AC:37:43"|"00:17:C4"|"DC:A6:32") echo "Samsung" ;;
        "3C:22:FB"|"F0:18:98"|"8C:85:90") echo "Apple" ;;
        "B4:2E:99"|"CC:46:D6"|"28:6C:07") echo "Samsung" ;;
        "00:50:F2"|"60:45:BD"|"7C:1E:52") echo "Microsoft" ;;
        "00:26:AB"|"8C:FA:BA"|"2C:6E:85") echo "Intel" ;;
        "B0:BE:76"|"E0:B9:A5") echo "Samsung" ;;
        "FC:F8:AE"|"E4:B3:18") echo "Intel" ;;
        "A4:83:E7"|"E0:63:DA") echo "Apple" ;;
        "00:0C:29"|"00:50:56") echo "VMware" ;;
        "F8:28:19"|"74:DA:38") echo "Google" ;;
        *) echo "Unknown" ;;
    esac
}

# Extract unique MACs and their probed SSIDs
declare -A DEVICE_SSIDS
declare -A DEVICE_COUNT
declare -A DEVICE_FIRST
declare -A DEVICE_LAST

while read -r line; do
    [ -z "$line" ] && continue
    # Extract MAC address (source)
    mac=$(echo "$line" | grep -oE "([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" | head -1)
    [ -z "$mac" ] && continue
    mac=$(echo "$mac" | tr '[:upper:]' '[:lower:]')

    # Extract probed SSID
    ssid=$(echo "$line" | grep -oE "Probe Request \([^)]*\)" | sed 's/Probe Request (\(.*\))/\1/')
    [ -z "$ssid" ] && ssid="<broadcast>"

    # Track
    timestamp=$(echo "$line" | awk '{print $1}')
    DEVICE_COUNT[$mac]=$(( ${DEVICE_COUNT[$mac]:-0} + 1 ))
    [ -z "${DEVICE_FIRST[$mac]}" ] && DEVICE_FIRST[$mac]="$timestamp"
    DEVICE_LAST[$mac]="$timestamp"

    # Append SSID if new for this device
    if [[ "${DEVICE_SSIDS[$mac]}" != *"$ssid"* ]]; then
        DEVICE_SSIDS[$mac]="${DEVICE_SSIDS[$mac]}|$ssid"
    fi
done < "$PROBE_RAW"

DEVICE_TOTAL=${#DEVICE_COUNT[@]}

echo "--- DEVICE PROFILES ($DEVICE_TOTAL devices) ---" >> "$REPORT"
echo "" >> "$REPORT"

# Sort by probe count (most active first)
for mac in $(for k in "${!DEVICE_COUNT[@]}"; do echo "${DEVICE_COUNT[$k]} $k"; done | sort -rn | awk '{print $2}'); do
    vendor=$(oui_lookup "$mac")
    count=${DEVICE_COUNT[$mac]}
    ssid_list=$(echo "${DEVICE_SSIDS[$mac]}" | tr '|' '\n' | grep -v '^$' | sort -u)
    ssid_count=$(echo "$ssid_list" | grep -c .)

    echo "  DEVICE: $mac ($vendor)" >> "$REPORT"
    echo "  Probes: $count | Unique SSIDs: $ssid_count" >> "$REPORT"
    echo "  First seen: ${DEVICE_FIRST[$mac]} | Last: ${DEVICE_LAST[$mac]}" >> "$REPORT"
    echo "  Networks probed:" >> "$REPORT"
    echo "$ssid_list" | while read -r s; do
        [ -n "$s" ] && echo "    - $s" >> "$REPORT"
    done

    # Categorize by SSID patterns
    CATEGORY=""
    echo "$ssid_list" | grep -qiE "(corp|office|enterprise|internal)" && CATEGORY="Corporate device"
    echo "$ssid_list" | grep -qiE "(hotel|marriott|hilton|hyatt|airport|lounge)" && CATEGORY="${CATEGORY:+$CATEGORY, }Traveler"
    echo "$ssid_list" | grep -qiE "(home|mynetwork|netgear|linksys|xfinity|spectrum)" && CATEGORY="${CATEGORY:+$CATEGORY, }Home user"
    echo "$ssid_list" | grep -qiE "(iphone|android|galaxy)" && CATEGORY="${CATEGORY:+$CATEGORY, }Mobile hotspot user"
    [ -n "$CATEGORY" ] && echo "  Profile: $CATEGORY" >> "$REPORT"
    echo "" >> "$REPORT"
done

# Summary stats
TOTAL_PROBES=$(wc -l < "$PROBE_RAW")
ALL_SSIDS=$(for mac in "${!DEVICE_SSIDS[@]}"; do echo "${DEVICE_SSIDS[$mac]}"; done | tr '|' '\n' | grep -v '^$' | sort -u | wc -l)

echo "--- SUMMARY ---" >> "$REPORT"
echo "Total probes captured: $TOTAL_PROBES" >> "$REPORT"
echo "Unique devices: $DEVICE_TOTAL" >> "$REPORT"
echo "Unique SSIDs probed: $ALL_SSIDS" >> "$REPORT"
echo "" >> "$REPORT"
echo "================================================================" >> "$REPORT"

SPINNER_STOP

PROMPT "PROFILING COMPLETE

Devices profiled: $DEVICE_TOTAL
Total probes: $TOTAL_PROBES
Unique SSIDs: $ALL_SSIDS

Report saved:
$REPORT"
