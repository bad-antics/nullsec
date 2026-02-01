#!/bin/bash
# WiFi Pineapple Pager CLI Interface
# bad-antics Development Team

PAGER_IP="172.16.52.1"
PAGER_USER="root"
PAGER_PASS="flooding1337"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

banner() {
    echo -e "${RED}"
    echo "  ██████▓  █████▓  ██████▓ ███████▓██████▓ "
    echo "  ██▓━━██▓██▓━━██▓██▓━━━━▓ ██▓━━━━▓██▓━━██▓"
    echo "  ██████▓▓███████████  ███▓█████▓  ██████▓▓"
    echo "  ██▓━━━▓ ██▓━━██████   █████▓━━▓  ██▓━━██▓"
    echo "  ███     ███  ███▓██████▓▓███████▓███  ███"
    echo "  ▓━▓     ▓━▓  ▓━▓ ▓━━━━━▓ ▓━━━━━━▓▓━▓  ▓━▓"
    echo -e "${PURPLE}     WiFi Pineapple Pager CLI - bad-antics${NC}"
    echo ""
}

# Check connection to Pager
pager_ping() {
    echo -e "${CYAN}[*] Pinging Pager at $PAGER_IP...${NC}"
    ping -c 2 $PAGER_IP > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] Pager is online!${NC}"
        return 0
    else
        echo -e "${RED}[-] Pager is offline or unreachable${NC}"
        return 1
    fi
}

# SSH into Pager
pager_ssh() {
    echo -e "${CYAN}[*] Connecting to Pager via SSH...${NC}"
    sshpass -p "$PAGER_PASS" ssh -o StrictHostKeyChecking=no $PAGER_USER@$PAGER_IP
}

# Execute command on Pager
pager_exec() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: pager_exec <command>${NC}"
        return 1
    fi
    sshpass -p "$PAGER_PASS" ssh -o StrictHostKeyChecking=no $PAGER_USER@$PAGER_IP "$*"
}

# List payloads
pager_payloads() {
    echo -e "${CYAN}[*] Available Payloads:${NC}"
    pager_exec "find /root/payloads -name '*.sh' -o -name 'payload.txt' 2>/dev/null | head -50"
}

# List themes
pager_themes() {
    echo -e "${CYAN}[*] Available Themes:${NC}"
    pager_exec "ls -1 /root/themes/themes/ 2>/dev/null"
}

# Upload file to Pager
pager_upload() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo -e "${YELLOW}Usage: pager_upload <local_file> <remote_path>${NC}"
        return 1
    fi
    echo -e "${CYAN}[*] Uploading $1 to $PAGER_IP:$2...${NC}"
    sshpass -p "$PAGER_PASS" scp -o StrictHostKeyChecking=no "$1" $PAGER_USER@$PAGER_IP:"$2"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] Upload complete!${NC}"
    else
        echo -e "${RED}[-] Upload failed${NC}"
    fi
}

# Download file from Pager
pager_download() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo -e "${YELLOW}Usage: pager_download <remote_file> <local_path>${NC}"
        return 1
    fi
    echo -e "${CYAN}[*] Downloading $PAGER_IP:$1 to $2...${NC}"
    sshpass -p "$PAGER_PASS" scp -o StrictHostKeyChecking=no $PAGER_USER@$PAGER_IP:"$1" "$2"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] Download complete!${NC}"
    else
        echo -e "${RED}[-] Download failed${NC}"
    fi
}

# Get Pager system info
pager_info() {
    echo -e "${CYAN}[*] Pager System Info:${NC}"
    pager_exec "echo '--- Hostname ---' && hostname && echo '--- Uptime ---' && uptime && echo '--- Memory ---' && free -h 2>/dev/null || cat /proc/meminfo | head -3 && echo '--- Disk ---' && df -h / 2>/dev/null"
}

# Get loot from Pager
pager_loot() {
    echo -e "${CYAN}[*] Loot Directory:${NC}"
    pager_exec "ls -la /root/loot/ 2>/dev/null"
}

# Run a payload
pager_run() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: pager_run <payload_path>${NC}"
        echo -e "${YELLOW}Example: pager_run /root/payloads/recon/handshake_harvester/payload.sh${NC}"
        return 1
    fi
    echo -e "${CYAN}[*] Running payload: $1${NC}"
    pager_exec "chmod +x $1 && $1"
}

# Enable internet sharing to Pager
pager_internet() {
    echo -e "${CYAN}[*] Enabling internet sharing to Pager...${NC}"
    PAGER_IFACE=$(ip addr | grep -B2 "172.16.52" | grep -oP '^\d+: \K[^:]+')
    INET_IFACE=$(ip route get 8.8.8.8 | grep -oP 'dev \K\S+')
    
    sudo iptables -t nat -A POSTROUTING -s 172.16.52.0/24 -o $INET_IFACE -j MASQUERADE
    sudo iptables -A FORWARD -i $INET_IFACE -o $PAGER_IFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
    sudo iptables -A FORWARD -i $PAGER_IFACE -o $INET_IFACE -j ACCEPT
    sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
    
    # Set gateway on Pager
    LAPTOP_IP=$(ip addr show $PAGER_IFACE | grep -oP 'inet \K[\d.]+')
    pager_exec "route add default gw $LAPTOP_IP 2>/dev/null"
    
    echo -e "${GREEN}[+] Internet sharing enabled!${NC}"
    echo -e "${CYAN}[*] Testing Pager internet access...${NC}"
    pager_exec "ping -c 1 8.8.8.8" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] Pager has internet access!${NC}"
    else
        echo -e "${RED}[-] Pager cannot reach internet${NC}"
    fi
}

# Open Pager web interface
pager_web() {
    echo -e "${CYAN}[*] Opening Pager web interface...${NC}"
    xdg-open "http://$PAGER_IP:1471" 2>/dev/null &
}

# Help menu
pager_help() {
    banner
    echo -e "${GREEN}Available Commands:${NC}"
    echo -e "  ${YELLOW}pager_ping${NC}       - Check if Pager is online"
    echo -e "  ${YELLOW}pager_ssh${NC}        - SSH into Pager"
    echo -e "  ${YELLOW}pager_exec${NC}       - Execute command on Pager"
    echo -e "  ${YELLOW}pager_info${NC}       - Get Pager system info"
    echo -e "  ${YELLOW}pager_payloads${NC}   - List available payloads"
    echo -e "  ${YELLOW}pager_themes${NC}     - List available themes"
    echo -e "  ${YELLOW}pager_run${NC}        - Run a payload"
    echo -e "  ${YELLOW}pager_loot${NC}       - View loot directory"
    echo -e "  ${YELLOW}pager_upload${NC}     - Upload file to Pager"
    echo -e "  ${YELLOW}pager_download${NC}   - Download file from Pager"
    echo -e "  ${YELLOW}pager_internet${NC}   - Enable internet sharing"
    echo -e "  ${YELLOW}pager_web${NC}        - Open Pager web interface"
    echo -e "  ${YELLOW}pager_help${NC}       - Show this help menu"
    echo ""
}

# Auto-run banner and help on source (but only once per session)
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Prevent duplicate banner display on SSH or nested shells
    if [[ -z "$PAGER_CLI_LOADED" ]]; then
        export PAGER_CLI_LOADED=1
        banner
        echo -e "${GREEN}[+] Pager CLI loaded! Type 'pager_help' for commands.${NC}"
        pager_ping
    fi
