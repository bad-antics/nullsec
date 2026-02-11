# Network Setup

## Dual-Network Configuration

The WiFi Pineapple needs two network paths:
1. **Management** — Your connection to the Pineapple
2. **Internet** — Pineapple's upstream internet

### USB Ethernet + WiFi
```bash
# Run the dual-network script
./dual-network.sh

# This configures:
# - eth0: Management (172.16.42.0/24)
# - wlan0: Shared internet connection
```

### Internet Sharing (Linux)
```bash
# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# NAT masquerade
iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o wlan0 -j ACCEPT
iptables -A FORWARD -i wlan0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

### VPN Through Pineapple
```bash
# On Pineapple, install OpenVPN
opkg update && opkg install openvpn

# Copy VPN config
scp vpn.ovpn root@172.16.42.1:/etc/openvpn/

# Start VPN
ssh root@172.16.42.1 "openvpn --config /etc/openvpn/vpn.ovpn --daemon"
```

## Cloud C2 Integration

```bash
# Install C2 agent on Pineapple
./pineapple-c2.sh install

# Configure C2 connection
./pineapple-c2.sh configure --server c2.example.com --token YOUR_TOKEN

# Start C2 beacon
./pineapple-c2.sh start
```

## Troubleshooting Network

### No Internet on Pineapple
```bash
# Check DNS
ssh root@172.16.42.1 "ping -c 1 8.8.8.8"

# Fix DNS
ssh root@172.16.42.1 "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
```

### Can't SSH to Pineapple
```bash
# Check interface
ip addr show eth0
# Should show 172.16.42.x

# Try alternate IP
ssh root@172.16.42.1
ssh root@192.168.1.1
```
