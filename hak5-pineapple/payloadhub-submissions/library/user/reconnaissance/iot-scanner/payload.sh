#!/bin/bash
# Title:         IoT Scanner
# Description:   Discover and fingerprint IoT/smart home devices by WiFi signatures
# Author:        bad-antics
# Version:       1.0
# Category:      Reconnaissance
# Target:        WiFi Pineapple Pager
#
# LED State Descriptions
# SETUP     - Initializing scanner
# SPECIAL   - Scanning for IoT devices
# SUCCESS   - Devices found
# FAIL      - No devices found / error
# CLEANUP   - Restoring interfaces
#
# Firmware:  Tested on firmware 1.0.4+

# ============================================================================
# CONFIGURATION
# ============================================================================
INTERFACE="wlan0"
LOOT_DIR="/root/loot/iot_scanner"
PASSIVE_DURATION=20

# ============================================================================
# IOT DEVICE SIGNATURE DATABASE
# ============================================================================
# Format: OUI:DeviceType
IOT_OUIS="18:B4:30:Nest Thermostat
64:16:66:Nest Protect
F4:F5:D8:Google Home
20:DF:B9:Google Home Mini
30:FD:38:Google Home Hub
48:D6:D5:Amazon Echo
50:DC:E7:Amazon Echo Dot
68:37:E9:Amazon Fire TV
FC:65:DE:Amazon Ring
44:65:0D:Amazon Alexa
00:FC:8B:Amazon Echo Show
00:17:88:Philips Hue Bridge
EC:B5:FA:Philips Hue
00:24:88:Ring Doorbell
9C:02:98:Ring Camera
94:10:3E:Ring Floodlight
50:14:79:TP-Link Kasa
B0:BE:76:TP-Link Tapo
60:01:94:TP-Link Smart Plug
D8:0D:17:TP-Link Deco
70:4F:57:TP-Link Smart
74:DA:38:EZVIZ Camera
8C:7A:15:Roku Streaming
B0:A7:B9:Roku Ultra
DC:3A:5E:Roku Express
D8:31:34:Roku Premiere
70:A7:93:Roku TV
84:EA:64:Roku Stick
14:91:82:Belkin WeMo
EC:1A:59:Belkin Smart
C4:41:1E:Belkin Wemo
78:4B:87:Wink Hub
88:D7:F6:Apple HomePod
9C:20:7B:Apple TV
D0:5F:B8:Apple HomeKit
60:3C:92:Wyze Cam
2C:AA:8E:Wyze Doorbell
7C:78:B2:Wyze Plug
AC:ED:5C:Insteon Hub
D0:73:D5:LIFX Bulb
00:22:6D:August Lock
38:B1:DB:August Connect
F0:45:DA:Samsung SmartThings
24:62:AB:Espressif (IoT)
CC:50:E3:Espressif (IoT)
AC:67:B2:Espressif (IoT)
A4:CF:12:Espressif (IoT)
B4:E6:2D:Espressif (IoT)
30:AE:A4:Espressif (IoT)
08:3A:F2:Espressif (IoT)"

# Known IoT SSID patterns
IOT_SSIDS="RING-|Ring-|NEST-|Nest-|Wyze|ECHO-|echo-|SmartThings|HUE-|Philips|WeMo|MyQ|DIRECTV|Roku|Fire-TV|Amazon-|LIFX|Sonos|Arlo-|YI-|Blink-|SimpliSafe|ecobee|iRobot|Roomba|Tuya|SmartLife|Govee"

# ============================================================================
# CLEANUP TRAP
# ============================================================================
cleanup() {
    airmon-ng stop "${INTERFACE}mon" 2>/dev/null
    airmon-ng stop "$INTERFACE" 2>/dev/null
    rm -rf "/tmp/iotscan_$$"
    LED CLEANUP
}
trap cleanup EXIT

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
classify_device() {
    local oui="$1"
    local ssid="$2"

    # Check OUI first
    local match=$(echo "$IOT_OUIS" | grep -i "$oui" | head -1)
    if [ -n "$match" ]; then
        echo "$match" | cut -d':' -f4-
        return 0
    fi

    # Check SSID patterns
    if [ -n "$ssid" ]; then
        case "$ssid" in
            *RING*|*Ring*)    echo "Ring Device" ;;
            *NEST*|*Nest*)    echo "Nest Device" ;;
            *Wyze*)           echo "Wyze Device" ;;
            *ECHO*|*echo*)    echo "Amazon Echo" ;;
            *Alexa*)          echo "Amazon Alexa" ;;
            *HUE*|*Philips*)  echo "Philips Hue" ;;
            *Roku*)           echo "Roku Streaming" ;;
            *LIFX*)           echo "LIFX Smart Light" ;;
            *Sonos*)          echo "Sonos Speaker" ;;
            *Arlo*)           echo "Arlo Camera" ;;
            *Blink*)          echo "Blink Camera" ;;
            *Tuya*|*Smart*)   echo "Tuya Smart Device" ;;
            *Govee*)          echo "Govee Light" ;;
            *iRobot*|*Roomba*) echo "iRobot Vacuum" ;;
            *)                return 1 ;;
        esac
        return 0
    fi
    return 1
}

# ============================================================================
# PAYLOAD START
# ============================================================================
LED SETUP

PROMPT "IOT SCANNER v1.0

Discover smart home and
IoT devices by WiFi.

Detects 50+ device types:
- Smart speakers
- Cameras & doorbells
- Smart plugs & lights
- Streaming devices
- Thermostats & locks
- Robot vacuums

Press OK to configure."

# Scan mode selection
PROMPT "SCAN MODE

1. Passive (monitor mode)
   Stealthy, captures
   beacon frames only

2. Active (network scan)
   Scans connected network
   for IoT by MAC/OUI

3. Combined (both)
   Maximum coverage

Press OK then pick mode."

SCAN_MODE=$(NUMBER_PICKER "Mode (1-3):" 3)
case $? in
    $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED)
        LOG "Cancelled"
        exit 0
        ;;
esac
[ -z "$SCAN_MODE" ] && SCAN_MODE=3

# ============================================================================
# PREPARE LOOT
# ============================================================================
mkdir -p "$LOOT_DIR"
LOOT_FILE="$LOOT_DIR/iot_$(date +%Y%m%d_%H%M%S).txt"

{
    echo "════════════════════════════════════════"
    echo "  IOT SCANNER - Results"
    echo "════════════════════════════════════════"
    echo "Date:  $(date)"
    echo "Mode:  $([ "$SCAN_MODE" = "1" ] && echo "Passive" || ([ "$SCAN_MODE" = "2" ] && echo "Active" || echo "Combined"))"
    echo "════════════════════════════════════════"
} > "$LOOT_FILE"

FOUND=0
DEVICE_LIST=""

# ============================================================================
# PASSIVE SCAN (Monitor Mode)
# ============================================================================
if [ "$SCAN_MODE" = "1" ] || [ "$SCAN_MODE" = "3" ]; then
    LED SPECIAL
    SPINNER_START "Passive scan (${PASSIVE_DURATION}s)..."

    airmon-ng check kill 2>/dev/null
    sleep 1
    airmon-ng start "$INTERFACE" >/dev/null 2>&1
    MON_IF="${INTERFACE}mon"
    [ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

    TEMP_DIR="/tmp/iotscan_$$"
    mkdir -p "$TEMP_DIR"
    timeout "$PASSIVE_DURATION" airodump-ng "$MON_IF" -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
    SCAN_PID=$!
    sleep "$PASSIVE_DURATION"
    kill $SCAN_PID 2>/dev/null
    wait $SCAN_PID 2>/dev/null

    SPINNER_STOP

    SPINNER_START "Analyzing passive results..."

    echo "" >> "$LOOT_FILE"
    echo "─── Passive Scan Results ───" >> "$LOOT_FILE"

    if [ -f "$TEMP_DIR/scan-01.csv" ]; then
        while IFS=',' read -r BSSID F2 F3 CHANNEL F5 F6 F7 F8 F9 POWER F11 F12 F13 ESSID REST; do
            BSSID=$(echo "$BSSID" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
            ESSID=$(echo "$ESSID" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [ -n "$BSSID" ] && echo "$BSSID" | grep -qE "^[0-9A-Fa-f]{2}:"; then
                OUI=$(echo "$BSSID" | cut -d':' -f1-3)
                DEVICE_TYPE=$(classify_device "$OUI" "$ESSID")

                if [ -n "$DEVICE_TYPE" ]; then
                    {
                        echo ""
                        echo "  ◆ $DEVICE_TYPE"
                        echo "    MAC:     $BSSID"
                        echo "    SSID:    $ESSID"
                        echo "    Channel: $(echo "$CHANNEL" | tr -d ' ')"
                        echo "    Signal:  $(echo "$POWER" | tr -d ' ') dBm"
                    } >> "$LOOT_FILE"
                    DEVICE_LIST="${DEVICE_LIST}${DEVICE_TYPE}\n"
                    ((FOUND++))
                fi
            fi
        done < "$TEMP_DIR/scan-01.csv"
    fi

    rm -rf "$TEMP_DIR"
    airmon-ng stop "$MON_IF" 2>/dev/null

    SPINNER_STOP
fi

# ============================================================================
# ACTIVE SCAN (Network ARP/Ping)
# ============================================================================
if [ "$SCAN_MODE" = "2" ] || [ "$SCAN_MODE" = "3" ]; then
    # Get network range
    GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
    if [ -n "$GATEWAY" ]; then
        DEFAULT_NET=$(echo "$GATEWAY" | sed 's/\.[0-9]*$/.0\/24/')
    else
        DEFAULT_NET="192.168.1.0/24"
    fi

    NETWORK=$(TEXT_PICKER "Network to scan:" "$DEFAULT_NET")
    case $? in
        $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED)
            [ "$FOUND" -eq 0 ] && exit 0
            NETWORK=""
            ;;
    esac

    if [ -n "$NETWORK" ]; then
        LED SPECIAL
        SPINNER_START "Active network scan..."

        echo "" >> "$LOOT_FILE"
        echo "─── Active Scan Results ───" >> "$LOOT_FILE"
        echo "Network: $NETWORK" >> "$LOOT_FILE"

        # Try arp-scan first, fall back to ping sweep + arp table
        if command -v arp-scan >/dev/null 2>&1; then
            arp-scan -I "$INTERFACE" "$NETWORK" 2>/dev/null | while IFS=$'\t' read -r IP MAC VENDOR; do
                if [ -n "$MAC" ] && echo "$MAC" | grep -qE "^[0-9a-fA-F]{2}:"; then
                    OUI=$(echo "$MAC" | tr '[:lower:]' '[:upper:]' | cut -d':' -f1-3)
                    DEVICE_TYPE=$(classify_device "$OUI" "")

                    if [ -n "$DEVICE_TYPE" ]; then
                        {
                            echo ""
                            echo "  ◆ $DEVICE_TYPE"
                            echo "    IP:  $IP"
                            echo "    MAC: $MAC"
                        } >> "$LOOT_FILE"
                        ((FOUND++))
                    fi
                fi
            done
        else
            # Ping sweep + ARP table
            for i in $(seq 1 254); do
                SUBNET=$(echo "$NETWORK" | sed 's/\.[0-9]*\/.*$//')
                ping -c 1 -W 1 "${SUBNET}.${i}" >/dev/null 2>&1 &
            done
            wait

            arp -an 2>/dev/null | grep -v incomplete | while read -r _ IP _ _ MAC _; do
                IP=$(echo "$IP" | tr -d '()')
                MAC=$(echo "$MAC" | tr '[:lower:]' '[:upper:]')
                if [ -n "$MAC" ] && echo "$MAC" | grep -qE "^[0-9A-F]{2}:"; then
                    OUI=$(echo "$MAC" | cut -d':' -f1-3)
                    DEVICE_TYPE=$(classify_device "$OUI" "")

                    if [ -n "$DEVICE_TYPE" ]; then
                        {
                            echo ""
                            echo "  ◆ $DEVICE_TYPE"
                            echo "    IP:  $IP"
                            echo "    MAC: $MAC"
                        } >> "$LOOT_FILE"
                        ((FOUND++))
                    fi
                fi
            done
        fi

        SPINNER_STOP
    fi
fi

# ============================================================================
# SUMMARY
# ============================================================================
{
    echo ""
    echo "════════════════════════════════════════"
    echo "Total IoT Devices Found: $FOUND"
    echo "════════════════════════════════════════"
} >> "$LOOT_FILE"

if [ "$FOUND" -gt 0 ]; then
    LED SUCCESS

    # Count unique device types
    UNIQUE_TYPES=$(echo -e "$DEVICE_LIST" | sort -u | grep -v '^$' | head -8)

    PROMPT "IOT DEVICES FOUND: $FOUND

Device types:
$UNIQUE_TYPES

Results saved to:
$LOOT_FILE

Press OK to exit."
else
    LED FAIL
    PROMPT "NO IOT DEVICES

No IoT devices detected.

Tips:
- Ensure you are near
  a smart home network
- Try active scan mode
- Check WiFi connection

Press OK to exit."
fi

LOG "IoT Scanner complete. Found: $FOUND"
