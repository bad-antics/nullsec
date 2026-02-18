#!/bin/bash
# Title: Infra Map
# Author: bad-antics
# Description: Network infrastructure mapping — topology, VLANs, routing, and trust relationships
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/inframap"
mkdir -p "$LOOT_DIR"

PROMPT "INFRA MAP

Network infrastructure
topology discovery.

Maps:
- Network topology
- VLAN boundaries
- Router/switch detection
- DHCP/DNS servers
- Trust relationships
- Gateway chains
- Firewall detection

Press OK to begin."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$LOOT_DIR/inframap_${TIMESTAMP}.txt"
IFACE=$(ip route | grep default | awk "{print \$5}" | head -1)
GATEWAY=$(ip route | grep default | awk "{print \$3}" | head -1)
SUBNET=$(ip -4 addr show "$IFACE" | grep -oP "(\d+\.){3}0/\d+" | head -1)
LOCAL_IP=$(ip -4 addr show "$IFACE" | grep -oP "(?<=inet\s)\d+(\.\d+){3}" | head -1)

resp=$(CONFIRMATION_DIALOG "MAP INFRASTRUCTURE?

Interface: $IFACE
Subnet: $SUBNET
Gateway: $GATEWAY

Full scan takes 5-10 min.
Press OK to start.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "InfraMap: subnet=$SUBNET"
SPINNER_START "Mapping infrastructure..."

cat > "$REPORT" << EOF
=======================================
 INFRASTRUCTURE MAP
 $(date)
 Scanner: $LOCAL_IP
=======================================

EOF

# Layer 1: Gateway analysis
echo "=== GATEWAY ===" >> "$REPORT"
echo "IP: $GATEWAY" >> "$REPORT"
traceroute -n -m 5 "$GATEWAY" 2>/dev/null >> "$REPORT"
nmap -sV -p 22,23,80,443,161 "$GATEWAY" 2>/dev/null | grep -E "open|Nmap" >> "$REPORT"

# Layer 2: Host discovery
echo "" >> "$REPORT"
echo "=== LIVE HOSTS ===" >> "$REPORT"
nmap -sn "$SUBNET" -oG - 2>/dev/null | grep "Up" | while read -r line; do
    IP=$(echo "$line" | grep -oP "(\d+\.){3}\d+")
    TTL=$(ping -c 1 -W 1 "$IP" 2>/dev/null | grep -oP "ttl=\K\d+")
    case "$TTL" in
        128|127) OS="Windows" ;;
        64|63)   OS="Linux/Mac" ;;
        255|254) OS="Network Device" ;;
        *)       OS="Unknown (TTL=$TTL)" ;;
    esac
    echo "  $IP | TTL=$TTL | $OS" >> "$REPORT"
done

# Layer 3: DHCP info
echo "" >> "$REPORT"
echo "=== DHCP ===" >> "$REPORT"
grep -r "dhcp\|DHCP" /var/log/ 2>/dev/null | tail -5 >> "$REPORT"
cat /var/lib/dhcp/dhclient.leases 2>/dev/null | grep -E "dhcp-server|domain-name|routers" >> "$REPORT"

# Layer 4: DNS infrastructure
echo "" >> "$REPORT"
echo "=== DNS ===" >> "$REPORT"
cat /etc/resolv.conf 2>/dev/null | grep nameserver >> "$REPORT"
nslookup -type=any "$GATEWAY" 2>/dev/null >> "$REPORT"

# Layer 5: Service landscape
echo "" >> "$REPORT"
echo "=== KEY SERVICES ===" >> "$REPORT"
nmap -sV "$SUBNET" --top-ports 20 -T4 -oG - 2>/dev/null | grep "open" | while read -r line; do
    echo "  $line" >> "$REPORT"
done

# Layer 6: SNMP discovery
echo "" >> "$REPORT"
echo "=== SNMP DEVICES ===" >> "$REPORT"
nmap -sU -p 161 "$SUBNET" --open -T4 2>/dev/null | grep -E "open|Nmap" >> "$REPORT"

# Layer 7: Firewall detection
echo "" >> "$REPORT"
echo "=== FIREWALL DETECTION ===" >> "$REPORT"
nmap -sA "$GATEWAY" --top-ports 20 2>/dev/null | grep -E "filtered|unfiltered" >> "$REPORT"

SPINNER_STOP

HOST_COUNT=$(grep -c "Host is up\|Up$" "$REPORT" 2>/dev/null)
SERVICE_COUNT=$(grep -c "open" "$REPORT" 2>/dev/null)

PROMPT "INFRA MAP COMPLETE

Hosts: $HOST_COUNT
Services: $SERVICE_COUNT
Gateway: $GATEWAY

Topology saved to:
inframap/

Press OK to exit."
