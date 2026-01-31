#!/bin/bash
# NULLSEC Pretexting - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC PRETEXTING ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
echo -e "  ${YELLOW}Pretext persona:${RESET}"
echo -e "    ${DIM}1) IT Support technician${RESET}"
echo -e "    ${DIM}2) Vendor/Contractor${RESET}"
echo -e "    ${DIM}3) Executive assistant${RESET}"
echo -e "    ${DIM}4) Auditor/Compliance${RESET}"
echo -e "    ${DIM}5) New employee${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select [1-5]: '${RESET})" PERSONA; [ -z "$PERSONA" ] && PERSONA="1"
read -p "$(echo -e ${WHITE}'  [>] Target employee name: '${RESET})" TARGET; [ -z "$TARGET" ] && TARGET="John Smith"
read -p "$(echo -e ${WHITE}'  [>] Target company: '${RESET})" COMPANY; [ -z "$COMPANY" ] && COMPANY="Acme Corp"
read -p "$(echo -e ${WHITE}'  [>] Objective (creds/access/info): '${RESET})" OBJECTIVE; [ -z "$OBJECTIVE" ] && OBJECTIVE="creds"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    personas=("IT Support" "Vendor" "Exec Assistant" "Auditor" "New Employee")
    echo -e "${YELLOW}[*]${RESET} Executing pretext scenario"
    echo -e "${DIM}[*] Persona: ${personas[$((PERSONA-1))]}${RESET}"
    echo -e "${DIM}[*] Target: $TARGET at $COMPANY${RESET}"; sleep 0.5
    echo ""
    echo -e "${CYAN}Script:${RESET}"
    case $PERSONA in
        1) echo -e "${DIM}\"Hi $TARGET, this is Mike from IT. We're doing security updates and need to verify your account...\"${RESET}" ;;
        2) echo -e "${DIM}\"Hello, I'm from [Vendor]. We need to access the server room to complete scheduled maintenance...\"${RESET}" ;;
        3) echo -e "${DIM}\"Hi, I'm calling on behalf of [Exec]. They need the Q4 financial reports sent urgently...\"${RESET}" ;;
        4) echo -e "${DIM}\"Good morning, I'm here for the compliance audit. I'll need access to your records...\"${RESET}" ;;
        5) echo -e "${DIM}\"Hey, I just started in Marketing. HR said you could help me get system access...\"${RESET}" ;;
    esac
    echo ""
    echo -e "${GREEN}[+]${RESET} Objective: $OBJECTIVE"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Requires social engineering skills and authorization"
fi
