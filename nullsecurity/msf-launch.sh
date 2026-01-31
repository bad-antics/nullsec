#!/bin/bash
# NULLSEC Framework - MSF Quick Launcher
# bad-antics development
# Launches Metasploit with NULLSEC integration


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

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RC_FILE="$SCRIPT_DIR/msf-integration.rc"

clear
echo -e "${RED}"
cat << 'BANNER'
    ███▓   ██▓██▓   ██▓██▓     ██▓     ███████▓███████▓ ██████▓
    ████▓  ██████   ██████     ███     ██▓━━━━▓██▓━━━━▓██▓━━━━▓
    ██▓██▓ ██████   ██████     ███     ███████▓█████▓  ███     
    ███▓██▓██████   ██████     ███     ▓━━━━█████▓━━▓  ███     
    ███ ▓█████▓██████▓▓███████▓███████▓███████████████▓▓██████▓
    ╺━╸  ╺━━━╸ ╺━━━━━╸ ╺━━━━━━╸╺━━━━━━╸╺━━━━━━╸╺━━━━━━╸ ╺━━━━━╸
BANNER
echo -e "${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}              NULLSEC + Metasploit Framework Integration${RESET}"
echo -e "${CYAN}                        [ bad-antics development ]${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Check if msfconsole is installed
if ! command -v msfconsole &> /dev/null; then
    echo -e "${RED}[!] Metasploit Framework not found!${RESET}"
    echo -e "${YELLOW}[*] Install with: sudo apt install metasploit-framework${RESET}"
    echo ""
    exit 1
fi

echo -e "${GREEN}[+] Metasploit Framework detected${RESET}"
echo -e "${GREEN}[+] Loading NULLSEC integration...${RESET}"
echo ""

# Check if resource file exists
if [ -f "$RC_FILE" ]; then
    echo -e "${CYAN}[*] Launching msfconsole with NULLSEC resource script...${RESET}"
    sleep 1
    msfconsole -r "$RC_FILE"
else
    echo -e "${YELLOW}[!] Resource file not found, launching standard msfconsole...${RESET}"
    sleep 1
    msfconsole
fi
