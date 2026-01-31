#!/bin/bash
# NULLSEC Physical Bypass - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC PHYSICAL BYPASS ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
echo -e "  ${YELLOW}Bypass type:${RESET}"
echo -e "    ${DIM}1) Lock picking simulation${RESET}"
echo -e "    ${DIM}2) RFID badge cloning${RESET}"
echo -e "    ${DIM}3) Tailgating${RESET}"
echo -e "    ${DIM}4) Alarm bypass${RESET}"
echo -e "    ${DIM}5) Camera blind spots${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select [1-5]: '${RESET})" BYPASS_TYPE; [ -z "$BYPASS_TYPE" ] && BYPASS_TYPE="1"
read -p "$(echo -e ${WHITE}'  [>] Target location: '${RESET})" LOCATION; [ -z "$LOCATION" ] && LOCATION="Server Room B"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing physical bypass at $LOCATION"
    case $BYPASS_TYPE in
        1)
            echo -e "${DIM}[*] Analyzing lock type...${RESET}"; sleep 0.5
            echo -e "${GREEN}[+]${RESET} Lock: Schlage 5-pin tumbler"
            echo -e "${DIM}[*] Picking...${RESET}"; sleep 1
            echo -e "${GREEN}[+]${RESET} Lock bypassed in 45 seconds"
            ;;
        2)
            echo -e "${DIM}[*] Scanning badge...${RESET}"; sleep 0.8
            echo -e "${GREEN}[+]${RESET} Badge type: HID iCLASS"
            echo -e "${GREEN}[+]${RESET} Cloned to blank card"
            ;;
        3)
            echo -e "${DIM}[*] Waiting for employee...${RESET}"; sleep 1
            echo -e "${GREEN}[+]${RESET} Tailgated through door"
            ;;
        4)
            echo -e "${DIM}[*] Analyzing alarm system...${RESET}"; sleep 0.8
            echo -e "${GREEN}[+]${RESET} Type: PIR motion sensor"
            echo -e "${GREEN}[+]${RESET} Bypass: Low approach angle"
            ;;
        5)
            echo -e "${DIM}[*] Mapping camera coverage...${RESET}"; sleep 0.8
            echo -e "${GREEN}[+]${RESET} Blind spot identified: NE corner"
            ;;
    esac
    echo -e "${GREEN}[+]${RESET} Access gained to $LOCATION"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Physical penetration testing requires authorization"
fi
