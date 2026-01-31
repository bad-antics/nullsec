#!/bin/bash
# NULLSEC PLC Attack - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC PLC ATTACK ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
echo -e "  ${YELLOW}PLC Type:${RESET}"
echo -e "    ${DIM}1) Siemens S7${RESET}"
echo -e "    ${DIM}2) Allen-Bradley${RESET}"
echo -e "    ${DIM}3) Modicon${RESET}"
echo -e "    ${DIM}4) Omron${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select [1-4]: '${RESET})" PLC_TYPE; [ -z "$PLC_TYPE" ] && PLC_TYPE="1"
read -p "$(echo -e ${WHITE}'  [>] Target IP: '${RESET})" TARGET; [ -z "$TARGET" ] && TARGET="192.168.1.50"
read -p "$(echo -e ${WHITE}'  [>] Attack (1-Stop 2-Modify 3-DoS): '${RESET})" ATTACK; [ -z "$ATTACK" ] && ATTACK="1"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    plcs=("Siemens S7-1200" "Allen-Bradley ControlLogix" "Modicon M340" "Omron CP1L")
    attacks=("Stop CPU" "Modify Ladder Logic" "Denial of Service")
    echo -e "${YELLOW}[*]${RESET} Executing attack on ${plcs[$((PLC_TYPE-1))]}"
    echo -e "${DIM}[*] Connecting to $TARGET...${RESET}"; sleep 0.5
    echo -e "${GREEN}[+]${RESET} PLC: ${plcs[$((PLC_TYPE-1))]}"
    echo -e "${GREEN}[+]${RESET} Firmware: v2.1.3"
    echo -e "${DIM}[*] Attack: ${attacks[$((ATTACK-1))]}${RESET}"; sleep 0.4
    case $ATTACK in
        1) echo -e "${RED}[!]${RESET} CPU STOP command sent"; echo -e "${RED}[!]${RESET} PLC halted" ;;
        2) echo -e "${GREEN}[+]${RESET} Downloading ladder logic"; echo -e "${GREEN}[+]${RESET} Injecting malicious rung" ;;
        3) echo -e "${RED}[!]${RESET} Flooding with malformed packets" ;;
    esac
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Use ISF (Industrial Security Framework)"
fi
