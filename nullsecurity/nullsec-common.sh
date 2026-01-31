#!/bin/bash
# NULLSEC Common Functions & Integration
# Source this in all attack modules for consistent behavior

# Colors

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

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'
BLUE='\033[1;34m'; MAGENTA='\033[1;35m'; WHITE='\033[1;37m'; DIM='\033[2m'
RESET='\033[0m'; BOLD='\033[1m'

# Paths
NULLSEC_DIR="/home/antics/nullsec"
NULLSEC_CACHE="$NULLSEC_DIR/.shodan_cache"
SHODAN_TARGET="$NULLSEC_DIR/.shodan_target"
LOG_DIR="$NULLSEC_DIR/logs"

mkdir -p "$LOG_DIR" "$NULLSEC_CACHE"

# Load Shodan target if available
load_shodan_target() {
    if [ -f "$SHODAN_TARGET" ]; then
        source "$SHODAN_TARGET"
        if [ ! -z "$TARGET" ]; then
            echo -e "${GREEN}[+]${RESET} Shodan target loaded: ${GREEN}$TARGET${RESET}"
            [ ! -z "$PORTS" ] && echo -e "${DIM}    Ports: $PORTS${RESET}"
            return 0
        fi
    fi
    return 1
}

# Standard header in blood-drip style
print_header() {
    local title="$1"
    local subtitle="${2:-bad-antics development}"
    echo -e "${RED}"
    echo "  ▄▄▄▄    ▄▄▄      ▓█████▄     ▄▄▄       ███▄    █ ▄▄▄█████▓ ██▓ ▄████▄    ██████ "
    echo " ▓█████▄ ▒████▄    ▒██▀ ██▌   ▒████▄     ██ ▀█   █ ▓  ██▒ ▓▒▓██▒▒██▀ ▀█  ▒██    ▒ "
    echo " ▒██▒ ▄██▒██  ▀█▄  ░██   █▌   ▒██  ▀█▄  ▓██  ▀█ ██▒▒ ▓██░ ▒░▒██▒▒▓█    ▄ ░ ▓██▄   "
    echo -e "${RESET}"
    echo -e "${CYAN}  ╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
    echo -e "${WHITE}              ☠  $title  ☠${RESET}"
    echo -e "${DIM}                     $subtitle${RESET}"
    echo -e "${CYAN}  ╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
    echo ""
}

# Mini header for modules
print_module_header() {
    local title="$1"
    local icon="${2:-☠}"
    echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
    echo -e "${RED}█${RESET}              ${WHITE}$icon  NULLSEC $title  $icon${RESET}"
    echo -e "${RED}█${RESET}                  ${CYAN}[ bad-antics development ]${RESET}"
    echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
    echo ""
}

# Section separator
print_section() {
    local title="$1"
    echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
    echo -e "  ${WHITE}$title${RESET}"
    echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
}

# Status messages
success() { echo -e "${GREEN}[✓]${RESET} $1"; }
info() { echo -e "${CYAN}[*]${RESET} $1"; }
warn() { echo -e "${YELLOW}[!]${RESET} $1"; }
error() { echo -e "${RED}[✗]${RESET} $1"; }

# Check if running as test mode
is_test_mode() {
    [[ "$TEST_MODE" =~ ^[Yy]$ ]]
}

# Log activity
log_activity() {
    local module="$1"
    local action="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $module | $action" >> "$LOG_DIR/activity.log"
}

# Prompt for target with Shodan integration
get_target() {
    local prompt="${1:-Target IP/Host}"
    local default="${2:-}"
    
    # Check for Shodan target first
    if load_shodan_target 2>/dev/null; then
        echo ""
        read -p "$(echo -e ${YELLOW}'  [?] Use Shodan target '$TARGET'? (Y/n): '${RESET})" USE_SHODAN
        if [[ ! "$USE_SHODAN" =~ ^[Nn]$ ]]; then
            echo "$TARGET"
            return
        fi
    fi
    
    read -p "$(echo -e ${WHITE}'  [>] '$prompt': '${RESET})" INPUT
    if [ -z "$INPUT" ]; then
        echo "${default:-192.168.1.1}"
    else
        echo "$INPUT"
    fi
}

# Ask for test mode
ask_test_mode() {
    echo ""
    read -p "$(echo -e ${YELLOW}'  [!] Run in TEST MODE? (y/N): '${RESET})" TEST_MODE
    TEST_MODE=${TEST_MODE:-n}
}

# Footer
print_footer() {
    echo ""
    echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
    echo -e "${DIM}              bad-antics • nullsec framework • $(date +%Y)${RESET}"
    echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
}

export -f load_shodan_target print_header print_module_header print_section
export -f success info warn error is_test_mode log_activity get_target ask_test_mode print_footer
