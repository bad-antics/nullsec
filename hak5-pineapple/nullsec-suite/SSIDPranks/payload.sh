#!/bin/sh
# Title: SSID Pranks
# Author: NullSec
# Description: Broadcast funny/offensive WiFi names
# Category: WiFi Chaos/Prank

LOOT_DIR="/mmc/nullsec/pranks"
mkdir -p "$LOOT_DIR"

echo "😈 SSID PRANKS"
echo "━━━━━━━━━━━━━━"

[ ! -d "/sys/class/net/wlan0" ] && { echo "[!] wlan0 not found!"; exit 1; }

# Prank SSID categories
echo "Select prank category:"
echo "1) Funny names"
echo "2) Scary/Warning names"
echo "3) Trolling names"
echo "4) Tech humor"
echo "5) Custom message"
echo ""
echo -n "Choice [1]: "
read CHOICE
CHOICE=${CHOICE:-1}

case "$CHOICE" in
    1)
        SSIDS="Pretty_Fly_For_A_WiFi
WiFi_Art_Thou_Romeo
Bill_Wi_The_Science_Fi
The_LAN_Before_Time
Drop_It_Like_Its_Hotspot
Wu_Tang_LAN
LAN_Solo
Silence_of_the_LANs
The_Ping_in_the_North
It_Hurts_When_IP
Lord_of_the_Pings
Hogwarts_Great_Hall_WiFi
Nacho_WiFi"
        ;;
    2)
        SSIDS="FBI_Surveillance_Van_7
NSA_Field_Unit
Police_Stakeout
IRS_Audit_Mobile
VIRUS_INFECTED
MALWARE_DISTRIBUTION
YOUR_DATA_IS_OURS
SYSTEM_COMPROMISED
DO_NOT_CONNECT
QUARANTINE_ZONE"
        ;;
    3)
        SSIDS="Yell_PENIS_for_password
Hack_Me_If_You_Can
Loading...
Searching...
No_Internet_Connection
Error_404_WiFi_Not_Found
Connecting...
Please_Wait...
Network_Not_Found
Access_Denied"
        ;;
    4)
        SSIDS="127.0.0.1
localhost
/dev/null
rm_-rf_slash
sudo_rm_-rf
DROP_TABLE_wifi
SELECT_*_FROM_users
Buffer_Overflow
Stack_Smash_WiFi
Kernel_Panic"
        ;;
    5)
        echo "Enter your custom message (will be SSID):"
        read CUSTOM_MSG
        SSIDS="$CUSTOM_MSG"
        ;;
esac

echo -n "Duration in seconds [60]: "
read DURATION
DURATION=${DURATION:-60}

echo ""
echo "[*] Starting SSID prank broadcast..."
LOG_FILE="$LOOT_DIR/prank_$(date +%Y%m%d_%H%M).log"

# Use hostapd to create actual visible networks
END_TIME=$(($(date +%s) + DURATION))
COUNT=0

echo "$SSIDS" | while read SSID; do
    [ -z "$SSID" ] && continue
    [ $(date +%s) -ge $END_TIME ] && break
    
    CH=$((RANDOM % 11 + 1))
    
    echo "[+] Broadcasting: $SSID (CH:$CH)"
    echo "$(date +%H:%M:%S) $SSID CH:$CH" >> "$LOG_FILE"
    
    # Create temp hostapd config
    cat > /tmp/prank_ap.conf << APEOF
interface=wlan0
ssid=$SSID
channel=$CH
hw_mode=g
auth_algs=1
wpa=0
APEOF
    
    # Run briefly
    timeout 5 hostapd /tmp/prank_ap.conf 2>/dev/null &
    sleep 5
    killall hostapd 2>/dev/null
    
    COUNT=$((COUNT + 1))
done

rm -f /tmp/prank_ap.conf 2>/dev/null

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━"
echo "😈 PRANK COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━"
echo "SSIDs broadcast: $COUNT"
echo "Log: $LOG_FILE"
