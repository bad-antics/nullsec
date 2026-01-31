#!/bin/bash
# NULLSEC VLAN Hopping - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC VLAN HOPPING ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
echo -e "  ${YELLOW}Attack type:${RESET}"
echo -e "    ${DIM}1) Switch spoofing (DTP)${RESET}"
echo -e "    ${DIM}2) Double tagging${RESET}"
echo -e "    ${DIM}3) VTP injection${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select [1-3]: '${RESET})" ATTACK; [ -z "$ATTACK" ] && ATTACK="1"
read -p "$(echo -e ${WHITE}'  [>] Interface: '${RESET})" IFACE; [ -z "$IFACE" ] && IFACE="eth0"
read -p "$(echo -e ${WHITE}'  [>] Target VLAN: '${RESET})" TARGET_VLAN; [ -z "$TARGET_VLAN" ] && TARGET_VLAN="100"
read -p "$(echo -e ${WHITE}'  [>] Native VLAN: '${RESET})" NATIVE_VLAN; [ -z "$NATIVE_VLAN" ] && NATIVE_VLAN="1"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    attacks=("Switch Spoofing" "Double Tagging" "VTP Injection")
    echo -e "${YELLOW}[*]${RESET} Executing ${attacks[$((ATTACK-1))]}"
    echo -e "${DIM}[*] Interface: $IFACE${RESET}"; sleep 0.4
    case $ATTACK in
        1)
            echo -e "${DIM}[*] Sending DTP negotiate packets...${RESET}"; sleep 0.5
            echo -e "${GREEN}[+]${RESET} Trunk negotiation successful"
            echo -e "${GREEN}[+]${RESET} Access to all VLANs granted"
            ;;
        2)
            echo -e "${DIM}[*] Native VLAN: $NATIVE_VLAN -> Target: $TARGET_VLAN${RESET}"; sleep 0.5
            echo -e "${GREEN}[+]${RESET} Crafting double-tagged frame"
            echo -e "${GREEN}[+]${RESET} Outer tag: $NATIVE_VLAN, Inner tag: $TARGET_VLAN"
            echo -e "${GREEN}[+]${RESET} Packet reached VLAN $TARGET_VLAN"
            ;;
        3)
            echo -e "${DIM}[*] Spoofing VTP revision...${RESET}"; sleep 0.5
            echo -e "${GREEN}[+]${RESET} VTP update sent"
            echo -e "${GREEN}[+]${RESET} Network-wide VLAN config modified"
            ;;
    esac
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    case $ATTACK in
        1) echo -e "${RED}[*]${RESET} yersinia dtp -attack 1 -interface $IFACE" ;;
        2) echo -e "${RED}[*]${RESET} Use scapy for double-tagging" ;;
        3) echo -e "${RED}[*]${RESET} yersinia vtp -attack" ;;
    esac
fi
