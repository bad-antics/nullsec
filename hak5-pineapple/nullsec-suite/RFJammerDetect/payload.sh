#!/bin/bash
# Title: RF Jammer Detector - Radio Frequency Interference Scanner
# Author: bad-antics
# Description: Detect and locate RF jamming sources using signal analysis and interference patterns
# Category: nullsec/sigint

LOOT_DIR="/mmc/nullsec/rfjammer"
mkdir -p "$LOOT_DIR"

PROMPT "RF JAMMER DETECTOR

Radio Frequency Analysis

Capabilities:
- Detect WiFi jamming
- Deauth flood detection
- Beacon anomaly analysis
- Signal noise monitoring
- Interference mapping
- Channel saturation check
- Source triangulation

Press OK to scan."

SCAN_TIME=$(NUMBER_PICKER "Monitor time (sec):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_TIME=30 ;; esac

# Find monitor interface
MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!

Run: airmon-ng start wlan1"; exit 1; }

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$LOOT_DIR/rf_analysis_${TIMESTAMP}.txt"
ALERT_FILE="$LOOT_DIR/rf_alerts_${TIMESTAMP}.txt"

SPINNER_START "Monitoring RF environment..."

{
    echo "RF Jammer Detection Report - $(date)"
    echo "======================================="
    echo "Monitor Interface: $MON_IF"
    echo "Duration: ${SCAN_TIME}s"
    echo ""
} > "$REPORT"

# Phase 1: Baseline signal measurement
echo "=== PHASE 1: BASELINE MEASUREMENT ===" >> "$REPORT"

# Capture baseline noise floor per channel
declare -A BASELINE_NOISE
declare -A DEAUTH_COUNT
declare -A BEACON_COUNT

for ch in 1 6 11 36 44 149; do
    iwconfig "$MON_IF" channel "$ch" 2>/dev/null
    sleep 0.5

    # Get noise level
    noise=$(iwconfig "$MON_IF" 2>/dev/null | grep -oP 'Noise level[=:]-?\d+' | grep -oP '-?\d+')
    [ -z "$noise" ] && noise=-95
    BASELINE_NOISE[$ch]=$noise
    echo "  Channel $ch noise floor: ${noise} dBm" >> "$REPORT"
done

# Phase 2: Deauth Detection
echo "" >> "$REPORT"
echo "=== PHASE 2: DEAUTH FLOOD DETECTION ===" >> "$REPORT"

rm -f /tmp/rf_detect*

# Capture packets for analysis
timeout "$SCAN_TIME" tcpdump -i "$MON_IF" -c 50000 -w /tmp/rf_detect.pcap 2>/dev/null &
TCPDUMP_PID=$!

# Also run airodump for visual
timeout "$SCAN_TIME" airodump-ng "$MON_IF" \
    -w /tmp/rf_scan --output-format csv 2>/dev/null &
AIRO_PID=$!

sleep "$SCAN_TIME"
kill "$TCPDUMP_PID" "$AIRO_PID" 2>/dev/null
wait 2>/dev/null

SPINNER_STOP

# Analyze captured data
SPINNER_START "Analyzing RF data..."

DEAUTH_TOTAL=0
DISASSOC_TOTAL=0
BEACON_ANOMALIES=0
JAMMING_DETECTED=false
ALERTS=""

# Count deauth frames
if [ -f /tmp/rf_detect.pcap ] && command -v tcpdump &>/dev/null; then
    DEAUTH_TOTAL=$(tcpdump -r /tmp/rf_detect.pcap 'type mgt subtype deauth' 2>/dev/null | wc -l)
    DISASSOC_TOTAL=$(tcpdump -r /tmp/rf_detect.pcap 'type mgt subtype disassoc' 2>/dev/null | wc -l)

    echo "  Deauth frames: $DEAUTH_TOTAL" >> "$REPORT"
    echo "  Disassoc frames: $DISASSOC_TOTAL" >> "$REPORT"

    # Deauth flood threshold (>50 in scan period = suspicious)
    if [ "$DEAUTH_TOTAL" -gt 50 ]; then
        JAMMING_DETECTED=true
        ALERTS="${ALERTS}⚠ DEAUTH FLOOD DETECTED: ${DEAUTH_TOTAL} frames\n"
        echo "  ⚠ DEAUTH FLOOD DETECTED!" >> "$REPORT"

        # Find source
        DEAUTH_SOURCES=$(tcpdump -r /tmp/rf_detect.pcap 'type mgt subtype deauth' 2>/dev/null | \
            grep -oP '[0-9a-f]{2}(:[0-9a-f]{2}){5}' | sort | uniq -c | sort -rn | head -5)
        echo "  Top deauth sources:" >> "$REPORT"
        echo "$DEAUTH_SOURCES" >> "$REPORT"
    fi
fi

# Phase 3: Channel Saturation Check
echo "" >> "$REPORT"
echo "=== PHASE 3: CHANNEL SATURATION ===" >> "$REPORT"

SATURATED_CHANNELS=0
if [ -f /tmp/rf_scan-01.csv ]; then
    declare -A CH_AP_COUNT
    while IFS=',' read -r bssid first last channel rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        ch=$(echo "$channel" | tr -d ' ')
        [ -z "$ch" ] && continue
        CH_AP_COUNT[$ch]=$(( ${CH_AP_COUNT[$ch]:-0} + 1 ))
    done < /tmp/rf_scan-01.csv

    for ch in "${!CH_AP_COUNT[@]}"; do
        count=${CH_AP_COUNT[$ch]}
        echo "  Channel $ch: $count APs" >> "$REPORT"
        if [ "$count" -gt 15 ]; then
            SATURATED_CHANNELS=$((SATURATED_CHANNELS + 1))
            ALERTS="${ALERTS}⚠ Channel $ch saturated: ${count} APs\n"
        fi
    done
fi

# Phase 4: Noise Floor Comparison
echo "" >> "$REPORT"
echo "=== PHASE 4: POST-SCAN NOISE CHECK ===" >> "$REPORT"

NOISE_SPIKES=0
for ch in 1 6 11 36 44 149; do
    iwconfig "$MON_IF" channel "$ch" 2>/dev/null
    sleep 0.3
    noise=$(iwconfig "$MON_IF" 2>/dev/null | grep -oP 'Noise level[=:]-?\d+' | grep -oP '-?\d+')
    [ -z "$noise" ] && noise=-95
    baseline=${BASELINE_NOISE[$ch]:--95}

    diff=$((noise - baseline))
    if [ "$diff" -gt 10 ] 2>/dev/null; then
        NOISE_SPIKES=$((NOISE_SPIKES + 1))
        ALERTS="${ALERTS}⚠ Noise spike on Ch${ch}: ${diff}dB above baseline\n"
        echo "  Channel $ch: NOISE SPIKE (+${diff}dB)" >> "$REPORT"
    else
        echo "  Channel $ch: Normal (${noise}dBm)" >> "$REPORT"
    fi
done

SPINNER_STOP

# Summary
THREAT_LEVEL="CLEAR"
[ "$DEAUTH_TOTAL" -gt 50 ] || [ "$SATURATED_CHANNELS" -gt 2 ] && THREAT_LEVEL="SUSPICIOUS"
[ "$DEAUTH_TOTAL" -gt 200 ] || [ "$NOISE_SPIKES" -gt 2 ] && THREAT_LEVEL="JAMMING LIKELY"
[ "$DEAUTH_TOTAL" -gt 500 ] && [ "$NOISE_SPIKES" -gt 0 ] && THREAT_LEVEL="ACTIVE JAMMING"

{
    echo ""
    echo "╔═══════════════════════════════╗"
    echo "║         THREAT SUMMARY         ║"
    echo "╚═══════════════════════════════╝"
    echo ""
    echo "Threat Level: $THREAT_LEVEL"
    echo "Deauth Frames: $DEAUTH_TOTAL"
    echo "Disassoc Frames: $DISASSOC_TOTAL"
    echo "Saturated Channels: $SATURATED_CHANNELS"
    echo "Noise Spikes: $NOISE_SPIKES"
} >> "$REPORT"

# Save alerts
echo -e "$ALERTS" > "$ALERT_FILE"

PROMPT "RF ANALYSIS COMPLETE

Threat Level: $THREAT_LEVEL

Deauth Frames: $DEAUTH_TOTAL
Disassoc: $DISASSOC_TOTAL
Saturated Ch: $SATURATED_CHANNELS
Noise Spikes: $NOISE_SPIKES

$(echo -e "$ALERTS" | head -5)

Report: rf_analysis_${TIMESTAMP}
Loot: $LOOT_DIR"

# Cleanup
rm -f /tmp/rf_detect* /tmp/rf_scan*
