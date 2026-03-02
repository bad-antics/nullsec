#!/bin/bash
# Title: Isolation Test
# Author: bad-antics
# Description: Test AP client isolation and network segmentation effectiveness
# Category: nullsec/compliance

LOOT_DIR="/mmc/nullsec/isolation"
mkdir -p "$LOOT_DIR"

PROMPT "ISOLATION TEST

Verify that AP client isolation
and network segmentation is
properly configured.

Tests:
- Client-to-client connectivity
- VLAN boundary integrity
- ARP visibility between clients
- Broadcast domain leaks
- Gateway spoofing potential
- DNS hijack susceptibility

Press OK to configure."

IFACE=$(TEXT_PICKER "Interface:" "br-lan")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) IFACE="br-lan" ;; esac

GATEWAY=$(TEXT_PICKER "Gateway IP:" "192.168.1.1")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) GATEWAY="192.168.1.1" ;; esac

SUBNET=$(TEXT_PICKER "Subnet (CIDR):" "192.168.1.0/24")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SUBNET="192.168.1.0/24" ;; esac

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/isolation_${TIMESTAMP}.txt"

resp=$(CONFIRMATION_DIALOG "START ISOLATION TEST?

Interface: $IFACE
Gateway: $GATEWAY
Subnet: $SUBNET

This tests if clients can
reach each other (they shouldn't
if isolation is enabled).

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting isolation test..."
SPINNER_START "Testing isolation..."

MY_IP=$(ip -4 addr show "$IFACE" | grep -oE 'inet [0-9.]+' | awk '{print $2}')

echo "================================================================" > "$REPORT"
echo "         NULLSEC ISOLATION TEST REPORT                         " >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "Time: $(date)" >> "$REPORT"
echo "Interface: $IFACE | IP: $MY_IP" >> "$REPORT"
echo "Gateway: $GATEWAY | Subnet: $SUBNET" >> "$REPORT"
echo "" >> "$REPORT"

PASS=0
FAIL=0
WARN=0

# Test 1: ARP scan to discover peers
echo "--- TEST 1: ARP DISCOVERY ---" >> "$REPORT"
echo "  Scanning for other clients on same segment..." >> "$REPORT"
PEER_COUNT=0
PEERS=""

# Quick ARP ping sweep
BASE=$(echo "$SUBNET" | cut -d'/' -f1 | cut -d'.' -f1-3)
for i in $(seq 1 254); do
    IP="${BASE}.${i}"
    [ "$IP" = "$MY_IP" ] && continue
    [ "$IP" = "$GATEWAY" ] && continue
    ping -c 1 -W 1 "$IP" > /dev/null 2>&1 &
done
wait

# Read ARP table
sleep 2
while read -r ip hw flags mac iface_arp; do
    [ "$ip" = "$MY_IP" ] && continue
    [ "$ip" = "$GATEWAY" ] && continue
    [[ "$mac" =~ ^([0-9a-fA-F]{2}:){5} ]] || continue
    PEERS="${PEERS}$ip ($mac)\n"
    PEER_COUNT=$((PEER_COUNT + 1))
done < <(arp -n -i "$IFACE" 2>/dev/null | tail -n +2)

if [ $PEER_COUNT -eq 0 ]; then
    echo "  PASS: No peer clients visible via ARP" >> "$REPORT"
    PASS=$((PASS + 1))
else
    echo "  FAIL: $PEER_COUNT peer clients visible!" >> "$REPORT"
    echo -e "$PEERS" | while read -r line; do
        [ -n "$line" ] && echo "    -> $line" >> "$REPORT"
    done
    FAIL=$((FAIL + 1))
fi
echo "" >> "$REPORT"

# Test 2: Ping gateway
echo "--- TEST 2: GATEWAY REACHABILITY ---" >> "$REPORT"
if ping -c 3 -W 2 "$GATEWAY" > /dev/null 2>&1; then
    GW_MS=$(ping -c 1 -W 2 "$GATEWAY" 2>/dev/null | grep -oE 'time=[0-9.]+' | cut -d= -f2)
    echo "  OK: Gateway reachable (${GW_MS}ms)" >> "$REPORT"
else
    echo "  WARN: Gateway not reachable" >> "$REPORT"
    WARN=$((WARN + 1))
fi
echo "" >> "$REPORT"

# Test 3: Peer connectivity
echo "--- TEST 3: PEER CONNECTIVITY ---" >> "$REPORT"
if [ $PEER_COUNT -gt 0 ]; then
    REACHABLE=0
    echo -e "$PEERS" | while read -r line; do
        [ -z "$line" ] && continue
        peer_ip=$(echo "$line" | awk '{print $1}')
        if ping -c 1 -W 1 "$peer_ip" > /dev/null 2>&1; then
            echo "  FAIL: Can ping $peer_ip" >> "$REPORT"
            REACHABLE=$((REACHABLE + 1))
        fi
    done
    [ $REACHABLE -gt 0 ] && FAIL=$((FAIL + 1)) || PASS=$((PASS + 1))
else
    echo "  PASS: No peers to test (isolation working)" >> "$REPORT"
    PASS=$((PASS + 1))
fi
echo "" >> "$REPORT"

# Test 4: ARP spoofing potential
echo "--- TEST 4: ARP SPOOF SUSCEPTIBILITY ---" >> "$REPORT"
GW_MAC=$(arp -n "$GATEWAY" 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}')
if [ -n "$GW_MAC" ]; then
    echo "  Gateway MAC: $GW_MAC" >> "$REPORT"
    # Check if gratuitous ARP is accepted (basic check)
    echo "  INFO: Gateway MAC visible - ARP spoofing possible if no DAI" >> "$REPORT"
    WARN=$((WARN + 1))
else
    echo "  PASS: Gateway MAC not in ARP table" >> "$REPORT"
    PASS=$((PASS + 1))
fi
echo "" >> "$REPORT"

# Test 5: Broadcast domain check
echo "--- TEST 5: BROADCAST DOMAIN ---" >> "$REPORT"
BCAST=$(ip -4 addr show "$IFACE" | grep -oE 'brd [0-9.]+' | awk '{print $2}')
if [ -n "$BCAST" ]; then
    BCAST_REPLIES=$(ping -c 1 -W 2 -b "$BCAST" 2>/dev/null | grep -c "bytes from" || echo 0)
    if [ "$BCAST_REPLIES" -gt 1 ]; then
        echo "  FAIL: $BCAST_REPLIES hosts responded to broadcast" >> "$REPORT"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: Broadcast responses limited" >> "$REPORT"
        PASS=$((PASS + 1))
    fi
else
    echo "  SKIP: Could not determine broadcast address" >> "$REPORT"
fi
echo "" >> "$REPORT"

# Test 6: DNS hijack check
echo "--- TEST 6: DNS INTEGRITY ---" >> "$REPORT"
DNS_SERVER=$(grep nameserver /etc/resolv.conf 2>/dev/null | head -1 | awk '{print $2}')
if [ -n "$DNS_SERVER" ]; then
    echo "  DNS Server: $DNS_SERVER" >> "$REPORT"
    # Resolve a well-known domain and check
    RESOLVED=$(nslookup google.com "$DNS_SERVER" 2>/dev/null | grep -A1 "Name:" | grep "Address" | awk '{print $2}')
    if [ -n "$RESOLVED" ]; then
        echo "  google.com -> $RESOLVED" >> "$REPORT"
        echo "  INFO: Verify this is a legitimate Google IP" >> "$REPORT"
    fi
else
    echo "  WARN: No DNS server configured" >> "$REPORT"
    WARN=$((WARN + 1))
fi
echo "" >> "$REPORT"

# Summary
TOTAL=$((PASS + FAIL + WARN))
echo "--- SUMMARY ---" >> "$REPORT"
echo "  PASS: $PASS | FAIL: $FAIL | WARN: $WARN" >> "$REPORT"
echo "" >> "$REPORT"

if [ $FAIL -eq 0 ]; then
    GRADE="A - Isolation appears effective"
elif [ $FAIL -eq 1 ]; then
    GRADE="C - Partial isolation (gaps found)"
else
    GRADE="F - Isolation is NOT working"
fi
echo "  GRADE: $GRADE" >> "$REPORT"
echo "================================================================" >> "$REPORT"

SPINNER_STOP

PROMPT "ISOLATION TEST COMPLETE

Pass: $PASS | Fail: $FAIL | Warn: $WARN
Peers visible: $PEER_COUNT
Grade: $GRADE

Report: $REPORT"
