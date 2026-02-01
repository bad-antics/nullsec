#!/bin/bash
#===============================================================================
#  PINEAPPLE/PAGER USB CONNECTION SCRIPT
#  Connects to Hak5 device via USB without losing internet
#===============================================================================

PINEAPPLE_IP="${PINEAPPLE_IP:-172.16.42.1}"  # Default Pineapple IP
PINEAPPLE_NET="172.16.42.0/24"
PINEAPPLE_USER="${PINEAPPLE_USER:-root}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[-]${NC} $1"; }

# Find the Pineapple USB interface
find_pineapple_interface() {
    # Look for new USB ethernet interface
    local iface=""
    
    # Common names for USB ethernet gadgets
    for pattern in usb0 usb1 enp0s*u* enx*; do
        for dev in /sys/class/net/$pattern; do
            if [[ -e "$dev" ]]; then
                iface=$(basename "$dev")
                # Check if it's the Pineapple network
                if ip addr show "$iface" 2>/dev/null | grep -q "172.16.42"; then
                    echo "$iface"
                    return 0
                fi
            fi
        done
    done
    
    # Fallback - find any interface with 172.16.42.x
    iface=$(ip -o addr | grep "172.16.42" | awk '{print $2}')
    [[ -n "$iface" ]] && echo "$iface" && return 0
    
    # Last resort - newest USB interface
    iface=$(ls -1t /sys/class/net/ | grep -E "usb|enp.*u" | head -1)
    [[ -n "$iface" ]] && echo "$iface" && return 0
    
    return 1
}

# Save current default route
save_default_route() {
    ip route | grep "^default" | head -1 > /tmp/.default_route_backup
    log "Saved default route: $(cat /tmp/.default_route_backup)"
}

# Restore default route if Pineapple hijacked it
fix_routing() {
    local pineapple_iface="$1"
    
    # Get current default gateway
    local current_gw=$(ip route | grep "^default" | head -1)
    
    # Check if Pineapple hijacked the default route
    if echo "$current_gw" | grep -q "$pineapple_iface\|172.16.42"; then
        warn "Pineapple hijacked default route, fixing..."
        
        # Remove Pineapple as default gateway
        ip route del default via 172.16.42.1 2>/dev/null
        ip route del default dev "$pineapple_iface" 2>/dev/null
        
        # Restore original default route
        if [[ -f /tmp/.default_route_backup ]]; then
            eval "ip route add $(cat /tmp/.default_route_backup)" 2>/dev/null
        else
            # Try to find and restore via DHCP interface
            for iface in eth0 wlan0 enp* wlp*; do
                local gw=$(ip route | grep "$iface" | grep -oP 'via \K[\d.]+' | head -1)
                if [[ -n "$gw" ]] && [[ "$gw" != "172.16.42"* ]]; then
                    ip route add default via "$gw" dev "$iface" 2>/dev/null
                    log "Restored default route via $gw ($iface)"
                    break
                fi
            done
        fi
    fi
    
    # Add specific route to Pineapple network only
    ip route add $PINEAPPLE_NET dev "$pineapple_iface" 2>/dev/null
    log "Added route to Pineapple network via $pineapple_iface"
}

# Configure interface if needed
configure_interface() {
    local iface="$1"
    
    # Check if already configured
    if ip addr show "$iface" | grep -q "172.16.42"; then
        log "Interface $iface already has Pineapple IP"
        return 0
    fi
    
    # Configure with static IP in Pineapple network
    log "Configuring $iface with IP 172.16.42.42/24"
    ip addr add 172.16.42.42/24 dev "$iface" 2>/dev/null
    ip link set "$iface" up
}

# Test connectivity
test_connection() {
    log "Testing connection to Pineapple at $PINEAPPLE_IP..."
    
    if ping -c 1 -W 2 "$PINEAPPLE_IP" &>/dev/null; then
        log "Pineapple is reachable!"
        
        # Test SSH
        if nc -zw2 "$PINEAPPLE_IP" 22 2>/dev/null; then
            log "SSH port is open"
        fi
        
        # Test web interface
        if nc -zw2 "$PINEAPPLE_IP" 1471 2>/dev/null; then
            log "Web interface port 1471 is open"
        fi
        
        return 0
    else
        err "Cannot reach Pineapple at $PINEAPPLE_IP"
        return 1
    fi
}

# Test internet still works
test_internet() {
    log "Testing internet connectivity..."
    
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        log "Internet connectivity OK!"
        return 0
    else
        err "Internet connectivity LOST!"
        warn "Attempting to restore..."
        
        # Try to restore from backup
        if [[ -f /tmp/.default_route_backup ]]; then
            eval "ip route add $(cat /tmp/.default_route_backup)" 2>/dev/null
        fi
        
        # Retest
        if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
            log "Internet restored!"
            return 0
        fi
        return 1
    fi
}

# Main connect function
connect() {
    log "Looking for Pineapple USB interface..."
    
    # Save current route first
    save_default_route
    
    # Wait for interface to appear
    local attempts=0
    local iface=""
    
    while [[ -z "$iface" ]] && [[ $attempts -lt 10 ]]; do
        iface=$(find_pineapple_interface)
        if [[ -z "$iface" ]]; then
            warn "Waiting for Pineapple interface... ($((attempts+1))/10)"
            sleep 2
            ((attempts++))
        fi
    done
    
    if [[ -z "$iface" ]]; then
        err "Could not find Pineapple interface!"
        echo ""
        echo "Make sure:"
        echo "  1. Pineapple is connected via USB"
        echo "  2. Pineapple is powered on"
        echo "  3. USB data cable (not charge-only)"
        echo ""
        echo "Available interfaces:"
        ip link show | grep -E "^[0-9]" | awk '{print "  " $2}'
        return 1
    fi
    
    log "Found Pineapple interface: $iface"
    
    # Configure interface
    configure_interface "$iface"
    
    # Fix routing to keep internet
    fix_routing "$iface"
    
    # Test connections
    echo ""
    test_connection
    test_internet
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${GREEN}PINEAPPLE CONNECTED!${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  Interface:     $iface"
    echo "  Pineapple IP:  $PINEAPPLE_IP"
    echo "  Web UI:        http://$PINEAPPLE_IP:1471"
    echo ""
    echo "  SSH:           ssh $PINEAPPLE_USER@$PINEAPPLE_IP"
    echo "  SCP files:     scp file.sh $PINEAPPLE_USER@$PINEAPPLE_IP:/root/"
    echo ""
    echo "  Internet:      $(ping -c1 -W1 8.8.8.8 &>/dev/null && echo 'WORKING' || echo 'DOWN')"
    echo ""
}

# SSH into Pineapple
ssh_connect() {
    log "Connecting to Pineapple via SSH..."
    ssh -o StrictHostKeyChecking=no "$PINEAPPLE_USER@$PINEAPPLE_IP"
}

# Deploy payloads to Pineapple
deploy_payloads() {
    local payload_dir="${1:-$(dirname $0)/payloads/nullsec}"
    
    log "Deploying NullSec payloads to Pineapple..."
    
    # Create payload directory on Pineapple
    ssh "$PINEAPPLE_USER@$PINEAPPLE_IP" "mkdir -p /root/payloads/nullsec"
    
    # Copy payloads
    scp -r "$payload_dir"/* "$PINEAPPLE_USER@$PINEAPPLE_IP:/root/payloads/nullsec/"
    
    # Make executable
    ssh "$PINEAPPLE_USER@$PINEAPPLE_IP" "chmod +x /root/payloads/nullsec/*.sh /root/payloads/nullsec/*/*.sh 2>/dev/null"
    
    log "Payloads deployed to /root/payloads/nullsec/"
}

# Get Pineapple info
info() {
    log "Getting Pineapple info..."
    ssh "$PINEAPPLE_USER@$PINEAPPLE_IP" << 'REMOTE'
echo "=== PINEAPPLE INFO ==="
cat /etc/os-release 2>/dev/null | head -3
echo ""
echo "=== STORAGE ==="
df -h / /sd 2>/dev/null
echo ""
echo "=== NETWORK ==="
ip addr | grep -E "inet |^[0-9]"
echo ""
echo "=== MODULES ==="
ls /pineapple/modules 2>/dev/null || ls /root/modules 2>/dev/null || echo "No modules found"
REMOTE
}

# Disconnect (cleanup routes)
disconnect() {
    log "Cleaning up Pineapple routes..."
    ip route del $PINEAPPLE_NET 2>/dev/null
    log "Disconnected. You can unplug the Pineapple now."
}

# Show status
status() {
    echo "=== PINEAPPLE CONNECTION STATUS ==="
    echo ""
    
    local iface=$(find_pineapple_interface)
    if [[ -n "$iface" ]]; then
        echo "Interface: $iface (FOUND)"
        ip addr show "$iface" | grep -E "inet|state"
    else
        echo "Interface: NOT FOUND"
    fi
    
    echo ""
    echo -n "Pineapple ($PINEAPPLE_IP): "
    ping -c1 -W1 "$PINEAPPLE_IP" &>/dev/null && echo "REACHABLE" || echo "UNREACHABLE"
    
    echo -n "Internet (8.8.8.8): "
    ping -c1 -W1 8.8.8.8 &>/dev/null && echo "WORKING" || echo "DOWN"
    
    echo ""
    echo "Default route:"
    ip route | grep "^default"
}

case "${1:-connect}" in
    connect) connect ;;
    ssh) ssh_connect ;;
    deploy) shift; deploy_payloads "$@" ;;
    info) info ;;
    disconnect) disconnect ;;
    status) status ;;
    fix) 
        iface=$(find_pineapple_interface)
        [[ -n "$iface" ]] && fix_routing "$iface"
        ;;
    *)
        echo "Pineapple/Pager USB Connection Manager"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  connect     - Connect to Pineapple (default)"
        echo "  ssh         - SSH into Pineapple"
        echo "  deploy      - Deploy NullSec payloads"
        echo "  info        - Get Pineapple system info"
        echo "  status      - Show connection status"
        echo "  fix         - Fix routing (keep internet)"
        echo "  disconnect  - Cleanup and disconnect"
        echo ""
        echo "Environment:"
        echo "  PINEAPPLE_IP=$PINEAPPLE_IP"
        echo "  PINEAPPLE_USER=$PINEAPPLE_USER"
        ;;
esac
