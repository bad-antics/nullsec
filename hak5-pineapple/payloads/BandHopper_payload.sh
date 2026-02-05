#!/bin/bash
# Title: Band Hopper
# Author: bad-antics
# Description: Rapidly hop between 2.4/5/6GHz bands for comprehensive reconnaissance
# Category: nullsec/recon
# Version: 1.0.0

LOOT_DIR="/mmc/nullsec/band_hopper"
RESULTS_FILE="$LOOT_DIR/all_bands.csv"
LOG_FILE="$LOOT_DIR/session.log"

mkdir -p "$LOOT_DIR"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

PROMPT "📻 BAND HOPPER

Multi-band WiFi recon:

2.4 GHz (Channels 1-14)
• Longer range
• Most devices
• More congested

5 GHz (Channels 36-165)  
• Higher speed
• Corporate networks
• Less interference

6 GHz (WiFi 6E)
• Newest devices
• Enterprise gear
• Often unmonitored

Scan ALL frequencies!"

INTERFACE="${1:-wlan0}"

# Detect band support
SPINNER_START "Detecting radio capabilities..."

BANDS_SUPPORTED=""
IW_LIST=$(iw list 2>/dev/null)

if echo "$IW_LIST" | grep -q "2412 MHz"; then
    BANDS_SUPPORTED="${BANDS_SUPPORTED}2.4GHz "
    CHANNELS_24="1 2 3 4 5 6 7 8 9 10 11"
fi

if echo "$IW_LIST" | grep -q "5180 MHz"; then
    BANDS_SUPPORTED="${BANDS_SUPPORTED}5GHz "
    CHANNELS_5="36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 144 149 153 157 161 165"
fi

if echo "$IW_LIST" | grep -q "5955 MHz"; then
    BANDS_SUPPORTED="${BANDS_SUPPORTED}6GHz "
    CHANNELS_6="1 5 9 13 17 21 25 29 33 37 41 45 49 53 57 61 65 69 73 77 81 85 89 93"
fi

SPINNER_STOP

if [ -z "$BANDS_SUPPORTED" ]; then
    ERROR_DIALOG "No supported bands detected!

Check your wireless adapter."
    exit 1
fi

PROMPT "Supported bands:
$BANDS_SUPPORTED

Your adapter can scan
$(echo $CHANNELS_24 $CHANNELS_5 $CHANNELS_6 | wc -w) channels

Press OK to start hopping."

# Kill interfering processes
airmon-ng check kill &>/dev/null

# Enable monitor mode
SPINNER_START "Enabling monitor mode..."
airmon-ng start $INTERFACE &>/dev/null
MON_IFACE="${INTERFACE}mon"
if ! iwconfig $MON_IFACE &>/dev/null; then
    MON_IFACE="$INTERFACE"
    ip link set $INTERFACE down
    iw dev $INTERFACE set type monitor
    ip link set $INTERFACE up
fi
SPINNER_STOP

# Initialize results
echo "band,channel,bssid,ssid,signal,encryption,clients" > "$RESULTS_FILE"

# Channel hop and capture function
scan_channel() {
    local band=$1
    local channel=$2
    local output_prefix="/tmp/hopper_${band}_${channel}"
    
    # Set channel
    iw dev $MON_IFACE set channel $channel 2>/dev/null
    
    # Quick capture (3 seconds per channel)
    timeout 3 airodump-ng $MON_IFACE -c $channel --write-interval 1 -w "$output_prefix" --output-format csv &>/dev/null
    
    # Parse results
    if [ -f "${output_prefix}-01.csv" ]; then
        grep -E "^([0-9A-Fa-f]{2}:){5}" "${output_prefix}-01.csv" 2>/dev/null | while IFS=',' read bssid first last chan speed privacy cipher auth power beacons iv lan essid key; do
            if [ -n "$bssid" ] && [ -n "$essid" ]; then
                CLIENTS=$(grep -c "$bssid" "${output_prefix}-01.csv" 2>/dev/null || echo 0)
                echo "$band,$channel,$bssid,$essid,$power,$privacy,$CLIENTS" >> "$RESULTS_FILE"
            fi
        done
        rm -f ${output_prefix}*.csv
    fi
}

# Main scan loop
TOTAL_NETWORKS=0
START_TIME=$(date +%s)

log "Starting band hopping..."

# 2.4 GHz Band
if [[ "$BANDS_SUPPORTED" == *"2.4GHz"* ]]; then
    SPINNER_START "Scanning 2.4GHz band..."
    for ch in $CHANNELS_24; do
        scan_channel "2.4GHz" $ch
        printf "\r2.4GHz: Channel $ch/11"
    done
    SPINNER_STOP
    BAND_COUNT=$(grep -c "2.4GHz" "$RESULTS_FILE" 2>/dev/null || echo 0)
    log "2.4GHz: Found $BAND_COUNT networks"
    TOTAL_NETWORKS=$((TOTAL_NETWORKS + BAND_COUNT))
fi

# 5 GHz Band
if [[ "$BANDS_SUPPORTED" == *"5GHz"* ]]; then
    SPINNER_START "Scanning 5GHz band..."
    for ch in $CHANNELS_5; do
        scan_channel "5GHz" $ch
        printf "\r5GHz: Channel $ch/165"
    done
    SPINNER_STOP
    BAND_COUNT=$(grep -c "5GHz" "$RESULTS_FILE" 2>/dev/null || echo 0)
    log "5GHz: Found $BAND_COUNT networks"
    TOTAL_NETWORKS=$((TOTAL_NETWORKS + BAND_COUNT))
fi

# 6 GHz Band (WiFi 6E)
if [[ "$BANDS_SUPPORTED" == *"6GHz"* ]]; then
    SPINNER_START "Scanning 6GHz band (WiFi 6E)..."
    for ch in $CHANNELS_6; do
        scan_channel "6GHz" $ch
        printf "\r6GHz: Channel $ch/93"
    done
    SPINNER_STOP
    BAND_COUNT=$(grep -c "6GHz" "$RESULTS_FILE" 2>/dev/null || echo 0)
    log "6GHz: Found $BAND_COUNT networks"
    TOTAL_NETWORKS=$((TOTAL_NETWORKS + BAND_COUNT))
fi

SCAN_TIME=$(($(date +%s) - START_TIME))

# Generate summary
SUMMARY_24=$(grep -c "2.4GHz" "$RESULTS_FILE" 2>/dev/null || echo 0)
SUMMARY_5=$(grep -c "5GHz" "$RESULTS_FILE" 2>/dev/null || echo 0)
SUMMARY_6=$(grep -c "6GHz" "$RESULTS_FILE" 2>/dev/null || echo 0)

# Security breakdown
WPA3_COUNT=$(grep -ci "WPA3\|SAE" "$RESULTS_FILE" 2>/dev/null || echo 0)
WPA2_COUNT=$(grep -ci "WPA2" "$RESULTS_FILE" 2>/dev/null || echo 0)
OPEN_COUNT=$(grep -ci "OPN\|Open" "$RESULTS_FILE" 2>/dev/null || echo 0)

# Find high-value targets (5GHz/6GHz + WPA2/3)
HIGH_VALUE=$(awk -F',' '$1~/5GHz|6GHz/ && $6~/WPA/' "$RESULTS_FILE" | wc -l)

PROMPT "📊 SCAN COMPLETE

Duration: ${SCAN_TIME}s
Total: $TOTAL_NETWORKS networks

BY BAND:
• 2.4GHz: $SUMMARY_24
• 5GHz: $SUMMARY_5  
• 6GHz: $SUMMARY_6

BY SECURITY:
• WPA3: $WPA3_COUNT
• WPA2: $WPA2_COUNT
• Open: $OPEN_COUNT

High-Value Targets: $HIGH_VALUE

Press OK for detailed view."

# Interactive results browser
while true; do
    DIALOG "Band Hopper Results

[1] View All Networks
[2] 2.4GHz Only
[3] 5GHz Only
[4] 6GHz Only
[5] Open Networks
[6] High-Value Targets
[7] Export & Exit" CHOICE

    case $CHOICE in
        1)
            column -t -s',' "$RESULTS_FILE" | PAGER
            ;;
        2)
            grep "2.4GHz" "$RESULTS_FILE" | column -t -s',' | PAGER
            ;;
        3)
            grep "5GHz" "$RESULTS_FILE" | column -t -s',' | PAGER
            ;;
        4)
            grep "6GHz" "$RESULTS_FILE" | column -t -s',' | PAGER
            ;;
        5)
            grep -i "OPN\|Open" "$RESULTS_FILE" | column -t -s',' | PAGER
            ;;
        6)
            awk -F',' '$1~/5GHz|6GHz/ && $6~/WPA/' "$RESULTS_FILE" | column -t -s',' | PAGER
            ;;
        7|timeout|255)
            break
            ;;
    esac
done

# Cleanup
airmon-ng stop $MON_IFACE &>/dev/null 2>&1

# Create analysis report
REPORT_FILE="$LOOT_DIR/analysis_$(date +%Y%m%d_%H%M%S).txt"
cat > "$REPORT_FILE" << EOF
BAND HOPPER ANALYSIS REPORT
===========================
Date: $(date)
Duration: ${SCAN_TIME}s
Interface: $MON_IFACE

BAND SUMMARY
------------
2.4GHz Networks: $SUMMARY_24
5GHz Networks: $SUMMARY_5
6GHz Networks: $SUMMARY_6
TOTAL: $TOTAL_NETWORKS

SECURITY ANALYSIS
-----------------
WPA3/SAE: $WPA3_COUNT ($(echo "scale=1; $WPA3_COUNT * 100 / $TOTAL_NETWORKS" | bc 2>/dev/null || echo 0)%)
WPA2: $WPA2_COUNT ($(echo "scale=1; $WPA2_COUNT * 100 / $TOTAL_NETWORKS" | bc 2>/dev/null || echo 0)%)
Open: $OPEN_COUNT ($(echo "scale=1; $OPEN_COUNT * 100 / $TOTAL_NETWORKS" | bc 2>/dev/null || echo 0)%)

HIGH-VALUE TARGETS (5/6GHz + WPA2/3)
------------------------------------
$(awk -F',' '$1~/5GHz|6GHz/ && $6~/WPA/ {print $4 " (" $1 ", " $6 ")"}' "$RESULTS_FILE" | head -20)

STRONGEST SIGNALS
-----------------
$(sort -t',' -k5 -n "$RESULTS_FILE" | head -10 | awk -F',' '{print $4 " " $5 "dBm (" $1 ")"}')

BUSIEST NETWORKS (by clients)
-----------------------------
$(sort -t',' -k7 -rn "$RESULTS_FILE" | head -10 | awk -F',' '{print $4 ": " $7 " clients (" $1 ")"}')

FILES
-----
Raw Data: $RESULTS_FILE
Report: $REPORT_FILE
EOF

PROMPT "✅ EXPORT COMPLETE

Report: $REPORT_FILE
Data: $RESULTS_FILE

Found $TOTAL_NETWORKS networks
across all bands.

High-value targets: $HIGH_VALUE"

log "Session complete. $TOTAL_NETWORKS networks across $BANDS_SUPPORTED"
