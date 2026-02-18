#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# NullSec PXE Boot Server
# Installs Debian 13 on target server over direct Ethernet
# ═══════════════════════════════════════════════════════════════════
# Usage: sudo ./nullsec-pxe-server.sh [start|stop|status]
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Configuration ──
ETH_IFACE="${NULLSEC_ETH:-eth0}"          # Ethernet port (auto: set NULLSEC_ETH)
WIFI_IFACE="${NULLSEC_WIFI:-wlan0}"       # WiFi (for internet NAT to target)
PXE_SUBNET="10.0.0"          # PXE network subnet
PXE_SERVER_IP="10.0.0.1"     # Our IP on the Ethernet link
PXE_DHCP_START="10.0.0.100"  # DHCP range start
PXE_DHCP_END="10.0.0.200"    # DHCP range end
TFTP_ROOT="/tmp/tftpboot"    # TFTP root directory
DNSMASQ_PID="/tmp/nullsec-pxe-dnsmasq.pid"
DNSMASQ_LOG="/tmp/nullsec-pxe-dnsmasq.log"
WG_IFACE="${NULLSEC_WG:-wg0}"             # WireGuard VPN interface (if active)
VPN_DNS="${NULLSEC_VPN_DNS:-10.64.0.1}"   # VPN internal DNS

RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[1;33m'
CYN='\033[0;36m'
RST='\033[0m'

banner() {
    echo -e "${CYN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║     NullSec PXE Boot Server - Network Installer     ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${RST}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[!] Must run as root: sudo $0 $*${RST}"
        exit 1
    fi
}

check_prereqs() {
    local missing=0
    for cmd in dnsmasq ip iptables; do
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${RED}[!] Missing: $cmd${RST}"
            missing=1
        fi
    done
    if [[ ! -d "$TFTP_ROOT" ]]; then
        echo -e "${RED}[!] TFTP root not found: $TFTP_ROOT${RST}"
        echo -e "${YEL}    Run the setup first to download netboot files${RST}"
        missing=1
    fi
    if [[ ! -f "$TFTP_ROOT/debian-installer/amd64/bootnetx64.efi" ]]; then
        echo -e "${RED}[!] Missing UEFI netboot files in $TFTP_ROOT${RST}"
        missing=1
    fi
    if [[ ! -f "$TFTP_ROOT/debian-installer/amd64/initrd.gz" ]]; then
        echo -e "${RED}[!] Missing initrd.gz (with preseed) in $TFTP_ROOT${RST}"
        missing=1
    fi
    [[ $missing -eq 1 ]] && exit 1
    echo -e "${GRN}[✓] All prerequisites met${RST}"
}

check_cable() {
    echo -e "${YEL}[*] Checking Ethernet cable on $ETH_IFACE...${RST}"
    ip link set "$ETH_IFACE" up 2>/dev/null
    sleep 2
    local carrier
    carrier=$(cat "/sys/class/net/$ETH_IFACE/carrier" 2>/dev/null || echo "0")
    if [[ "$carrier" == "1" ]]; then
        echo -e "${GRN}[✓] Cable connected on $ETH_IFACE${RST}"
        return 0
    else
        echo -e "${RED}[!] No cable detected on $ETH_IFACE${RST}"
        echo -e "${YEL}    Plug an Ethernet cable between this machine and the target server${RST}"
        echo -e "${YEL}    Then run this script again${RST}"
        return 1
    fi
}

detect_vpn() {
    # Check if WireGuard VPN is active
    if ip link show "$WG_IFACE" &>/dev/null && [[ $(cat /sys/class/net/$WG_IFACE/operstate 2>/dev/null) == "unknown" || $(cat /sys/class/net/$WG_IFACE/carrier 2>/dev/null) == "1" ]]; then
        VPN_ACTIVE=1
        NAT_IFACE="$WG_IFACE"
        DNS_SERVERS="$VPN_DNS"
        echo -e "${CYN}[*] VPN detected — routing target traffic through VPN tunnel${RST}"
    else
        VPN_ACTIVE=0
        NAT_IFACE="$WIFI_IFACE"
        DNS_SERVERS="8.8.8.8,1.1.1.1"
        echo -e "${YEL}[*] No VPN detected — routing target traffic through WiFi${RST}"
    fi
}

start_server() {
    banner
    check_root
    check_prereqs

    echo -e "${YEL}[*] Setting up PXE boot server...${RST}"

    # ── Step 1: Configure Ethernet interface ──
    echo -e "${CYN}[1/5] Configuring $ETH_IFACE with IP $PXE_SERVER_IP/24${RST}"
    ip addr flush dev "$ETH_IFACE" 2>/dev/null
    ip link set "$ETH_IFACE" up
    ip addr add "$PXE_SERVER_IP/24" dev "$ETH_IFACE"
    sleep 1

    if ! check_cable; then
        echo -e "${YEL}[!] Continuing anyway - plug cable in before booting target${RST}"
    fi

    # ── Step 2: Detect VPN and enable NAT ──
    detect_vpn
    echo -e "${CYN}[2/5] Enabling NAT ($ETH_IFACE → $NAT_IFACE)${RST}"
    echo 1 > /proc/sys/net/ipv4/ip_forward

    # Clean up any old PXE NAT rules (both wifi and VPN)
    for iface in "$WIFI_IFACE" "$WG_IFACE"; do
        iptables -t nat -D POSTROUTING -s "${PXE_SUBNET}.0/24" -o "$iface" -j MASQUERADE 2>/dev/null || true
        iptables -D FORWARD -i "$ETH_IFACE" -o "$iface" -j ACCEPT 2>/dev/null || true
        iptables -D FORWARD -i "$iface" -o "$ETH_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    done
    # Also clean up old broad MASQUERADE rules from previous version
    iptables -t nat -D POSTROUTING -o "$WIFI_IFACE" -j MASQUERADE 2>/dev/null || true

    # Add NAT rules targeting the correct outbound interface
    iptables -t nat -A POSTROUTING -s "${PXE_SUBNET}.0/24" -o "$NAT_IFACE" -j MASQUERADE
    iptables -I FORWARD 1 -i "$ETH_IFACE" -o "$NAT_IFACE" -j ACCEPT
    iptables -I FORWARD 2 -i "$NAT_IFACE" -o "$ETH_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT

    # If VPN is active, add a policy route so target subnet traffic uses the VPN
    if [[ $VPN_ACTIVE -eq 1 ]]; then
        # Mark packets from the PXE subnet and route them through the VPN table
        local vpn_table
        vpn_table=$(ip rule list 2>/dev/null | grep -oP 'lookup \K[0-9]+' | grep -v '^0$\|^253$\|^254$\|^255$' | head -1)
        if [[ -n "$vpn_table" ]]; then
            ip rule del from "${PXE_SUBNET}.0/24" lookup "$vpn_table" 2>/dev/null || true
            ip rule add from "${PXE_SUBNET}.0/24" lookup "$vpn_table" prio 32000
            echo -e "${GRN}[✓] Policy route added — target traffic goes through VPN${RST}"
        fi
    fi

    echo -e "${GRN}[✓] NAT enabled — target internet via $NAT_IFACE${RST}"

    # ── Step 3: Kill any existing dnsmasq ──
    echo -e "${CYN}[3/5] Starting DHCP + TFTP server${RST}"
    if [[ -f "$DNSMASQ_PID" ]]; then
        kill "$(cat "$DNSMASQ_PID")" 2>/dev/null || true
        rm -f "$DNSMASQ_PID"
    fi
    # Kill any dnsmasq on our interface
    pkill -f "dnsmasq.*$ETH_IFACE" 2>/dev/null || true
    sleep 1

    # ── Step 4: Start dnsmasq (DHCP + TFTP + DNS) ──
    echo -e "${CYN}    DNS for target: $DNS_SERVERS${RST}"
    dnsmasq \
        --interface="$ETH_IFACE" \
        --bind-interfaces \
        --dhcp-range="${PXE_DHCP_START},${PXE_DHCP_END},255.255.255.0,1h" \
        --dhcp-option=option:router,"$PXE_SERVER_IP" \
        --dhcp-option=option:dns-server,"$DNS_SERVERS" \
        --dhcp-boot=debian-installer/amd64/bootnetx64.efi \
        --enable-tftp \
        --tftp-root="$TFTP_ROOT" \
        --tftp-secure \
        --log-queries \
        --log-dhcp \
        --log-facility="$DNSMASQ_LOG" \
        --pid-file="$DNSMASQ_PID" \
        --no-daemon \
        --port=0 \
        2>&1 &

    DNSMASQ_BGPID=$!
    echo "$DNSMASQ_BGPID" > "$DNSMASQ_PID"
    sleep 2

    # Verify it started
    if kill -0 "$DNSMASQ_BGPID" 2>/dev/null; then
        echo -e "${GRN}[✓] dnsmasq running (PID $DNSMASQ_BGPID)${RST}"
    else
        echo -e "${RED}[!] dnsmasq failed to start. Check $DNSMASQ_LOG${RST}"
        tail -20 "$DNSMASQ_LOG" 2>/dev/null
        exit 1
    fi

    # ── Step 5: Show status ──
    echo ""
    echo -e "${GRN}═══════════════════════════════════════════════════════${RST}"
    echo -e "${GRN}  PXE Boot Server is RUNNING${RST}"
    echo -e "${GRN}═══════════════════════════════════════════════════════${RST}"
    echo ""
    echo -e "  ${CYN}Interface:${RST}  $ETH_IFACE"
    echo -e "  ${CYN}Server IP:${RST}  $PXE_SERVER_IP"
    echo -e "  ${CYN}DHCP Pool:${RST}  $PXE_DHCP_START - $PXE_DHCP_END"
    echo -e "  ${CYN}TFTP Root:${RST}  $TFTP_ROOT"
    echo -e "  ${CYN}Boot File:${RST}  debian-installer/amd64/bootnetx64.efi"
    echo -e "  ${CYN}NAT:${RST}       $ETH_IFACE → $NAT_IFACE (internet)"
    if [[ $VPN_ACTIVE -eq 1 ]]; then
        echo -e "  ${CYN}VPN:${RST}       ${GRN}VPN active — target traffic is VPN-tunneled${RST}"
    fi
    echo -e "  ${CYN}DNS:${RST}       $DNS_SERVERS"
    echo -e "  ${CYN}Log:${RST}       $DNSMASQ_LOG"
    echo ""
    echo -e "${YEL}  ┌─────────────────────────────────────────────────┐${RST}"
    echo -e "${YEL}  │  ON THE TARGET SERVER:                          │${RST}"
    echo -e "${YEL}  │  1. Plug Ethernet between this machine & target  │${RST}"
    echo -e "${YEL}  │  2. Power on / reboot the target server           │${RST}"
    echo -e "${YEL}  │  3. Press F12 during POST for boot menu         │${RST}"
    echo -e "${YEL}  │  4. Select 'UEFI: Network / PXE'               │${RST}"
    echo -e "${YEL}  │  5. It auto-installs Debian 13 + NullSec config │${RST}"
    echo -e "${YEL}  │  6. After reboot, stop this server:             │${RST}"
    echo -e "${YEL}  │     sudo ./nullsec-pxe-server.sh stop           │${RST}"
    echo -e "${YEL}  └─────────────────────────────────────────────────┘${RST}"
    echo ""
    echo -e "${CYN}  Watching for PXE activity... (Ctrl+C to detach, server keeps running)${RST}"
    echo ""

    # Tail the log to show activity
    tail -f "$DNSMASQ_LOG" 2>/dev/null || true
}

stop_server() {
    banner
    check_root
    echo -e "${YEL}[*] Stopping PXE boot server...${RST}"

    # Kill dnsmasq
    if [[ -f "$DNSMASQ_PID" ]]; then
        kill "$(cat "$DNSMASQ_PID")" 2>/dev/null && echo -e "${GRN}[✓] dnsmasq stopped${RST}"
        rm -f "$DNSMASQ_PID"
    else
        pkill -f "dnsmasq.*$ETH_IFACE" 2>/dev/null && echo -e "${GRN}[✓] dnsmasq stopped${RST}" || echo -e "${YEL}[*] dnsmasq not running${RST}"
    fi

    # Remove NAT rules (clean up both VPN and WiFi paths)
    for iface in "$WIFI_IFACE" "$WG_IFACE"; do
        iptables -t nat -D POSTROUTING -s "${PXE_SUBNET}.0/24" -o "$iface" -j MASQUERADE 2>/dev/null || true
        iptables -D FORWARD -i "$ETH_IFACE" -o "$iface" -j ACCEPT 2>/dev/null || true
        iptables -D FORWARD -i "$iface" -o "$ETH_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    done
    # Clean up old broad MASQUERADE rules too
    iptables -t nat -D POSTROUTING -o "$WIFI_IFACE" -j MASQUERADE 2>/dev/null || true
    # Remove VPN policy route (try all known tables)
    for table_id in $(ip rule list 2>/dev/null | grep "from ${PXE_SUBNET}.0/24" | grep -oP 'lookup \K[0-9]+'); do
        ip rule del from "${PXE_SUBNET}.0/24" lookup "$table_id" 2>/dev/null || true
    done
    echo -e "${GRN}[✓] NAT rules removed${RST}"

    # Remove IP from Ethernet
    ip addr flush dev "$ETH_IFACE" 2>/dev/null
    echo -e "${GRN}[✓] $ETH_IFACE cleaned up${RST}"

    echo -e "${GRN}[✓] PXE server stopped${RST}"
}

show_status() {
    banner
    echo -e "${CYN}[*] PXE Server Status${RST}"
    echo ""

    # Check dnsmasq
    if [[ -f "$DNSMASQ_PID" ]] && kill -0 "$(cat "$DNSMASQ_PID")" 2>/dev/null; then
        echo -e "  ${GRN}● dnsmasq:${RST}    Running (PID $(cat "$DNSMASQ_PID"))"
    else
        echo -e "  ${RED}○ dnsmasq:${RST}    Not running"
    fi

    # Check interface
    local ip_addr
    ip_addr=$(ip addr show "$ETH_IFACE" 2>/dev/null | grep "inet " | awk '{print $2}')
    if [[ -n "$ip_addr" ]]; then
        echo -e "  ${GRN}● $ETH_IFACE:${RST} $ip_addr"
    else
        echo -e "  ${RED}○ $ETH_IFACE:${RST} No IP assigned"
    fi

    # Check cable
    local carrier
    carrier=$(cat "/sys/class/net/$ETH_IFACE/carrier" 2>/dev/null || echo "0")
    if [[ "$carrier" == "1" ]]; then
        echo -e "  ${GRN}● Cable:${RST}      Connected"
    else
        echo -e "  ${RED}○ Cable:${RST}      Not connected"
    fi

    # Check NAT and VPN
    if iptables -t nat -L POSTROUTING 2>/dev/null | grep -q MASQUERADE; then
        echo -e "  ${GRN}● NAT:${RST}        Enabled"
    else
        echo -e "  ${RED}○ NAT:${RST}        Disabled"
    fi
    if ip link show "$WG_IFACE" &>/dev/null && [[ $(cat /sys/class/net/$WG_IFACE/operstate 2>/dev/null) == "unknown" ]]; then
        echo -e "  ${GRN}● VPN:${RST}        VPN active — target traffic tunneled"
    else
        echo -e "  ${YEL}○ VPN:${RST}        Not active — target using direct WiFi"
    fi

    # Show recent DHCP activity
    if [[ -f "$DNSMASQ_LOG" ]]; then
        echo ""
        echo -e "${CYN}  Recent activity:${RST}"
        tail -10 "$DNSMASQ_LOG" 2>/dev/null | sed 's/^/    /'
    fi
}

# ── Main ──
case "${1:-start}" in
    start)  start_server ;;
    stop)   stop_server ;;
    status) show_status ;;
    *)
        echo "Usage: sudo $0 {start|stop|status}"
        exit 1
        ;;
esac
