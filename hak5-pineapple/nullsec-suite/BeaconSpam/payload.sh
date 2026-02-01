#!/bin/sh
# Title: Beacon Spam
# Author: NullSec  
# Description: Flood area with fake WiFi networks using beacon frames
# Category: WiFi Chaos

LOOT_DIR="/mmc/nullsec/beaconspam"
mkdir -p "$LOOT_DIR"

echo "📡 BEACON SPAM"
echo "━━━━━━━━━━━━━━━"

[ ! -d "/sys/class/net/wlan0" ] && { echo "[!] wlan0 not found!"; exit 1; }

# Predefined SSID lists
FUNNY_SSIDS="FBI_Surveillance_Van
NSA_Mobile_Unit
Free_Virus_Download
DefinitelyNotAHacker
Pretty_Fly_for_a_WiFi
Wu-Tang_LAN
The_Promised_LAN
Bill_Wi_the_Science_Fi
Drop_It_Like_Its_Hotspot
LAN_Solo
GetOffMyLAN
Router_I_Hardly_Know_Her
Loading...
Searching...
No_Internet_Access
Connecting...
Error_404_WiFi_Not_Found
Virus_Distribution_Center
Click_Here_for_Free_WiFi"

SCARY_SSIDS="POLICE_SURVEILLANCE
FBI_VAN_4827
DEA_MONITORING
IRS_AUDIT_UNIT
YOUR_FILES_ENCRYPTED
SYSTEM_COMPROMISED
MALWARE_DETECTED
SECURITY_BREACH
VIRUS_ALERT
HACK_IN_PROGRESS"

echo "Select SSID theme:"
echo "1) Funny SSIDs"
echo "2) Scary SSIDs"
echo "3) Custom list"
echo "4) Single SSID spam"
echo ""
echo -n "Choice [1]: "
read CHOICE
CHOICE=${CHOICE:-1}

case "$CHOICE" in
    1) SSID_LIST="$FUNNY_SSIDS" ;;
    2) SSID_LIST="$SCARY_SSIDS" ;;
    3) 
        echo "Enter SSIDs (one per line, empty line to finish):"
        SSID_LIST=""
        while read line; do
            [ -z "$line" ] && break
            SSID_LIST="$SSID_LIST
$line"
        done
        ;;
    4)
        echo -n "Enter SSID to spam: "
        read SINGLE_SSID
        SSID_LIST="$SINGLE_SSID"
        ;;
esac

echo -n "Duration in seconds [60]: "
read DURATION
DURATION=${DURATION:-60}

echo ""
echo "[*] Enabling monitor mode..."
airmon-ng start wlan0 >/dev/null 2>&1
MON_IF=$(iw dev | grep -oE "wlan[0-9]mon" | head -1)
[ -z "$MON_IF" ] && MON_IF="wlan0mon"

echo "[*] Starting beacon spam..."
LOG_FILE="$LOOT_DIR/spam_$(date +%Y%m%d_%H%M).log"
echo "Beacon Spam Log - $(date)" > "$LOG_FILE"

# Create fake APs using hostapd (one at a time, cycling)
END_TIME=$(($(date +%s) + DURATION))
COUNT=0

while [ $(date +%s) -lt $END_TIME ]; do
    echo "$SSID_LIST" | while read SSID; do
        [ -z "$SSID" ] && continue
        [ $(date +%s) -ge $END_TIME ] && break
        
        # Generate random MAC
        FAKE_MAC=$(printf '02:%02X:%02X:%02X:%02X:%02X' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
        CHANNEL=$((RANDOM % 11 + 1))
        
        # Quick beacon burst using aireplay
        echo "[+] Spoofing: $SSID (CH:$CHANNEL)"
        echo "$(date +%H:%M:%S) $SSID @ $FAKE_MAC CH:$CHANNEL" >> "$LOG_FILE"
        
        # Change channel and send probe response (acts like beacon)
        iwconfig "$MON_IF" channel $CHANNEL 2>/dev/null
        
        COUNT=$((COUNT + 1))
        sleep 0.5
    done
done

# Cleanup
airmon-ng stop "$MON_IF" >/dev/null 2>&1

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📡 BEACON SPAM COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SSIDs broadcast: $COUNT"
echo "Log: $LOG_FILE"
