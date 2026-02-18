#!/bin/bash
# Title: SSID Pranks
# Author: bad-antics
# Description: Broadcast funny WiFi names
# Category: nullsec/prank

LOOT_DIR="/mmc/nullsec/pranks"
mkdir -p "$LOOT_DIR"

PROMPT "SSID PRANKS

Broadcast funny or scary
WiFi network names that
show up on nearby devices.

Uses hostapd to create
real visible networks.

Press OK to configure."

PROMPT "PRANK CATEGORY:

1. Funny Names
2. Scary/Warning
3. Trolling Names
4. Tech Humor
5. Custom Message

Select on next screen."

CHOICE=$(NUMBER_PICKER "Category (1-5):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) CHOICE=1 ;; esac

SSID_FILE="/tmp/prank_ssids.txt"
case $CHOICE in
    1) printf "Pretty_Fly_For_A_WiFi\nWu_Tang_LAN\nBill_Wi_The_Science_Fi\nDrop_It_Like_Its_Hotspot\nLAN_Solo\nThe_Promised_LAN\nGetOffMyLAN\nIt_Hurts_When_IP\nLoading...\nError_404_WiFi_Not_Found" > "$SSID_FILE" ;;
    2) printf "FBI_Surveillance_Van_7\nNSA_Field_Unit\nPolice_Stakeout\nVIRUS_INFECTED\nYOUR_FILES_ENCRYPTED\nSYSTEM_COMPROMISED\nMALWARE_DETECTED\nDO_NOT_CONNECT\nQUARANTINE_ZONE" > "$SSID_FILE" ;;
    3) printf "Loading...\nSearching...\nConnecting...\nNo_Internet_Connection\nError_404_WiFi_Not_Found\nPlease_Wait...\nNetwork_Not_Found\nAccess_Denied\nHack_Me_If_You_Can" > "$SSID_FILE" ;;
    4) printf "127.0.0.1\nlocalhost\n/dev/null\nrm_-rf_slash\nDROP_TABLE_wifi\nSELECT_*_FROM_users\nBuffer_Overflow\nKernel_Panic\nSEGFAULT" > "$SSID_FILE" ;;
    5) CUSTOM=$(TEXT_PICKER "Enter SSID:" "NullSec_Was_Here")
       echo "$CUSTOM" > "$SSID_FILE" ;;
esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START SSID PRANKS?

Category: $CHOICE
Duration: ${DURATION}s

SSIDs will be visible
on all nearby devices.

Press OK to prank.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting SSID pranks..."
LOG_FILE="$LOOT_DIR/prank_$(date +%Y%m%d_%H%M).log"

# Use mdk4/mdk3 for proper beacon spam
if command -v mdk4 >/dev/null 2>&1; then
    timeout "$DURATION" mdk4 wlan1mon b -f "$SSID_FILE" -s 50 2>&1 | tee "$LOG_FILE" &
    wait $!
elif command -v mdk3 >/dev/null 2>&1; then
    timeout "$DURATION" mdk3 wlan1mon b -f "$SSID_FILE" -s 50 2>&1 | tee "$LOG_FILE" &
    wait $!
else
    # Fallback: hostapd rotation
    END_TIME=$(($(date +%s) + DURATION))
    COUNT=0
    while [ $(date +%s) -lt $END_TIME ]; do
        while read SSID; do
            [ -z "$SSID" ] && continue
            [ $(date +%s) -ge $END_TIME ] && break
            CH=$((RANDOM % 11 + 1))
            cat > /tmp/prank_ap.conf << APEOF
interface=wlan1
ssid=$SSID
channel=$CH
hw_mode=g
auth_algs=1
wpa=0
APEOF
            timeout 4 hostapd /tmp/prank_ap.conf 2>/dev/null &
            sleep 4
            killall hostapd 2>/dev/null
            COUNT=$((COUNT + 1))
            echo "$(date +%H:%M:%S) $SSID CH:$CH" >> "$LOG_FILE"
        done < "$SSID_FILE"
    done
fi

killall mdk4 mdk3 hostapd 2>/dev/null
rm -f "$SSID_FILE" /tmp/prank_ap.conf

PROMPT "PRANK COMPLETE

Duration: ${DURATION}s
Log: $LOG_FILE

Press OK to exit."
