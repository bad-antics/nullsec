#!/bin/bash
# Title: Net Inventory
# Author: bad-antics
# Description: Full network asset inventory and device discovery
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/inventory"
mkdir -p "$LOOT_DIR"

PROMPT "NET INVENTORY

Comprehensive network asset
discovery and inventory.

Discovers:
- All hosts on subnet
- Open ports & services
- OS fingerprinting
- Device types & vendors
- Hostnames & domains
- Network topology map

Press OK to configure."

# Interface selection
IFACE=$(TEXT_PICKER "Interface:" "br-lan")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) IFACE="br-lan" ;; esac

[ ! -d "/sys/class/net/$IFACE" ] && { ERROR_DIALOG "Interface $IFACE not found!"; exit 1; }

# Get network info
MY_IP=$(ip addr show "$IFACE" 2>/dev/null | grep -oP 'inet \K[0-9.]+/[0-9]+' | head -1)
SUBNET=$(echo "$MY_IP" | cut -d/ -f1 | awk -F. '{print $1"."$2"."$3".0/24"}')

[ -z "$MY_IP" ] && { ERROR_DIALOG "No IP on $IFACE!"; exit 1; }

CUSTOM_SUBNET=$(TEXT_PICKER "Subnet to scan:" "$SUBNET")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) CUSTOM_SUBNET="$SUBNET" ;; esac

# Scan depth
resp=$(CONFIRMATION_DIALOG "DEEP SCAN?

YES = Full port scan + OS detect
(slower, more thorough)

NO = Quick scan — top 100 ports
(faster, less detail)

Press OK for deep scan.")
if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    SCAN_DEPTH="deep"
else
    SCAN_DEPTH="quick"
fi

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/inventory_${TIMESTAMP}.txt"
CSV="$LOOT_DIR/inventory_${TIMESTAMP}.csv"

resp=$(CONFIRMATION_DIALOG "START INVENTORY SCAN?

Interface: $IFACE
Subnet: $CUSTOM_SUBNET
Depth: $SCAN_DEPTH

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Discovering hosts..."

echo "================================================================" > "$REPORT"
echo "          NULLSEC NET INVENTORY                                " >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "Time: $(date)" >> "$REPORT"
echo "Interface: $IFACE ($MY_IP)" >> "$REPORT"
echo "Subnet: $CUSTOM_SUBNET" >> "$REPORT"
echo "Scan depth: $SCAN_DEPTH" >> "$REPORT"
echo "" >> "$REPORT"

echo "IP,MAC,Vendor,Hostname,OS,Ports,Type" > "$CSV"

# Phase 1: Host Discovery
LOG "Phase 1: Host discovery..."
echo "--- PHASE 1: HOST DISCOVERY ---" >> "$REPORT"

HOSTS_FILE="/tmp/net_inv_hosts.txt"
> "$HOSTS_FILE"

# ARP scan
arp-scan -I "$IFACE" "$CUSTOM_SUBNET" 2>/dev/null | grep -E "^[0-9]" | while IFS=$'\t' read -r ip mac vendor; do
    echo "${ip}|${mac}|${vendor}" >> "$HOSTS_FILE"
done

# Also ping sweep for anything ARP missed
for i in $(seq 1 254); do
    BASE=$(echo "$CUSTOM_SUBNET" | cut -d/ -f1 | awk -F. '{print $1"."$2"."$3}')
    ping -c 1 -W 1 "${BASE}.${i}" > /dev/null 2>&1 &
done
wait 2>/dev/null

# Grab ARP table additions
arp -n -i "$IFACE" 2>/dev/null | grep -v "incomplete" | tail -n +2 | while read -r ip type mac flags iface; do
    [ -z "$mac" ] && continue
    grep -q "$ip|" "$HOSTS_FILE" 2>/dev/null || echo "${ip}|${mac}|unknown" >> "$HOSTS_FILE"
done

HOST_COUNT=$(wc -l < "$HOSTS_FILE" 2>/dev/null || echo 0)
echo "  Hosts discovered: $HOST_COUNT" >> "$REPORT"
echo "" >> "$REPORT"

# Phase 2: Service scan
LOG "Phase 2: Scanning services..."
SPINNER_START "Scanning $HOST_COUNT hosts..."
echo "--- PHASE 2: DEVICE INVENTORY ---" >> "$REPORT"

DEVICE_NUM=0
SERVERS=0
WORKSTATIONS=0
NETWORKING=0
IOT=0
MOBILE=0
UNKNOWN=0

while IFS='|' read -r ip mac vendor; do
    [ -z "$ip" ] && continue
    DEVICE_NUM=$((DEVICE_NUM + 1))

    LOG "Scanning $DEVICE_NUM/$HOST_COUNT: $ip"

    # Port scan
    if [ "$SCAN_DEPTH" = "deep" ]; then
        SCAN_RESULT=$(nmap -sS -sV -O --top-ports 1000 -T4 "$ip" 2>/dev/null)
    else
        SCAN_RESULT=$(nmap -sS --top-ports 100 -T4 "$ip" 2>/dev/null)
    fi

    # Extract open ports
    PORTS=$(echo "$SCAN_RESULT" | grep "^[0-9].*open" | awk '{print $1}' | tr '\n' ' ')
    PORT_LIST=$(echo "$PORTS" | tr ' ' ',' | sed 's/,$//')

    # Extract OS guess
    OS_GUESS=$(echo "$SCAN_RESULT" | grep "OS details:" | sed 's/OS details: //' | head -1)
    [ -z "$OS_GUESS" ] && OS_GUESS=$(echo "$SCAN_RESULT" | grep "Running:" | sed 's/Running: //' | head -1)
    [ -z "$OS_GUESS" ] && OS_GUESS="Unknown"

    # Resolve hostname
    HOSTNAME=$(nslookup "$ip" 2>/dev/null | grep "name = " | awk '{print $NF}' | sed 's/\.$//')
    [ -z "$HOSTNAME" ] && HOSTNAME=$(echo "$SCAN_RESULT" | grep "Nmap scan report" | grep -oP '\(.*\)' | tr -d '()')
    [ -z "$HOSTNAME" ] && HOSTNAME="-"

    # Classify device type
    DEVICE_TYPE="unknown"
    case "$PORTS" in
        *80*|*443*|*8080*)
            case "$PORTS" in
                *22*|*3306*|*5432*) DEVICE_TYPE="server"; SERVERS=$((SERVERS + 1)) ;;
                *) DEVICE_TYPE="webhost" ;;
            esac ;;
    esac
    case "$PORTS" in
        *3389*|*5900*|*5901*) DEVICE_TYPE="workstation"; WORKSTATIONS=$((WORKSTATIONS + 1)) ;;
    esac
    case "$PORTS" in
        *161*|*179*|*23*) DEVICE_TYPE="network"; NETWORKING=$((NETWORKING + 1)) ;;
    esac
    case "$vendor" in
        *Espressif*|*Tuya*|*Shenzhen*|*Sonoff*) DEVICE_TYPE="iot"; IOT=$((IOT + 1)) ;;
        *Apple*|*Samsung*|*OnePlus*|*Xiaomi*) DEVICE_TYPE="mobile"; MOBILE=$((MOBILE + 1)) ;;
    esac
    [ "$DEVICE_TYPE" = "unknown" ] && UNKNOWN=$((UNKNOWN + 1))

    # Write to report
    echo "  [$DEVICE_NUM] $ip" >> "$REPORT"
    echo "      MAC: $mac ($vendor)" >> "$REPORT"
    echo "      Hostname: $HOSTNAME" >> "$REPORT"
    echo "      OS: $OS_GUESS" >> "$REPORT"
    echo "      Ports: ${PORT_LIST:-none}" >> "$REPORT"
    echo "      Type: $DEVICE_TYPE" >> "$REPORT"
    echo "" >> "$REPORT"

    # Write CSV
    echo "\"$ip\",\"$mac\",\"$vendor\",\"$HOSTNAME\",\"$OS_GUESS\",\"$PORT_LIST\",\"$DEVICE_TYPE\"" >> "$CSV"

done < "$HOSTS_FILE"

# Summary
echo "--- INVENTORY SUMMARY ---" >> "$REPORT"
echo "  Total devices: $HOST_COUNT" >> "$REPORT"
echo "  Servers: $SERVERS" >> "$REPORT"
echo "  Workstations: $WORKSTATIONS" >> "$REPORT"
echo "  Network devices: $NETWORKING" >> "$REPORT"
echo "  IoT devices: $IOT" >> "$REPORT"
echo "  Mobile: $MOBILE" >> "$REPORT"
echo "  Unclassified: $UNKNOWN" >> "$REPORT"
echo "================================================================" >> "$REPORT"

# Cleanup
rm -f "$HOSTS_FILE"

SPINNER_STOP

PROMPT "INVENTORY COMPLETE

Subnet: $CUSTOM_SUBNET
Hosts: $HOST_COUNT

Breakdown:
  Servers: $SERVERS
  Workstations: $WORKSTATIONS
  Network: $NETWORKING
  IoT: $IOT
  Mobile: $MOBILE
  Other: $UNKNOWN

Report: $REPORT
CSV: $CSV"
