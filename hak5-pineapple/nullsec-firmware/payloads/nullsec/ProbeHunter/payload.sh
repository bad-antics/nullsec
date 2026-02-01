#!/bin/bash
# Title: NullSec Probe Hunter
# Author: bad-antics
# Description: Collect WiFi probe requests to discover network names and device info
# Category: nullsec

LOOT_DIR="/mmc/nullsec"
mkdir -p "$LOOT_DIR"/{probes,logs}

# --- BRIEFING ---
PROMPT "NULLSEC PROBE HUNTER

Passive reconnaissance:
- Capture probe requests
- Identify target networks
- Track device movements
- Build SSID wordlists

100% passive - undetectable

Press OK to configure."

# --- INTERFACE ---
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

# --- CAPTURE MODE ---
LIST "CAPTURE MODE

1: Quick Sweep (1 min)
2: Standard (5 min)
3: Extended (15 min)
4: Stake Out (1 hour)
5: Continuous" MODE_SEL

case $MODE_SEL in
    1) DURATION=60 ;;
    2) DURATION=300 ;;
    3) DURATION=900 ;;
    4) DURATION=3600 ;;
    5) DURATION=0 ;;
    *) DURATION=300 ;;
esac

# --- CHANNEL HOPPING ---
LIST "CHANNEL MODE

1: Hop All Channels
2: 2.4GHz Only (1-11)
3: 5GHz Only
4: Fixed Channel" CHAN_SEL

if [ "$CHAN_SEL" = "4" ]; then
    LIST "SELECT CHANNEL

1: Channel 1
2: Channel 6
3: Channel 11
4: Custom" CH_SEL
    
    case $CH_SEL in
        1) CHANNEL=1 ;;
        2) CHANNEL=6 ;;
        3) CHANNEL=11 ;;
        4) KEYBOARD "CHANNEL (1-14)" 2 CHANNEL ;;
    esac
fi

# --- CONFIRMATION ---
PROMPT "PROBE HUNTER READY

Interface: $IFACE
Duration: $((DURATION/60)) min
Channels: $CHAN_SEL

Passive collection will
not alert targets.

Press OK to START."

# --- EXECUTE CAPTURE ---
SCREEN "HUNTING PROBES" "Listening passively..." 3
LED B SLOW

PROBE_FILE="$LOOT_DIR/probes/probes_$(date +%Y%m%d_%H%M%S).txt"
SSID_FILE="$LOOT_DIR/probes/ssids_$(date +%Y%m%d).txt"
DEVICE_FILE="$LOOT_DIR/probes/devices_$(date +%Y%m%d).txt"

PROBE_COUNT=0
UNIQUE_SSIDS=0
UNIQUE_DEVICES=0

# Channel hopping function
channel_hop() {
    case $CHAN_SEL in
        1) CHANNELS="1 2 3 4 5 6 7 8 9 10 11 36 40 44 48 52 56 60 64" ;;
        2) CHANNELS="1 2 3 4 5 6 7 8 9 10 11" ;;
        3) CHANNELS="36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 149 153 157 161 165" ;;
        4) CHANNELS="$CHANNEL"; return ;;
    esac
    
    while true; do
        for ch in $CHANNELS; do
            iwconfig "$IFACE" channel $ch 2>/dev/null
            sleep 0.5
        done
    done
}

# Start channel hopping in background
if [ "$CHAN_SEL" != "4" ]; then
    channel_hop &
    HOP_PID=$!
else
    iwconfig "$IFACE" channel "$CHANNEL" 2>/dev/null
fi

# Capture probes using tcpdump
capture_probes() {
    tcpdump -i "$IFACE" -e -l -s 256 type mgt subtype probe-req 2>/dev/null | \
    while read line; do
        # Extract MAC address
        MAC=$(echo "$line" | grep -oE "[0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5}" | head -1)
        
        # Extract SSID (probe request target)
        SSID=$(echo "$line" | grep -oE "Probe Request \([^)]*\)" | sed 's/Probe Request (//;s/)//')
        
        # Skip broadcast probes
        [ -z "$SSID" ] && continue
        
        TIMESTAMP=$(date '+%H:%M:%S')
        
        # Log full probe
        echo "[$TIMESTAMP] $MAC -> $SSID" >> "$PROBE_FILE"
        
        # Track unique SSIDs
        if ! grep -qF "$SSID" "$SSID_FILE" 2>/dev/null; then
            echo "$SSID" >> "$SSID_FILE"
        fi
        
        # Track unique devices
        if ! grep -qF "$MAC" "$DEVICE_FILE" 2>/dev/null; then
            echo "$MAC|$SSID|$TIMESTAMP" >> "$DEVICE_FILE"
        fi
        
        PROBE_COUNT=$((PROBE_COUNT + 1))
    done
}

# Run capture
if [ "$DURATION" -gt 0 ]; then
    timeout $DURATION sh -c "$(declare -f capture_probes); capture_probes" &
    CAPTURE_PID=$!
    
    # Monitor progress
    START_TIME=$(date +%s)
    while kill -0 $CAPTURE_PID 2>/dev/null; do
        ELAPSED=$(($(date +%s) - START_TIME))
        REMAINING=$((DURATION - ELAPSED))
        
        PROBE_COUNT=$(wc -l < "$PROBE_FILE" 2>/dev/null || echo 0)
        UNIQUE_SSIDS=$(wc -l < "$SSID_FILE" 2>/dev/null || echo 0)
        UNIQUE_DEVICES=$(wc -l < "$DEVICE_FILE" 2>/dev/null || echo 0)
        
        SCREEN "PROBE HUNTING" "Probes:$PROBE_COUNT SSIDs:$UNIQUE_SSIDS
Devices:$UNIQUE_DEVICES | ${REMAINING}s" 2
        
        # Flash LED on new captures
        if [ "$PROBE_COUNT" -gt 0 ]; then
            LED G FAST
            sleep 0.5
            LED B SLOW
        fi
        
        sleep 5
    done
else
    capture_probes &
    CAPTURE_PID=$!
    
    PROMPT "CAPTURE RUNNING

Probes being collected.
Press OK to stop."
    
    kill $CAPTURE_PID 2>/dev/null
fi

# Cleanup
[ -n "$HOP_PID" ] && kill $HOP_PID 2>/dev/null
killall tcpdump 2>/dev/null

# --- PROCESS RESULTS ---
SCREEN "PROCESSING..." "Analyzing data..." 2

# Final counts
PROBE_COUNT=$(wc -l < "$PROBE_FILE" 2>/dev/null || echo 0)
UNIQUE_SSIDS=$(sort -u "$SSID_FILE" 2>/dev/null | wc -l || echo 0)
UNIQUE_DEVICES=$(wc -l < "$DEVICE_FILE" 2>/dev/null || echo 0)

# Create sorted SSID list (by frequency)
if [ -f "$PROBE_FILE" ]; then
    grep -oE "-> .+$" "$PROBE_FILE" | sed 's/-> //' | sort | uniq -c | sort -rn > "$LOOT_DIR/probes/ssids_ranked_$(date +%Y%m%d).txt"
fi

# --- RESULTS ---
LED G SOLID

PROMPT "PROBE HUNT COMPLETE

Probes Captured: $PROBE_COUNT
Unique SSIDs: $UNIQUE_SSIDS
Unique Devices: $UNIQUE_DEVICES

Saved to:
$LOOT_DIR/probes/

Press OK for details."

# --- DETAILED VIEW ---
LIST "VIEW OPTIONS

1: Top SSIDs
2: Device List
3: Recent Probes
4: Build Wordlist
5: Exit" VIEW_SEL

case $VIEW_SEL in
    1)
        TOP_SSIDS=$(head -10 "$LOOT_DIR/probes/ssids_ranked_$(date +%Y%m%d).txt" 2>/dev/null)
        PROMPT "TOP 10 SSIDs:

$TOP_SSIDS"
        ;;
    2)
        DEVICES=$(head -10 "$DEVICE_FILE" 2>/dev/null | cut -d'|' -f1,2)
        PROMPT "DEVICES FOUND:

$DEVICES"
        ;;
    3)
        RECENT=$(tail -10 "$PROBE_FILE" 2>/dev/null)
        PROMPT "RECENT PROBES:

$RECENT"
        ;;
    4)
        # Build wordlist for cracking
        WORDLIST="$LOOT_DIR/probes/ssid_wordlist.txt"
        sort -u "$SSID_FILE" > "$WORDLIST"
        WL_COUNT=$(wc -l < "$WORDLIST")
        PROMPT "WORDLIST CREATED

$WORDLIST
$WL_COUNT unique SSIDs

Use for hashcat/aircrack
password attacks."
        ;;
esac

LED OFF
