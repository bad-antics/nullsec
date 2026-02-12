#!/bin/bash
# Keep WiFi internet while USB connects to Pager
# Run this AFTER plugging in Pager via USB

PAGER_IF="usb0"  # or enx... - will auto-detect
WIFI_IF="wlo1"
PAGER_IP="172.16.52.1"
PAGER_SUBNET="172.16.52.0/24"
LOCAL_IP="172.16.52.42"

echo "Setting up dual network for Pineapple Pager..."

# Find USB interface (Hak5 devices use 00:13:37 OUI)
USB_IF=$(ip link | grep -E "usb|enx" | grep -v "enxe89c251ea5bd" | head -1 | cut -d: -f2 | tr -d ' ')
[ -z "$USB_IF" ] && USB_IF=$(ip link | grep "00:13:37" | head -1 | awk -F: '{print $2}' | tr -d ' ')
[ -z "$USB_IF" ] && { echo "No USB interface found. Plug in Pager first."; exit 1; }

# Auto-detect WiFi interface
[ ! -d "/sys/class/net/$WIFI_IF" ] && WIFI_IF=$(ip route | grep default | awk '{print $5}' | head -1)

echo "USB Interface: $USB_IF"
echo "WiFi Interface: $WIFI_IF"
echo "Pager IP: $PAGER_IP"

# Configure USB interface for Pager
sudo ip addr flush dev $USB_IF 2>/dev/null
sudo ip addr add ${LOCAL_IP}/24 dev $USB_IF 2>/dev/null
sudo ip link set $USB_IF up

# Add route to Pager only via USB
sudo ip route add $PAGER_SUBNET dev $USB_IF 2>/dev/null

# Make sure default route stays on WiFi
WIFI_GW=$(ip route | grep "default.*$WIFI_IF" | awk '{print $3}')
if [ -n "$WIFI_GW" ]; then
    sudo ip route del default 2>/dev/null
    sudo ip route add default via $WIFI_GW dev $WIFI_IF
fi

# Test connection
echo ""
if ping -c 1 -W 2 $PAGER_IP >/dev/null 2>&1; then
    echo "✓ Internet: via $WIFI_IF"
    echo "✓ Pager: via $USB_IF at $PAGER_IP"
    echo ""
    echo "SSH: ssh root@$PAGER_IP"
else
    echo "✗ Cannot reach Pager at $PAGER_IP"
    echo "  Check USB connection and try again"
fi
