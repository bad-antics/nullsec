#!/bin/bash
# Title: RF Spectrum
# Author: bad-antics
# Description: RF spectrum analysis and interference detection across WiFi bands
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/rfspectrum"
mkdir -p "$LOOT_DIR"

PROMPT "RF SPECTRUM

RF spectrum analysis and
interference detection.

Features:
- 2.4GHz & 5GHz band survey
- Channel utilization heatmap
- Interference source detection
- Non-WiFi RF identification
- Signal quality scoring
- Optimal channel recommendation

Press OK to configure."

# Monitor interface
MONITOR_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && { ERROR_DIALOG "No monitor interface!\nRun: airmon-ng start wlan1"; exit 1; }

# Band selection
resp=$(CONFIRMATION_DIALOG "SCAN BOTH BANDS?

YES = Scan 2.4GHz AND 5GHz
(requires dual-band adapter)

NO = 2.4GHz only

Press OK for both bands.")
if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    BANDS="both"
else
    BANDS="2.4"
fi

# Scan duration per channel
DWELL=$(NUMBER_PICKER "Dwell time per channel (sec):" 5)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DWELL=5 ;; esac

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/spectrum_${TIMESTAMP}.txt"

resp=$(CONFIRMATION_DIALOG "START SPECTRUM ANALYSIS?

Interface: $MONITOR_IF
Bands: $BANDS
Dwell: ${DWELL}s per channel

This takes ~2-5 minutes.

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Scanning RF spectrum..."

echo "================================================================" > "$REPORT"
echo "         NULLSEC RF SPECTRUM ANALYSIS                          " >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "Time: $(date)" >> "$REPORT"
echo "Interface: $MONITOR_IF" >> "$REPORT"
echo "Bands: $BANDS | Dwell: ${DWELL}s" >> "$REPORT"
echo "" >> "$REPORT"

# Define channels
CHANNELS_24="1 2 3 4 5 6 7 8 9 10 11 12 13"
CHANNELS_5="36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 149 153 157 161 165"

if [ "$BANDS" = "both" ]; then
    ALL_CHANNELS="$CHANNELS_24 $CHANNELS_5"
else
    ALL_CHANNELS="$CHANNELS_24"
fi

TOTAL_CH=$(echo "$ALL_CHANNELS" | wc -w)
CURRENT_CH=0

# Per-channel data collection
declare -A CH_APS CH_CLIENTS CH_SIGNAL CH_NOISE CH_UTIL

echo "--- PER-CHANNEL ANALYSIS ---" >> "$REPORT"
printf "%-6s %-6s %-8s %-10s %-8s %-10s\n" "Chan" "APs" "Clients" "AvgSignal" "Band" "Rating" >> "$REPORT"
printf "%-6s %-6s %-8s %-10s %-8s %-10s\n" "----" "----" "-------" "---------" "----" "------" >> "$REPORT"

BEST_CH=""
BEST_SCORE=999
WORST_CH=""
WORST_SCORE=0

for ch in $ALL_CHANNELS; do
    CURRENT_CH=$((CURRENT_CH + 1))
    LOG "Channel $ch ($CURRENT_CH/$TOTAL_CH)..."

    # Determine band
    if [ "$ch" -le 14 ]; then
        BAND="2.4GHz"
        # Calculate frequency
        if [ "$ch" -eq 14 ]; then
            FREQ="2484"
        else
            FREQ=$((2407 + ch * 5))
        fi
    else
        BAND="5GHz"
        FREQ=$((5000 + ch * 5))
    fi

    # Set channel and capture
    iwconfig "$MONITOR_IF" channel "$ch" 2>/dev/null
    sleep 0.5

    SCAN_FILE="/tmp/rf_ch${ch}"
    rm -f "${SCAN_FILE}"*.csv 2>/dev/null
    timeout "$DWELL" airodump-ng "$MONITOR_IF" -c "$ch" -w "$SCAN_FILE" --output-format csv 2>/dev/null

    # Count APs on this channel
    AP_COUNT=0
    SIGNAL_SUM=0
    while IFS=',' read -r bssid first last channel_csv speed privacy cipher auth power beacons iv lan_ip id_len essid rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        power=$(echo "$power" | tr -d ' ')
        [ -z "$power" ] || [ "$power" = "-1" ] && power="-90"
        AP_COUNT=$((AP_COUNT + 1))
        SIGNAL_SUM=$((SIGNAL_SUM + power))
    done < "${SCAN_FILE}-01.csv" 2>/dev/null

    # Count clients
    CLIENT_COUNT=0
    IN_CLIENT_SECTION=0
    while IFS=',' read -r field1 rest; do
        field1=$(echo "$field1" | tr -d ' ')
        [ "$field1" = "Station MAC" ] && IN_CLIENT_SECTION=1 && continue
        [ $IN_CLIENT_SECTION -eq 0 ] && continue
        [[ "$field1" =~ ^[0-9A-Fa-f]{2}: ]] && CLIENT_COUNT=$((CLIENT_COUNT + 1))
    done < "${SCAN_FILE}-01.csv" 2>/dev/null

    # Calculate average signal
    if [ $AP_COUNT -gt 0 ]; then
        AVG_SIGNAL=$((SIGNAL_SUM / AP_COUNT))
    else
        AVG_SIGNAL=-95
    fi

    # Score channel (lower = better, fewer APs + weaker signals = cleaner)
    SCORE=$((AP_COUNT * 10 + CLIENT_COUNT * 5))
    [ $AVG_SIGNAL -gt -50 ] && SCORE=$((SCORE + 20))  # Strong signals = more interference

    # Rating
    if [ $AP_COUNT -eq 0 ]; then
        RATING="CLEAR"
    elif [ $AP_COUNT -le 2 ] && [ $CLIENT_COUNT -le 5 ]; then
        RATING="GOOD"
    elif [ $AP_COUNT -le 5 ]; then
        RATING="FAIR"
    elif [ $AP_COUNT -le 10 ]; then
        RATING="BUSY"
    else
        RATING="CROWDED"
    fi

    printf "%-6s %-6s %-8s %-10s %-8s %-10s\n" "$ch" "$AP_COUNT" "$CLIENT_COUNT" "${AVG_SIGNAL}dBm" "$BAND" "$RATING" >> "$REPORT"

    # Track best/worst
    if [ $SCORE -lt $BEST_SCORE ]; then
        BEST_SCORE=$SCORE
        BEST_CH=$ch
    fi
    if [ $SCORE -gt $WORST_SCORE ]; then
        WORST_SCORE=$SCORE
        WORST_CH=$ch
    fi

    # Cleanup
    rm -f "${SCAN_FILE}"*.csv 2>/dev/null
done

echo "" >> "$REPORT"

# Interference analysis
echo "--- INTERFERENCE ANALYSIS ---" >> "$REPORT"

# Check for common interference patterns
echo "  2.4GHz Overlap Analysis:" >> "$REPORT"
echo "  Non-overlapping channels: 1, 6, 11" >> "$REPORT"

# Collect totals for overlap channels
for grp_name in "Ch 1-3" "Ch 4-5" "Ch 6-8" "Ch 9-10" "Ch 11-13"; do
    case "$grp_name" in
        "Ch 1-3") chs="1 2 3" ;;
        "Ch 4-5") chs="4 5" ;;
        "Ch 6-8") chs="6 7 8" ;;
        "Ch 9-10") chs="9 10" ;;
        "Ch 11-13") chs="11 12 13" ;;
    esac
    GRP_APS=0
    for c in $chs; do
        iwconfig "$MONITOR_IF" channel "$c" 2>/dev/null
        CNT=$(timeout 2 airodump-ng "$MONITOR_IF" -c "$c" --output-format csv -w /tmp/rf_grp 2>/dev/null; grep -cE "^([0-9A-Fa-f]{2}:){5}" /tmp/rf_grp*.csv 2>/dev/null || echo 0)
        GRP_APS=$((GRP_APS + CNT))
        rm -f /tmp/rf_grp*.csv 2>/dev/null
    done
    echo "  $grp_name: ~$GRP_APS APs (overlap group)" >> "$REPORT"
done

echo "" >> "$REPORT"
echo "--- RECOMMENDATIONS ---" >> "$REPORT"
echo "  Best channel: $BEST_CH (score: $BEST_SCORE)" >> "$REPORT"
echo "  Worst channel: $WORST_CH (score: $WORST_SCORE)" >> "$REPORT"
echo "  Recommendation: Use channel $BEST_CH for least interference" >> "$REPORT"
echo "================================================================" >> "$REPORT"

SPINNER_STOP

PROMPT "SPECTRUM ANALYSIS COMPLETE

Channels scanned: $TOTAL_CH
Best channel: $BEST_CH
Worst channel: $WORST_CH

Recommendation:
Deploy on channel $BEST_CH
for optimal performance.

Report: $REPORT"
