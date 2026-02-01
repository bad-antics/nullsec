#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Network Mapper
# Comprehensive network topology discovery and mapping tool
#
# For authorized security testing only!
# Credits: Built for Hak5 WiFi Pineapple - https://hak5.org
#═══════════════════════════════════════════════════════════════════════════════

VERSION="1.0"
LOOT_DIR="/mmc/nullsec/network-maps"
DATE_TAG=$(date +%Y%m%d_%H%M%S)

mkdir -p "$LOOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
    echo -e "${RED}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║              NULLSEC NETWORK MAPPER v1.0                      ║
    ║                                                               ║
    ║         Network Topology Discovery & Mapping                  ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "    ${CYAN}Built for Hak5 WiFi Pineapple - https://hak5.org${NC}"
    echo ""
}

log() {
    local timestamp=$(date '+%H:%M:%S')
    echo -e "${GREEN}[$timestamp]${NC} $1"
}

# Detect local network information
detect_network() {
    log "Detecting network configuration..."
    
    # Get default interface
    local default_if=$(ip route | grep default | awk '{print $5}' | head -1)
    local local_ip=$(ip addr show "$default_if" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    local subnet=$(ip route | grep "$default_if" | grep -v default | awk '{print $1}' | head -1)
    local gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    
    echo ""
    echo -e "${CYAN}Network Configuration:${NC}"
    echo "  Interface: $default_if"
    echo "  Local IP:  $local_ip"
    echo "  Subnet:    $subnet"
    echo "  Gateway:   $gateway"
    echo ""
    
    echo "$subnet"
}

# Quick ping sweep
ping_sweep() {
    local subnet=$1
    local output_file="$LOOT_DIR/hosts_${DATE_TAG}.txt"
    
    log "Running ping sweep on $subnet..."
    
    # Extract base network
    local base=$(echo "$subnet" | cut -d'/' -f1 | sed 's/\.[0-9]*$//')
    
    local found=0
    for i in {1..254}; do
        ping -c 1 -W 1 "${base}.${i}" &>/dev/null && {
            echo "${base}.${i}" >> "$output_file"
            echo -e "  ${GREEN}→${NC} Found: ${base}.${i}"
            ((found++))
        } &
        
        # Limit parallel pings
        [ $(jobs -r | wc -l) -ge 50 ] && wait
    done
    wait
    
    log "Ping sweep complete. Found $found hosts."
    echo "$output_file"
}

# ARP scan (faster, requires root)
arp_scan() {
    local interface=${1:-$(ip route | grep default | awk '{print $5}' | head -1)}
    local output_file="$LOOT_DIR/arp_scan_${DATE_TAG}.txt"
    
    log "Running ARP scan on $interface..."
    
    if command -v arp-scan &>/dev/null; then
        arp-scan -I "$interface" --localnet 2>/dev/null | tee "$output_file"
    else
        # Fallback to basic ARP table
        log "arp-scan not available, using ARP table..."
        ip neigh show | grep -v FAILED | tee "$output_file"
    fi
    
    echo "$output_file"
}

# Port scan
port_scan() {
    local target=$1
    local ports=${2:-"21,22,23,25,53,80,110,139,143,443,445,993,995,3306,3389,5900,8080,8443"}
    local output_file="$LOOT_DIR/ports_${target}_${DATE_TAG}.txt"
    
    log "Scanning ports on $target..."
    
    if command -v nmap &>/dev/null; then
        nmap -sT -p "$ports" --open -oN "$output_file" "$target" 2>/dev/null
    else
        # Fallback to bash port scan
        echo "Port scan for $target" > "$output_file"
        echo "========================" >> "$output_file"
        
        IFS=',' read -ra PORT_ARRAY <<< "$ports"
        for port in "${PORT_ARRAY[@]}"; do
            (echo >/dev/tcp/"$target"/"$port") 2>/dev/null && {
                echo "  Port $port: OPEN" | tee -a "$output_file"
            }
        done
    fi
    
    echo "$output_file"
}

# Service identification
identify_services() {
    local target=$1
    local output_file="$LOOT_DIR/services_${target}_${DATE_TAG}.txt"
    
    log "Identifying services on $target..."
    
    if command -v nmap &>/dev/null; then
        nmap -sV -p- --open --top-ports 1000 -oN "$output_file" "$target" 2>/dev/null
    else
        log "nmap not available, doing basic check..."
        
        echo "Service Check for $target" > "$output_file"
        
        # Common service ports
        local services=(
            "21:FTP"
            "22:SSH"
            "23:Telnet"
            "25:SMTP"
            "53:DNS"
            "80:HTTP"
            "110:POP3"
            "143:IMAP"
            "443:HTTPS"
            "445:SMB"
            "3306:MySQL"
            "3389:RDP"
            "5900:VNC"
            "8080:HTTP-Proxy"
        )
        
        for service in "${services[@]}"; do
            local port=$(echo "$service" | cut -d: -f1)
            local name=$(echo "$service" | cut -d: -f2)
            
            (echo >/dev/tcp/"$target"/"$port") 2>/dev/null && {
                echo "  $port/tcp - $name: OPEN" | tee -a "$output_file"
                
                # Try to grab banner
                local banner=$(timeout 2 bash -c "exec 3<>/dev/tcp/$target/$port; cat <&3" 2>/dev/null | head -1)
                [ -n "$banner" ] && echo "    Banner: $banner" | tee -a "$output_file"
            }
        done
    fi
    
    echo "$output_file"
}

# OS fingerprinting
fingerprint_os() {
    local target=$1
    
    log "Attempting OS fingerprint on $target..."
    
    if command -v nmap &>/dev/null; then
        nmap -O "$target" 2>/dev/null | grep -E "OS|Running|Device"
    else
        # Basic TTL-based guess
        local ttl=$(ping -c 1 "$target" 2>/dev/null | grep "ttl=" | sed 's/.*ttl=\([0-9]*\).*/\1/')
        
        if [ -n "$ttl" ]; then
            if [ "$ttl" -le 64 ]; then
                echo "  Likely: Linux/Unix (TTL=$ttl)"
            elif [ "$ttl" -le 128 ]; then
                echo "  Likely: Windows (TTL=$ttl)"
            else
                echo "  Likely: Network device (TTL=$ttl)"
            fi
        fi
    fi
}

# DHCP info
get_dhcp_info() {
    log "Getting DHCP information..."
    
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    echo ""
    echo -e "${CYAN}DHCP Lease Information:${NC}"
    
    if [ -f /var/lib/dhcp/dhclient.leases ]; then
        grep -A 20 "lease {" /var/lib/dhcp/dhclient.leases | tail -20
    elif [ -f /tmp/dhcp.leases ]; then
        cat /tmp/dhcp.leases
    else
        log "No DHCP lease file found"
    fi
}

# Generate network map
generate_map() {
    local hosts_file=$1
    local output_file="$LOOT_DIR/network_map_${DATE_TAG}.txt"
    
    log "Generating network map..."
    
    cat > "$output_file" << EOF
═══════════════════════════════════════════════════════════════════════════════
                        NULLSEC NETWORK MAP
═══════════════════════════════════════════════════════════════════════════════
Generated: $(date)
Device: $(cat /etc/hostname 2>/dev/null || echo "Unknown")

Credits: Built for Hak5 WiFi Pineapple - https://hak5.org
───────────────────────────────────────────────────────────────────────────────

NETWORK TOPOLOGY
════════════════

                    ┌─────────────┐
                    │   GATEWAY   │
                    │$(printf "%-13s" "$(ip route | grep default | awk '{print $3}')")│
                    └──────┬──────┘
                           │
            ┌──────────────┼──────────────┐
            │              │              │
EOF

    if [ -f "$hosts_file" ]; then
        while read -r host; do
            # Get hostname if possible
            local hostname=$(timeout 1 host "$host" 2>/dev/null | grep "domain name pointer" | awk '{print $NF}' | sed 's/\.$//')
            [ -z "$hostname" ] && hostname="unknown"
            
            cat >> "$output_file" << EOF
    ┌───────────────────┐
    │ $(printf "%-17s" "$host") │
    │ $(printf "%-17s" "$hostname") │
    └───────────────────┘
EOF
        done < "$hosts_file"
    fi
    
    cat >> "$output_file" << EOF

───────────────────────────────────────────────────────────────────────────────

HOST DETAILS
═══════════

EOF

    if [ -f "$hosts_file" ]; then
        while read -r host; do
            echo "Host: $host" >> "$output_file"
            fingerprint_os "$host" >> "$output_file" 2>/dev/null
            echo "" >> "$output_file"
        done < "$hosts_file"
    fi
    
    log "Network map saved to: $output_file"
    cat "$output_file"
}

# Full network discovery
full_discovery() {
    banner
    log "Starting full network discovery..."
    echo ""
    
    # Phase 1: Detect network
    echo -e "${CYAN}═══ PHASE 1: Network Detection ═══${NC}"
    local subnet=$(detect_network)
    
    # Phase 2: Host discovery
    echo -e "${CYAN}═══ PHASE 2: Host Discovery ═══${NC}"
    local hosts_file=$(ping_sweep "$subnet")
    
    # Phase 3: ARP scan
    echo -e "${CYAN}═══ PHASE 3: ARP Scan ═══${NC}"
    arp_scan
    
    # Phase 4: DHCP info
    echo -e "${CYAN}═══ PHASE 4: DHCP Information ═══${NC}"
    get_dhcp_info
    
    # Phase 5: Port scan discovered hosts
    echo -e "${CYAN}═══ PHASE 5: Port Scanning ═══${NC}"
    if [ -f "$hosts_file" ]; then
        while read -r host; do
            port_scan "$host"
        done < "$hosts_file"
    fi
    
    # Phase 6: Generate map
    echo -e "${CYAN}═══ PHASE 6: Generate Map ═══${NC}"
    generate_map "$hosts_file"
    
    echo ""
    log "Full network discovery complete!"
    log "Results saved to: $LOOT_DIR"
}

# Interactive mode
interactive() {
    banner
    
    echo "Select operation:"
    echo "  1) Full Network Discovery"
    echo "  2) Quick Ping Sweep"
    echo "  3) ARP Scan"
    echo "  4) Port Scan (single host)"
    echo "  5) Service Identification"
    echo "  6) OS Fingerprinting"
    echo "  7) Generate Network Map"
    echo ""
    read -p "Choice [1-7]: " choice
    
    case $choice in
        1) full_discovery ;;
        2) 
            local subnet=$(detect_network)
            ping_sweep "$subnet"
            ;;
        3) arp_scan ;;
        4)
            read -p "Target IP: " target
            port_scan "$target"
            ;;
        5)
            read -p "Target IP: " target
            identify_services "$target"
            ;;
        6)
            read -p "Target IP: " target
            fingerprint_os "$target"
            ;;
        7)
            read -p "Hosts file (or press enter to scan): " hosts
            if [ -z "$hosts" ]; then
                local subnet=$(detect_network)
                hosts=$(ping_sweep "$subnet")
            fi
            generate_map "$hosts"
            ;;
        *) echo "Invalid choice" ;;
    esac
}

# Main
main() {
    case "$1" in
        -f|--full) full_discovery ;;
        -s|--sweep) 
            local subnet=$(detect_network)
            ping_sweep "$subnet"
            ;;
        -a|--arp) arp_scan ;;
        -p|--port)
            [ -z "$2" ] && { echo "Usage: $0 -p <target>"; exit 1; }
            port_scan "$2"
            ;;
        -h|--help)
            banner
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -f, --full     Full network discovery"
            echo "  -s, --sweep    Quick ping sweep"
            echo "  -a, --arp      ARP scan"
            echo "  -p, --port     Port scan (requires target)"
            echo "  -h, --help     Show this help"
            echo ""
            ;;
        *) interactive ;;
    esac
}

main "$@"
