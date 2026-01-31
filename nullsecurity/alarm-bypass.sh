#!/bin/bash
# NULLSEC Alarm Bypass - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC ALARM BYPASS ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
echo -e "  ${YELLOW}Alarm system type:${RESET}"
echo -e "    ${DIM}1) Wireless (433MHz)${RESET}"
echo -e "    ${DIM}2) Z-Wave based${RESET}"
echo -e "    ${DIM}3) IP-based panel${RESET}"
echo -e "    ${DIM}4) Wired with cellular backup${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select [1-4]: '${RESET})" ALARM_TYPE; [ -z "$ALARM_TYPE" ] && ALARM_TYPE="1"
read -p "$(echo -e ${WHITE}'  [>] Target address: '${RESET})" TARGET; [ -z "$TARGET" ] && TARGET="192.168.1.200"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    types=("Wireless 433MHz" "Z-Wave" "IP Panel" "Wired+Cellular")
    echo -e "${YELLOW}[*]${RESET} Executing ${types[$((ALARM_TYPE-1))]} alarm bypass"
    case $ALARM_TYPE in
        1)
            echo -e "${DIM}[*] SDR scanning 433MHz...${RESET}"; sleep 0.6
            echo -e "${GREEN}[+]${RESET} Captured sensor signal"
            echo -e "${GREEN}[+]${RESET} Replay attack ready"
            echo -e "${GREEN}[+]${RESET} Jamming bypass available"
            ;;
        2)
            echo -e "${DIM}[*] Analyzing Z-Wave network...${RESET}"; sleep 0.6
            echo -e "${GREEN}[+]${RESET} Network ID captured"
            echo -e "${GREEN}[+]${RESET} S0 encryption vulnerable"
            ;;
        3)
            echo -e "${DIM}[*] Connecting to $TARGET...${RESET}"; sleep 0.6
            echo -e "${GREEN}[+]${RESET} Panel: Honeywell Vista"
            echo -e "${GREEN}[+]${RESET} Default code: 1234"
            ;;
        4)
            echo -e "${DIM}[*] GSM jamming simulation...${RESET}"; sleep 0.6
            echo -e "${GREEN}[+]${RESET} Cellular backup disabled"
            ;;
    esac
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Alarm bypass requires specialized hardware"
fi
