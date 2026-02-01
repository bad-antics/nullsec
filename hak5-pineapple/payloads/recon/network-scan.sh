#!/bin/bash
# NullSec Network Scanner Payload
# Scans and logs all nearby networks

OUTPUT="/tmp/nullsec_netscan_$(date +%s).txt"
IFACE="${1:-wlan1mon}"

echo "[*] NullSec Network Scanner" | tee $OUTPUT
echo "[*] Interface: $IFACE" | tee -a $OUTPUT
echo "[*] Timestamp: $(date)" | tee -a $OUTPUT
echo "================================" | tee -a $OUTPUT

# Quick scan
timeout 30 airodump-ng $IFACE -w /tmp/ns_scan --output-format csv 2>/dev/null &
sleep 35

if [[ -f /tmp/ns_scan-01.csv ]]; then
    cat /tmp/ns_scan-01.csv >> $OUTPUT
    echo "[+] Scan complete: $OUTPUT"
else
    echo "[-] Scan failed"
fi
