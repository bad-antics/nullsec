#!/bin/bash
# Title:         Deauth Detector
# Description:   Detect WiFi deauthentication attacks in your area in real-time
# Author:        bad-antics
# Version:       1.0
# Category:      Reconnaissance
# Target:        WiFi Pineapple Pager
#
# LED State Descriptions
# SETUP     - Initializing monitor mode
# SPECIAL   - Monitoring for deauth frames
# ATTACK    - Deauth attack detected!
# SUCCESS   - Monitoring complete (clean)
# CLEANUP   - Restoring interfaces
#
# Firmware:  Tested on firmware 1.0.4+

# ============================================================================
# CONFIGURATION
# ============================================================================
INTERFACE="wlan0"
LOOT_DIR="/root/loot/deauth_detector"
ALERT_THRESHOLD=5          # Deauth frames before triggering alert
CHANNEL_HOP_DELAY=0.5      # Seconds per channel
MONITOR_DURATION=120       # Default monitoring time (seconds)

# ============================================================================
# CLEANUP TRAP
# ============================================================================
cleanup() {
    [ -n "$MONITOR_PID" ] && kill $MONITOR_PID 2>/dev/null
    [ -n "$HOP_PID" ] && kill $HOP_PID 2>/dev/null
    airmon-ng stop "${INTERFACE}mon" 2>/dev/null
    airmon-ng stop "$INTERFACE" 2>/dev/null
    rm -f /tmp/deauth_capture_$$ /tmp/deauth_count_$$
    LED CLEANUP
}
trap cleanup EXIT

# ============================================================================
# CHANNEL HOPPER
# ============================================================================
channel_hop() {
    local iface="$1"
    while true; do
        for ch in 1 2 3 4 5 6 7 8 9 10 11 36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 149 153 157 161 165; do
            iwconfig "$iface" channel $ch 2>/dev/null
            sleep "$CHANNEL_HOP_DELAY"
        done
    done
}

# ============================================================================
# PAYLOAD START
# ============================================================================
LED SETUP

PROMPT "DEAUTH DETECTOR v1.0

Defensive WiFi monitoring
payload that detects
deauthentication attacks
in real-time.

Monitors all channels for
deauth/disassoc frames
and alerts you when an
attack is happening.

Press OK to configure."

# Get monitoring duration
DURATION=$(NUMBER_PICKER "Monitor time (sec):" $MONITOR_DURATION)
case $? in
    $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED)
        LOG "Cancelled"
        exit 0
        ;;
esac
[ -z "$DURATION" ] && DURATION=$MONITOR_DURATION

# Get alert threshold
THRESHOLD=$(NUMBER_PICKER "Alert threshold:" $ALERT_THRESHOLD)
[ -z "$THRESHOLD" ] && THRESHOLD=$ALERT_THRESHOLD

# ============================================================================
# INITIALIZE MONITOR MODE
# ============================================================================
SPINNER_START "Preparing monitor mode..."

airmon-ng check kill 2>/dev/null
sleep 1
airmon-ng start "$INTERFACE" >/dev/null 2>&1
MON_IF="${INTERFACE}mon"
[ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

SPINNER_STOP

# ============================================================================
# PREPARE LOOT
# ============================================================================
mkdir -p "$LOOT_DIR"
LOOT_FILE="$LOOT_DIR/deauth_$(date +%Y%m%d_%H%M%S).txt"

{
    echo "════════════════════════════════════════"
    echo "  DEAUTH DETECTOR - Monitor Log"
    echo "════════════════════════════════════════"
    echo "Date:      $(date)"
    echo "Duration:  ${DURATION}s"
    echo "Threshold: ${THRESHOLD} frames"
    echo "Interface: $MON_IF"
    echo "════════════════════════════════════════"
    echo ""
} > "$LOOT_FILE"

# ============================================================================
# START MONITORING
# ============================================================================
LED SPECIAL
LOG "Monitoring for deauth attacks..."

# Start channel hopper in background
channel_hop "$MON_IF" &
HOP_PID=$!

TOTAL_DEAUTHS=0
TOTAL_DISASSOC=0
ATTACKS_DETECTED=0
ATTACK_SOURCES=""
START_TIME=$(date +%s)

echo 0 > /tmp/deauth_count_$$

# Monitor using tcpdump for deauth (subtype 0xc0) and disassoc (subtype 0xa0) frames
tcpdump -i "$MON_IF" -c 10000 -l 'subtype deauth or subtype disassoc' 2>/dev/null | \
while IFS= read -r line; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    # Check if we've exceeded duration
    if [ "$ELAPSED" -ge "$DURATION" ]; then
        break
    fi

    TIMESTAMP=$(date '+%H:%M:%S')

    # Extract source and destination from tcpdump output
    SRC=$(echo "$line" | grep -oE '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
    DST=$(echo "$line" | grep -oE '([0-9a-f]{2}:){5}[0-9a-f]{2}' | tail -1)
    CHAN=$(iwconfig "$MON_IF" 2>/dev/null | grep -oE 'Channel[=:][0-9]+' | grep -oE '[0-9]+')

    # Determine frame type
    if echo "$line" | grep -qi "deauth"; then
        FRAME_TYPE="DEAUTH"
        TOTAL_DEAUTHS=$((TOTAL_DEAUTHS + 1))
    else
        FRAME_TYPE="DISASSOC"
        TOTAL_DISASSOC=$((TOTAL_DISASSOC + 1))
    fi

    TOTAL=$((TOTAL_DEAUTHS + TOTAL_DISASSOC))
    echo "$TOTAL" > /tmp/deauth_count_$$

    # Log every frame
    echo "[$TIMESTAMP] $FRAME_TYPE  SRC=$SRC  DST=$DST  CH=$CHAN" >> "$LOOT_FILE"

    # Check if threshold crossed
    if [ "$TOTAL" -eq "$THRESHOLD" ]; then
        ATTACKS_DETECTED=$((ATTACKS_DETECTED + 1))

        # Vibrate and alert
        VIBRATE 500 200 500 200 500
        LED ATTACK

        ALERT "⚠ DEAUTH ATTACK!

$TOTAL frames detected
Source: $SRC
Channel: $CHAN

Attack in progress!"

        echo "" >> "$LOOT_FILE"
        echo "  ⚠ ATTACK ALERT TRIGGERED" >> "$LOOT_FILE"
        echo "  Primary source: $SRC" >> "$LOOT_FILE"
        echo "  Channel: $CHAN" >> "$LOOT_FILE"
        echo "" >> "$LOOT_FILE"

        ATTACK_SOURCES="${ATTACK_SOURCES}${SRC}\n"

        LED SPECIAL
    fi

    # Every 50 frames, update threshold check
    if [ $((TOTAL % 50)) -eq 0 ] && [ "$TOTAL" -gt "$THRESHOLD" ]; then
        VIBRATE 200 100 200
        ALERT "Ongoing attack: $TOTAL frames"
    fi
done &
MONITOR_PID=$!

# Wait for monitoring duration
SPINNER_START "Monitoring (${DURATION}s)..."
sleep "$DURATION"
SPINNER_STOP

# Kill monitoring processes
kill $MONITOR_PID 2>/dev/null
kill $HOP_PID 2>/dev/null
wait 2>/dev/null

# ============================================================================
# RESULTS
# ============================================================================
TOTAL_DEAUTHS=$(cat /tmp/deauth_count_$$ 2>/dev/null || echo 0)

{
    echo ""
    echo "════════════════════════════════════════"
    echo "  MONITORING COMPLETE"
    echo "════════════════════════════════════════"
    echo "Total deauth/disassoc frames: $TOTAL_DEAUTHS"
    echo "Alerts triggered: $ATTACKS_DETECTED"
    echo "════════════════════════════════════════"
} >> "$LOOT_FILE"

if [ "$TOTAL_DEAUTHS" -gt 0 ]; then
    LED ATTACK

    # Get unique attackers from log
    UNIQUE_SOURCES=$(grep "SRC=" "$LOOT_FILE" | grep -oE 'SRC=[0-9a-f:]+' | cut -d'=' -f2 | sort | uniq -c | sort -rn | head -5)

    PROMPT "MONITORING COMPLETE

Total frames: $TOTAL_DEAUTHS
Alerts: $ATTACKS_DETECTED

Top sources:
$UNIQUE_SOURCES

Deauth activity detected!
Your area may be under
WiFi attack.

Log: $LOOT_FILE

Press OK to exit."
else
    LED SUCCESS
    PROMPT "ALL CLEAR

Monitored for ${DURATION}s.
No deauth attacks detected.

Your WiFi environment
appears clean.

Press OK to exit."
fi

LOG "Deauth Detector complete. Frames: $TOTAL_DEAUTHS"
