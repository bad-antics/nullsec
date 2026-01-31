#!/bin/bash
# NULLSEC Water System Attack - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC WATER SYSTEM ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
echo -e "  ${YELLOW}Target:${RESET}"
echo -e "    ${DIM}1) Treatment plant HMI${RESET}"
echo -e "    ${DIM}2) Pump station PLC${RESET}"
echo -e "    ${DIM}3) Chemical dosing system${RESET}"
echo -e "    ${DIM}4) Reservoir sensors${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select [1-4]: '${RESET})" SYSTEM; [ -z "$SYSTEM" ] && SYSTEM="1"
read -p "$(echo -e ${WHITE}'  [>] Target IP: '${RESET})" TARGET; [ -z "$TARGET" ] && TARGET="10.10.20.1"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    systems=("Treatment HMI" "Pump Station" "Chemical Dosing" "Reservoir Sensors")
    echo -e "${YELLOW}[*]${RESET} Executing attack on ${systems[$((SYSTEM-1))]}"
    echo -e "${DIM}[*] Connecting to $TARGET...${RESET}"; sleep 0.5
    echo -e "${GREEN}[+]${RESET} Access to ${systems[$((SYSTEM-1))]}"
    case $SYSTEM in
        1) echo -e "${GREEN}[+]${RESET} HMI: Wonderware InTouch"; echo -e "${RED}[!]${RESET} Modifying process parameters" ;;
        2) echo -e "${RED}[!]${RESET} Pump 1: STOP"; echo -e "${RED}[!]${RESET} Pump 2: MAX SPEED"; echo -e "${RED}[!]${RESET} Pressure anomaly" ;;
        3) echo -e "${RED}[!]${RESET} Chlorine dosage: 0.5 ppm -> 50 ppm"; echo -e "${RED}[!]${RESET} DANGER: Toxic levels" ;;
        4) echo -e "${GREEN}[+]${RESET} Spoofing sensor readings"; echo -e "${GREEN}[+]${RESET} Level shown: 80%, Actual: 10%" ;;
    esac
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Critical infrastructure attacks are federal crimes"
fi
