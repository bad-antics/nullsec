#!/bin/bash
# NULLSEC Directory Bruteforce - FULLY FUNCTIONAL

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
echo -e "${RED}▓▓▓ NULLSEC DIR BRUTEFORCE ▓▓▓${RESET}"
echo ""

read -p "$(echo -e ${WHITE}'  [>] Target URL: '${RESET})" TARGET
[ -z "$TARGET" ] && TARGET="http://victim.com"
read -p "$(echo -e ${WHITE}'  [>] Wordlist: '${RESET})" WORDLIST
[ -z "$WORDLIST" ] && WORDLIST="/usr/share/wordlists/dirb/common.txt"
echo -e "  ${YELLOW}Tool:${RESET}"
echo -e "    1) gobuster"
echo -e "    2) ffuf"
echo -e "    3) dirb"
read -p "$(echo -e ${WHITE}'  [>] Select [1-3]: '${RESET})" TOOL
[ -z "$TOOL" ] && TOOL="1"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing directory bruteforce"
    echo -e "${DIM}[*] Target: $TARGET${RESET}"
    sleep 0.4
    echo -e "${GREEN}[200]${RESET} /admin"
    sleep 0.2
    echo -e "${GREEN}[200]${RESET} /uploads"
    sleep 0.2
    echo -e "${GREEN}[403]${RESET} /backup"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Live directory bruteforce"
    
    case $TOOL in
        1)
            if ! command -v gobuster &> /dev/null; then
                echo -e "${RED}[!] gobuster not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install gobuster${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] gobuster dir -u $TARGET -w $WORDLIST -t 50${RESET}"
            gobuster dir -u $TARGET -w $WORDLIST -t 50
            ;;
        2)
            if ! command -v ffuf &> /dev/null; then
                echo -e "${RED}[!] ffuf not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install ffuf${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] ffuf -u $TARGET/FUZZ -w $WORDLIST -mc all${RESET}"
            ffuf -u $TARGET/FUZZ -w $WORDLIST -mc all
            ;;
        3)
            if ! command -v dirb &> /dev/null; then
                echo -e "${RED}[!] dirb not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install dirb${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] dirb $TARGET $WORDLIST${RESET}"
            dirb $TARGET $WORDLIST
            ;;
    esac
    echo -e "${GREEN}[✓]${RESET} Complete"
fi
echo ""
