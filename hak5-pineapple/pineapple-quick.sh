#!/bin/bash
#===============================================================================
#  PINEAPPLE QUICK ACCESS - Switch to Pineapple, run commands, switch back
#===============================================================================

PINEAPPLE_CONN="Pineapple-Pager"
HOME_CONN="null"
PINEAPPLE_IP="172.16.52.1"
PINEAPPLE_USER="root"
PINEAPPLE_PASS="null??"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
err() { echo -e "${RED}[-]${NC} $1"; }

# Connect to Pineapple WiFi
connect_pineapple() {
    log "Switching to Pineapple WiFi..."
    nmcli connection up "$PINEAPPLE_CONN" 2>/dev/null
    sleep 3
}

# Connect back to home WiFi
connect_home() {
    log "Switching back to home WiFi..."
    nmcli connection down "$PINEAPPLE_CONN" 2>/dev/null
    sleep 1
    nmcli connection up "$HOME_CONN" 2>/dev/null
    sleep 2
}

# SSH to Pineapple
pineapple_ssh() {
    connect_pineapple
    log "Connecting to Pineapple via SSH..."
    sshpass -p "$PINEAPPLE_PASS" ssh -o StrictHostKeyChecking=no "$PINEAPPLE_USER@$PINEAPPLE_IP"
    connect_home
}

# Run command on Pineapple
pineapple_cmd() {
    local cmd="$*"
    connect_pineapple
    log "Running command on Pineapple: $cmd"
    sshpass -p "$PINEAPPLE_PASS" ssh -o StrictHostKeyChecking=no "$PINEAPPLE_USER@$PINEAPPLE_IP" "$cmd"
    connect_home
}

# Copy file to Pineapple
pineapple_push() {
    local src="$1"
    local dest="${2:-/root/}"
    connect_pineapple
    log "Copying $src to Pineapple:$dest"
    sshpass -p "$PINEAPPLE_PASS" scp -o StrictHostKeyChecking=no "$src" "$PINEAPPLE_USER@$PINEAPPLE_IP:$dest"
    connect_home
}

# Copy file from Pineapple
pineapple_pull() {
    local src="$1"
    local dest="${2:-.}"
    connect_pineapple
    log "Copying Pineapple:$src to $dest"
    sshpass -p "$PINEAPPLE_PASS" scp -o StrictHostKeyChecking=no "$PINEAPPLE_USER@$PINEAPPLE_IP:$src" "$dest"
    connect_home
}

# Deploy NullSec payloads
deploy_payloads() {
    local payload_dir="${1:-/home/antics/nullsec/hak5-pineapple/payloads/nullsec}"
    connect_pineapple
    log "Deploying NullSec payloads..."
    sshpass -p "$PINEAPPLE_PASS" ssh -o StrictHostKeyChecking=no "$PINEAPPLE_USER@$PINEAPPLE_IP" "mkdir -p /root/payloads"
    sshpass -p "$PINEAPPLE_PASS" scp -r -o StrictHostKeyChecking=no "$payload_dir" "$PINEAPPLE_USER@$PINEAPPLE_IP:/root/payloads/"
    sshpass -p "$PINEAPPLE_PASS" ssh -o StrictHostKeyChecking=no "$PINEAPPLE_USER@$PINEAPPLE_IP" "chmod +x /root/payloads/nullsec/*.sh /root/payloads/nullsec/*/*.sh 2>/dev/null"
    log "Payloads deployed to /root/payloads/nullsec/"
    connect_home
}

# Get Pineapple info
pineapple_info() {
    pineapple_cmd "echo '=== SYSTEM ==='; uname -a; echo ''; echo '=== STORAGE ==='; df -h; echo ''; echo '=== NETWORK ==='; ip addr | grep -E 'inet |^[0-9]'"
}

case "${1:-ssh}" in
    ssh) pineapple_ssh ;;
    cmd) shift; pineapple_cmd "$@" ;;
    push) shift; pineapple_push "$@" ;;
    pull) shift; pineapple_pull "$@" ;;
    deploy) shift; deploy_payloads "$@" ;;
    info) pineapple_info ;;
    *)
        echo "Pineapple Quick Access"
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  ssh              - Interactive SSH session"
        echo "  cmd <command>    - Run command on Pineapple"
        echo "  push <file> [dest] - Copy file to Pineapple"
        echo "  pull <file> [dest] - Copy file from Pineapple"
        echo "  deploy [dir]     - Deploy NullSec payloads"
        echo "  info             - Get Pineapple system info"
        ;;
esac
