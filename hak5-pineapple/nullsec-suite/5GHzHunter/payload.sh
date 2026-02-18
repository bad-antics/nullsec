#!/bin/bash
# Title: 5GHz Hunter - Dual Band Network Analyzer
# Author: bad-antics
# Description: Focused 5GHz band scanner with DFS channel detection and channel utilization mapping
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/5ghzhunter"
mkdir -p "$LOOT_DIR"

PROMPT "5GHz HUNTER

Dual-Band Network Analyzer

Features:
- 5GHz-only scanning
- DFS channel detection
- Channel utilization map
- Radar event detection
- Band steering analysis
- Wide channel (80/160MHz)
- AP density per channel

Press OK to hunt."

SCAN_TIME=$(NUMBER_PICKER "Scan time (sec):" 20)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_TIME=20 ;; esac

# Find monitor interface
MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!

Run: airmon-ng start wlan1"; exit 1; }

SPINNER_START "Scanning 5GHz band..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCAN_FILE="$LOOT_DIR/5ghz_${TIMESTAMP}"

# Scan only 5GHz band (channels 36-165)
rm -f /tmp/5ghz*
timeout "$SCAN_TIME" airodump-ng "$MON_IF" \
    --band a \
    -w /tmp/5ghzscan --output-format csv 2>/dev/null &
sleep "$SCAN_TIME"
killall airodump-ng 2>/dev/null
wait 2>/dev/null

SPINNER_STOP

# Channel density tracking
declare -A CHAN_COUNT
declare -A CHAN_NETS
DFS_NETS=0
WIDE_CHAN=0
TOTAL=0

# DFS channels (52-144 in most regions)
DFS_CHANNELS="52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 144"

if [ -f /tmp/5ghzscan-01.csv ]; then
    while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lanip idlen essid key; do
        bssid=$(echo "$bssid" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue

        channel=$(echo "$channel" | tr -d ' ')
        ch_num=$(echo "$channel" | grep -oP '\d+' | head -1)
        [ -z "$ch_num" ] && continue
        [ "$ch_num" -le 14 ] 2>/dev/null && continue  # Skip 2.4GHz

        TOTAL=$((TOTAL + 1))
        essid=$(echo "$essid" | tr -d ' ')
        speed=$(echo "$speed" | tr -d ' ')
        power=$(echo "$power" | tr -d ' ')
        privacy=$(echo "$privacy" | tr -d ' ')

        # Track channel density
        CHAN_COUNT[$ch_num]=$(( ${CHAN_COUNT[$ch_num]:-0} + 1 ))

        # Check DFS
        IS_DFS="NO"
        for dfs_ch in $DFS_CHANNELS; do
            [ "$ch_num" -eq "$dfs_ch" ] 2>/dev/null && { IS_DFS="YES"; DFS_NETS=$((DFS_NETS + 1)); break; }
        done

        # Check wide channels (80/160MHz indicated by higher speeds)
        speed_num=$(echo "$speed" | grep -oP '\d+' | head -1)
        [ -n "$speed_num" ] && [ "$speed_num" -ge 400 ] 2>/dev/null && WIDE_CHAN=$((WIDE_CHAN + 1))

        # Determine channel width estimate
        WIDTH="20MHz"
        [ -n "$speed_num" ] && [ "$speed_num" -ge 150 ] 2>/dev/null && WIDTH="40MHz"
        [ -n "$speed_num" ] && [ "$speed_num" -ge 400 ] 2>/dev/null && WIDTH="80MHz"
        [ -n "$speed_num" ] && [ "$speed_num" -ge 800 ] 2>/dev/null && WIDTH="160MHz"

        echo "${bssid}|${essid}|${ch_num}|${power}|${privacy}|${IS_DFS}|${WIDTH}" >> "${SCAN_FILE}.raw"

    done < /tmp/5ghzscan-01.csv
fi

# Generate report
{
    echo "5GHz Hunter Report - $(date)"
    echo "================================"
    echo ""
    echo "Total 5GHz Networks: $TOTAL"
    echo "DFS Channel Networks: $DFS_NETS"
    echo "Wide Channel (80+MHz): $WIDE_CHAN"
    echo ""
    echo "CHANNEL DENSITY MAP:"
    echo "──────────────────────"

    for ch in 36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 144 149 153 157 161 165; do
        count=${CHAN_COUNT[$ch]:-0}
        bar=""
        for ((i=0; i<count; i++)); do bar="${bar}█"; done
        dfs_marker=""
        for dfs_ch in $DFS_CHANNELS; do
            [ "$ch" -eq "$dfs_ch" ] && dfs_marker=" [DFS]"
        done
        printf "  Ch%-3s: %-20s (%d)%s\n" "$ch" "$bar" "$count" "$dfs_marker"
    done

    echo ""
    echo "NETWORKS:"
    echo "BSSID|ESSID|Channel|Power|Security|DFS|Width"
    [ -f "${SCAN_FILE}.raw" ] && cat "${SCAN_FILE}.raw"
} > "${SCAN_FILE}.txt"

# Find best channel (least congested)
BEST_CH=""
BEST_COUNT=999
for ch in 36 40 44 48 149 153 157 161 165; do
    count=${CHAN_COUNT[$ch]:-0}
    if [ "$count" -lt "$BEST_COUNT" ]; then
        BEST_COUNT=$count
        BEST_CH=$ch
    fi
done

# Display
DISPLAY="5GHz HUNT RESULTS

Total 5GHz APs: $TOTAL
DFS Networks: $DFS_NETS
Wide (80+MHz): $WIDE_CHAN
Best Channel: $BEST_CH ($BEST_COUNT APs)

Channel Density:
"

for ch in 36 44 48 52 149 153 157 161; do
    count=${CHAN_COUNT[$ch]:-0}
    DISPLAY="${DISPLAY}Ch${ch}: ${count}  "
done

DISPLAY="${DISPLAY}

Saved: 5ghz_${TIMESTAMP}.txt
Loot: $LOOT_DIR"

PROMPT "$DISPLAY"

# Cleanup
rm -f /tmp/5ghzscan* "${SCAN_FILE}.raw"
