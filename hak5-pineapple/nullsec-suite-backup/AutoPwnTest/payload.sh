#!/bin/sh
# Title: NullSec AutoPwn TEST MODE
# Author: bad-antics
# Description: Safe test mode for home network - NO DEAUTH, just monitoring
# Category: nullsec

LOOT_DIR="/mmc/nullsec"
mkdir -p "$LOOT_DIR"/{handshakes,logs,test}

PROMPT "NULLSEC AUTOPWN - TEST MODE

SAFE testing on home network:
- NO deauthentication
- Passive monitoring only
- Tests all functions
- Validates capture setup

Press OK to start test."

# Find monitor interface
MONITOR_IF=""
for iface in wlan1mon wlan2mon mon0; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done

if [ -z "$MONITOR_IF" ]; then
    # Try to enable
    for iface in wlan1 wlan2; do
        if [ -d "/sys/class/net/$iface" ]; then
            LOG "Enabling monitor on $iface..."
            airmon-ng start $iface 2>/dev/null
            sleep 2
            MONITOR_IF="${iface}mon"
            [ -d "/sys/class/net/$MONITOR_IF" ] && break
        fi
    done
fi

[ -z "$MONITOR_IF" ] && { ERROR_DIALOG "No monitor interface found!"; exit 1; }

LOG "Using: $MONITOR_IF"

# Enter home network SSID
HOME_SSID=$(TEXT_PICKER "Your home SSID:" "MyHomeWiFi")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 1 ;; esac

PROMPT "TEST MODE ACTIVE

Will scan for: $HOME_SSID
Duration: 30 seconds

NO packets will be sent!
This is passive only.

Press OK to scan."

# Scan for home network
LOG "Scanning for $HOME_SSID..."
SPINNER_START "Scanning for home network..."

rm -f /tmp/test_scan*
timeout 20 airodump-ng "$MONITOR_IF" -w /tmp/test_scan --output-format csv --essid "$HOME_SSID" 2>/dev/null &
sleep 20
killall airodump-ng 2>/dev/null

SPINNER_STOP

# Find target
TARGET_BSSID=""
TARGET_CHANNEL=""

while IFS=',' read -r bssid x1 x2 channel x3 x4 x5 x6 power x7 x8 x9 x10 essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
    
    essid_clean=$(echo "$essid" | tr -d ' ')
    if [ "$essid_clean" = "$HOME_SSID" ]; then
        TARGET_BSSID="$bssid"
        TARGET_CHANNEL=$(echo "$channel" | tr -d ' ')
        break
    fi
done < /tmp/test_scan-01.csv

if [ -z "$TARGET_BSSID" ]; then
    ERROR_DIALOG "Network not found: $HOME_SSID

Make sure:
- SSID is correct
- Network is in range
- Network is broadcasting"
    exit 1
fi

PROMPT "FOUND HOME NETWORK!

SSID: $HOME_SSID
BSSID: $TARGET_BSSID
Channel: $TARGET_CHANNEL

Press OK to start passive capture."

# Passive capture test
LOG "Starting passive capture test..."
CAPTURE_FILE="$LOOT_DIR/test/${HOME_SSID}_test_$(date +%Y%m%d_%H%M%S)"

iwconfig "$MONITOR_IF" channel "$TARGET_CHANNEL" 2>/dev/null

airodump-ng "$MONITOR_IF" --bssid "$TARGET_BSSID" -c "$TARGET_CHANNEL" \
    -w "$CAPTURE_FILE" --output-format pcap 2>/dev/null &
CAPTURE_PID=$!

LOG "Capturing for 30 seconds (passive)..."
sleep 30

kill $CAPTURE_PID 2>/dev/null
killall airodump-ng 2>/dev/null

# Check results
RESULT="FAILED"
PACKETS=0
HS_STATUS="Not captured (passive mode)"

if [ -f "${CAPTURE_FILE}-01.cap" ]; then
    PACKETS=$(tcpdump -r "${CAPTURE_FILE}-01.cap" 2>/dev/null | wc -l || echo 0)
    RESULT="SUCCESS"
    
    # Check for any handshakes (unlikely without deauth but possible)
    if aircrack-ng "${CAPTURE_FILE}-01.cap" 2>/dev/null | grep -q "1 handshake"; then
        HS_STATUS="CAPTURED! (lucky!)"
    fi
fi

PROMPT "TEST COMPLETE

Network: $HOME_SSID
Status: $RESULT
Packets: $PACKETS
Handshake: $HS_STATUS

Capture file:
${CAPTURE_FILE}-01.cap

In real attack mode, deauth
packets would force handshake.

Press OK to exit."

LOG "Test complete - $RESULT"
