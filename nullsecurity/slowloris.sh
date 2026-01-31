#!/bin/bash
# NULLSEC Slowloris DoS - bad-antics development

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
echo -e "${RED}▓▓▓ NULLSEC SLOWLORIS ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
read -p "$(echo -e ${WHITE}'  [>] Target URL: '${RESET})" TARGET; [ -z "$TARGET" ] && TARGET="http://192.168.1.100"
read -p "$(echo -e ${WHITE}'  [>] Port: '${RESET})" PORT; [ -z "$PORT" ] && PORT="80"
read -p "$(echo -e ${WHITE}'  [>] Connections: '${RESET})" CONNS; [ -z "$CONNS" ] && CONNS="500"
read -p "$(echo -e ${WHITE}'  [>] Duration (sec): '${RESET})" DURATION; [ -z "$DURATION" ] && DURATION="60"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing Slowloris attack on $TARGET"
    for i in $(seq 1 8); do
        echo -e "${DIM}[*] Opening connection $((i*50))/$CONNS...${RESET}"; sleep 0.3
    done
    echo -e "${GREEN}[+]${RESET} $CONNS connections opened"
    echo -e "${DIM}[*] Sending partial headers...${RESET}"; sleep 0.5
    for i in $(seq 1 5); do
        echo -e "${GREEN}[+]${RESET} Keeping connections alive... $((i*20))%"; sleep 0.4
    done
    echo -e "${RED}[!]${RESET} Target server unresponsive"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} slowloris -p $PORT -s $CONNS $TARGET"
fi
