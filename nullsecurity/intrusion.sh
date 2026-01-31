#!/bin/bash
# NULLSEC Network Intrusion - bad-antics development
# Attack Module

# Source common library

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
source "$SCRIPT_DIR/nullsec-common.sh" 2>/dev/null || {
    RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'
    WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'; MAGENTA='\033[1;35m'
}

clear
print_module_header "NETWORK INTRUSION" "💀" 2>/dev/null || {
    echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
    echo -e "${RED}█${RESET}             ${WHITE}💀  NULLSEC NETWORK INTRUSION  💀${RESET}"
    echo -e "${RED}█${RESET}                  ${CYAN}[ bad-antics development ]${RESET}"
    echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
}
echo ""

# Check for Shodan target
SHODAN_TARGET="/home/antics/nullsec/.shodan_target"
if [ -f "$SHODAN_TARGET" ]; then
    source "$SHODAN_TARGET"
    if [ ! -z "$TARGET" ]; then
        echo -e "${GREEN}[+]${RESET} Shodan target loaded: ${GREEN}$TARGET${RESET}"
        echo ""
        read -p "$(echo -e ${YELLOW}'  [?] Use this target? (Y/n): '${RESET})" USE_SHODAN
        if [[ "$USE_SHODAN" =~ ^[Nn]$ ]]; then
            unset TARGET
        else
            PRIMARY_HOST="$TARGET"
        fi
    fi
fi

echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "  ${WHITE}TARGET CONFIGURATION${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo ""

if [ -z "$TARGET" ]; then
    read -p "$(echo -e ${WHITE}'  [>] Target network/IP (e.g., 192.168.1.0/24): '${RESET})" TARGET
    [ -z "$TARGET" ] && TARGET="10.0.0.0/24"
fi

if [ -z "$PRIMARY_HOST" ]; then
    read -p "$(echo -e ${WHITE}'  [>] Primary target host (e.g., 192.168.1.100): '${RESET})" PRIMARY_HOST
    [ -z "$PRIMARY_HOST" ] && PRIMARY_HOST="10.0.0.88"
fi

echo ""
echo -e "  ${YELLOW}Intrusion phases:${RESET}"
echo -e "    ${DIM}1) Full intrusion (all phases)${RESET}"
echo -e "    ${DIM}2) Reconnaissance only${RESET}"
echo -e "    ${DIM}3) Vulnerability scan only${RESET}"
echo -e "    ${DIM}4) Exploitation attempt${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select phase [1-4]: '${RESET})" PHASE_OPT
[ -z "$PHASE_OPT" ] && PHASE_OPT="1"

echo ""
read -p "$(echo -e ${YELLOW}'  [!] Demo mode? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}  ATTACK CONFIGURATION${RESET}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  ${CYAN}Target Network:${RESET}  $TARGET"
echo -e "  ${CYAN}Primary Host:${RESET}    $PRIMARY_HOST"
echo ""

run_recon() {
    echo -e "${RED}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
    echo -e "${WHITE}PHASE 1: RECONNAISSANCE${RESET}                                              "
    echo -e "${RED}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
    echo ""
    
    if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}[*]${RESET} Executing reconnaissance"
        sleep 0.5
        echo -e "${DIM}[*] Scanning network $TARGET...${RESET}"
        sleep 1
        echo -e "${GREEN}[+]${RESET} Host discovered: $PRIMARY_HOST"
        echo -e "${GREEN}[+]${RESET} Host discovered: $(echo $PRIMARY_HOST | sed 's/\.[0-9]*$/.1/')"
        echo -e "${GREEN}[+]${RESET} Host discovered: $(echo $PRIMARY_HOST | sed 's/\.[0-9]*$/.254/')"
        sleep 0.5
        echo -e "${DIM}[*] Port scanning $PRIMARY_HOST...${RESET}"
        sleep 0.8
        for p in 22 80 443 3306 8080; do echo -e "${GREEN}[+]${RESET} Open port: $p"; sleep 0.1; done
    else
        echo -e "${RED}[*]${RESET} Running live reconnaissance"
        if command -v nmap &> /dev/null; then
            echo -e "${YELLOW}[*] Host discovery on $TARGET...${RESET}"
            nmap -sn "$TARGET" 2>/dev/null | grep "Nmap scan" 
            echo ""
            echo -e "${YELLOW}[*] Port scan on $PRIMARY_HOST...${RESET}"
            nmap -sV --top-ports 20 "$PRIMARY_HOST" 2>/dev/null
        else
            echo -e "${RED}[!] nmap not installed${RESET}"
        fi
    fi
    echo ""
}

run_vuln() {
    echo -e "${RED}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
    echo -e "${WHITE}PHASE 2: VULNERABILITY ASSESSMENT${RESET}                                   "
    echo -e "${RED}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
    echo ""
    
    if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}[*]${RESET} Executing vulnerability scan"
        sleep 0.5
        echo -e "${DIM}[*] Running vulnerability scripts against $PRIMARY_HOST...${RESET}"
        sleep 1
        echo -e "${RED}[!]${RESET} VULN: CVE-2021-44228 - Log4Shell (CRITICAL)"
        sleep 0.3
        echo -e "${RED}[!]${RESET} VULN: CVE-2022-22965 - Spring4Shell (HIGH)"
        sleep 0.3
        echo -e "${YELLOW}[?]${RESET} VULN: CVE-2021-3156 - Sudo Baron Samedit (MEDIUM)"
        sleep 0.3
        echo -e "${GREEN}[+]${RESET} SSH weak key detected"
    else
        echo -e "${RED}[*]${RESET} Running live vulnerability scan"
        if command -v nmap &> /dev/null; then
            echo -e "${YELLOW}[*] Running NSE vuln scripts...${RESET}"
            nmap --script vuln "$PRIMARY_HOST" 2>/dev/null | head -50
        fi
    fi
    echo ""
}

run_exploit() {
    echo -e "${RED}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
    echo -e "${WHITE}PHASE 3: EXPLOITATION${RESET}                                                "
    echo -e "${RED}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
    echo ""
    
    if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}[*]${RESET} Executing exploitation"
        sleep 0.5
        echo -e "${DIM}[*] Attempting Log4Shell exploit on $PRIMARY_HOST:8080...${RESET}"
        sleep 1.5
        echo -e "${GREEN}[+]${RESET} Payload delivered successfully"
        sleep 0.5
        echo -e "${GREEN}[+]${RESET} Callback received from target"
        echo -e "${GREEN}[+]${RESET} Shell established - UID=0(root)"
        sleep 0.3
        echo ""
        echo -e "${WHITE}root@$PRIMARY_HOST:~#${RESET} id"
        echo "uid=0(root) gid=0(root) groups=0(root)"
    else
        echo -e "${RED}[*]${RESET}"
        echo -e "${YELLOW}[!] Manual exploitation required${RESET}"
        echo -e "${DIM}    Suggested tools: msfconsole, sqlmap, hydra${RESET}"
    fi
    echo ""
}

case $PHASE_OPT in
    1) run_recon; run_vuln; run_exploit ;;
    2) run_recon ;;
    3) run_vuln ;;
    4) run_exploit ;;
esac

echo -e "${GREEN}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
echo -e "${GREEN}█${RESET}  ${WHITE}INTRUSION COMPLETE${RESET}                                                    ${GREEN}█${RESET}"
echo -e "${GREEN}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
