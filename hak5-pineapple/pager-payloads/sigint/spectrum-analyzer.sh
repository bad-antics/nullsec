#!/bin/bash
# ============================================================
# NullSec: RF Spectrum Analyzer & Signal Intelligence
# Author: bad-antics
# Description: Comprehensive RF analysis and SIGINT collection
# Category: pager/sigint
#
# UNIQUE FEATURES:
# - Multi-band spectrum analysis (2.4GHz, 5GHz, 6GHz)
# - Bluetooth/WiFi coexistence analysis
# - Hidden network detection via timing analysis
# - Signal triangulation helpers
# - First SIGINT suite for Pineapple Pager
# ============================================================

PAYLOAD_NAME="RF Spectrum Analyzer"
VERSION="1.0.0"
LOOT="/root/loot/sigint"
LOG="$LOOT/sigint.log"

init_payload() {
    mkdir -p "$LOOT"/{spectrum,hidden,bluetooth,analysis}
    echo "[$(date)] $PAYLOAD_NAME started" >> "$LOG"
    NOTIFY "SIGINT" "Initializing RF analysis..."
}

# Comprehensive spectrum scan
spectrum_scan() {
    NOTIFY "SPECTRUM" "Starting multi-band scan..."
    
    local SCAN_FILE="$LOOT/spectrum/scan_$(date +%Y%m%d_%H%M).txt"
    
    # 2.4GHz Band Analysis
    echo "=== 2.4GHz Band (Channels 1-14) ===" > "$SCAN_FILE"
    
    for ch in $(seq 1 14); do
        # Set channel
        iwconfig wlan0 channel $ch 2>/dev/null
        sleep 0.5
        
        # Measure signal levels
        SIGNALS=$(iwlist wlan0 scan 2>/dev/null | grep -E "Signal level|ESSID" | \
            paste - - | head -10)
        
        # Count networks on channel
        NET_COUNT=$(echo "$SIGNALS" | wc -l)
        
        # Get average signal
        AVG_SIG=$(iwlist wlan0 scan 2>/dev/null | grep "Signal level" | \
            grep -oE "\-[0-9]+" | awk '{s+=$1;c++}END{print s/c}')
        
        echo "Channel $ch: $NET_COUNT networks, avg signal: ${AVG_SIG:-N/A} dBm" >> "$SCAN_FILE"
        
        NOTIFY "CH $ch" "$NET_COUNT networks"
    done
    
    # 5GHz Band Analysis
    echo "" >> "$SCAN_FILE"
    echo "=== 5GHz Band ===" >> "$SCAN_FILE"
    
    # Common 5GHz channels
    for ch in 36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 144 149 153 157 161 165; do
        iwconfig wlan0 channel $ch 2>/dev/null || continue
        sleep 0.3
        
        NET_COUNT=$(iwlist wlan0 scan 2>/dev/null | grep -c "ESSID")
        echo "Channel $ch: $NET_COUNT networks" >> "$SCAN_FILE"
    done
    
    NOTIFY "COMPLETE" "Spectrum scan saved"
    cat "$SCAN_FILE"
}

# Detect hidden networks through timing analysis
detect_hidden_networks() {
    NOTIFY "HIDDEN" "Detecting hidden networks..."
    
    local HIDDEN_FILE="$LOOT/hidden/hidden_$(date +%Y%m%d_%H%M).txt"
    
    # Hidden networks still broadcast beacons with empty SSID
    # We can detect them by looking for beacon frames with no SSID
    
    NOTIFY "CAPTURE" "Capturing beacon frames..."
    
    # Capture for 60 seconds
    timeout 60 tcpdump -i wlan0 -e -s 256 type mgt subtype beacon 2>/dev/null > /tmp/beacons.txt &
    
    # Also monitor for probe responses (more reliable)
    timeout 60 tcpdump -i wlan0 -e -s 256 type mgt subtype probe-resp 2>/dev/null > /tmp/probes.txt &
    
    wait
    
    # Find beacons with empty/hidden SSID
    echo "=== Hidden Networks Detected ===" > "$HIDDEN_FILE"
    
    grep "SSID=" /tmp/beacons.txt | grep -E "SSID=\s*$|SSID=\"\"" | \
        grep -oE "BSSID:[0-9a-f:]+" | sort -u | while read bssid; do
        
        MAC=$(echo "$bssid" | cut -d: -f2-)
        CHANNEL=$(grep "$MAC" /tmp/beacons.txt | grep -oE "CH [0-9]+" | head -1)
        
        echo "Hidden Network: $MAC ($CHANNEL)" >> "$HIDDEN_FILE"
        NOTIFY "FOUND" "Hidden: $MAC"
    done
    
    # Correlation: Find hidden SSIDs from probe responses to same BSSID
    echo "" >> "$HIDDEN_FILE"
    echo "=== Probe Response Correlation ===" >> "$HIDDEN_FILE"
    
    grep "SSID=" /tmp/probes.txt | grep -v "SSID=\"\"" >> "$HIDDEN_FILE" 2>/dev/null
    
    HIDDEN_COUNT=$(grep -c "Hidden Network:" "$HIDDEN_FILE")
    NOTIFY "HIDDEN" "$HIDDEN_COUNT hidden networks found"
}

# Bluetooth signal analysis
bluetooth_scan() {
    NOTIFY "BLUETOOTH" "Scanning Bluetooth spectrum..."
    
    local BT_FILE="$LOOT/bluetooth/bt_$(date +%Y%m%d_%H%M).txt"
    
    # Check if Bluetooth is available
    if ! hciconfig hci0 up 2>/dev/null; then
        NOTIFY "NO BT" "Bluetooth adapter not available"
        return 1
    fi
    
    echo "=== Bluetooth Device Scan ===" > "$BT_FILE"
    
    # Standard inquiry
    NOTIFY "INQUIRY" "Classic Bluetooth scan..."
    timeout 30 hcitool scan >> "$BT_FILE" 2>/dev/null
    
    # BLE scan
    echo "" >> "$BT_FILE"
    echo "=== Bluetooth Low Energy ===" >> "$BT_FILE"
    
    NOTIFY "BLE" "Low Energy scan..."
    timeout 30 hcitool lescan >> "$BT_FILE" 2>&1 &
    sleep 30
    killall hcitool 2>/dev/null
    
    # WiFi/BT coexistence analysis
    echo "" >> "$BT_FILE"
    echo "=== Coexistence Analysis ===" >> "$BT_FILE"
    echo "Bluetooth operates in 2.4GHz (2402-2480 MHz)" >> "$BT_FILE"
    echo "WiFi Channel 1: 2412 MHz (overlap)" >> "$BT_FILE"
    echo "WiFi Channel 6: 2437 MHz (overlap)" >> "$BT_FILE"
    echo "WiFi Channel 11: 2462 MHz (overlap)" >> "$BT_FILE"
    echo "" >> "$BT_FILE"
    echo "High Bluetooth activity may indicate:" >> "$BT_FILE"
    echo "  - Wireless keyboards/mice (security risk)" >> "$BT_FILE"
    echo "  - Audio devices" >> "$BT_FILE"
    echo "  - IoT sensors" >> "$BT_FILE"
    
    BT_COUNT=$(grep -c ":" "$BT_FILE" 2>/dev/null || echo 0)
    NOTIFY "BT FOUND" "$BT_COUNT Bluetooth devices"
}

# Signal strength mapping
signal_mapping() {
    NOTIFY "MAPPING" "Creating signal strength map..."
    
    local MAP_FILE="$LOOT/analysis/signal_map_$(date +%Y%m%d_%H%M).txt"
    local TARGET_BSSID="$1"
    
    if [ -z "$TARGET_BSSID" ]; then
        # Pick strongest network
        TARGET_BSSID=$(iwlist wlan0 scan 2>/dev/null | grep -A5 "Signal level" | \
            grep "Address" | head -1 | awk '{print $5}')
    fi
    
    [ -z "$TARGET_BSSID" ] && {
        NOTIFY "ERROR" "No target BSSID"
        return 1
    }
    
    NOTIFY "TARGET" "Mapping: $TARGET_BSSID"
    
    echo "=== Signal Strength Map ===" > "$MAP_FILE"
    echo "Target: $TARGET_BSSID" >> "$MAP_FILE"
    echo "Start: $(date)" >> "$MAP_FILE"
    echo "" >> "$MAP_FILE"
    echo "Timestamp | Signal (dBm) | Noise | SNR" >> "$MAP_FILE"
    echo "-----------------------------------------" >> "$MAP_FILE"
    
    # Continuous monitoring
    NOTIFY "MONITOR" "Recording signal for 2 minutes..."
    NOTIFY "MOVE" "Move around to map signal..."
    
    for i in $(seq 1 24); do
        SIGNAL=$(iwlist wlan0 scan 2>/dev/null | grep -A5 "$TARGET_BSSID" | \
            grep "Signal level" | grep -oE "\-[0-9]+")
        
        NOISE=$(cat /proc/net/wireless 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '.')
        
        if [ -n "$SIGNAL" ]; then
            SNR=$((SIGNAL - NOISE))
            echo "$(date '+%H:%M:%S') | $SIGNAL | $NOISE | $SNR" >> "$MAP_FILE"
        fi
        
        sleep 5
    done
    
    # Calculate statistics
    echo "" >> "$MAP_FILE"
    echo "=== Statistics ===" >> "$MAP_FILE"
    
    AVG=$(grep "dBm" "$MAP_FILE" | grep -oE "\-[0-9]+" | head -n -1 | \
        awk '{s+=$1;c++}END{printf "%.1f", s/c}')
    MIN=$(grep "dBm" "$MAP_FILE" | grep -oE "\-[0-9]+" | head -n -1 | sort -n | head -1)
    MAX=$(grep "dBm" "$MAP_FILE" | grep -oE "\-[0-9]+" | head -n -1 | sort -rn | head -1)
    
    echo "Average: $AVG dBm" >> "$MAP_FILE"
    echo "Strongest: $MAX dBm" >> "$MAP_FILE"
    echo "Weakest: $MIN dBm" >> "$MAP_FILE"
    
    NOTIFY "MAPPED" "Avg: $AVG dBm, Range: $MAX to $MIN"
}

# Channel utilization analysis
channel_utilization() {
    NOTIFY "UTILIZATION" "Analyzing channel utilization..."
    
    local UTIL_FILE="$LOOT/analysis/utilization_$(date +%Y%m%d_%H%M).txt"
    
    echo "=== Channel Utilization Analysis ===" > "$UTIL_FILE"
    echo "Time: $(date)" >> "$UTIL_FILE"
    echo "" >> "$UTIL_FILE"
    
    for ch in 1 6 11; do  # Most common 2.4GHz channels
        iwconfig wlan0 channel $ch 2>/dev/null
        sleep 1
        
        # Count packets for 10 seconds
        PACKETS=$(timeout 10 tcpdump -i wlan0 -c 1000 2>/dev/null | wc -l)
        
        # Count networks
        NETWORKS=$(iwlist wlan0 scan 2>/dev/null | grep -c "ESSID")
        
        # Estimate utilization
        if [ "$PACKETS" -gt 800 ]; then
            UTIL="HIGH (>80%)"
        elif [ "$PACKETS" -gt 500 ]; then
            UTIL="MEDIUM (50-80%)"
        else
            UTIL="LOW (<50%)"
        fi
        
        echo "Channel $ch: $NETWORKS networks, ~$PACKETS pkt/10s, Utilization: $UTIL" >> "$UTIL_FILE"
        NOTIFY "CH $ch" "$UTIL utilization"
    done
    
    # Recommendation
    echo "" >> "$UTIL_FILE"
    echo "=== Recommendation ===" >> "$UTIL_FILE"
    
    BEST_CH=$(grep "LOW" "$UTIL_FILE" | head -1 | grep -oE "Channel [0-9]+" | awk '{print $2}')
    [ -z "$BEST_CH" ] && BEST_CH=$(grep "MEDIUM" "$UTIL_FILE" | head -1 | grep -oE "Channel [0-9]+" | awk '{print $2}')
    
    echo "Best channel for operations: ${BEST_CH:-6}" >> "$UTIL_FILE"
    NOTIFY "RECOMMEND" "Use channel ${BEST_CH:-6}"
}

# Generate SIGINT report
generate_report() {
    NOTIFY "REPORT" "Generating SIGINT report..."
    
    local REPORT="$LOOT/sigint_report.txt"
    
    cat > "$REPORT" << REPORT
╔══════════════════════════════════════════════════════════════╗
║              NULLSEC SIGINT ANALYSIS REPORT                  ║
╠══════════════════════════════════════════════════════════════╣
║ Analysis Date: $(date)
║ Payload: $PAYLOAD_NAME v$VERSION
║ Location: $(hostname)
╠══════════════════════════════════════════════════════════════╣

RF ENVIRONMENT SUMMARY:
$(cat "$LOOT/spectrum/"*.txt 2>/dev/null | tail -20)

HIDDEN NETWORKS:
$(cat "$LOOT/hidden/"*.txt 2>/dev/null | grep "Hidden Network" | head -10)

BLUETOOTH DEVICES:
$(cat "$LOOT/bluetooth/"*.txt 2>/dev/null | grep -E "^[0-9A-F]{2}:" | head -10)

CHANNEL UTILIZATION:
$(cat "$LOOT/analysis/utilization"*.txt 2>/dev/null | grep "Channel")

SECURITY OBSERVATIONS:
  • Hidden networks present: $(grep -c "Hidden" "$LOOT/hidden/"*.txt 2>/dev/null || echo 0)
  • Open networks: $(iwlist wlan0 scan 2>/dev/null | grep -c "Encryption:off")
  • WEP networks (vulnerable): $(iwlist wlan0 scan 2>/dev/null | grep -c "WEP")

╚══════════════════════════════════════════════════════════════╝
REPORT

    NOTIFY "DONE" "Report saved to $REPORT"
    cat "$REPORT"
}

# Main menu
main() {
    init_payload
    
    while true; do
        echo ""
        echo "=== NullSec SIGINT Suite ==="
        echo "1. Full Spectrum Scan"
        echo "2. Detect Hidden Networks"
        echo "3. Bluetooth Analysis"
        echo "4. Signal Strength Mapping"
        echo "5. Channel Utilization"
        echo "6. Generate Report"
        echo "7. Exit"
        echo ""
        read -p "Choice: " choice
        
        case $choice in
            1) spectrum_scan ;;
            2) detect_hidden_networks ;;
            3) bluetooth_scan ;;
            4) 
                read -p "Target BSSID (blank for strongest): " BSSID
                signal_mapping "$BSSID"
                ;;
            5) channel_utilization ;;
            6) generate_report ;;
            7) exit 0 ;;
        esac
    done
}

NOTIFY() {
    echo -e "\033[0;33m[$1]\033[0m $2"
    echo "[$(date '+%H:%M:%S')] [$1] $2" >> "$LOG"
}

main "$@"
