#!/bin/bash
#╔═══════════════════════════════════════════════════════════════════════════════╗
#║                                                                               ║
#║     ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗              ║
#║     ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝              ║
#║     ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║                   ║
#║     ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║                   ║
#║     ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗              ║
#║     ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝              ║
#║                                                                               ║
#║              NullSec Mesh Performance Optimizer v1.0                          ║
#║                     Developed by: bad-antics                                  ║
#║                                                                               ║
#╚═══════════════════════════════════════════════════════════════════════════════╝
#
#  Tunes batman-adv, kernel network stack, and interface parameters
#  for maximum mesh throughput and minimum latency.
#
#  Usage: sudo ./nullsec-mesh-optimize.sh [--aggressive]
#
#  What it does:
#    1. batman-adv: gateway bandwidth, hop penalty, orig interval, network coding
#    2. Interface:  MTU alignment, txqueuelen, qdisc (CAKE/fq_codel)
#    3. Kernel:     TCP buffers, conntrack, neighbor tables, GRO
#    4. Optional:   --aggressive mode for low-latency / max-throughput
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

BAT_IFACE="bat0"
MESH_IFACE="mesh0"
GRE_IFACE=$(ip link show 2>/dev/null | grep -oP '\S+(?=@NONE.*master bat0)' | head -1)
WIFI_IFACE="${NULLSEC_WIFI:-wlo1}"
AGGRESSIVE="${1:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}  [✓]${NC} $1"; }
warn() { echo -e "${YELLOW}  [!]${NC} $1"; }
err()  { echo -e "${RED}  [✗]${NC} $1"; }
info() { echo -e "${BLUE}  [i]${NC} $1"; }

# ═══════════════════════════════════════════════════════════════════════════════
# PRE-FLIGHT
# ═══════════════════════════════════════════════════════════════════════════════

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[!] Run as root: sudo $0${NC}"
    exit 1
fi

if ! ip link show "$BAT_IFACE" &>/dev/null; then
    echo -e "${RED}[!] bat0 not found — run nullsec-mesh-setup.sh first${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         NullSec Mesh Performance Optimizer                  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Detect GRE interface if not found
if [[ -z "$GRE_IFACE" ]]; then
    GRE_IFACE=$(batctl meshif bat0 interface 2>/dev/null | awk '{print $1}' | grep -v '^$' | head -1)
fi

info "bat0 interface:   ${BAT_IFACE}"
info "Transport iface:  ${GRE_IFACE:-unknown}"
info "WiFi interface:   ${WIFI_IFACE}"
[[ "$AGGRESSIVE" == "--aggressive" ]] && info "Mode: ${RED}AGGRESSIVE${NC} (low-latency / max-throughput)"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 1: BATMAN-ADV TUNING
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${PURPLE}━━━ Phase 1: batman-adv Protocol Tuning ━━━${NC}"

# --- Gateway Bandwidth ---
# Default is 10/2 MBit which is absurdly low.
# Announce actual capacity so mesh clients properly select this gateway.
BEFORE_GW=$(batctl meshif "$BAT_IFACE" gw_mode 2>/dev/null)
batctl meshif "$BAT_IFACE" gw_mode server 1000mbit/1000mbit 2>/dev/null || \
    batctl gw_mode server 1000mbit/1000mbit 2>/dev/null || true
AFTER_GW=$(batctl meshif "$BAT_IFACE" gw_mode 2>/dev/null)
log "Gateway bandwidth: ${BEFORE_GW} → ${AFTER_GW}"

# --- Hop Penalty ---
# Lower = prefer this node as gateway. Default 30, set to 15 for gateway.
BEFORE_HP=$(batctl meshif "$BAT_IFACE" hop_penalty 2>/dev/null)
batctl meshif "$BAT_IFACE" hop_penalty 15 2>/dev/null || batctl hop_penalty 15 2>/dev/null || true
log "Hop penalty: ${BEFORE_HP} → 15"

# --- Originator Interval ---
# How often this node announces itself (ms). Lower = faster convergence, more overhead.
# Default 1000ms. 500ms is good for small mesh; 250ms for aggressive.
if [[ "$AGGRESSIVE" == "--aggressive" ]]; then
    OI=250
else
    OI=500
fi
BEFORE_OI=$(batctl meshif "$BAT_IFACE" orig_interval 2>/dev/null)
batctl meshif "$BAT_IFACE" orig_interval "$OI" 2>/dev/null || batctl orig_interval "$OI" 2>/dev/null || true
log "Originator interval: ${BEFORE_OI}ms → ${OI}ms"

# --- Network Coding ---
# XOR-based coding: combine packets in multi-hop scenarios for throughput gain.
BEFORE_NC=$(batctl meshif "$BAT_IFACE" network_coding 2>/dev/null)
batctl meshif "$BAT_IFACE" network_coding 1 2>/dev/null || batctl nc 1 2>/dev/null || true
log "Network coding: ${BEFORE_NC} → enabled"

# --- Aggregation ---
# Combine multiple batman-adv OGMs into single frames to reduce overhead.
batctl meshif "$BAT_IFACE" aggregation 1 2>/dev/null || batctl ag 1 2>/dev/null || true
log "Aggregation: enabled ✓"

# --- Distributed ARP Table ---
# Cache ARP across mesh to avoid broadcast storms. Essential.
batctl meshif "$BAT_IFACE" distributed_arp_table 1 2>/dev/null || batctl dat 1 2>/dev/null || true
log "Distributed ARP table: enabled ✓"

# --- Bridge Loop Avoidance ---
batctl meshif "$BAT_IFACE" bridge_loop_avoidance 1 2>/dev/null || batctl bla 1 2>/dev/null || true
log "Bridge loop avoidance: enabled ✓"

# --- Fragmentation ---
# Allow large frames to be fragmented by batman-adv rather than dropped.
batctl meshif "$BAT_IFACE" fragmentation 1 2>/dev/null || batctl f 1 2>/dev/null || true
log "Fragmentation: enabled ✓"

# --- Multicast Fanout ---
# Max recipients for multicast before switching to broadcast. Higher = less broadcast.
if [[ "$AGGRESSIVE" == "--aggressive" ]]; then
    batctl meshif "$BAT_IFACE" multicast_fanout 32 2>/dev/null || true
    log "Multicast fanout: 32"
else
    batctl meshif "$BAT_IFACE" multicast_fanout 16 2>/dev/null || true
    log "Multicast fanout: 16"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 2: INTERFACE TUNING
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${PURPLE}━━━ Phase 2: Interface Tuning ━━━${NC}"

# --- txqueuelen ---
# Increase transmit queue length to prevent drops under load.
# Default 1000, bump to 5000 for throughput.
ip link set "$BAT_IFACE" txqueuelen 5000 2>/dev/null && \
    log "bat0 txqueuelen: 1000 → 5000" || warn "Could not set bat0 txqueuelen"

if [[ -n "$GRE_IFACE" ]]; then
    ip link set "$GRE_IFACE" txqueuelen 5000 2>/dev/null && \
        log "${GRE_IFACE} txqueuelen: → 5000" || true
fi

# --- MTU Alignment ---
# GRE adds 24-byte header. batman-adv adds ~28 bytes overhead.
# Optimal: GRE tunnel MTU should leave room for batman-adv encapsulation.
# With GRE MTU 1462, bat0 effective payload is ~1434.
# Raising GRE to 1500 and letting path MTU discovery handle it is better
# than fragmenting inside batman-adv.
if [[ -n "$GRE_IFACE" ]]; then
    CURRENT_GRE_MTU=$(cat /sys/class/net/"$GRE_IFACE"/mtu 2>/dev/null || echo "unknown")
    # For GRE over Ethernet (1500), max GRE payload = 1500 - 24(GRE) = 1476
    # batman-adv overhead = ~28, so effective bat0 MTU = 1476 - 28 = 1448
    # Set GRE MTU to 1476 to avoid double fragmentation
    ip link set "$GRE_IFACE" mtu 1476 2>/dev/null && \
        log "${GRE_IFACE} MTU: ${CURRENT_GRE_MTU} → 1476 (aligned for batman-adv overhead)" || \
        warn "Could not adjust ${GRE_IFACE} MTU"
fi

# --- qdisc ---
# Use CAKE (if available) or fq_codel for smart queuing on the mesh interfaces.
# CAKE is superior for shaped links; fq_codel is great general-purpose.
QDISC_CHOICE=""
if tc qdisc replace dev "$BAT_IFACE" root cake bandwidth 1gbit 2>/dev/null; then
    QDISC_CHOICE="cake"
    log "bat0 qdisc: cake (bandwidth 1gbit)"
elif tc qdisc replace dev "$BAT_IFACE" root fq_codel 2>/dev/null; then
    QDISC_CHOICE="fq_codel"
    log "bat0 qdisc: fq_codel"
else
    warn "Could not set qdisc on bat0 (current qdisc may be fine)"
fi

# Apply same to transport interface
if [[ -n "$GRE_IFACE" && -n "$QDISC_CHOICE" ]]; then
    if [[ "$QDISC_CHOICE" == "cake" ]]; then
        tc qdisc replace dev "$GRE_IFACE" root cake bandwidth 1gbit 2>/dev/null && \
            log "${GRE_IFACE} qdisc: cake" || true
    else
        tc qdisc replace dev "$GRE_IFACE" root fq_codel 2>/dev/null && \
            log "${GRE_IFACE} qdisc: fq_codel" || true
    fi
fi

# --- GRO (Generic Receive Offload) ---
# Enable where possible for receive-side performance.
ethtool -K "$BAT_IFACE" gro on 2>/dev/null && log "bat0 GRO: enabled" || true
if [[ -n "$GRE_IFACE" ]]; then
    ethtool -K "$GRE_IFACE" gro on 2>/dev/null && log "${GRE_IFACE} GRO: enabled" || true
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 3: KERNEL NETWORK STACK TUNING
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${PURPLE}━━━ Phase 3: Kernel Network Stack ━━━${NC}"

# --- TCP Buffer Sizes ---
# Already decent (4096 1048576 16777216) but ensure they're set.
sysctl -w net.core.rmem_max=16777216 > /dev/null 2>&1
sysctl -w net.core.wmem_max=16777216 > /dev/null 2>&1
sysctl -w net.core.rmem_default=1048576 > /dev/null 2>&1
sysctl -w net.core.wmem_default=1048576 > /dev/null 2>&1
sysctl -w net.ipv4.tcp_rmem="4096 1048576 16777216" > /dev/null 2>&1
sysctl -w net.ipv4.tcp_wmem="4096 1048576 16777216" > /dev/null 2>&1
log "TCP buffer sizes: 4K / 1M / 16M"

# --- UDP Buffer Sizes (critical for batman-adv which uses raw frames) ---
sysctl -w net.core.optmem_max=65536 > /dev/null 2>&1
log "UDP/optmem max: 64K"

# --- BBR Congestion Control (already set but ensure) ---
sysctl -w net.ipv4.tcp_congestion_control=bbr > /dev/null 2>&1 && \
    log "TCP congestion: BBR ✓" || warn "BBR not available"

# --- TCP Fast Open (already 3 but ensure) ---
sysctl -w net.ipv4.tcp_fastopen=3 > /dev/null 2>&1
log "TCP Fast Open: client+server (3)"

# --- Disable Slow Start After Idle ---
# Crucial for mesh: prevents TCP from resetting cwnd after idle periods.
sysctl -w net.ipv4.tcp_slow_start_after_idle=0 > /dev/null 2>&1
log "TCP slow start after idle: disabled"

# --- MTU Probing ---
# Essential for mesh where MTU varies across paths.
sysctl -w net.ipv4.tcp_mtu_probing=1 > /dev/null 2>&1
log "TCP MTU probing: enabled"

# --- Backlog & Connection Queue ---
sysctl -w net.core.netdev_max_backlog=5000 > /dev/null 2>&1
sysctl -w net.core.somaxconn=4096 > /dev/null 2>&1
log "Backlog: 5000, somaxconn: 4096"

# --- Neighbor Table Sizes ---
# Prevents "neighbor table overflow" on busy mesh networks.
sysctl -w net.ipv4.neigh.default.gc_thresh1=1024 > /dev/null 2>&1
sysctl -w net.ipv4.neigh.default.gc_thresh2=4096 > /dev/null 2>&1
sysctl -w net.ipv4.neigh.default.gc_thresh3=8192 > /dev/null 2>&1
log "Neighbor table: 1024/4096/8192 (prevents overflow)"

# --- Conntrack Tuning ---
# More connection tracking slots for mesh NAT traffic.
if [[ -f /proc/sys/net/netfilter/nf_conntrack_max ]]; then
    sysctl -w net.netfilter.nf_conntrack_max=131072 > /dev/null 2>&1
    log "Conntrack max: 131072"
    # Reduce conntrack timeout for faster slot reuse
    sysctl -w net.netfilter.nf_conntrack_tcp_timeout_established=3600 > /dev/null 2>&1
    sysctl -w net.netfilter.nf_conntrack_tcp_timeout_time_wait=30 > /dev/null 2>&1
    log "Conntrack timeouts: established=3600s, time_wait=30s"
fi

# --- Reduce Keepalive (faster dead peer detection over mesh) ---
sysctl -w net.ipv4.tcp_keepalive_time=60 > /dev/null 2>&1
sysctl -w net.ipv4.tcp_keepalive_intvl=10 > /dev/null 2>&1
sysctl -w net.ipv4.tcp_keepalive_probes=6 > /dev/null 2>&1
log "TCP keepalive: 60s / 10s interval / 6 probes"

# --- Enable TCP Window Scaling ---
sysctl -w net.ipv4.tcp_window_scaling=1 > /dev/null 2>&1
log "TCP window scaling: enabled"

# --- Enable TCP Timestamps (needed for BBR accuracy) ---
sysctl -w net.ipv4.tcp_timestamps=1 > /dev/null 2>&1
log "TCP timestamps: enabled (BBR accuracy)"

# --- Reduce TCP FIN timeout ---
sysctl -w net.ipv4.tcp_fin_timeout=15 > /dev/null 2>&1
log "TCP FIN timeout: 15s"

# --- Enable ECN (if aggressive) ---
if [[ "$AGGRESSIVE" == "--aggressive" ]]; then
    sysctl -w net.ipv4.tcp_ecn=1 > /dev/null 2>&1
    log "TCP ECN: enabled (aggressive)"

    # Lower TCP notsent_lowat for latency
    sysctl -w net.ipv4.tcp_notsent_lowat=16384 > /dev/null 2>&1
    log "TCP notsent_lowat: 16K (low-latency)"

    # Increase max SYN backlog
    sysctl -w net.ipv4.tcp_max_syn_backlog=8192 > /dev/null 2>&1
    log "TCP SYN backlog: 8192"

    # Enable TCP SACK for better loss recovery
    sysctl -w net.ipv4.tcp_sack=1 > /dev/null 2>&1
    sysctl -w net.ipv4.tcp_dsack=1 > /dev/null 2>&1
    log "TCP SACK + DSACK: enabled"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 4: PERSIST TUNINGS
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${PURPLE}━━━ Phase 4: Persist Settings ━━━${NC}"

# Write sysctl config for persistence across reboots
SYSCTL_CONF="/etc/sysctl.d/90-nullsec-mesh.conf"
cat > "$SYSCTL_CONF" << 'SYSCTL'
# ═══════════════════════════════════════════════════════════════
# NullSec Mesh Network Performance Tuning
# Generated by nullsec-mesh-optimize.sh
# ═══════════════════════════════════════════════════════════════

# --- IP Forwarding (required for mesh gateway) ---
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.conf.all.proxy_arp = 1

# --- TCP Buffer Sizes ---
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.ipv4.tcp_rmem = 4096 1048576 16777216
net.ipv4.tcp_wmem = 4096 1048576 16777216
net.core.optmem_max = 65536

# --- Congestion & Fast Open ---
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1

# --- Queues ---
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 4096
net.core.default_qdisc = fq

# --- Neighbor Tables (prevent overflow on mesh) ---
net.ipv4.neigh.default.gc_thresh1 = 1024
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh3 = 8192

# --- Conntrack ---
net.netfilter.nf_conntrack_max = 131072
net.netfilter.nf_conntrack_tcp_timeout_established = 3600
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30

# --- Keepalive (faster dead mesh peer detection) ---
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6

# --- Timeouts ---
net.ipv4.tcp_fin_timeout = 15
SYSCTL

log "Sysctl config written to ${SYSCTL_CONF}"

# Write batman-adv tuning to a boot script
BATADV_TUNE="/usr/local/bin/nullsec-mesh-tune"
cat > "$BATADV_TUNE" << 'TUNE'
#!/bin/bash
# NullSec batman-adv performance tuning (run at boot after mesh is up)
BAT="bat0"
[[ ! -d /sys/class/net/$BAT ]] && exit 0

batctl meshif $BAT gw_mode server 1000mbit/1000mbit 2>/dev/null
batctl meshif $BAT hop_penalty 15 2>/dev/null
batctl meshif $BAT orig_interval 500 2>/dev/null
batctl meshif $BAT network_coding 1 2>/dev/null
batctl meshif $BAT aggregation 1 2>/dev/null
batctl meshif $BAT distributed_arp_table 1 2>/dev/null
batctl meshif $BAT bridge_loop_avoidance 1 2>/dev/null
batctl meshif $BAT fragmentation 1 2>/dev/null
batctl meshif $BAT multicast_fanout 16 2>/dev/null

# Interface tuning
ip link set $BAT txqueuelen 5000 2>/dev/null

# qdisc — prefer cake, fallback to fq_codel
tc qdisc replace dev $BAT root cake bandwidth 1gbit 2>/dev/null || \
    tc qdisc replace dev $BAT root fq_codel 2>/dev/null || true

# Tune transport interface too
TRANSPORT=$(batctl meshif $BAT interface 2>/dev/null | awk '{print $1}' | head -1)
if [[ -n "$TRANSPORT" ]]; then
    ip link set "$TRANSPORT" txqueuelen 5000 2>/dev/null
    ip link set "$TRANSPORT" mtu 1476 2>/dev/null
    tc qdisc replace dev "$TRANSPORT" root cake bandwidth 1gbit 2>/dev/null || \
        tc qdisc replace dev "$TRANSPORT" root fq_codel 2>/dev/null || true
fi
TUNE
chmod +x "$BATADV_TUNE"
log "Boot tune script written to ${BATADV_TUNE}"

# Add to mesh systemd service ExecStartPost
MESH_SERVICE="/etc/systemd/system/nullsec-mesh.service"
if [[ -f "$MESH_SERVICE" ]]; then
    if ! grep -q "nullsec-mesh-tune" "$MESH_SERVICE" 2>/dev/null; then
        sed -i '/ExecStart=/a ExecStartPost=/usr/local/bin/nullsec-mesh-tune' "$MESH_SERVICE" 2>/dev/null && {
            systemctl daemon-reload 2>/dev/null
            log "Added tune script to nullsec-mesh.service ExecStartPost"
        } || warn "Could not update systemd service (do it manually)"
    else
        log "Tune script already in systemd service ✓"
    fi
else
    warn "nullsec-mesh.service not found — run nullsec-mesh-setup.sh first for boot persistence"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              Optimization Complete ✓                        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${WHITE}batman-adv:${NC}"
echo -e "    Gateway BW:      $(batctl meshif $BAT_IFACE gw_mode 2>/dev/null)"
echo -e "    Hop Penalty:     $(batctl meshif $BAT_IFACE hop_penalty 2>/dev/null)"
echo -e "    Orig Interval:   $(batctl meshif $BAT_IFACE orig_interval 2>/dev/null)ms"
echo -e "    Network Coding:  $(batctl meshif $BAT_IFACE network_coding 2>/dev/null)"
echo -e "    Fragmentation:   $(batctl meshif $BAT_IFACE fragmentation 2>/dev/null)"
echo -e "    DAT:             $(batctl meshif $BAT_IFACE distributed_arp_table 2>/dev/null)"
echo ""
echo -e "  ${WHITE}Interface:${NC}"
echo -e "    bat0 txqueuelen: $(cat /sys/class/net/$BAT_IFACE/tx_queue_len 2>/dev/null)"
echo -e "    bat0 MTU:        $(cat /sys/class/net/$BAT_IFACE/mtu 2>/dev/null)"
echo -e "    bat0 qdisc:      $(tc qdisc show dev $BAT_IFACE 2>/dev/null | head -1 | awk '{print $2}')"
if [[ -n "$GRE_IFACE" ]]; then
    echo -e "    ${GRE_IFACE} MTU:  $(cat /sys/class/net/$GRE_IFACE/mtu 2>/dev/null)"
fi
echo ""
echo -e "  ${WHITE}Kernel:${NC}"
echo -e "    Congestion:      $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
echo -e "    Fast Open:       $(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null)"
echo -e "    Slow Start Idle: $(sysctl -n net.ipv4.tcp_slow_start_after_idle 2>/dev/null)"
echo -e "    MTU Probing:     $(sysctl -n net.ipv4.tcp_mtu_probing 2>/dev/null)"
echo -e "    Conntrack Max:   $(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null)"
echo ""
echo -e "  ${WHITE}Persisted:${NC}"
echo -e "    ${SYSCTL_CONF}"
echo -e "    ${BATADV_TUNE}"
echo ""
echo -e "  ${GRAY}Run with --aggressive for low-latency mode${NC}"
echo -e "  ${GRAY}Test with: iperf3 -s (on remote) → iperf3 -c <mesh-ip> (here)${NC}"
echo ""
