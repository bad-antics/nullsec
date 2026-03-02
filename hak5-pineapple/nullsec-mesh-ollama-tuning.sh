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
#║           NullSec Mesh Tuning for Ollama AI v1.0                             ║
#║        Optimize batman-adv + kernel for distributed inference                ║
#║                     Developed by: bad-antics                                 ║
#║                                                                               ║
#╚═══════════════════════════════════════════════════════════════════════════════╝
#
# This script tunes the batman-adv mesh network + kernel for maximum performance
# when running distributed Ollama AI inference across cluster nodes.
#
# Optimizations include:
#   - Large buffer sizes for model transfers (multi-GB files)
#   - Low-latency packet scheduling (CAKE qdisc)
#   - batman-adv hop penalty tuning
#   - UDP offload for large model downloads
#   - Connection tracking optimization
#   - TCP window scaling for long-distance mesh
#
# Usage:
#   sudo ./nullsec-mesh-ollama-tuning.sh        # Normal tuning
#   sudo ./nullsec-mesh-ollama-tuning.sh --ultra # Ultra-aggressive (max throughput)
#

set -euo pipefail

AGGRESSIVE="${1:-}"
BAT_IFACE="bat0"
MESH_IFACE="mesh0"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[-]${NC} $1"; }
info()  { echo -e "${BLUE}[i]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[!] Run as root: sudo $0${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     NullSec Mesh Tuning for Ollama AI v1.0                   ║${NC}"
echo -e "${CYAN}║     Optimizing for Distributed Inference Performance          ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# PART 1: BATMAN-ADV TUNING
# ═══════════════════════════════════════════════════════════════════════════════

if ! ip link show "$BAT_IFACE" &>/dev/null; then
    err "bat0 not found - run nullsec-mesh-setup.sh first"
    exit 1
fi

echo -e "${CYAN}━━━ Phase 1: batman-adv Protocol Tuning ━━━${NC}"

# Increase gateway bandwidth announcement for ISP-like performance
log "Setting gateway bandwidth: 1000mbit/1000mbit"
batctl meshif "$BAT_IFACE" gw_mode server 1000mbit/1000mbit 2>/dev/null || true

# Lower hop penalty = prefer direct routes (less hops = lower latency)
log "Setting hop penalty for low-latency routing: 15"
batctl meshif "$BAT_IFACE" hop_penalty 15 2>/dev/null || true

# Increase orig_interval for stable mesh topology (less churn on model transfer)
log "Setting originator interval: 5000ms"
batctl meshif "$BAT_IFACE" orig_interval 5000 2>/dev/null || true

# Enable network coding (reduces retransmissions on lossy links)
log "Enabling network coding"
batctl meshif "$BAT_IFACE" nc 1 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════════
# PART 2: INTERFACE TUNING
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}━━━ Phase 2: Interface Parameters ━━━${NC}"

# Increase TX queue length for burst model traffic
log "Setting bat0 txqueuelen: 10000"
ip link set bat0 txqueuelen 10000 2>/dev/null || true

# Use CAKE qdisc if available (better than fq_codel for large files)
if tc qdisc add dev bat0 root cake diffserv4 2>/dev/null; then
    log "Using CAKE qdisc (optimized for large transfers)"
else
    log "CAKE not available, falling back to fq_codel"
    tc qdisc add dev bat0 root fq_codel 2>/dev/null || true
fi

# ═══════════════════════════════════════════════════════════════════════════════
# PART 3: KERNEL NETWORK BUFFER TUNING
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}━━━ Phase 3: Kernel Network Buffers ━━━${NC}"

# Massive buffers for model transfers (typically 4-50GB models)
# Default Linux limit is usually 128MB - we need much more

log "Increasing RX buffer max to 1GB"
sysctl -w net.core.rmem_max=1073741824 2>/dev/null || true

log "Increasing TX buffer max to 1GB"
sysctl -w net.core.wmem_max=1073741824 2>/dev/null || true

log "Setting default RX buffer to 256MB"
sysctl -w net.core.rmem_default=268435456 2>/dev/null || true

log "Setting default TX buffer to 256MB"
sysctl -w net.core.wmem_default=268435456 2>/dev/null || true

# TCP buffer tuning (min, default, max)
log "Tuning TCP buffers for large model transfers"
sysctl -w net.ipv4.tcp_rmem="4096 268435456 1073741824" 2>/dev/null || true
sysctl -w net.ipv4.tcp_wmem="4096 268435456 1073741824" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════════
# PART 4: CONNECTION & THROUGHPUT OPTIMIZATION
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}━━━ Phase 4: Connection & Throughput Optimization ━━━${NC}"

# Increase connection backlog for multiple parallel Ollama connections
log "Setting socket backlog to 4096 (multi-worker inference)"
sysctl -w net.core.somaxconn=4096 2>/dev/null || true
sysctl -w net.ipv4.tcp_max_syn_backlog=4096 2>/dev/null || true

# Enable TCP window scaling (helps large file transfers)
log "Enabling TCP window scaling"
sysctl -w net.ipv4.tcp_window_scaling=1 2>/dev/null || true

# Disable ECN to avoid confusion on mesh (batman handles drops)
log "Disabling ECN (batman-adv handles congestion)"
sysctl -w net.ipv4.tcp_ecn=0 2>/dev/null || true

# Increase TCP FIN timeout (mesh routes may be slow)
log "Increasing TCP FIN timeout to 60 seconds"
sysctl -w net.ipv4.tcp_fin_timeout=60 2>/dev/null || true

# Disable TCP slow start after idle (always use full bandwidth)
log "Disabling slow start after idle"
sysctl -w net.ipv4.tcp_slow_start_after_idle=0 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════════
# PART 5: AGGRESSIVE MODE (Ultra-high throughput)
# ═══════════════════════════════════════════════════════════════════════════════

if [[ "$AGGRESSIVE" == "--ultra" ]]; then
    echo -e "${CYAN}━━━ Phase 5: ULTRA-AGGRESSIVE MODE ━━━${NC}"
    
    warn "Enabling ULTRA mode - maximum throughput for AI workloads"
    
    # Maximum buffer sizes
    log "Setting absolute maximum buffers"
    sysctl -w net.core.rmem_max=2147483647 2>/dev/null || true
    sysctl -w net.core.wmem_max=2147483647 2>/dev/null || true
    sysctl -w net.core.rmem_default=536870912 2>/dev/null || true
    sysctl -w net.core.wmem_default=536870912 2>/dev/null || true
    
    # Maximum TCP buffers (2GB range)
    log "Setting maximum TCP buffers"
    sysctl -w net.ipv4.tcp_rmem="4096 536870912 2147483647" 2>/dev/null || true
    sysctl -w net.ipv4.tcp_wmem="4096 536870912 2147483647" 2>/dev/null || true
    
    # Aggressive connection tuning
    log "Aggressive connection limits"
    sysctl -w net.core.netdev_max_backlog=10000 2>/dev/null || true
    sysctl -w net.ipv4.tcp_max_syn_backlog=8192 2>/dev/null || true
    
    # Disable TCP retransmit throttling (mesh is unstable, we want fast retries)
    log "Tuning TCP retransmission for unstable links"
    sysctl -w net.ipv4.tcp_retries1=2 2>/dev/null || true
    sysctl -w net.ipv4.tcp_retries2=8 2>/dev/null || true
    
    # Enable UDP offload if available (for model downloads via UDP)
    log "Attempting to enable UDP offload"
    ethtool -K bat0 udp-segmentation-offload on 2>/dev/null || warn "UDP offload not available"
    ethtool -K bat0 ufo on 2>/dev/null || true
fi

# ═══════════════════════════════════════════════════════════════════════════════
# PART 6: CONNECTION TRACKING OPTIMIZATION
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}━━━ Phase 6: Connection Tracking ━━━${NC}"

# Increase connection tracking table
if [[ -f /sys/module/nf_conntrack/parameters/hashsize ]]; then
    log "Increasing conntrack hash size for parallel model transfers"
    echo 262144 > /sys/module/nf_conntrack/parameters/hashsize 2>/dev/null || true
fi

# Increase max connections
if [[ -f /proc/sys/net/netfilter/nf_conntrack_max ]]; then
    log "Increasing max tracked connections"
    sysctl -w net.netfilter.nf_conntrack_max=1000000 2>/dev/null || true
fi

# ═══════════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    Tuning Complete!                          ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

info "Mesh Network Status:"
batctl meshif "$BAT_IFACE" gw_mode 2>/dev/null | head -1 || true
echo ""

info "Network Buffer Configuration:"
echo "  RX Buffer: $(sysctl -n net.core.rmem_default) bytes"
echo "  TX Buffer: $(sysctl -n net.core.wmem_default) bytes"
echo ""

info "TCP Configuration:"
echo "  Window Scaling: $(sysctl -n net.ipv4.tcp_window_scaling)"
echo "  FIN Timeout: $(sysctl -n net.ipv4.tcp_fin_timeout) seconds"
echo ""

info "Next steps:"
echo "  1. Test model transfer: ollama pull mistral"
echo "  2. Monitor throughput: iftop -i bat0"
echo "  3. Check mesh topology: batctl meshif bat0 originators"
echo "  4. Start Ollama cluster: ./nullsec-ollama-cluster.sh start"
echo "  5. Launch proxy: ./nullsec-ollama-cluster.sh proxy"
echo ""

success "Mesh network optimized for distributed Ollama AI inference!"
