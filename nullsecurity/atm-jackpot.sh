#!/bin/bash
# NULLSEC ATM Jackpotting - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC ATM JACKPOT ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
echo -e "  ${YELLOW}ATM type:${RESET}"
echo -e "    ${DIM}1) NCR (Persona)${RESET}"
echo -e "    ${DIM}2) Diebold Nixdorf${RESET}"
echo -e "    ${DIM}3) Wincor${RESET}"
echo -e "    ${DIM}4) Generic XFS${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select [1-4]: '${RESET})" ATM_TYPE; [ -z "$ATM_TYPE" ] && ATM_TYPE="1"
read -p "$(echo -e ${WHITE}'  [>] Attack vector (1-USB 2-Network 3-Physical): '${RESET})" VECTOR; [ -z "$VECTOR" ] && VECTOR="1"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    types=("NCR Persona" "Diebold Nixdorf" "Wincor" "XFS")
    vectors=("USB" "Network" "Physical")
    echo -e "${YELLOW}[*]${RESET} Executing ${types[$((ATM_TYPE-1))]} jackpotting"
    echo -e "${DIM}[*] Attack vector: ${vectors[$((VECTOR-1))]}${RESET}"
    echo -e "${DIM}[*] Connecting to XFS service...${RESET}"; sleep 0.8
    echo -e "${GREEN}[+]${RESET} XFS Manager detected"
    echo -e "${GREEN}[+]${RESET} Cash dispenser: CDM v3.0"
    echo -e "${DIM}[*] Sending dispense command...${RESET}"; sleep 0.6
    echo -e "${RED}    ████████████████████████${RESET}"
    echo -e "${RED}    █  CASH DISPENSE SIM  █${RESET}"
    echo -e "${RED}    █    \$\$\$\$ \$\$\$\$ \$\$\$\$    █${RESET}"
    echo -e "${RED}    ████████████████████████${RESET}"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete (no actual dispense)"
else
    echo -e "${RED}[*]${RESET} ATM attacks are federal crimes"
fi
