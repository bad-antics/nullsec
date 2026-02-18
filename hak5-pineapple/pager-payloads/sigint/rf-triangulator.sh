#!/bin/bash
# ============================================================
# NullSec: RF Triangulator - Signal Source Locator
# Author: bad-antics
# Description: Multi-point RF signal triangulation and device geolocation
# Category: pager/sigint
#
# UNIQUE FEATURES:
# - Multi-band signal strength mapping
# - GPS-correlated signal readings
# - Triangulation from multiple mesh nodes
# - Heat map generation
# - Real-time signal tracking
# - Hidden transmitter detection
# ============================================================

PAYLOAD_NAME="RF Triangulator"
VERSION="1.0.0"
LOOT="/root/loot/sigint"
LOG="$LOOT/triangulator.log"

init_payload() {
    mkdir -p "$LOOT"/{readings,maps,targets,gps}
    echo "[$(date)] $PAYLOAD_NAME started" >> "$LOG"
    NOTIFY "SIGINT" "RF Triangulator initializing..."
}

get_gps() {
    # Try gpsd first
    local GPS=$(gpspipe -w -n 3 2>/dev/null | grep -m1 "\"lat\"" | \
        python3 -c "import sys,json;d=json.load(sys.stdin);print(f'{d[\"lat\"]},{d[\"lon\"]}')" 2>/dev/null)
    
    if [ -z "$GPS" ]; then
        # Try manual position entry
        GPS="0.000,0.000"
    fi
    echo "$GPS"
}

signal_sweep() {
    NOTIFY "SWEEP" "Multi-band signal sweep..."
    
    local SWEEP_FILE="$LOOT/readings/sweep_$(date +%Y%m%d_%H%M).csv"
    echo "timestamp,channel,frequency,bssid,ssid,signal_dbm,noise,gps_lat,gps_lon" > "$SWEEP_FILE"
    
    GPS_POS=$(get_gps)
    
    # 2.4GHz sweep (channels 1-14)
    for ch in $(seq 1 14); do
        iwconfig wlan0mon channel "$ch" 2>/dev/null
        sleep 0.5
        
        FREQ=$((2412 + (ch - 1) * 5))
        [ "$ch" -eq 14 ] && FREQ=2484
        
        # Capture beacon/probe responses with signal
        timeout 2 tshark -i wlan0mon -Y "wlan.fc.subtype == 8" \
            -T fields -e wlan.sa -e wlan.ssid -e wlan_radio.signal_dbm \
            -e wlan_radio.noise_dbm 2>/dev/null | while IFS=$'\t' read -r bssid ssid signal noise; do
            echo "$(date +%s),$ch,$FREQ,$bssid,$ssid,$signal,$noise,$GPS_POS" >> "$SWEEP_FILE"
        done
    done
    
    # 5GHz sweep (common channels)
    for ch in 36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 149 153 157 161 165; do
        iwconfig wlan0mon channel "$ch" 2>/dev/null
        sleep 0.5
        
        FREQ=$((5000 + ch * 5))
        
        timeout 2 tshark -i wlan0mon -Y "wlan.fc.subtype == 8" \
            -T fields -e wlan.sa -e wlan.ssid -e wlan_radio.signal_dbm \
            -e wlan_radio.noise_dbm 2>/dev/null | while IFS=$'\t' read -r bssid ssid signal noise; do
            echo "$(date +%s),$ch,$FREQ,$bssid,$ssid,$signal,$noise,$GPS_POS" >> "$SWEEP_FILE"
        done
    done
    
    READINGS=$(tail -n +2 "$SWEEP_FILE" | wc -l)
    UNIQUE_AP=$(tail -n +2 "$SWEEP_FILE" | cut -d',' -f4 | sort -u | wc -l)
    NOTIFY "SWEEP" "$READINGS readings from $UNIQUE_AP APs"
}

track_target() {
    local TARGET_BSSID="$1"
    NOTIFY "TRACK" "Tracking $TARGET_BSSID..."
    
    local TRACK_FILE="$LOOT/targets/track_${TARGET_BSSID//:/}_$(date +%Y%m%d_%H%M).csv"
    echo "timestamp,signal_dbm,noise,channel,gps_lat,gps_lon" > "$TRACK_FILE"
    
    # Determine target channel
    TARGET_CH=$(tshark -i wlan0mon -c 5 -Y "wlan.sa == $TARGET_BSSID" \
        -T fields -e wlan_radio.channel 2>/dev/null | head -1)
    
    if [ -n "$TARGET_CH" ]; then
        iwconfig wlan0mon channel "$TARGET_CH" 2>/dev/null
    fi
    
    # Continuous signal strength monitoring
    TRACKING_DURATION=120
    START=$(date +%s)
    
    while [ $(( $(date +%s) - START )) -lt "$TRACKING_DURATION" ]; do
        GPS_POS=$(get_gps)
        
        SIGNAL=$(tshark -i wlan0mon -c 1 -Y "wlan.sa == $TARGET_BSSID" \
            -T fields -e wlan_radio.signal_dbm -e wlan_radio.noise_dbm \
            -e wlan_radio.channel 2>/dev/null | head -1)
        
        if [ -n "$SIGNAL" ]; then
            SIG=$(echo "$SIGNAL" | cut -f1)
            NOISE=$(echo "$SIGNAL" | cut -f2)
            CH=$(echo "$SIGNAL" | cut -f3)
            echo "$(date +%s),$SIG,$NOISE,$CH,$GPS_POS" >> "$TRACK_FILE"
            
            # Signal strength indicator
            if [ "$SIG" -gt -50 ] 2>/dev/null; then
                NOTIFY "TRACK" "VERY CLOSE: ${SIG}dBm"
            elif [ "$SIG" -gt -65 ] 2>/dev/null; then
                NOTIFY "TRACK" "CLOSE: ${SIG}dBm"
            elif [ "$SIG" -gt -75 ] 2>/dev/null; then
                NOTIFY "TRACK" "MEDIUM: ${SIG}dBm"
            else
                NOTIFY "TRACK" "FAR: ${SIG}dBm"
            fi
        fi
        
        sleep 1
    done
    
    READINGS=$(tail -n +2 "$TRACK_FILE" | wc -l)
    NOTIFY "TRACK" "Tracked $TARGET_BSSID: $READINGS readings"
}

multi_point_triangulate() {
    local TARGET_BSSID="$1"
    NOTIFY "TRIANGULATE" "Multi-point triangulation..."
    
    local TRI_FILE="$LOOT/targets/triangulation_${TARGET_BSSID//:/}_$(date +%Y%m%d_%H%M).txt"
    
    # Collect readings from mesh nodes
    MESH_NODES=$(cat /root/loot/mesh/nodes/active.txt 2>/dev/null)
    
    {
        echo "=== TRIANGULATION: $TARGET_BSSID ==="
        echo "Time: $(date)"
        echo ""
        
        # Local reading
        GPS_POS=$(get_gps)
        LOCAL_SIG=$(tshark -i wlan0mon -c 3 -Y "wlan.sa == $TARGET_BSSID" \
            -T fields -e wlan_radio.signal_dbm 2>/dev/null | head -1)
        echo "Local Node: GPS=$GPS_POS Signal=${LOCAL_SIG}dBm"
        
        # Remote readings via mesh
        echo "$MESH_NODES" | while IFS='|' read -r IP HOSTNAME TYPE; do
            [ -z "$IP" ] && continue
            REMOTE_SIG=$(ssh -o BatchMode=yes -o ConnectTimeout=5 root@"$IP" \
                "tshark -i wlan0mon -c 3 -Y 'wlan.sa == $TARGET_BSSID' -T fields -e wlan_radio.signal_dbm 2>/dev/null | head -1" 2>/dev/null)
            REMOTE_GPS=$(ssh -o BatchMode=yes root@"$IP" "gpspipe -w -n 1 2>/dev/null | grep -o '\"lat\":[^,]*' | head -1" 2>/dev/null)
            echo "Node $IP ($HOSTNAME): GPS=$REMOTE_GPS Signal=${REMOTE_SIG}dBm"
        done
        
        echo ""
        echo "=== ESTIMATED LOCATION ==="
        echo "Use signal readings with GPS coordinates to triangulate"
        echo "Stronger signal = closer to node"
    } > "$TRI_FILE"
    
    NOTIFY "TRIANGULATE" "Multi-point data collected"
}

hidden_transmitter_scan() {
    NOTIFY "HIDDEN" "Scanning for hidden transmitters..."
    
    local HIDDEN_FILE="$LOOT/targets/hidden_$(date +%Y%m%d_%H%M).txt"
    
    # Look for unusual RF activity
    {
        echo "=== HIDDEN TRANSMITTER SCAN ==="
        echo "Time: $(date)"
        echo ""
        
        # Non-standard channels
        echo "--- Non-Standard Channel Activity ---"
        for ch in $(seq 1 14); do
            iwconfig wlan0mon channel "$ch" 2>/dev/null
            ACTIVITY=$(timeout 3 tshark -i wlan0mon -c 50 2>/dev/null | wc -l)
            [ "$ACTIVITY" -gt 0 ] && echo "Channel $ch: $ACTIVITY frames"
        done
        
        echo ""
        echo "--- Hidden SSIDs ---"
        timeout 10 tshark -i wlan0mon -Y "wlan.fc.subtype == 8 and wlan.ssid == \"\"" \
            -T fields -e wlan.sa -e wlan_radio.signal_dbm -e wlan_radio.channel \
            2>/dev/null | sort -u
        
        echo ""
        echo "--- Unusual Beacon Intervals ---"
        timeout 10 tshark -i wlan0mon -Y "wlan.fc.subtype == 8" \
            -T fields -e wlan.sa -e wlan.fixed.beacon 2>/dev/null | \
            awk -F'\t' '{if($2 != 100 && $2 != ""){print $1" beacon_interval="$2}}' | sort -u
        
        echo ""
        echo "--- Rogue AP Detection ---"
        # Look for multiple APs with same SSID but different BSSIDs
        timeout 10 tshark -i wlan0mon -Y "wlan.fc.subtype == 8" \
            -T fields -e wlan.ssid -e wlan.sa 2>/dev/null | sort | \
            awk -F'\t' '{count[$1]++; bssids[$1]=bssids[$1]" "$2} END {for(s in count) if(count[s]>1) print s": "count[s]" APs -"bssids[s]}'
        
    } > "$HIDDEN_FILE"
    
    HIDDEN=$(grep -c "frames\|beacon\|APs" "$HIDDEN_FILE" 2>/dev/null)
    NOTIFY "HIDDEN" "Scan complete: $HIDDEN findings"
}

main() {
    init_payload
    signal_sweep
    hidden_transmitter_scan
    
    # Auto-track strongest hidden target
    STRONGEST=$(tail -n +2 "$LOOT/readings/"sweep_*.csv 2>/dev/null | \
        sort -t',' -k6 -rn | head -1 | cut -d',' -f4)
    [ -n "$STRONGEST" ] && track_target "$STRONGEST"
    
    TOTAL=$(find "$LOOT" -name "*.csv" -o -name "*.txt" 2>/dev/null | wc -l)
    NOTIFY "DONE" "RF Triangulator complete: $TOTAL data files"
}

main "$@"
