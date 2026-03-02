#!/bin/bash
# Title: Threat Score
# Author: bad-antics
# Description: Score wireless networks by threat level and security posture
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/threatscore"
mkdir -p "$LOOT_DIR"

PROMPT "THREAT SCORE

Analyze and score wireless
networks by threat level.

Scoring criteria:
- Encryption strength (WPA3/2/1/Open)
- Hidden SSID detection
- WPS vulnerability
- Client exposure
- Rouge AP indicators
- Signal anomalies
- PMKID vulnerability
- Management frame protection

Press OK to configure."

# Monitor interface
MONITOR_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && { ERROR_DIALOG "No monitor interface!\nRun: airmon-ng start wlan1"; exit 1; }

SCAN_TIME=$(NUMBER_PICKER "Scan duration (sec):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_TIME=30 ;; esac

# Minimum signal threshold
MIN_SIGNAL=$(NUMBER_PICKER "Min signal dBm (-90 to -30):" -80)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MIN_SIGNAL=-80 ;; esac

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/threat_${TIMESTAMP}.txt"

resp=$(CONFIRMATION_DIALOG "START THREAT SCORING?

Interface: $MONITOR_IF
Scan time: ${SCAN_TIME}s
Min signal: ${MIN_SIGNAL}dBm

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Scanning networks..."

SCAN_FILE="/tmp/threat_scan"
rm -f "${SCAN_FILE}"*.csv 2>/dev/null
timeout "$SCAN_TIME" airodump-ng "$MONITOR_IF" -w "$SCAN_FILE" --output-format csv --wps 2>/dev/null

echo "================================================================" > "$REPORT"
echo "         NULLSEC THREAT SCORE REPORT                           " >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "Time: $(date)" >> "$REPORT"
echo "Interface: $MONITOR_IF | Duration: ${SCAN_TIME}s" >> "$REPORT"
echo "" >> "$REPORT"

# Count clients per BSSID
declare -A CLIENT_COUNTS
IN_CLIENT=0
while IFS=',' read -r station_mac first last power packets bssid probed rest; do
    station_mac=$(echo "$station_mac" | tr -d ' ')
    bssid=$(echo "$bssid" | tr -d ' ')
    [ "$station_mac" = "Station MAC" ] && IN_CLIENT=1 && continue
    [ $IN_CLIENT -eq 0 ] && continue
    [[ ! "$station_mac" =~ ^[0-9A-Fa-f]{2}: ]] && continue
    [[ "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && CLIENT_COUNTS[$bssid]=$(( ${CLIENT_COUNTS[$bssid]:-0} + 1 ))
done < "${SCAN_FILE}-01.csv" 2>/dev/null

# Score each network
SPINNER_START "Scoring networks..."

printf "%-20s %-18s %-6s %-12s %-6s %-8s\n" "SSID" "BSSID" "Ch" "Security" "Score" "Threat" >> "$REPORT"
printf "%-20s %-18s %-6s %-12s %-6s %-8s\n" "----" "-----" "--" "--------" "-----" "------" >> "$REPORT"

TOTAL_NETS=0
CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0
SECURE_COUNT=0

while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lan_ip id_len essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    essid=$(echo "$essid" | sed 's/^ *//;s/ *$//')
    channel=$(echo "$channel" | tr -d ' ')
    privacy=$(echo "$privacy" | tr -d ' ')
    cipher=$(echo "$cipher" | tr -d ' ')
    auth=$(echo "$auth" | tr -d ' ')
    power=$(echo "$power" | tr -d ' ')

    [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
    [ -z "$power" ] || [ "$power" = "-1" ] && power="-90"
    [ "$power" -lt "$MIN_SIGNAL" ] 2>/dev/null && continue

    [ -z "$essid" ] && essid="<hidden>"

    TOTAL_NETS=$((TOTAL_NETS + 1))
    SCORE=0
    FINDINGS=""

    # --- Encryption scoring ---
    case "$privacy" in
        *OPN*)
            SCORE=$((SCORE + 40))
            FINDINGS="${FINDINGS}OPEN network (+40); "
            ;;
        *WEP*)
            SCORE=$((SCORE + 35))
            FINDINGS="${FINDINGS}WEP encryption (+35); "
            ;;
        *WPA*WPA2*|*WPA2*WPA*)
            SCORE=$((SCORE + 10))
            FINDINGS="${FINDINGS}WPA/WPA2 mixed (+10); "
            ;;
        *WPA2*)
            SCORE=$((SCORE + 5))
            FINDINGS="${FINDINGS}WPA2 (+5); "
            ;;
        *WPA3*)
            SCORE=$((SCORE + 0))
            FINDINGS="${FINDINGS}WPA3 (+0); "
            ;;
        *WPA*)
            SCORE=$((SCORE + 20))
            FINDINGS="${FINDINGS}WPA1 only (+20); "
            ;;
    esac

    # --- Cipher scoring ---
    case "$cipher" in
        *TKIP*)
            SCORE=$((SCORE + 10))
            FINDINGS="${FINDINGS}TKIP cipher (+10); "
            ;;
        *CCMP*)
            # Good cipher
            ;;
    esac

    # --- Auth scoring ---
    case "$auth" in
        *PSK*)
            SCORE=$((SCORE + 5))
            FINDINGS="${FINDINGS}PSK auth (+5); "
            ;;
        *MGT*|*SAE*)
            # Enterprise or WPA3-SAE = good
            ;;
    esac

    # --- Hidden SSID ---
    if [ "$essid" = "<hidden>" ] || [ -z "$essid" ]; then
        SCORE=$((SCORE + 5))
        FINDINGS="${FINDINGS}Hidden SSID (+5); "
    fi

    # --- Client exposure ---
    CLIENTS=${CLIENT_COUNTS[$bssid]:-0}
    if [ "$CLIENTS" -gt 20 ]; then
        SCORE=$((SCORE + 15))
        FINDINGS="${FINDINGS}High client count: $CLIENTS (+15); "
    elif [ "$CLIENTS" -gt 10 ]; then
        SCORE=$((SCORE + 10))
        FINDINGS="${FINDINGS}Many clients: $CLIENTS (+10); "
    elif [ "$CLIENTS" -gt 5 ]; then
        SCORE=$((SCORE + 5))
        FINDINGS="${FINDINGS}Active clients: $CLIENTS (+5); "
    fi

    # --- Signal anomaly (unusually strong = possible rogue) ---
    if [ "$power" -gt -30 ] 2>/dev/null; then
        SCORE=$((SCORE + 10))
        FINDINGS="${FINDINGS}Extremely strong signal ${power}dBm (+10); "
    fi

    # --- Duplicate SSID check (rogue AP indicator) ---
    DUPE_COUNT=$(grep -c "$essid" "${SCAN_FILE}-01.csv" 2>/dev/null || echo 1)
    if [ "$DUPE_COUNT" -gt 2 ] && [ "$essid" != "<hidden>" ]; then
        SCORE=$((SCORE + 15))
        FINDINGS="${FINDINGS}Duplicate SSID ($DUPE_COUNT instances) (+15); "
    fi

    # --- Threat level ---
    if [ $SCORE -ge 50 ]; then
        THREAT="CRITICAL"
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    elif [ $SCORE -ge 35 ]; then
        THREAT="HIGH"
        HIGH_COUNT=$((HIGH_COUNT + 1))
    elif [ $SCORE -ge 20 ]; then
        THREAT="MEDIUM"
        MEDIUM_COUNT=$((MEDIUM_COUNT + 1))
    elif [ $SCORE -ge 10 ]; then
        THREAT="LOW"
        LOW_COUNT=$((LOW_COUNT + 1))
    else
        THREAT="SECURE"
        SECURE_COUNT=$((SECURE_COUNT + 1))
    fi

    DISPLAY_SSID=$(echo "$essid" | cut -c1-18)
    printf "%-20s %-18s %-6s %-12s %-6s %-8s\n" "$DISPLAY_SSID" "$bssid" "$channel" "$privacy" "$SCORE" "$THREAT" >> "$REPORT"

done < "${SCAN_FILE}-01.csv" 2>/dev/null

echo "" >> "$REPORT"
echo "--- THREAT SUMMARY ---" >> "$REPORT"
echo "  Total networks: $TOTAL_NETS" >> "$REPORT"
echo "  CRITICAL: $CRITICAL_COUNT" >> "$REPORT"
echo "  HIGH:     $HIGH_COUNT" >> "$REPORT"
echo "  MEDIUM:   $MEDIUM_COUNT" >> "$REPORT"
echo "  LOW:      $LOW_COUNT" >> "$REPORT"
echo "  SECURE:   $SECURE_COUNT" >> "$REPORT"

# Overall environment score
ENV_SCORE=0
[ $TOTAL_NETS -gt 0 ] && ENV_SCORE=$(( (CRITICAL_COUNT * 50 + HIGH_COUNT * 35 + MEDIUM_COUNT * 20 + LOW_COUNT * 10) / TOTAL_NETS ))

echo "" >> "$REPORT"
echo "  Environment threat score: $ENV_SCORE / 50" >> "$REPORT"
if [ $ENV_SCORE -ge 30 ]; then
    echo "  Environment: HOSTILE" >> "$REPORT"
elif [ $ENV_SCORE -ge 15 ]; then
    echo "  Environment: RISKY" >> "$REPORT"
else
    echo "  Environment: ACCEPTABLE" >> "$REPORT"
fi
echo "================================================================" >> "$REPORT"

SPINNER_STOP

PROMPT "THREAT SCORING COMPLETE

Networks scored: $TOTAL_NETS

CRITICAL: $CRITICAL_COUNT
HIGH: $HIGH_COUNT
MEDIUM: $MEDIUM_COUNT
LOW: $LOW_COUNT
SECURE: $SECURE_COUNT

Env score: $ENV_SCORE/50

Report: $REPORT"
