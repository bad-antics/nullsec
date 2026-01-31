#!/bin/bash
# NULLSEC Attack Module Launcher
# bad-antics development


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

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}              ☠  OFFENSIVE SECURITY OPERATIONS  ☠${RESET}"
echo -e "${CYAN}                    [ bad-antics development ]${RESET}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "${CYAN}  SELECT ATTACK MODULE:${RESET}"
echo ""
echo -e "  ${RED}[1]${RESET}  🖥️  Network Intrusion"
echo -e "  ${RED}[2]${RESET}  🔒 Ransomware Deploy"
echo -e "  ${RED}[3]${RESET}  📡 WiFi Deauth Attack"
echo -e "  ${RED}[4]${RESET}  🦷 Bluetooth Warfare"
echo -e "  ${RED}[5]${RESET}  🗄️  SQL Injection"
echo -e "  ${RED}[6]${RESET}  🎭 Phishing Campaign"
echo -e "  ${RED}[7]${RESET}  💀 APT Kill Chain"
echo -e "  ${RED}[8]${RESET}  ⛏️  Cryptominer Botnet"
echo -e "  ${RED}[9]${RESET}  🔥 Zero-Day Exploit"
echo -e "  ${RED}[10]${RESET} 🌐 C2 Server"
echo -e "  ${RED}[11]${RESET} 🔓 Physical Bypass"
echo -e "  ${RED}[12]${RESET} 🧅 Dark Web Ops"
echo ""
echo -e "  ${GREEN}[Q]${RESET}  Exit"
echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
read -p "$(echo -e ${WHITE}'  Enter choice: '${RESET})" choice

case $choice in
    1) bash "$SCRIPT_DIR/intrusion.sh" ;;
    2) bash "$SCRIPT_DIR/ransomware.sh" ;;
    3) bash "$SCRIPT_DIR/wifi-deauth.sh" ;;
    4) bash "$SCRIPT_DIR/bluetooth-attack.sh" ;;
    5) bash "$SCRIPT_DIR/database-exfil.sh" ;;
    6) bash "$SCRIPT_DIR/social-engineering.sh" ;;
    7) bash "$SCRIPT_DIR/apt-attack.sh" ;;
    8) bash "$SCRIPT_DIR/cryptominer.sh" ;;
    9) bash "$SCRIPT_DIR/zero-day.sh" ;;
    10) bash "$SCRIPT_DIR/c2-server.sh" ;;
    11) bash "$SCRIPT_DIR/physical-bypass.sh" ;;
    12) bash "$SCRIPT_DIR/darkweb-ops.sh" ;;
    q|Q) echo -e "\n${RED}[!] Exiting...${RESET}\n"; exit 0 ;;
    *) echo -e "\n${RED}[!] Invalid option${RESET}\n" ;;
esac
