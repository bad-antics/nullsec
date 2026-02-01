#!/bin/sh
# NetworkMapper - Scan and map all networks
LOOT_DIR="/mmc/nullsec/networkmap"
mkdir -p "$LOOT_DIR"
LOG_FILE="$LOOT_DIR/map_$(date +%Y%m%d_%H%M%S).txt"

echo "[*] NetworkMapper - Scanning environment..."

# Enable monitor mode
airmon-ng start wlan1 2>/dev/null

# Scan for 60 seconds
echo "[*] Scanning all channels (60s)..."
timeout 60 airodump-ng wlan1mon --output-format csv -w "$LOOT_DIR/scan" 2>/dev/null

# Parse results
if [ -f "$LOOT_DIR/scan-01.csv" ]; then
    echo "=== NETWORKS FOUND ===" | tee "$LOG_FILE"
    grep -v "BSSID\|Station" "$LOOT_DIR/scan-01.csv" | grep -v "^$" | while read line; do
        BSSID=$(echo "$line" | cut -d',' -f1)
        CH=$(echo "$line" | cut -d',' -f4)
        ENC=$(echo "$line" | cut -d',' -f6)
        ESSID=$(echo "$line" | cut -d',' -f14)
        [ -n "$BSSID" ] && echo "$BSSID | Ch:$CH | $ENC | $ESSID" | tee -a "$LOG_FILE"
    done
fi
echo "[+] Map saved to $LOG_FILE"
