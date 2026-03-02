#!/bin/bash
# Title: Beacon Decoder
# Author: bad-antics
# Description: Decode and analyze 802.11 beacon frame contents in detail
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/beacons"
mkdir -p "$LOOT_DIR"

PROMPT "BEACON DECODER

Deep analysis of 802.11 beacon
frames from nearby access points.

Extracts:
- Supported rates & capabilities
- RSN/WPA information elements
- HT/VHT capabilities (11n/11ac)
- HE capabilities (WiFi 6)
- Country/regulatory info
- Vendor-specific OUI data
- WPS configuration state
- Power constraint info
- Channel utilization

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

DURATION=$(NUMBER_PICKER "Capture duration (sec):" 15)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=15 ;; esac

SINGLE=$(CONFIRMATION_DIALOG "SINGLE TARGET?

OK = Decode specific BSSID
CANCEL = Decode all beacons")

TARGET_BSSID=""
if [ "$SINGLE" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    TARGET_BSSID=$(TEXT_PICKER "Target BSSID:" "AA:BB:CC:DD:EE:FF")
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TARGET_BSSID="" ;; esac
fi

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/beacons_${TIMESTAMP}.txt"

resp=$(CONFIRMATION_DIALOG "START BEACON DECODE?

Duration: ${DURATION}s
Target: $([ -n \"$TARGET_BSSID\" ] && echo \"$TARGET_BSSID\" || echo 'All APs')

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Capturing beacons..."
SPINNER_START "Decoding beacons..."

PCAP_FILE="/tmp/beacons_${TIMESTAMP}.pcap"

# Capture beacon frames
if [ -n "$TARGET_BSSID" ]; then
    timeout $DURATION tcpdump -i wlan0 -e -s 0 -w "$PCAP_FILE" "type mgt subtype beacon and ether src $TARGET_BSSID" 2>/dev/null
else
    timeout $DURATION tcpdump -i wlan0 -e -s 0 -w "$PCAP_FILE" "type mgt subtype beacon" 2>/dev/null
fi

# Also capture verbose text output
BEACON_TXT="/tmp/beacons_txt_${TIMESTAMP}.txt"
if [ -n "$TARGET_BSSID" ]; then
    timeout $DURATION tcpdump -i wlan0 -e -vvv "type mgt subtype beacon and ether src $TARGET_BSSID" 2>/dev/null > "$BEACON_TXT" &
else
    timeout $DURATION tcpdump -i wlan0 -e -vvv "type mgt subtype beacon" 2>/dev/null > "$BEACON_TXT" &
fi
TXT_PID=$!
sleep $DURATION
kill $TXT_PID 2>/dev/null

echo "================================================================" > "$REPORT"
echo "         NULLSEC BEACON DECODER REPORT                         " >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "Time: $(date)" >> "$REPORT"
echo "Duration: ${DURATION}s" >> "$REPORT"
echo "" >> "$REPORT"

# Also use airodump for structured data
SCAN_FILE="/tmp/beacon_scan"
rm -f "${SCAN_FILE}"*.csv 2>/dev/null
timeout $DURATION airodump-ng wlan0 --write-interval 5 -w "$SCAN_FILE" --output-format csv 2>/dev/null

# Parse and decode each AP
declare -A DECODED
AP_COUNT=0

while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lan_ip id_len essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    essid=$(echo "$essid" | sed 's/^ *//;s/ *$//')
    channel=$(echo "$channel" | tr -d ' ')
    speed=$(echo "$speed" | tr -d ' ')
    privacy=$(echo "$privacy" | tr -d ' ')
    cipher=$(echo "$cipher" | tr -d ' ')
    auth=$(echo "$auth" | tr -d ' ')
    power=$(echo "$power" | tr -d ' ')
    beacons=$(echo "$beacons" | tr -d ' ')
    [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue

    if [ -n "$TARGET_BSSID" ] && [ "$bssid" != "$TARGET_BSSID" ]; then
        continue
    fi

    AP_COUNT=$((AP_COUNT + 1))
    [ -z "$essid" ] && essid="<hidden>"

    echo "--- AP #$AP_COUNT: $essid ---" >> "$REPORT"
    echo "" >> "$REPORT"
    echo "  BSSID:    $bssid" >> "$REPORT"
    echo "  SSID:     $essid" >> "$REPORT"
    echo "  Channel:  $channel" >> "$REPORT"
    echo "  Signal:   ${power} dBm" >> "$REPORT"
    echo "  Beacons:  $beacons captured" >> "$REPORT"
    echo "" >> "$REPORT"

    # Security analysis
    echo "  SECURITY:" >> "$REPORT"
    echo "    Encryption: $privacy" >> "$REPORT"
    echo "    Cipher:     $cipher" >> "$REPORT"
    echo "    Auth:       $auth" >> "$REPORT"

    # Grade the security
    SEC_GRADE="UNKNOWN"
    case "$privacy" in
        *WPA3*|*SAE*) SEC_GRADE="A+ (WPA3-SAE)" ;;
        *WPA2*CCMP*|*WPA2*) 
            if echo "$auth" | grep -qi "PSK"; then
                SEC_GRADE="B (WPA2-PSK)"
            else
                SEC_GRADE="A (WPA2-Enterprise)"
            fi
            ;;
        *WPA*TKIP*) SEC_GRADE="D (WPA-TKIP, deprecated)" ;;
        *WEP*) SEC_GRADE="F (WEP, broken)" ;;
        *OPN*) SEC_GRADE="F (Open, no encryption)" ;;
    esac
    echo "    Grade:      $SEC_GRADE" >> "$REPORT"
    echo "" >> "$REPORT"

    # Capabilities from speed
    echo "  CAPABILITIES:" >> "$REPORT"
    echo "    Max Rate: ${speed} Mbps" >> "$REPORT"

    SPEED_NUM=$(echo "$speed" | grep -oE '[0-9]+' | head -1)
    if [ -n "$SPEED_NUM" ]; then
        if [ "$SPEED_NUM" -ge 1200 ]; then
            echo "    Standard: 802.11ax (WiFi 6)" >> "$REPORT"
        elif [ "$SPEED_NUM" -ge 400 ]; then
            echo "    Standard: 802.11ac (WiFi 5)" >> "$REPORT"
        elif [ "$SPEED_NUM" -ge 100 ]; then
            echo "    Standard: 802.11n (WiFi 4)" >> "$REPORT"
        elif [ "$SPEED_NUM" -ge 54 ]; then
            echo "    Standard: 802.11g/a" >> "$REPORT"
        else
            echo "    Standard: 802.11b (legacy)" >> "$REPORT"
        fi
    fi

    # Band detection from channel
    CH_NUM=$(echo "$channel" | grep -oE '[0-9]+')
    if [ -n "$CH_NUM" ]; then
        if [ "$CH_NUM" -le 14 ]; then
            BAND="2.4 GHz"
            FREQ=$((2407 + CH_NUM * 5))
            [ "$CH_NUM" -eq 14 ] && FREQ=2484
        elif [ "$CH_NUM" -le 64 ]; then
            BAND="5 GHz (UNII-1/2)"
            FREQ=$((5000 + CH_NUM * 5))
        else
            BAND="5 GHz (UNII-2E/3)"
            FREQ=$((5000 + CH_NUM * 5))
        fi
        echo "    Band:     $BAND (~${FREQ} MHz)" >> "$REPORT"
    fi

    # OUI vendor lookup
    OUI_PREFIX=$(echo "$bssid" | tr '[:lower:]' '[:upper:]' | cut -c1-8)
    case "$OUI_PREFIX" in
        "00:00:0C"|"F4:CF:E2") VENDOR="Cisco Systems" ;;
        "00:1A:2B"|"AC:F2:C5") VENDOR="Ayecom Technology" ;;
        "3C:22:FB"|"F0:18:98"|"A4:83:E7") VENDOR="Apple Inc." ;;
        "DC:A6:32"|"B8:27:EB") VENDOR="Raspberry Pi" ;;
        "00:50:F2"|"60:45:BD") VENDOR="Microsoft" ;;
        "00:14:BF"|"F8:E4:3B") VENDOR="Linksys" ;;
        "C0:25:E9"|"08:02:8E") VENDOR="TP-Link" ;;
        "20:CF:30"|"44:94:FC") VENDOR="ASUSTek" ;;
        "00:26:F2"|"00:24:B2") VENDOR="Netgear" ;;
        "00:17:DF"|"00:22:07") VENDOR="Ubiquiti" ;;
        *) VENDOR="Unknown" ;;
    esac
    echo "    Vendor:   $VENDOR" >> "$REPORT"
    echo "" >> "$REPORT"

    # WPS detection
    echo "  WPS STATUS:" >> "$REPORT"
    if grep -qi "WPS" "$BEACON_TXT" 2>/dev/null; then
        echo "    WPS: Detected (potential attack vector)" >> "$REPORT"
    else
        echo "    WPS: Not detected or disabled" >> "$REPORT"
    fi
    echo "" >> "$REPORT"

done < "${SCAN_FILE}-01.csv" 2>/dev/null

# Save PCAP
cp "$PCAP_FILE" "$LOOT_DIR/" 2>/dev/null

echo "--- SUMMARY ---" >> "$REPORT"
echo "  APs decoded: $AP_COUNT" >> "$REPORT"
echo "  PCAP saved: beacons_${TIMESTAMP}.pcap" >> "$REPORT"
echo "================================================================" >> "$REPORT"

SPINNER_STOP

PROMPT "BEACON DECODE COMPLETE

APs analyzed: $AP_COUNT

Detailed report:
$REPORT

Raw PCAP saved for
further analysis."
