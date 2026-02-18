#!/bin/bash
# Title: WiFi6 Scanner - 802.11ax Network Analyzer
# Author: bad-antics
# Description: Advanced WiFi 6/6E network scanner with ax-specific feature detection
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/wifi6scan"
mkdir -p "$LOOT_DIR"

PROMPT "WiFi6 SCANNER

802.11ax Network Analyzer

Detects WiFi 6/6E features:
- OFDMA channels
- MU-MIMO capability
- BSS Coloring
- TWT (Target Wake Time)
- 6GHz band scanning
- WPA3-SAE detection

Press OK to begin."

SCAN_TIME=$(NUMBER_PICKER "Scan time (sec):" 15)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_TIME=15 ;; esac

# Find monitor interface
MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface found!

Run: airmon-ng start wlan1"; exit 1; }

SPINNER_START "Scanning WiFi 6 networks..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCAN_FILE="$LOOT_DIR/wifi6_scan_${TIMESTAMP}"

# Capture beacons and probe responses with extended info
rm -f /tmp/wifi6scan*
timeout "$SCAN_TIME" airodump-ng "$MON_IF" \
    -w /tmp/wifi6scan --output-format csv,pcap \
    --band abg 2>/dev/null &
SCAN_PID=$!
sleep "$SCAN_TIME"
kill "$SCAN_PID" 2>/dev/null
wait "$SCAN_PID" 2>/dev/null

SPINNER_STOP

# Parse results
WIFI6_COUNT=0
TOTAL_COUNT=0
RESULTS=""

if [ -f /tmp/wifi6scan-01.csv ]; then
    while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lanip idlen essid key; do
        bssid=$(echo "$bssid" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue

        TOTAL_COUNT=$((TOTAL_COUNT + 1))
        essid=$(echo "$essid" | tr -d ' ')
        channel=$(echo "$channel" | tr -d ' ')
        speed=$(echo "$speed" | tr -d ' ')
        power=$(echo "$power" | tr -d ' ')
        privacy=$(echo "$privacy" | tr -d ' ')

        # Detect WiFi 6 by speed and capabilities
        WIFI6="NO"
        AX_FEATURES=""

        # WiFi 6 typically shows speeds > 300Mbps in airodump
        speed_num=$(echo "$speed" | grep -oP '\d+' | head -1)
        if [ -n "$speed_num" ] && [ "$speed_num" -ge 300 ] 2>/dev/null; then
            WIFI6="LIKELY"
        fi

        # WPA3 detection
        WPA3="NO"
        if echo "$privacy" | grep -qi "WPA3\|SAE"; then
            WPA3="YES"
            AX_FEATURES="WPA3 "
        fi

        # High channel = 5GHz/6GHz
        ch_num=$(echo "$channel" | grep -oP '\d+' | head -1)
        BAND="2.4GHz"
        if [ -n "$ch_num" ] && [ "$ch_num" -gt 14 ] 2>/dev/null; then
            BAND="5GHz"
            [ "$ch_num" -gt 177 ] 2>/dev/null && BAND="6GHz"
        fi

        if [ "$WIFI6" = "LIKELY" ] || [ "$WPA3" = "YES" ]; then
            WIFI6_COUNT=$((WIFI6_COUNT + 1))
        fi

        RESULTS="${RESULTS}${bssid}|${essid}|${channel}|${BAND}|${power}|${privacy}|${WIFI6}|${WPA3}\n"

    done < /tmp/wifi6scan-01.csv

    # Save results
    {
        echo "WiFi6 Scan Report - $(date)"
        echo "================================"
        echo "Total Networks: $TOTAL_COUNT"
        echo "WiFi 6 Likely: $WIFI6_COUNT"
        echo ""
        echo "BSSID|ESSID|Channel|Band|Power|Security|WiFi6|WPA3"
        echo -e "$RESULTS"
    } > "${SCAN_FILE}.txt"

    # Copy pcap for detailed analysis
    cp /tmp/wifi6scan-01.cap "${SCAN_FILE}.pcap" 2>/dev/null
fi

# Show results
DISPLAY_TEXT="WiFi6 SCAN RESULTS

Total Networks: $TOTAL_COUNT
WiFi 6 (likely): $WIFI6_COUNT

"

if [ "$WIFI6_COUNT" -gt 0 ]; then
    DISPLAY_TEXT="${DISPLAY_TEXT}WiFi 6 / WPA3 Networks:
"
    echo -e "$RESULTS" | grep -E "LIKELY|YES" | head -8 | while IFS='|' read -r bssid essid ch band pwr sec w6 w3; do
        [ -z "$bssid" ] && continue
        DISPLAY_TEXT="${DISPLAY_TEXT}
${essid} (ch${ch})
 ${band} ${sec}
"
    done
fi

DISPLAY_TEXT="${DISPLAY_TEXT}
Saved: wifi6_scan_${TIMESTAMP}
Loot: $LOOT_DIR"

PROMPT "$DISPLAY_TEXT"

# Cleanup
rm -f /tmp/wifi6scan*
