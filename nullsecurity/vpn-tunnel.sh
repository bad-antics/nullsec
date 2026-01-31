#!/bin/bash
# NULLSEC VPN Tunnel - bad-antics development

# Source common library for Shodan integration

# === NULLSEC ENHANCED LOGGING ===
TARGET_DIR="${NULLSEC_TARGET_DIR:-$HOME/nullsec/logs/targets/default}"
LOG_FILE="${NULLSEC_LOG_FILE:-$TARGET_DIR/module.log}"

# Helper function: Log to file with timestamp
log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Helper function: Save output to target directory
save_output() {
    local filename="$1"
    local content="$2"
    echo "$content" > "$TARGET_DIR/$filename"
    log_to_file "Saved output to $TARGET_DIR/$filename"
}

# Helper function: Log discovered vulnerability
log_vulnerability() {
    local severity="$1"
    local title="$2"
    local description="$3"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] VULNERABILITY [$severity] $title - $description" >> "$LOG_FILE"
}

# Read environment variables set by framework

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/nullsec-common.sh" 2>/dev/null

# Check for Shodan target
SHODAN_TARGET="/home/antics/nullsec/.shodan_target"
if [ -f "$SHODAN_TARGET" ]; then
    source "$SHODAN_TARGET"
    if [ ! -z "$TARGET" ]; then
        echo -e "${GREEN}[+]${RESET} Shodan target available: ${GREEN}$TARGET${RESET}"
    fi
fi

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'
clear
echo -e "${RED}▓▓▓ NULLSEC VPN TUNNEL ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
echo -e "  ${YELLOW}Tunnel type:${RESET}"
echo -e "    ${DIM}1) SSH tunnel${RESET}"
echo -e "    ${DIM}2) OpenVPN${RESET}"
echo -e "    ${DIM}3) WireGuard${RESET}"
echo -e "    ${DIM}4) Chisel (HTTP tunnel)${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select [1-4]: '${RESET})" TUNNEL_TYPE; [ -z "$TUNNEL_TYPE" ] && TUNNEL_TYPE="1"
read -p "$(echo -e ${WHITE}'  [>] Remote server: '${RESET})" REMOTE; [ -z "$REMOTE" ] && REMOTE="vpn.server.com"
read -p "$(echo -e ${WHITE}'  [>] Local port: '${RESET})" LOCAL_PORT; [ -z "$LOCAL_PORT" ] && LOCAL_PORT="1080"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    types=("SSH" "OpenVPN" "WireGuard" "Chisel")
    echo -e "${YELLOW}[*]${RESET} Executing ${types[$((TUNNEL_TYPE-1))]} tunnel"
    echo -e "${DIM}[*] Connecting to $REMOTE...${RESET}"; sleep 0.8
    echo -e "${GREEN}[+]${RESET} Tunnel established"
    echo -e "${GREEN}[+]${RESET} SOCKS proxy on localhost:$LOCAL_PORT"
    echo -e "${GREEN}[+]${RESET} Your IP: 185.$((RANDOM%256)).$((RANDOM%256)).$((RANDOM%256))"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    case $TUNNEL_TYPE in
        1) echo -e "${RED}[*]${RESET} ssh -D $LOCAL_PORT -N user@$REMOTE" ;;
        4) echo -e "${RED}[*]${RESET} chisel client $REMOTE:8080 socks" ;;
        *) echo -e "${RED}[*]${RESET} Use appropriate VPN client" ;;
    esac
fi
