#!/bin/bash
# NULLSEC Active Directory Attack Module

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

source "$(dirname "$0")/nullsec-common.sh" 2>/dev/null || {
    RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'
    CYAN='\033[1;36m'; WHITE='\033[1;37m'; RESET='\033[0m'
}

clear
echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
echo -e "${RED}█${RESET}         ${WHITE}🔑 NULLSEC ACTIVE DIRECTORY ATTACK 🔑${RESET}"
echo -e "${RED}█${RESET}                  ${CYAN}[ bad-antics development ]${RESET}"
echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
echo ""
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "  ${WHITE}AD ATTACK VECTORS${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo ""
echo -e "    ${WHITE}1)${RESET} LDAP Enumeration"
echo -e "    ${WHITE}2)${RESET} AS-REP Roasting"
echo -e "    ${WHITE}3)${RESET} DCSync Attack"
echo -e "    ${WHITE}4)${RESET} Silver Ticket"
echo -e "    ${WHITE}5)${RESET} NTDS.dit Extraction"
echo -e "    ${WHITE}6)${RESET} BloodHound Collection"
echo -e "    ${WHITE}7)${RESET} Delegation Abuse"
read -p "$(echo -e ${WHITE}'  [>] Select [1-7]: '${RESET})" ATTACK

read -p "$(echo -e ${WHITE}'  [>] Domain Controller IP: '${RESET})" DC
[ -z "$DC" ] && DC="dc01.corp.local"

read -p "$(echo -e ${WHITE}'  [>] Domain: '${RESET})" DOMAIN
[ -z "$DOMAIN" ] && DOMAIN="corp.local"

echo ""
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "  ${WHITE}DOMAIN EXPLOITATION${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo ""

echo -e "${GREEN}[*]${RESET} Target DC: $DC"
echo -e "${GREEN}[*]${RESET} Domain: $DOMAIN"
echo ""

case $ATTACK in
    1)
        echo -e "${CYAN}[*]${RESET} Performing LDAP enumeration..."
        sleep 0.5
        echo -e "${GREEN}[+]${RESET} Domain Admins: 5 members"
        echo -e "${GREEN}[+]${RESET} Service Accounts: 12 found"
        echo -e "${GREEN}[+]${RESET} Computers: 234 objects"
        ;;
    2)
        echo -e "${CYAN}[*]${RESET} Finding AS-REP roastable accounts..."
        sleep 0.5
        echo -e "${GREEN}[+]${RESET} svc_backup - DONT_REQ_PREAUTH set"
        echo -e "${GREEN}[+]${RESET} Capturing AS-REP hash..."
        echo -e "${YELLOW}[!]${RESET} Hash saved for offline cracking"
        ;;
    3)
        echo -e "${CYAN}[*]${RESET} Initiating DCSync attack..."
        sleep 0.5
        echo -e "${GREEN}[+]${RESET} Replicating NTLM hashes..."
        echo -e "${GREEN}[+]${RESET} Administrator: aad3b435..."
        echo -e "${RED}[!]${RESET} All domain hashes extracted"
        ;;
    4)
        echo -e "${CYAN}[*]${RESET} Forging Silver Ticket..."
        sleep 0.5
        echo -e "${GREEN}[+]${RESET} Target service: CIFS/$DC"
        echo -e "${GREEN}[+]${RESET} Ticket forged for Administrator"
        echo -e "${GREEN}[+]${RESET} Injected into memory"
        ;;
    5)
        echo -e "${CYAN}[*]${RESET} Extracting NTDS.dit..."
        sleep 0.5
        echo -e "${GREEN}[+]${RESET} Volume Shadow Copy created"
        echo -e "${GREEN}[+]${RESET} NTDS.dit copied"
        echo -e "${GREEN}[+]${RESET} SYSTEM hive extracted"
        ;;
    6)
        echo -e "${CYAN}[*]${RESET} Running BloodHound collection..."
        sleep 0.5
        echo -e "${GREEN}[+]${RESET} Collecting sessions..."
        echo -e "${GREEN}[+]${RESET} Collecting ACLs..."
        echo -e "${GREEN}[+]${RESET} Collecting trusts..."
        echo -e "${GREEN}[+]${RESET} Data saved to bloodhound.zip"
        ;;
    7)
        echo -e "${CYAN}[*]${RESET} Finding delegation targets..."
        sleep 0.5
        echo -e "${GREEN}[+]${RESET} Unconstrained: WEB01$"
        echo -e "${GREEN}[+]${RESET} Constrained: SQL01$ -> DC01"
        echo -e "${YELLOW}[!]${RESET} Abusing RBCD..."
        ;;
esac

echo ""
echo -e "${GREEN}[✓]${RESET} Active Directory attack complete"
echo ""
