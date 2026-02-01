#!/bin/bash
# Title: NullSec WiFi Audit
# Author: bad-antics
# Description: Comprehensive WiFi security assessment with reporting
# Category: nullsec

LOOT_DIR="/mmc/nullsec"
REPORT_DIR="$LOOT_DIR/reports"
mkdir -p "$REPORT_DIR" "$LOOT_DIR/logs"

# --- BRIEFING ---
PROMPT "NULLSEC WIFI AUDIT

Professional security
assessment toolkit:

- Network discovery
- Security analysis
- Vulnerability checks
- PDF-ready report

Press OK to configure."

# --- INTERFACE ---
ALL_IFS=$(ls /sys/class/net 2>/dev/null | grep -E "wlan|mon")
IFACE_LIST=""
count=1
for iface in $ALL_IFS; do
    IFACE_LIST="${IFACE_LIST}${count}: ${iface}
"
    count=$((count + 1))
done

LIST "SELECT INTERFACE

$IFACE_LIST" IFACE_SEL

IFACE=$(echo "$ALL_IFS" | sed -n "${IFACE_SEL}p")
[ -z "$IFACE" ] && IFACE="wlan1mon"

# --- AUDIT TYPE ---
LIST "AUDIT TYPE

1: Quick Assessment (2m)
2: Standard Audit (5m)
3: Deep Scan (15m)
4: Full Pentest (30m)" AUDIT_SEL

case $AUDIT_SEL in
    1) DURATION=120; DEPTH="quick" ;;
    2) DURATION=300; DEPTH="standard" ;;
    3) DURATION=900; DEPTH="deep" ;;
    4) DURATION=1800; DEPTH="full" ;;
    *) DURATION=300; DEPTH="standard" ;;
esac

# --- TARGET SCOPE ---
LIST "TARGET SCOPE

1: All Visible Networks
2: Specific SSID
3: Specific BSSID
4: Channel Range" SCOPE_SEL

case $SCOPE_SEL in
    2) KEYBOARD "TARGET SSID" 32 TARGET_SSID ;;
    3) KEYBOARD "TARGET BSSID" 17 TARGET_BSSID ;;
    4) KEYBOARD "CHANNELS (1,6,11)" 20 CHANNELS ;;
esac

# --- CLIENT INFO ---
KEYBOARD "CLIENT NAME" 20 CLIENT_NAME
[ -z "$CLIENT_NAME" ] && CLIENT_NAME="Anonymous"

# --- CONFIRMATION ---
PROMPT "AUDIT CONFIGURATION

Client: $CLIENT_NAME
Depth: $DEPTH
Duration: $((DURATION/60)) min
Scope: $SCOPE_SEL

Press OK to begin audit."

# --- INITIALIZE REPORT ---
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/audit_${CLIENT_NAME}_${TIMESTAMP}.txt"
JSON_FILE="$REPORT_DIR/audit_${CLIENT_NAME}_${TIMESTAMP}.json"

cat > "$REPORT_FILE" << EOF
================================================================================
                    NULLSEC WIRELESS SECURITY AUDIT REPORT
================================================================================

Client:         $CLIENT_NAME
Date:           $(date '+%Y-%m-%d %H:%M:%S')
Auditor:        NullSec Automated Audit System
Interface:      $IFACE
Audit Depth:    $DEPTH
Duration:       $((DURATION/60)) minutes

================================================================================
                              EXECUTIVE SUMMARY
================================================================================

EOF

# Initialize JSON
echo "{" > "$JSON_FILE"
echo "  \"client\": \"$CLIENT_NAME\"," >> "$JSON_FILE"
echo "  \"timestamp\": \"$(date -Iseconds)\"," >> "$JSON_FILE"
echo "  \"depth\": \"$DEPTH\"," >> "$JSON_FILE"
echo "  \"networks\": [" >> "$JSON_FILE"

# --- PHASE 1: DISCOVERY ---
SCREEN "PHASE 1/4" "Network Discovery..." 3
LED B SLOW

SCAN_TIME=$((DURATION / 4))
timeout $SCAN_TIME airodump-ng "$IFACE" -w /tmp/audit_scan --output-format csv 2>/dev/null &
sleep $SCAN_TIME
killall airodump-ng 2>/dev/null

# Parse networks
NETWORK_COUNT=0
OPEN_COUNT=0
WEP_COUNT=0
WPA_COUNT=0
WPA2_COUNT=0
WPA3_COUNT=0
HIDDEN_COUNT=0

echo "
================================================================================
                              NETWORK INVENTORY
================================================================================
" >> "$REPORT_FILE"

printf "%-18s %-25s %-8s %-6s %-10s\n" "BSSID" "ESSID" "CHANNEL" "POWER" "SECURITY" >> "$REPORT_FILE"
echo "--------------------------------------------------------------------------------" >> "$REPORT_FILE"

while IFS=',' read bssid first last channel speed privacy cipher auth power beacons iv lan id essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    essid=$(echo "$essid" | tr -d ' ' | head -c 24)
    channel=$(echo "$channel" | tr -d ' ')
    power=$(echo "$power" | tr -d ' ')
    privacy=$(echo "$privacy" | tr -d ' ')
    
    [[ ! "$bssid" =~ ^[0-9A-Fa-f] ]] && continue
    
    NETWORK_COUNT=$((NETWORK_COUNT + 1))
    
    # Determine security type
    SEC_LEVEL="UNKNOWN"
    VULN_LEVEL="LOW"
    
    case "$privacy" in
        *WPA3*) WPA3_COUNT=$((WPA3_COUNT + 1)); SEC_LEVEL="WPA3"; VULN_LEVEL="LOW" ;;
        *WPA2*) WPA2_COUNT=$((WPA2_COUNT + 1)); SEC_LEVEL="WPA2"; VULN_LEVEL="MEDIUM" ;;
        *WPA*) WPA_COUNT=$((WPA_COUNT + 1)); SEC_LEVEL="WPA"; VULN_LEVEL="HIGH" ;;
        *WEP*) WEP_COUNT=$((WEP_COUNT + 1)); SEC_LEVEL="WEP"; VULN_LEVEL="CRITICAL" ;;
        *OPN*|*) OPEN_COUNT=$((OPEN_COUNT + 1)); SEC_LEVEL="OPEN"; VULN_LEVEL="CRITICAL" ;;
    esac
    
    [ -z "$essid" ] && { essid="<HIDDEN>"; HIDDEN_COUNT=$((HIDDEN_COUNT + 1)); }
    
    printf "%-18s %-25s %-8s %-6s %-10s\n" "$bssid" "$essid" "$channel" "$power" "$SEC_LEVEL" >> "$REPORT_FILE"
    
    # Add to JSON
    [ $NETWORK_COUNT -gt 1 ] && echo "," >> "$JSON_FILE"
    cat >> "$JSON_FILE" << JSONNET
    {
      "bssid": "$bssid",
      "essid": "$essid",
      "channel": "$channel",
      "power": "$power",
      "security": "$SEC_LEVEL",
      "vulnerability": "$VULN_LEVEL"
    }
JSONNET
    
done < /tmp/audit_scan-01.csv

# --- PHASE 2: SECURITY ANALYSIS ---
SCREEN "PHASE 2/4" "Security Analysis..." 3
LED Y SLOW

# Calculate risk score
RISK_SCORE=0
[ $OPEN_COUNT -gt 0 ] && RISK_SCORE=$((RISK_SCORE + OPEN_COUNT * 30))
[ $WEP_COUNT -gt 0 ] && RISK_SCORE=$((RISK_SCORE + WEP_COUNT * 25))
[ $WPA_COUNT -gt 0 ] && RISK_SCORE=$((RISK_SCORE + WPA_COUNT * 15))
[ $WPA2_COUNT -gt 0 ] && RISK_SCORE=$((RISK_SCORE + WPA2_COUNT * 5))
[ $HIDDEN_COUNT -gt 0 ] && RISK_SCORE=$((RISK_SCORE + HIDDEN_COUNT * 2))

# Normalize score
[ $NETWORK_COUNT -gt 0 ] && RISK_SCORE=$((RISK_SCORE / NETWORK_COUNT))
[ $RISK_SCORE -gt 100 ] && RISK_SCORE=100

# Risk rating
if [ $RISK_SCORE -ge 70 ]; then RISK_RATING="CRITICAL"
elif [ $RISK_SCORE -ge 50 ]; then RISK_RATING="HIGH"
elif [ $RISK_SCORE -ge 30 ]; then RISK_RATING="MEDIUM"
else RISK_RATING="LOW"
fi

echo "
================================================================================
                              SECURITY ANALYSIS
================================================================================

NETWORK STATISTICS:
  Total Networks:     $NETWORK_COUNT
  Hidden Networks:    $HIDDEN_COUNT
  
SECURITY BREAKDOWN:
  Open Networks:      $OPEN_COUNT  (CRITICAL RISK)
  WEP Encrypted:      $WEP_COUNT   (CRITICAL RISK)
  WPA Encrypted:      $WPA_COUNT   (HIGH RISK)
  WPA2 Encrypted:     $WPA2_COUNT  (MEDIUM RISK)
  WPA3 Encrypted:     $WPA3_COUNT  (LOW RISK)

OVERALL RISK SCORE:   $RISK_SCORE/100 ($RISK_RATING)
" >> "$REPORT_FILE"

# --- PHASE 3: VULNERABILITY CHECK ---
SCREEN "PHASE 3/4" "Vulnerability Scan..." 3
LED M SLOW

echo "
================================================================================
                           VULNERABILITIES IDENTIFIED
================================================================================
" >> "$REPORT_FILE"

VULN_COUNT=0

if [ $OPEN_COUNT -gt 0 ]; then
    VULN_COUNT=$((VULN_COUNT + 1))
    cat >> "$REPORT_FILE" << EOF
[CRITICAL] OPEN NETWORKS DETECTED
  Count: $OPEN_COUNT
  Risk: Unencrypted traffic can be intercepted
  Recommendation: Implement WPA2/WPA3 encryption immediately
  
EOF
fi

if [ $WEP_COUNT -gt 0 ]; then
    VULN_COUNT=$((VULN_COUNT + 1))
    cat >> "$REPORT_FILE" << EOF
[CRITICAL] WEP ENCRYPTION IN USE
  Count: $WEP_COUNT
  Risk: WEP can be cracked in minutes
  Recommendation: Upgrade to WPA2/WPA3 immediately
  
EOF
fi

if [ $WPA_COUNT -gt 0 ]; then
    VULN_COUNT=$((VULN_COUNT + 1))
    cat >> "$REPORT_FILE" << EOF
[HIGH] WPA (TKIP) ENCRYPTION IN USE
  Count: $WPA_COUNT
  Risk: Vulnerable to TKIP attacks
  Recommendation: Upgrade to WPA2-AES or WPA3
  
EOF
fi

if [ $HIDDEN_COUNT -gt 0 ]; then
    VULN_COUNT=$((VULN_COUNT + 1))
    cat >> "$REPORT_FILE" << EOF
[LOW] HIDDEN SSID DETECTED
  Count: $HIDDEN_COUNT
  Risk: Security through obscurity - easily discovered
  Note: Hidden SSIDs provide no real security benefit
  
EOF
fi

# --- PHASE 4: RECOMMENDATIONS ---
SCREEN "PHASE 4/4" "Generating Report..." 3
LED G SLOW

echo "
================================================================================
                              RECOMMENDATIONS
================================================================================

IMMEDIATE ACTIONS:
" >> "$REPORT_FILE"

[ $OPEN_COUNT -gt 0 ] && echo "  [!] Secure all open networks with WPA2/WPA3" >> "$REPORT_FILE"
[ $WEP_COUNT -gt 0 ] && echo "  [!] Replace WEP with WPA2/WPA3 immediately" >> "$REPORT_FILE"
[ $WPA_COUNT -gt 0 ] && echo "  [!] Upgrade WPA-TKIP to WPA2-AES" >> "$REPORT_FILE"

echo "
SHORT-TERM ACTIONS:
  - Enable 802.1X authentication for enterprise networks
  - Implement network segmentation
  - Deploy wireless IDS/IPS
  
LONG-TERM ACTIONS:
  - Migrate to WPA3 where supported
  - Implement certificate-based authentication
  - Regular security assessments
" >> "$REPORT_FILE"

# Close JSON
echo "  ]," >> "$JSON_FILE"
echo "  \"risk_score\": $RISK_SCORE," >> "$JSON_FILE"
echo "  \"risk_rating\": \"$RISK_RATING\"," >> "$JSON_FILE"
echo "  \"vulnerabilities\": $VULN_COUNT" >> "$JSON_FILE"
echo "}" >> "$JSON_FILE"

# Final summary in report
echo "
================================================================================
                              AUDIT COMPLETE
================================================================================

Report Generated: $(date '+%Y-%m-%d %H:%M:%S')
Report Location:  $REPORT_FILE
JSON Export:      $JSON_FILE

                         NULLSEC SECURITY AUDIT SYSTEM
                              bad-antics // 2025
================================================================================
" >> "$REPORT_FILE"

# --- DISPLAY RESULTS ---
LED G SOLID

PROMPT "AUDIT COMPLETE

Networks Found: $NETWORK_COUNT
Risk Score: $RISK_SCORE/100
Rating: $RISK_RATING

Vulnerabilities: $VULN_COUNT
- Open: $OPEN_COUNT
- WEP: $WEP_COUNT
- WPA: $WPA_COUNT

Press OK for options."

LIST "REPORT OPTIONS

1: View Summary
2: View Full Report
3: Export to USB
4: Exit" OPT_SEL

case $OPT_SEL in
    1)
        PROMPT "AUDIT SUMMARY

Client: $CLIENT_NAME
Networks: $NETWORK_COUNT
Risk: $RISK_RATING ($RISK_SCORE/100)

Critical Issues:
Open: $OPEN_COUNT
WEP: $WEP_COUNT

Report: $REPORT_FILE"
        ;;
    2)
        # Show sections of report
        head -60 "$REPORT_FILE" | tail -40
        PROMPT "Showing report excerpt.

Full report saved to:
$REPORT_FILE"
        ;;
    3)
        if [ -d "/mmc/usb" ]; then
            cp "$REPORT_FILE" "$JSON_FILE" /mmc/usb/
            PROMPT "Reports exported to USB!"
        else
            PROMPT "No USB drive detected."
        fi
        ;;
esac

LED OFF
rm -f /tmp/audit_scan*
