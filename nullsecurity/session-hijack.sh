#!/bin/bash
# NULLSEC Session Hijack - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC SESSION HIJACK ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
read -p "$(echo -e ${WHITE}'  [>] Target domain: '${RESET})" TARGET; [ -z "$TARGET" ] && TARGET="target.com"
read -p "$(echo -e ${WHITE}'  [>] Network interface: '${RESET})" IFACE; [ -z "$IFACE" ] && IFACE="eth0"
echo ""
echo -e "  ${YELLOW}Hijack method:${RESET}"
echo -e "    ${DIM}1) Cookie theft (MITM)${RESET}"
echo -e "    ${DIM}2) Session fixation${RESET}"
echo -e "    ${DIM}3) XSS cookie steal${RESET}"
echo -e "    ${DIM}4) Token prediction${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select [1-4]: '${RESET})" METHOD; [ -z "$METHOD" ] && METHOD="1"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing session hijack"
    echo ""
    echo -e "${DIM}[*] Sniffing traffic on $IFACE...${RESET}"; sleep 1
    echo ""
    echo -e "${RED}[CAPTURED]${RESET} Cookie: PHPSESSID=abc123def456ghi789"
    echo -e "${RED}[CAPTURED]${RESET} Cookie: auth_token=eyJhbGciOiJIUzI1NiJ9..."
    echo -e "${RED}[CAPTURED]${RESET} Cookie: _session=s%3Axyz789..."
    echo ""
    echo -e "${DIM}[*] Importing stolen session...${RESET}"; sleep 0.5
    echo -e "${GREEN}[+]${RESET} Session hijacked!"
    echo -e "${GREEN}[+]${RESET} Logged in as: admin@$TARGET"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Use Wireshark or Bettercap for cookie capture"
fi
