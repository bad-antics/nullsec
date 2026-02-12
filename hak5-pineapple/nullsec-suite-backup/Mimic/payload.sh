#!/bin/sh
# MIMIC - MAC Identity Manipulation & Impersonation Controller
# Clone any device on the network

LOOT_DIR="/mmc/nullsec/mimic"
mkdir -p "$LOOT_DIR"

echo "╔╦╗╦╔╦╗╦╔═╗ - MAC Cloner"
echo "║║║║║║║║║  "
echo "╩ ╩╩╩ ╩╩╚═╝"

# Get target MAC
TARGET_MAC="$1"
INTERFACE="${2:-wlan0}"

if [ -z "$TARGET_MAC" ]; then
    echo "Usage: $0 <target_mac> [interface]"
    echo ""
    echo "Scan for targets first:"
    airodump-ng wlan1mon --output-format csv -w /tmp/mimic_scan 2>/dev/null &
    sleep 15
    killall airodump-ng 2>/dev/null
    echo "Recent devices:"
    grep -v "Station MAC" /tmp/mimic_scan-01.csv 2>/dev/null | cut -d',' -f1 | head -10
    exit 1
fi

# Save original MAC
ORIGINAL_MAC=$(cat /sys/class/net/$INTERFACE/address)
echo "[*] Original MAC: $ORIGINAL_MAC"
echo "[*] Target MAC: $TARGET_MAC"

# Clone MAC
echo "[*] Cloning MAC on $INTERFACE..."
ip link set $INTERFACE down
ip link set $INTERFACE address $TARGET_MAC
ip link set $INTERFACE up

NEW_MAC=$(cat /sys/class/net/$INTERFACE/address)
echo "[+] Now using: $NEW_MAC"
echo "$(date) - Cloned $TARGET_MAC on $INTERFACE (was $ORIGINAL_MAC)" >> "$LOOT_DIR/clone_log.txt"
