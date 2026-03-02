#!/bin/bash
# Title:         Drone Hunter
# Description:   Detect and identify nearby drones by WiFi signatures (DJI, Parrot, Autel, Yuneec, Skydio)
# Author:        bad-antics
# Version:       1.0
# Category:      Reconnaissance
# Target:        WiFi Pineapple Pager
#
# LED State Descriptions
# SETUP     - Initializing monitor mode
# SPECIAL   - Scanning for drones
# SUCCESS   - Drones detected
# FAIL      - No drones found / error
# CLEANUP   - Restoring interfaces
#
# Firmware:  Tested on firmware 1.0.4+
# Props:     NullSec Collection

# ============================================================================
# CONFIGURATION
# ============================================================================
INTERFACE="wlan0"
LOOT_DIR="/root/loot/drone_hunter"
DEFAULT_DURATION=30

# ============================================================================
# DRONE SIGNATURE DATABASE
# ============================================================================
# Format: OUI:Manufacturer
DRONE_OUIS="60:60:1F:DJI
34:D2:62:DJI
48:1C:B9:DJI
60:B6:47:DJI
E0:49:4C:DJI
40:1C:A8:Parrot
90:03:B7:Parrot
A0:14:3D:Parrot
00:12:1C:Parrot
00:26:7E:Parrot
94:51:03:Autel
90:3A:E6:Autel
2C:41:A1:Yuneec
60:A4:4C:Skydio
9C:4E:36:Holy Stone
A0:C9:A0:Syma
4C:49:E3:Autel"

# Known drone SSID patterns
DRONE_SSIDS="Spark-|Mavic-|Phantom|TELLO-|Anafi-|Bebop|PARROT|DJI|Skydio|YUNEEC|AUTEL|EVO-"

# ============================================================================
# CLEANUP TRAP
# ============================================================================
cleanup() {
    airmon-ng stop "${INTERFACE}mon" 2>/dev/null
    airmon-ng stop "$INTERFACE" 2>/dev/null
    rm -rf "/tmp/dronehunt_$$"
    LED CLEANUP
}
trap cleanup EXIT

# ============================================================================
# PAYLOAD START
# ============================================================================
LED SETUP

PROMPT "DRONE HUNTER v1.0

Detect drones by their
WiFi signatures.

Supported manufacturers:
- DJI (Mavic/Spark/Phantom)
- Parrot (Anafi/Bebop)
- Autel (EVO series)
- Yuneec
- Skydio
- Holy Stone / Syma

Press OK to start."

# Get scan duration from user
DURATION=$(NUMBER_PICKER "Scan duration (seconds):" $DEFAULT_DURATION)
case $? in
    $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED)
        LOG "Cancelled by user"
        exit 0
        ;;
esac
[ -z "$DURATION" ] && DURATION=$DEFAULT_DURATION

# ============================================================================
# INITIALIZE MONITOR MODE
# ============================================================================
SPINNER_START "Preparing monitor mode..."

airmon-ng check kill 2>/dev/null
sleep 1
airmon-ng start "$INTERFACE" >/dev/null 2>&1
MON_IF="${INTERFACE}mon"
[ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

SPINNER_STOP

# ============================================================================
# SCAN FOR DRONES
# ============================================================================
LED SPECIAL
SPINNER_START "Scanning for drones (${DURATION}s)..."

TEMP_DIR="/tmp/dronehunt_$$"
mkdir -p "$TEMP_DIR"
timeout "$DURATION" airodump-ng "$MON_IF" -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
SCAN_PID=$!
sleep "$DURATION"
kill $SCAN_PID 2>/dev/null
wait $SCAN_PID 2>/dev/null

SPINNER_STOP

# ============================================================================
# PARSE RESULTS
# ============================================================================
SPINNER_START "Analyzing captures..."

mkdir -p "$LOOT_DIR"
LOOT_FILE="$LOOT_DIR/drones_$(date +%Y%m%d_%H%M%S).txt"

{
    echo "════════════════════════════════════════"
    echo "  DRONE HUNTER - Scan Results"
    echo "════════════════════════════════════════"
    echo "Date:     $(date)"
    echo "Duration: ${DURATION}s"
    echo "Interface: $MON_IF"
    echo "════════════════════════════════════════"
} > "$LOOT_FILE"

FOUND=0

if [ -f "$TEMP_DIR/scan-01.csv" ]; then
    while IFS=',' read -r BSSID F2 F3 CHANNEL F5 SPEED PRIVACY CIPHER AUTH POWER F11 F12 F13 ESSID REST; do
        BSSID=$(echo "$BSSID" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
        ESSID=$(echo "$ESSID" | tr -d ' ')

        if [ -n "$BSSID" ] && echo "$BSSID" | grep -qE "^[0-9A-Fa-f]{2}:"; then
            OUI=$(echo "$BSSID" | cut -d':' -f1-3)

            # Check by OUI database
            DRONE_TYPE=""
            if echo "$DRONE_OUIS" | grep -qi "$OUI"; then
                DRONE_TYPE=$(echo "$DRONE_OUIS" | grep -i "$OUI" | head -1 | cut -d':' -f4)
            fi

            # Check by SSID pattern
            if [ -z "$DRONE_TYPE" ] && [ -n "$ESSID" ] && echo "$ESSID" | grep -qiE "$DRONE_SSIDS"; then
                if echo "$ESSID" | grep -qi "DJI\|Spark\|Mavic\|Phantom\|TELLO"; then
                    DRONE_TYPE="DJI"
                elif echo "$ESSID" | grep -qi "Parrot\|Anafi\|Bebop"; then
                    DRONE_TYPE="Parrot"
                elif echo "$ESSID" | grep -qi "AUTEL\|EVO"; then
                    DRONE_TYPE="Autel"
                elif echo "$ESSID" | grep -qi "YUNEEC"; then
                    DRONE_TYPE="Yuneec"
                elif echo "$ESSID" | grep -qi "Skydio"; then
                    DRONE_TYPE="Skydio"
                else
                    DRONE_TYPE="Unknown Drone"
                fi
            fi

            if [ -n "$DRONE_TYPE" ]; then
                {
                    echo ""
                    echo "  ★ DRONE DETECTED"
                    echo "  Manufacturer: $DRONE_TYPE"
                    echo "  BSSID:        $BSSID"
                    echo "  SSID:         $ESSID"
                    echo "  Channel:      $(echo "$CHANNEL" | tr -d ' ')"
                    echo "  Signal:       $(echo "$POWER" | tr -d ' ') dBm"
                    echo "  Encryption:   $(echo "$PRIVACY" | tr -d ' ')"
                } >> "$LOOT_FILE"
                ((FOUND++))
            fi
        fi
    done < "$TEMP_DIR/scan-01.csv"
fi

echo "" >> "$LOOT_FILE"
echo "════════════════════════════════════════" >> "$LOOT_FILE"
echo "Total Drones Found: $FOUND" >> "$LOOT_FILE"
echo "════════════════════════════════════════" >> "$LOOT_FILE"

SPINNER_STOP

# ============================================================================
# DISPLAY RESULTS
# ============================================================================
if [ "$FOUND" -gt 0 ]; then
    LED SUCCESS

    # Build summary for display
    SUMMARY=""
    while IFS= read -r line; do
        if echo "$line" | grep -q "Manufacturer:"; then
            TYPE=$(echo "$line" | cut -d':' -f2- | tr -d ' ')
            SUMMARY="${SUMMARY}${TYPE} "
        fi
    done < "$LOOT_FILE"

    PROMPT "DRONES FOUND: $FOUND

Types detected:
$SUMMARY

Results saved to:
$LOOT_FILE

Press OK to exit."
else
    LED FAIL
    PROMPT "NO DRONES FOUND

No drone WiFi signals
detected in ${DURATION}s.

Tips:
- Try a longer scan
- Move to open area
- Drones may be on 5GHz

Press OK to exit."
fi

LOG "Drone Hunter complete. Found: $FOUND"
