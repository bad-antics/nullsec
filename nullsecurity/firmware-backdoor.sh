#!/bin/bash
# NULLSEC Firmware Backdoor - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC FIRMWARE BACKDOOR ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
echo -e "  ${YELLOW}Target device:${RESET}"
echo -e "    ${DIM}1) Router/Gateway${RESET}"
echo -e "    ${DIM}2) IoT Device${RESET}"
echo -e "    ${DIM}3) UEFI/BIOS${RESET}"
echo -e "    ${DIM}4) Network switch${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select [1-4]: '${RESET})" DEVICE; [ -z "$DEVICE" ] && DEVICE="1"
read -p "$(echo -e ${WHITE}'  [>] Firmware file: '${RESET})" FIRMWARE; [ -z "$FIRMWARE" ] && FIRMWARE="firmware.bin"
read -p "$(echo -e ${WHITE}'  [>] C2 address: '${RESET})" C2; [ -z "$C2" ] && C2="10.0.0.1:4444"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    devices=("Router" "IoT" "UEFI/BIOS" "Switch")
    echo -e "${YELLOW}[*]${RESET} Executing ${devices[$((DEVICE-1))]} firmware backdoor"
    echo -e "${DIM}[*] Extracting $FIRMWARE...${RESET}"; sleep 0.5
    echo -e "${GREEN}[+]${RESET} Filesystem: squashfs"
    echo -e "${DIM}[*] Analyzing...${RESET}"; sleep 0.4
    echo -e "${GREEN}[+]${RESET} Found /usr/sbin/httpd"
    echo -e "${DIM}[*] Injecting backdoor...${RESET}"; sleep 0.5
    echo -e "${GREEN}[+]${RESET} Added reverse shell to init scripts"
    echo -e "${GREEN}[+]${RESET} C2 callback: $C2"
    echo -e "${DIM}[*] Repacking firmware...${RESET}"; sleep 0.4
    echo -e "${GREEN}[+]${RESET} Backdoored firmware: ${FIRMWARE%.bin}_backdoor.bin"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} binwalk -e $FIRMWARE"
fi
