#!/bin/bash
# NULLSEC Proxy Chain - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC PROXY CHAIN ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
echo -e "  ${YELLOW}Proxy type:${RESET}"
echo -e "    ${DIM}1) SOCKS5 chain${RESET}"
echo -e "    ${DIM}2) HTTP proxies${RESET}"
echo -e "    ${DIM}3) Tor + Proxies${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select [1-3]: '${RESET})" PROXY_TYPE; [ -z "$PROXY_TYPE" ] && PROXY_TYPE="1"
read -p "$(echo -e ${WHITE}'  [>] Number of hops: '${RESET})" HOPS; [ -z "$HOPS" ] && HOPS="3"
read -p "$(echo -e ${WHITE}'  [>] Final target: '${RESET})" TARGET; [ -z "$TARGET" ] && TARGET="target.com"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Setting up proxy chain"
    echo ""
    for i in $(seq 1 $HOPS); do
        ip="$((RANDOM%256)).$((RANDOM%256)).$((RANDOM%256)).$((RANDOM%256))"
        port=$((RANDOM%10000+1080))
        country=("US" "NL" "RU" "DE" "JP" "BR")
        c=${country[$((RANDOM%6))]}
        sleep 0.3
        echo -e "${GREEN}[HOP $i]${RESET} $ip:$port ($c)"
    done
    echo ""
    echo -e "${DIM}[*] Testing chain...${RESET}"; sleep 0.5
    echo -e "${GREEN}[+]${RESET} Chain active: Your IP appears as 185.${RANDOM%256}.${RANDOM%256}.${RANDOM%256}"
    echo -e "${GREEN}[+]${RESET} Connecting to $TARGET through chain..."
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Configure /etc/proxychains4.conf"
    if command -v proxychains4 &> /dev/null; then
        echo -e "${YELLOW}[*] Run: proxychains4 curl $TARGET${RESET}"
    fi
fi
