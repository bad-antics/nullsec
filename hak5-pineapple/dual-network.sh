#!/bin/bash
# Keep WiFi internet while USB connects to Pager
# Run this AFTER plugging in Pager via USB

PAGER_IF="usb0"  # or enx... - will auto-detect
WIFI_IF="wlo1"

echo "Setting up dual network..."

# Find USB interface
USB_IF=$(ip link | grep -E "usb|enx" | grep -v "enxe89c251ea5bd" | head -1 | cut -d: -f2 | tr -d ' ')
[ -z "$USB_IF" ] && { echo "No USB interface found. Plug in Pager first."; exit 1; }

echo "USB Interface: $USB_IF"
echo "WiFi Interface: $WIFI_IF"

# Configure USB interface for Pager
sudo ip addr add 172.16.42.42/24 dev $USB_IF 2>/dev/null
sudo ip link set $USB_IF up

# Add route to Pager only via USB
sudo ip route add 172.16.42.0/24 dev $USB_IF 2>/dev/null

# Make sure default route stays on WiFi
WIFI_GW=$(ip route | grep "default.*$WIFI_IF" | awk '{print $3}')
if [ -n "$WIFI_GW" ]; then
    sudo ip route del default 2>/dev/null
    sudo ip route add default via $WIFI_GW dev $WIFI_IF
fi

echo ""
echo "✓ Internet: via $WIFI_IF"
echo "✓ Pager: via $USB_IF at 172.16.42.1"
echo ""
echo "Test: ping 172.16.42.1"
