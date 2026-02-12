#!/bin/bash
# Title: IoT Scanner
# Author: bad-antics
# Description: Discover and fingerprint IoT devices
# Category: nullsec/recon

PROMPT "IOT SCANNER

Discover smart devices:
- Smart TVs & Speakers
- Cameras & Doorbells
- Smart plugs & Lights
- Voice assistants

Press OK to configure."

LOOT_DIR="/mmc/nullsec/iot"
mkdir -p "$LOOT_DIR"
LOOT_FILE="$LOOT_DIR/iot_$(date +%Y%m%d_%H%M%S).txt"

# IoT OUI database
IOT_OUIS="18:B4:30:Nest
64:16:66:Nest
F4:F5:D8:Google_Home
20:DF:B9:Google_Home
30:FD:38:Google_Home
48:D6:D5:Amazon_Echo
50:DC:E7:Amazon
68:37:E9:Amazon
FC:65:DE:Amazon
44:65:0D:Amazon
00:FC:8B:Amazon
00:17:88:Philips_Hue
EC:B5:FA:Philips_Hue
00:24:88:Ring
9C:02:98:Ring
50:14:79:TP-Link
B0:BE:76:TP-Link
60:01:94:TP-Link
D8:0D:17:TP-Link
70:4F:57:TP-Link
74:DA:38:EZVIZ
8C:7A:15:Roku
B0:A7:B9:Roku
DC:3A:5E:Roku
D8:31:34:Roku
14:91:82:Belkin_WeMo
C4:41:1E:Belkin
60:3C:92:Wyze
2C:AA:8E:Wyze
7C:78:B2:Wyze
AC:ED:5C:Insteon
D0:73:D5:LiFX
00:22:6D:August_Lock
38:B1:DB:August_Lock
F0:45:DA:SmartThings"

IOT_SSIDS="RING-|Ring-|NEST-|Nest-|Wyze|ECHO-|echo-|SmartThings|HUE-|Philips|WeMo|DIRECTV|Roku|Fire-TV|Amazon-|LIFX|Sonos"

PROMPT "SCAN MODE:

1. Passive WiFi scan
2. Combined scan

Passive = stealth
Combined = thorough

Select on next screen."

SCAN_MODE=$(NUMBER_PICKER "Mode (1-2):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_MODE=1 ;; esac

DURATION=$(NUMBER_PICKER "Scan duration (sec):" 20)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=20 ;; esac

resp=$(CONFIRMATION_DIALOG "START IOT SCAN?

Mode: $SCAN_MODE
Duration: ${DURATION}s

Press OK to scan.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

echo "IoT Scanner Results" > "$LOOT_FILE"
echo "Date: $(date)" >> "$LOOT_FILE"
echo "---" >> "$LOOT_FILE"

FOUND=0

# Use existing monitor interface
MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

SPINNER_START "Scanning for IoT devices..."

TEMP_DIR="/tmp/iotscan_$$"
mkdir -p "$TEMP_DIR"
rm -f /tmp/iotscan_*
timeout "$DURATION" airodump-ng "$MON_IF" -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
sleep "$DURATION"
killall airodump-ng 2>/dev/null

SPINNER_STOP

if [ -f "$TEMP_DIR/scan-01.csv" ]; then
    while IFS=',' read -r BSSID F2 F3 CHANNEL F5 F6 F7 F8 F9 POWER F11 F12 F13 ESSID REST; do
        BSSID=$(echo "$BSSID" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
        ESSID=$(echo "$ESSID" | sed 's/^[[:space:]]*//')

        [[ ! "$BSSID" =~ ^[0-9A-Fa-f]{2}: ]] && continue

        OUI=$(echo "$BSSID" | cut -d':' -f1-3)
        DEVICE_TYPE=""

        # Check OUI - use exact prefix matching
        MATCH=$(echo "$IOT_OUIS" | grep -i "^$OUI" | head -1)
        if [ -n "$MATCH" ]; then
            DEVICE_TYPE=$(echo "$MATCH" | awk -F: '{print $4}')
        fi

        # Check SSID
        if [ -z "$DEVICE_TYPE" ] && [ -n "$ESSID" ] && echo "$ESSID" | grep -qiE "$IOT_SSIDS"; then
            DEVICE_TYPE="IoT_SSID_Match"
        fi

        if [ -n "$DEVICE_TYPE" ]; then
            echo "" >> "$LOOT_FILE"
            echo "IoT Device: $DEVICE_TYPE" >> "$LOOT_FILE"
            echo "  MAC: $BSSID" >> "$LOOT_FILE"
            echo "  SSID: $ESSID" >> "$LOOT_FILE"
            echo "  Channel: $(echo $CHANNEL | tr -d ' ')" >> "$LOOT_FILE"
            echo "  Signal: $(echo $POWER | tr -d ' ') dBm" >> "$LOOT_FILE"
            FOUND=$((FOUND + 1))
        fi
    done < "$TEMP_DIR/scan-01.csv"
fi

rm -rf "$TEMP_DIR"

PROMPT "IOT SCAN COMPLETE

IoT devices found: $FOUND

Results: $LOOT_FILE

Press OK to exit."
