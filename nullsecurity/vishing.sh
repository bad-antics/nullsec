#!/bin/bash
# NULLSEC Vishing Attack - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC VISHING ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
echo -e "  ${YELLOW}Pretext:${RESET}"
echo -e "    ${DIM}1) Bank fraud department${RESET}"
echo -e "    ${DIM}2) Tech support${RESET}"
echo -e "    ${DIM}3) IRS/Tax authority${RESET}"
echo -e "    ${DIM}4) Company IT helpdesk${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select [1-4]: '${RESET})" PRETEXT; [ -z "$PRETEXT" ] && PRETEXT="2"
read -p "$(echo -e ${WHITE}'  [>] Target phone: '${RESET})" PHONE; [ -z "$PHONE" ] && PHONE="+1-555-0100"
read -p "$(echo -e ${WHITE}'  [>] Spoofed caller ID: '${RESET})" SPOOF_ID; [ -z "$SPOOF_ID" ] && SPOOF_ID="+1-800-555-1234"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    pretexts=("Bank Fraud Dept" "Tech Support" "IRS" "IT Helpdesk")
    echo -e "${YELLOW}[*]${RESET} Executing vishing attack"
    echo -e "${DIM}[*] Pretext: ${pretexts[$((PRETEXT-1))]}${RESET}"
    echo -e "${DIM}[*] Caller ID spoofed: $SPOOF_ID${RESET}"; sleep 0.4
    echo -e "${GREEN}[+]${RESET} Initiating call to $PHONE"
    echo -e "${DIM}[*] Ring... Ring...${RESET}"; sleep 0.8
    echo -e "${GREEN}[+]${RESET} Call connected"
    echo ""
    echo -e "${CYAN}Script:${RESET}"
    case $PRETEXT in
        1) echo -e "${DIM}\"This is the fraud department. We've detected suspicious activity...\"${RESET}" ;;
        2) echo -e "${DIM}\"This is Microsoft support. Your computer is sending us errors...\"${RESET}" ;;
        3) echo -e "${DIM}\"This is the IRS. You owe back taxes and must pay immediately...\"${RESET}" ;;
        4) echo -e "${DIM}\"IT helpdesk here. We need to verify your credentials...\"${RESET}" ;;
    esac
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Voice phishing requires VoIP infrastructure"
fi
