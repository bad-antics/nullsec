#!/bin/bash
# Title: Beacon Spam
# Author: bad-antics
# Description: Flood area with fake WiFi networks
# Category: nullsec/chaos

LOOT_DIR="/mmc/nullsec/beaconspam"
mkdir -p "$LOOT_DIR"

PROMPT "BEACON SPAM

Flood the area with fake
WiFi network names.

Choose from themed lists
or enter custom SSIDs.

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!

Run: airmon-ng start wlan1"; exit 1; }

PROMPT "SELECT SSID THEME:

1. Funny Names
2. Scary/Warning
3. Tech Humor
4. Custom SSID List

Select on next screen."

THEME=$(NUMBER_PICKER "Theme (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) THEME=1 ;; esac

SSID_FILE="/tmp/beacon_ssids.txt"
rm -f "$SSID_FILE"

case $THEME in
    1)
        cat > "$SSID_FILE" << 'SSIDLIST'
FBI_Surveillance_Van
NSA_Mobile_Unit
Pretty_Fly_for_a_WiFi
Wu-Tang_LAN
Bill_Wi_the_Science_Fi
Drop_It_Like_Its_Hotspot
LAN_Solo
The_Promised_LAN
Loading...
Error_404_WiFi_Not_Found
Virus_Distribution_Center
Free_Virus_Download
DefinitelyNotAHacker
GetOffMyLAN
It_Hurts_When_IP
SSIDLIST
        ;;
    2)
        cat > "$SSID_FILE" << 'SSIDLIST'
POLICE_SURVEILLANCE
FBI_VAN_4827
DEA_MONITORING
IRS_AUDIT_UNIT
YOUR_FILES_ENCRYPTED
SYSTEM_COMPROMISED
MALWARE_DETECTED
SECURITY_BREACH
VIRUS_ALERT
DO_NOT_CONNECT
QUARANTINE_ZONE
SSIDLIST
        ;;
    3)
        cat > "$SSID_FILE" << 'SSIDLIST'
127.0.0.1
localhost
/dev/null
rm_-rf_slash
sudo_make_sandwich
DROP_TABLE_wifi
SELECT_*_FROM_users
Buffer_Overflow
Kernel_Panic
SEGFAULT
SSIDLIST
        ;;
    4)
        CUSTOM=$(TEXT_PICKER "Enter SSID name:" "NullSec_WiFi")
        echo "$CUSTOM" > "$SSID_FILE"
        ;;
esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START BEACON SPAM?

Theme: $THEME
Duration: ${DURATION}s
Interface: $MON_IF

Area will be flooded
with fake networks.

Press OK to start.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting beacon spam..."
LOG_FILE="$LOOT_DIR/spam_$(date +%Y%m%d_%H%M).log"

# Use mdk4 if available (proper beacon injection), otherwise mdk3
if command -v mdk4 >/dev/null 2>&1; then
    timeout "$DURATION" mdk4 "$MON_IF" b -f "$SSID_FILE" -s 100 2>&1 | tee "$LOG_FILE" &
elif command -v mdk3 >/dev/null 2>&1; then
    timeout "$DURATION" mdk3 "$MON_IF" b -f "$SSID_FILE" -s 100 2>&1 | tee "$LOG_FILE" &
else
    # Fallback: use aireplay-ng beacon frames per SSID
    END_TIME=$(($(date +%s) + DURATION))
    COUNT=0
    while [ $(date +%s) -lt $END_TIME ]; do
        while read SSID; do
            [ -z "$SSID" ] && continue
            [ $(date +%s) -ge $END_TIME ] && break
            CH=$(( (RANDOM % 11) + 1 ))
            iwconfig "$MON_IF" channel $CH 2>/dev/null
            # Send probe response which acts as beacon
            aireplay-ng -9 -e "$SSID" "$MON_IF" 2>/dev/null &
            sleep 0.3
            killall aireplay-ng 2>/dev/null
            COUNT=$((COUNT + 1))
            echo "$(date +%H:%M:%S) $SSID CH:$CH" >> "$LOG_FILE"
        done < "$SSID_FILE"
    done &
fi

BEACON_PID=$!
sleep "$DURATION"
kill $BEACON_PID 2>/dev/null
killall mdk4 mdk3 aireplay-ng 2>/dev/null

rm -f "$SSID_FILE"

PROMPT "BEACON SPAM COMPLETE

Duration: ${DURATION}s
Log: $LOG_FILE

Press OK to exit."
