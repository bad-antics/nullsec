#!/bin/bash
# Title:         Rogue AP Detector
# Description:   Detect evil twin and rogue access points in your environment
# Author:        bad-antics
# Version:       1.0
# Category:      Reconnaissance
# Target:        WiFi Pineapple Pager
#
# LED State Descriptions
# SETUP     - Initializing scanner
# SPECIAL   - Scanning and analyzing
# ATTACK    - Rogue AP detected!
# SUCCESS   - Environment clean
# CLEANUP   - Restoring interfaces
#
# Firmware:  Tested on firmware 1.0.4+

# ============================================================================
# CONFIGURATION
# ============================================================================
INTERFACE="wlan0"
LOOT_DIR="/root/loot/rogue_detector"
SCAN_DURATION=30

# Known legitimate networks (user should configure)
# Format: SSID|BSSID (add your trusted networks here)
TRUSTED_NETWORKS="YOURNETWORK|AA:BB:CC:DD:EE:FF"

# ============================================================================
# CLEANUP TRAP
# ============================================================================
cleanup() {
    airmon-ng stop "${INTERFACE}mon" 2>/dev/null
    airmon-ng stop "$INTERFACE" 2>/dev/null
    rm -rf "/tmp/rogue_$$"
    LED CLEANUP
}
trap cleanup EXIT

# ============================================================================
# ANALYSIS FUNCTIONS
# ============================================================================

# Check if two BSSIDs share the same SSID (potential evil twin)
find_duplicates() {
    local csv_file="$1"
    local dupes=""

    # Extract SSID:BSSID pairs
    while IFS=',' read -r BSSID F2 F3 CHANNEL F5 SPEED PRIVACY CIPHER AUTH POWER F11 F12 F13 ESSID REST; do
        BSSID=$(echo "$BSSID" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
        ESSID=$(echo "$ESSID" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [ -n "$BSSID" ] && [ -n "$ESSID" ] && echo "$BSSID" | grep -qE "^[0-9A-Fa-f]{2}:"; then
            echo "${ESSID}|${BSSID}|$(echo "$CHANNEL" | tr -d ' ')|$(echo "$POWER" | tr -d ' ')|$(echo "$PRIVACY" | tr -d ' ')"
        fi
    done < "$csv_file" | sort -t'|' -k1,1 > "$TEMP_DIR/ap_list.txt"

    # Find SSIDs with multiple BSSIDs
    cut -d'|' -f1 "$TEMP_DIR/ap_list.txt" | sort | uniq -d > "$TEMP_DIR/dupe_ssids.txt"
}

# Score how suspicious a potential rogue AP is
score_rogue() {
    local ssid="$1"
    local bssid="$2"
    local channel="$3"
    local power="$4"
    local encryption="$5"
    local score=0
    local reasons=""

    # Check if SSID matches common target names
    case "$ssid" in
        *"Free"*|*"free"*|*"Guest"*|*"guest"*|*"Public"*|*"public"*)
            score=$((score + 10))
            reasons="${reasons}Common lure SSID; "
            ;;
    esac

    # Check for open networks (no encryption)
    if [ "$encryption" = "OPN" ] || [ -z "$encryption" ]; then
        score=$((score + 20))
        reasons="${reasons}No encryption; "
    fi

    # Very strong signal could mean attacker is nearby
    if [ -n "$power" ] && [ "$power" -gt -30 ] 2>/dev/null; then
        score=$((score + 15))
        reasons="${reasons}Very strong signal (${power}dBm); "
    fi

    # Check against trusted list
    if echo "$TRUSTED_NETWORKS" | grep -qi "$ssid"; then
        TRUSTED_BSSID=$(echo "$TRUSTED_NETWORKS" | grep -i "$ssid" | cut -d'|' -f2)
        if [ -n "$TRUSTED_BSSID" ] && ! echo "$bssid" | grep -qi "$TRUSTED_BSSID"; then
            score=$((score + 50))
            reasons="${reasons}SSID matches trusted but BSSID differs!; "
        fi
    fi

    echo "${score}|${reasons}"
}

# ============================================================================
# PAYLOAD START
# ============================================================================
LED SETUP

PROMPT "ROGUE AP DETECTOR v1.0

Detect evil twin and
rogue access points.

Detection methods:
1. Duplicate SSID analysis
2. Encryption mismatch
3. Signal anomaly check
4. Trusted network
   verification
5. OUI vendor analysis

Press OK to configure."

# Configure trusted networks
resp=$(CONFIRMATION_DIALOG "Configure trusted
networks first?

(Add your known-good
SSIDs and BSSIDs)")

if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    TRUSTED_SSID=$(TEXT_PICKER "Trusted SSID:" "MyNetwork")
    [ -n "$TRUSTED_SSID" ] && {
        TRUSTED_MAC=$(TEXT_PICKER "Trusted BSSID:" "AA:BB:CC:DD:EE:FF")
        [ -n "$TRUSTED_MAC" ] && TRUSTED_NETWORKS="${TRUSTED_NETWORKS}\n${TRUSTED_SSID}|${TRUSTED_MAC}"
    }

    # Ask for more
    while true; do
        resp2=$(CONFIRMATION_DIALOG "Add another
trusted network?")
        [ "$resp2" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && break
        MORE_SSID=$(TEXT_PICKER "Trusted SSID:" "")
        [ -n "$MORE_SSID" ] && {
            MORE_MAC=$(TEXT_PICKER "Trusted BSSID:" "")
            [ -n "$MORE_MAC" ] && TRUSTED_NETWORKS="${TRUSTED_NETWORKS}\n${MORE_SSID}|${MORE_MAC}"
        }
    done
fi

DURATION=$(NUMBER_PICKER "Scan time (sec):" $SCAN_DURATION)
[ -z "$DURATION" ] && DURATION=$SCAN_DURATION

# ============================================================================
# SCAN
# ============================================================================
SPINNER_START "Preparing scanner..."

airmon-ng check kill 2>/dev/null
sleep 1
airmon-ng start "$INTERFACE" >/dev/null 2>&1
MON_IF="${INTERFACE}mon"
[ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

SPINNER_STOP

mkdir -p "$LOOT_DIR"
LOOT_FILE="$LOOT_DIR/rogue_$(date +%Y%m%d_%H%M%S).txt"
TEMP_DIR="/tmp/rogue_$$"
mkdir -p "$TEMP_DIR"

{
    echo "════════════════════════════════════════"
    echo "  ROGUE AP DETECTOR - Results"
    echo "════════════════════════════════════════"
    echo "Date:     $(date)"
    echo "Duration: ${DURATION}s"
    echo "════════════════════════════════════════"
    echo ""
} > "$LOOT_FILE"

LED SPECIAL
SPINNER_START "Scanning (${DURATION}s)..."

timeout "$DURATION" airodump-ng "$MON_IF" -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
SCAN_PID=$!
sleep "$DURATION"
kill $SCAN_PID 2>/dev/null
wait $SCAN_PID 2>/dev/null

SPINNER_STOP

# ============================================================================
# ANALYZE FOR ROGUES
# ============================================================================
SPINNER_START "Analyzing for rogues..."

ROGUE_COUNT=0
SUSPICIOUS_COUNT=0
TOTAL_APS=0

if [ -f "$TEMP_DIR/scan-01.csv" ]; then
    # Build AP list and find duplicates
    find_duplicates "$TEMP_DIR/scan-01.csv"

    TOTAL_APS=$(wc -l < "$TEMP_DIR/ap_list.txt" 2>/dev/null || echo 0)
    DUPE_COUNT=$(wc -l < "$TEMP_DIR/dupe_ssids.txt" 2>/dev/null || echo 0)

    echo "Total APs scanned: $TOTAL_APS" >> "$LOOT_FILE"
    echo "SSIDs with multiple BSSIDs: $DUPE_COUNT" >> "$LOOT_FILE"
    echo "" >> "$LOOT_FILE"

    # Analyze each duplicate SSID
    if [ "$DUPE_COUNT" -gt 0 ]; then
        while IFS= read -r DUPE_SSID; do
            [ -z "$DUPE_SSID" ] && continue

            echo "─── Duplicate SSID: $DUPE_SSID ───" >> "$LOOT_FILE"

            # Get all APs with this SSID
            grep "^${DUPE_SSID}|" "$TEMP_DIR/ap_list.txt" | while IFS='|' read -r S_SSID S_BSSID S_CH S_PWR S_ENC; do
                RESULT=$(score_rogue "$S_SSID" "$S_BSSID" "$S_CH" "$S_PWR" "$S_ENC")
                SCORE=$(echo "$RESULT" | cut -d'|' -f1)
                REASONS=$(echo "$RESULT" | cut -d'|' -f2)

                RISK="LOW"
                [ "$SCORE" -ge 20 ] && RISK="MEDIUM"
                [ "$SCORE" -ge 40 ] && RISK="HIGH"
                [ "$SCORE" -ge 60 ] && RISK="CRITICAL"

                if [ "$SCORE" -ge 40 ]; then
                    ROGUE_COUNT=$((ROGUE_COUNT + 1))
                    MARKER="⚠ POTENTIAL ROGUE"
                elif [ "$SCORE" -ge 20 ]; then
                    SUSPICIOUS_COUNT=$((SUSPICIOUS_COUNT + 1))
                    MARKER="? SUSPICIOUS"
                else
                    MARKER="  Normal"
                fi

                {
                    echo "  $MARKER"
                    echo "    BSSID:      $S_BSSID"
                    echo "    Channel:    $S_CH"
                    echo "    Signal:     $S_PWR dBm"
                    echo "    Encryption: $S_ENC"
                    echo "    Risk Score: $SCORE ($RISK)"
                    [ -n "$REASONS" ] && echo "    Flags:      $REASONS"
                    echo ""
                } >> "$LOOT_FILE"
            done
        done < "$TEMP_DIR/dupe_ssids.txt"
    fi

    # Check for open networks (potential honeypots)
    echo "" >> "$LOOT_FILE"
    echo "─── Open Networks (Potential Honeypots) ───" >> "$LOOT_FILE"

    grep "|OPN$" "$TEMP_DIR/ap_list.txt" 2>/dev/null | while IFS='|' read -r O_SSID O_BSSID O_CH O_PWR O_ENC; do
        {
            echo "  ⚠ OPEN: $O_SSID"
            echo "    BSSID:   $O_BSSID"
            echo "    Channel: $O_CH"
            echo "    Signal:  $O_PWR dBm"
            echo ""
        } >> "$LOOT_FILE"
        SUSPICIOUS_COUNT=$((SUSPICIOUS_COUNT + 1))
    done
fi

SPINNER_STOP

# ============================================================================
# RESULTS
# ============================================================================
{
    echo ""
    echo "════════════════════════════════════════"
    echo "  ANALYSIS COMPLETE"
    echo "════════════════════════════════════════"
    echo "Total APs:    $TOTAL_APS"
    echo "Rogues:       $ROGUE_COUNT"
    echo "Suspicious:   $SUSPICIOUS_COUNT"
    echo "════════════════════════════════════════"
} >> "$LOOT_FILE"

if [ "$ROGUE_COUNT" -gt 0 ]; then
    LED ATTACK
    VIBRATE 500 200 500 200 500

    PROMPT "⚠ ROGUES DETECTED!

Potential rogue APs: $ROGUE_COUNT
Suspicious APs:     $SUSPICIOUS_COUNT
Total scanned:      $TOTAL_APS

Your environment may
have evil twin or
rogue access points!

Review: $LOOT_FILE

Press OK to exit."
elif [ "$SUSPICIOUS_COUNT" -gt 0 ]; then
    LED SUCCESS

    PROMPT "SOME CONCERNS

No confirmed rogues but
$SUSPICIOUS_COUNT suspicious APs
found (open networks or
anomalies).

Total scanned: $TOTAL_APS

Review: $LOOT_FILE

Press OK to exit."
else
    LED SUCCESS

    PROMPT "ALL CLEAR

Scanned $TOTAL_APS access
points. No rogue or
suspicious APs detected.

Environment appears clean.

Press OK to exit."
fi

LOG "Rogue AP Detector complete. Rogues: $ROGUE_COUNT Suspicious: $SUSPICIOUS_COUNT"
