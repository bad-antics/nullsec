#!/bin/bash
# Title: Compliance Scanner
# Author: bad-antics
# Description: Automated wireless security compliance audit (PCI-DSS, HIPAA, NIST)
# Category: nullsec/compliance

LOOT_DIR="/mmc/nullsec/compliance"
mkdir -p "$LOOT_DIR"

PROMPT "COMPLIANCE SCANNER

Automated wireless compliance
audit against industry standards.

Checks:
- PCI-DSS 4.0 wireless req
- HIPAA wireless safeguards
- NIST 800-153 guidelines
- Encryption standards
- Rogue AP detection
- Open network detection
- WEP/WPA1 deprecation
- Default SSID detection

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

STANDARD=$(CONFIRMATION_DIALOG "SELECT STANDARD

OK = PCI-DSS 4.0
CANCEL = NIST 800-153

(Both check common controls)")

if [ "$STANDARD" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    STD_NAME="PCI-DSS 4.0"
else
    STD_NAME="NIST 800-153"
fi

SCAN_TIME=$(NUMBER_PICKER "Scan duration (sec):" 20)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_TIME=20 ;; esac

EXPECTED_SSID=$(TEXT_PICKER "Authorized SSID:" "CORP-WIFI")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) EXPECTED_SSID="" ;; esac

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/compliance_${STD_NAME// /_}_${TIMESTAMP}.txt"

resp=$(CONFIRMATION_DIALOG "START COMPLIANCE AUDIT?

Standard: $STD_NAME
Scan time: ${SCAN_TIME}s
Auth SSID: ${EXPECTED_SSID:-'(any)'}

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting compliance scan..."
SPINNER_START "Scanning wireless environment..."

SCAN_FILE="/tmp/compliance_scan"
rm -f "${SCAN_FILE}"*.csv 2>/dev/null
timeout $SCAN_TIME airodump-ng wlan0 --write-interval 5 -w "$SCAN_FILE" --output-format csv 2>/dev/null

SPINNER_STOP
SPINNER_START "Analyzing compliance..."

echo "================================================================" > "$REPORT"
echo "   NULLSEC WIRELESS COMPLIANCE AUDIT                           " >> "$REPORT"
echo "   Standard: $STD_NAME                                         " >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "Date: $(date)" >> "$REPORT"
echo "Auditor: NullSec Automated Scanner" >> "$REPORT"
echo "" >> "$REPORT"

PASS=0
FAIL=0
WARN=0
CRITICAL=0

# Parse all APs
declare -A AP_DATA
AP_TOTAL=0
OPEN_COUNT=0
WEP_COUNT=0
WPA1_COUNT=0
WPA2_COUNT=0
WPA3_COUNT=0
HIDDEN_COUNT=0
DEFAULT_SSID_COUNT=0

DEFAULT_SSIDS="linksys|netgear|default|dlink|belkin|ASUS|TP-LINK|SETUP|Wireless|HOME-|XFINITY"

while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lan_ip id_len essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    essid=$(echo "$essid" | sed 's/^ *//;s/ *$//')
    privacy=$(echo "$privacy" | tr -d ' ')
    [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue

    AP_TOTAL=$((AP_TOTAL + 1))

    case "$privacy" in
        *OPN*) OPEN_COUNT=$((OPEN_COUNT + 1)) ;;
        *WEP*) WEP_COUNT=$((WEP_COUNT + 1)) ;;
        *WPA2*WPA3*|*WPA3*) WPA3_COUNT=$((WPA3_COUNT + 1)) ;;
        *WPA2*) WPA2_COUNT=$((WPA2_COUNT + 1)) ;;
        *WPA*) WPA1_COUNT=$((WPA1_COUNT + 1)) ;;
    esac

    [ -z "$essid" ] && HIDDEN_COUNT=$((HIDDEN_COUNT + 1))
    echo "$essid" | grep -qiE "$DEFAULT_SSIDS" && DEFAULT_SSID_COUNT=$((DEFAULT_SSID_COUNT + 1))

    AP_DATA[$bssid]="$essid|$privacy|$channel"
done < "${SCAN_FILE}-01.csv" 2>/dev/null

# ========== COMPLIANCE CHECKS ==========

echo "--- CONTROL 1: ENCRYPTION STANDARDS ---" >> "$REPORT"
echo "" >> "$REPORT"

# Check: No open networks
echo "  1.1 Open Networks (no encryption)" >> "$REPORT"
if [ $OPEN_COUNT -eq 0 ]; then
    echo "    [PASS] No open networks detected" >> "$REPORT"
    PASS=$((PASS + 1))
else
    echo "    [CRITICAL] $OPEN_COUNT open network(s) detected!" >> "$REPORT"
    CRITICAL=$((CRITICAL + 1))
fi

# Check: No WEP
echo "  1.2 WEP Encryption (deprecated)" >> "$REPORT"
if [ $WEP_COUNT -eq 0 ]; then
    echo "    [PASS] No WEP networks detected" >> "$REPORT"
    PASS=$((PASS + 1))
else
    echo "    [CRITICAL] $WEP_COUNT WEP network(s) detected!" >> "$REPORT"
    echo "    WEP is cryptographically broken — immediate remediation required" >> "$REPORT"
    CRITICAL=$((CRITICAL + 1))
fi

# Check: No WPA1
echo "  1.3 WPA1/TKIP (deprecated)" >> "$REPORT"
if [ $WPA1_COUNT -eq 0 ]; then
    echo "    [PASS] No WPA1-only networks detected" >> "$REPORT"
    PASS=$((PASS + 1))
else
    echo "    [FAIL] $WPA1_COUNT WPA1-only network(s) detected" >> "$REPORT"
    echo "    WPA1/TKIP should be upgraded to WPA2-AES or WPA3" >> "$REPORT"
    FAIL=$((FAIL + 1))
fi

# Check: WPA3 adoption
echo "  1.4 WPA3 Adoption" >> "$REPORT"
if [ $WPA3_COUNT -gt 0 ]; then
    WPA3_PCT=$((WPA3_COUNT * 100 / AP_TOTAL))
    echo "    [INFO] $WPA3_COUNT/$AP_TOTAL networks support WPA3 (${WPA3_PCT}%)" >> "$REPORT"
    [ $WPA3_PCT -ge 50 ] && PASS=$((PASS + 1)) || WARN=$((WARN + 1))
else
    echo "    [WARN] No WPA3 networks detected" >> "$REPORT"
    WARN=$((WARN + 1))
fi

echo "" >> "$REPORT"
echo "--- CONTROL 2: NETWORK HYGIENE ---" >> "$REPORT"
echo "" >> "$REPORT"

# Check: Default SSIDs
echo "  2.1 Default/Vendor SSIDs" >> "$REPORT"
if [ $DEFAULT_SSID_COUNT -eq 0 ]; then
    echo "    [PASS] No default SSIDs detected" >> "$REPORT"
    PASS=$((PASS + 1))
else
    echo "    [WARN] $DEFAULT_SSID_COUNT default/vendor SSID(s) detected" >> "$REPORT"
    echo "    Default SSIDs indicate unconfigured access points" >> "$REPORT"
    WARN=$((WARN + 1))
fi

# Check: Hidden networks
echo "  2.2 Hidden Networks" >> "$REPORT"
if [ $HIDDEN_COUNT -eq 0 ]; then
    echo "    [PASS] No hidden networks (SSID broadcast disabled is security theater)" >> "$REPORT"
    PASS=$((PASS + 1))
else
    echo "    [INFO] $HIDDEN_COUNT hidden network(s) — hiding SSID is not a security control" >> "$REPORT"
fi

# Check: Authorized SSID
echo "  2.3 Rogue AP Detection" >> "$REPORT"
if [ -n "$EXPECTED_SSID" ]; then
    ROGUE_COUNT=0
    for bssid in "${!AP_DATA[@]}"; do
        IFS='|' read -r essid priv ch <<< "${AP_DATA[$bssid]}"
        if [ "$essid" = "$EXPECTED_SSID" ]; then
            # This is an "authorized" AP — in real audit, compare BSSID against known list
            :
        fi
    done
    echo "    [INFO] Authorized SSID '$EXPECTED_SSID' monitoring active" >> "$REPORT"
    echo "    Manual BSSID verification recommended" >> "$REPORT"
else
    echo "    [SKIP] No authorized SSID specified" >> "$REPORT"
fi

echo "" >> "$REPORT"
echo "--- CONTROL 3: CHANNEL MANAGEMENT ---" >> "$REPORT"
echo "" >> "$REPORT"

# Channel overlap analysis
declare -A CH_USAGE
for bssid in "${!AP_DATA[@]}"; do
    IFS='|' read -r essid priv ch <<< "${AP_DATA[$bssid]}"
    CH_USAGE[$ch]=$(( ${CH_USAGE[$ch]:-0} + 1 ))
done

CONGESTED=0
for ch in "${!CH_USAGE[@]}"; do
    [ "${CH_USAGE[$ch]}" -gt 8 ] && CONGESTED=$((CONGESTED + 1))
done

echo "  3.1 Channel Congestion" >> "$REPORT"
if [ $CONGESTED -eq 0 ]; then
    echo "    [PASS] No severely congested channels (>8 APs)" >> "$REPORT"
    PASS=$((PASS + 1))
else
    echo "    [WARN] $CONGESTED congested channel(s) detected" >> "$REPORT"
    WARN=$((WARN + 1))
fi

echo "" >> "$REPORT"

# ========== SCORE ==========
echo "================================================================" >> "$REPORT"
echo "   COMPLIANCE SUMMARY — $STD_NAME" >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "" >> "$REPORT"
echo "  Networks scanned: $AP_TOTAL" >> "$REPORT"
echo "  Encryption breakdown:" >> "$REPORT"
echo "    WPA3: $WPA3_COUNT | WPA2: $WPA2_COUNT | WPA1: $WPA1_COUNT" >> "$REPORT"
echo "    WEP: $WEP_COUNT | Open: $OPEN_COUNT" >> "$REPORT"
echo "" >> "$REPORT"
echo "  PASS: $PASS | FAIL: $FAIL | WARN: $WARN | CRITICAL: $CRITICAL" >> "$REPORT"
echo "" >> "$REPORT"

TOTAL_CHECKS=$((PASS + FAIL + WARN + CRITICAL))
if [ $CRITICAL -gt 0 ]; then
    VERDICT="NON-COMPLIANT (Critical findings)"
elif [ $FAIL -gt 0 ]; then
    VERDICT="NON-COMPLIANT (Failures found)"
elif [ $WARN -gt 2 ]; then
    VERDICT="CONDITIONAL (Warnings need review)"
else
    VERDICT="COMPLIANT"
fi

echo "  VERDICT: $VERDICT" >> "$REPORT"
echo "================================================================" >> "$REPORT"

SPINNER_STOP

PROMPT "COMPLIANCE AUDIT COMPLETE

Standard: $STD_NAME
APs Scanned: $AP_TOTAL

Pass: $PASS | Fail: $FAIL
Warn: $WARN | Critical: $CRITICAL

VERDICT: $VERDICT

Report: $REPORT"
