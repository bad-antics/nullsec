#!/bin/bash
# Title:         WPS Auditor
# Description:   Scan for WPS-enabled networks and identify vulnerable configurations
# Author:        bad-antics
# Version:       1.0
# Category:      Reconnaissance
# Target:        WiFi Pineapple Pager
#
# LED State Descriptions
# SETUP     - Initializing scanner
# SPECIAL   - Scanning for WPS networks
# ATTACK    - WPS vulnerabilities found
# SUCCESS   - Scan complete
# FAIL      - No WPS networks / error
# CLEANUP   - Restoring interfaces
#
# Firmware:  Tested on firmware 1.0.4+

# ============================================================================
# CONFIGURATION
# ============================================================================
INTERFACE="wlan0"
LOOT_DIR="/root/loot/wps_auditor"
SCAN_DURATION=30

# Known vulnerable router OUIs (historically WPS-vulnerable chipsets)
VULN_OUIS="C8:3A:35:Tenda
00:0C:43:Ralink
D8:50:E6:ASUSTek
F8:32:E4:ASUSTek
1C:87:2C:ASUS
30:85:A9:ASUSTek
B0:6E:BF:TP-Link
C0:25:E9:TP-Link
14:CC:20:TP-Link
A0:F3:C1:TP-Link
F4:EC:38:TP-Link
08:86:3B:Belkin
EC:1A:59:Belkin
94:10:3E:Belkin
C8:D7:19:ZyXEL
00:A0:C5:ZyXEL
20:76:93:Huawei
B4:15:13:Huawei
AC:E2:15:Huawei
E0:19:1D:Huawei"

# ============================================================================
# CLEANUP TRAP
# ============================================================================
cleanup() {
    [ -n "$WASH_PID" ] && kill $WASH_PID 2>/dev/null
    airmon-ng stop "${INTERFACE}mon" 2>/dev/null
    airmon-ng stop "$INTERFACE" 2>/dev/null
    rm -f /tmp/wps_scan_$$
    LED CLEANUP
}
trap cleanup EXIT

# ============================================================================
# PAYLOAD START
# ============================================================================
LED SETUP

PROMPT "WPS AUDITOR v1.0

Scan for WiFi Protected
Setup (WPS) enabled
access points.

Identifies:
- WPS-enabled networks
- Lock status
- Vulnerable chipsets
- WPS version info

⚠ For authorized
auditing only.

Press OK to start."

DURATION=$(NUMBER_PICKER "Scan time (sec):" $SCAN_DURATION)
case $? in
    $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED)
        exit 0
        ;;
esac
[ -z "$DURATION" ] && DURATION=$SCAN_DURATION

# ============================================================================
# INITIALIZE
# ============================================================================
SPINNER_START "Preparing scanner..."

airmon-ng check kill 2>/dev/null
sleep 1
airmon-ng start "$INTERFACE" >/dev/null 2>&1
MON_IF="${INTERFACE}mon"
[ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

SPINNER_STOP

mkdir -p "$LOOT_DIR"
LOOT_FILE="$LOOT_DIR/wps_$(date +%Y%m%d_%H%M%S).txt"

{
    echo "════════════════════════════════════════"
    echo "  WPS AUDITOR - Scan Results"
    echo "════════════════════════════════════════"
    echo "Date:     $(date)"
    echo "Duration: ${DURATION}s"
    echo "════════════════════════════════════════"
    echo ""
} > "$LOOT_FILE"

# ============================================================================
# SCAN WITH WASH (if available) OR FALLBACK TO AIRODUMP
# ============================================================================
LED SPECIAL
WPS_COUNT=0
VULN_COUNT=0

if command -v wash >/dev/null 2>&1; then
    # Use wash for proper WPS scanning
    SPINNER_START "WPS scan with wash (${DURATION}s)..."

    timeout "$DURATION" wash -i "$MON_IF" -o /tmp/wps_scan_$$ 2>/dev/null &
    WASH_PID=$!
    sleep "$DURATION"
    kill $WASH_PID 2>/dev/null
    wait $WASH_PID 2>/dev/null

    SPINNER_STOP

    SPINNER_START "Analyzing results..."

    if [ -f /tmp/wps_scan_$$ ]; then
        # Parse wash output
        # Format: BSSID Channel RSSI WPS_Version WPS_Locked ESSID
        while read -r BSSID CHANNEL RSSI WPS_VER WPS_LOCKED ESSID; do
            # Skip header lines
            echo "$BSSID" | grep -qE "^[0-9A-Fa-f]{2}:" || continue

            WPS_COUNT=$((WPS_COUNT + 1))

            # Check vulnerability indicators
            OUI=$(echo "$BSSID" | tr '[:lower:]' '[:upper:]' | cut -d':' -f1-3)
            VULN_MATCH=$(echo "$VULN_OUIS" | grep -i "$OUI" | head -1 | cut -d':' -f4-)
            RISK="LOW"
            FLAGS=""

            if [ "$WPS_LOCKED" = "No" ]; then
                FLAGS="${FLAGS}WPS unlocked; "
                RISK="MEDIUM"
            fi

            if [ -n "$VULN_MATCH" ]; then
                FLAGS="${FLAGS}Known vulnerable vendor ($VULN_MATCH); "
                RISK="HIGH"
                VULN_COUNT=$((VULN_COUNT + 1))
            fi

            if [ "$WPS_VER" = "1.0" ]; then
                FLAGS="${FLAGS}WPS 1.0 (pixie-dust candidate); "
                if [ "$RISK" != "HIGH" ]; then RISK="HIGH"; fi
                VULN_COUNT=$((VULN_COUNT + 1))
            fi

            {
                echo "  ◆ $ESSID"
                echo "    BSSID:      $BSSID"
                echo "    Channel:    $CHANNEL"
                echo "    Signal:     $RSSI dBm"
                echo "    WPS Ver:    $WPS_VER"
                echo "    WPS Locked: $WPS_LOCKED"
                echo "    Risk:       $RISK"
                [ -n "$FLAGS" ] && echo "    Flags:      $FLAGS"
                echo ""
            } >> "$LOOT_FILE"
        done < /tmp/wps_scan_$$
    fi

    SPINNER_STOP
else
    # Fallback: use airodump + check for WPS
    SPINNER_START "Scanning (${DURATION}s)..."

    TEMP_DIR="/tmp/wps_airo_$$"
    mkdir -p "$TEMP_DIR"
    timeout "$DURATION" airodump-ng "$MON_IF" --wps -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
    SCAN_PID=$!
    sleep "$DURATION"
    kill $SCAN_PID 2>/dev/null
    wait $SCAN_PID 2>/dev/null

    SPINNER_STOP
    SPINNER_START "Analyzing..."

    if [ -f "$TEMP_DIR/scan-01.csv" ]; then
        while IFS=',' read -r BSSID F2 F3 CHANNEL F5 SPEED PRIVACY CIPHER AUTH POWER F11 F12 F13 ESSID REST; do
            BSSID=$(echo "$BSSID" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
            ESSID=$(echo "$ESSID" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [ -n "$BSSID" ] && echo "$BSSID" | grep -qE "^[0-9A-Fa-f]{2}:"; then
                OUI=$(echo "$BSSID" | cut -d':' -f1-3)
                VULN_MATCH=$(echo "$VULN_OUIS" | grep -i "$OUI" | head -1 | cut -d':' -f4-)

                # Check if WPS might be enabled (heuristic from airodump)
                if [ -n "$VULN_MATCH" ] || echo "$REST" | grep -qi "WPS"; then
                    WPS_COUNT=$((WPS_COUNT + 1))

                    RISK="LOW"
                    FLAGS=""
                    if [ -n "$VULN_MATCH" ]; then
                        FLAGS="Potentially vulnerable vendor ($VULN_MATCH)"
                        RISK="MEDIUM"
                        VULN_COUNT=$((VULN_COUNT + 1))
                    fi

                    {
                        echo "  ◆ $ESSID"
                        echo "    BSSID:      $BSSID"
                        echo "    Channel:    $(echo "$CHANNEL" | tr -d ' ')"
                        echo "    Signal:     $(echo "$POWER" | tr -d ' ') dBm"
                        echo "    Encryption: $(echo "$PRIVACY" | tr -d ' ')"
                        echo "    Risk:       $RISK"
                        [ -n "$FLAGS" ] && echo "    Flags:      $FLAGS"
                        echo ""
                    } >> "$LOOT_FILE"
                fi
            fi
        done < "$TEMP_DIR/scan-01.csv"
    fi

    rm -rf "$TEMP_DIR"
    SPINNER_STOP
fi

# ============================================================================
# RESULTS
# ============================================================================
{
    echo "════════════════════════════════════════"
    echo "  SCAN COMPLETE"
    echo "════════════════════════════════════════"
    echo "WPS-enabled APs:  $WPS_COUNT"
    echo "Vulnerable APs:   $VULN_COUNT"
    echo "════════════════════════════════════════"
} >> "$LOOT_FILE"

if [ "$VULN_COUNT" -gt 0 ]; then
    LED ATTACK
    PROMPT "WPS VULNERABILITIES!

WPS-enabled:   $WPS_COUNT
Vulnerable:    $VULN_COUNT

Vulnerable networks may
be susceptible to:
- Pixie Dust attack
- Brute force PIN
- Null PIN attack

Report: $LOOT_FILE

Press OK to exit."
elif [ "$WPS_COUNT" -gt 0 ]; then
    LED SUCCESS
    PROMPT "WPS NETWORKS FOUND

WPS-enabled: $WPS_COUNT
Vulnerable:  0

WPS enabled but no known
vulnerabilities detected.

Report: $LOOT_FILE

Press OK to exit."
else
    LED FAIL
    PROMPT "NO WPS NETWORKS

No WPS-enabled access
points detected in
${DURATION}s scan.

Press OK to exit."
fi

LOG "WPS Auditor complete. WPS: $WPS_COUNT Vulnerable: $VULN_COUNT"
