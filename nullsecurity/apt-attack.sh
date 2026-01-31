#!/bin/bash
# NULLSEC APT Attack - bad-antics development

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

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'; MAGENTA='\033[1;35m'
clear
echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
echo -e "${RED}█${RESET}         ${WHITE}🎯  NULLSEC APT CAMPAIGN  🎯${RESET}"
echo -e "${RED}█${RESET}                  ${CYAN}[ bad-antics development ]${RESET}"
echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
echo ""
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${CYAN}${RESET}  ${WHITE}APT CAMPAIGN CONFIGURATION${RESET}                                           ${CYAN}${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo ""
read -p "$(echo -e ${WHITE}'  [>] Target organization: '${RESET})" TARGET_ORG
[ -z "$TARGET_ORG" ] && TARGET_ORG="ACME Corporation"
read -p "$(echo -e ${WHITE}'  [>] Target network range: '${RESET})" TARGET_NET
[ -z "$TARGET_NET" ] && TARGET_NET="10.0.0.0/8"
read -p "$(echo -e ${WHITE}'  [>] C2 server address: '${RESET})" C2_SERVER
[ -z "$C2_SERVER" ] && C2_SERVER="c2.evil.com:443"
echo ""
echo -e "  ${YELLOW}APT Phase:${RESET}"
echo -e "    ${DIM}1) Reconnaissance${RESET}"
echo -e "    ${DIM}2) Initial Compromise${RESET}"
echo -e "    ${DIM}3) Establish Foothold${RESET}"
echo -e "    ${DIM}4) Privilege Escalation${RESET}"
echo -e "    ${DIM}5) Lateral Movement${RESET}"
echo -e "    ${DIM}6) Data Exfiltration${RESET}"
echo -e "    ${DIM}7) Full Campaign (all phases)${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select phase [1-7]: '${RESET})" APT_PHASE
[ -z "$APT_PHASE" ] && APT_PHASE="7"
echo ""
read -p "$(echo -e ${YELLOW}'  [!] Demo mode? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}
echo ""

if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing APT campaign against $TARGET_ORG"
    echo ""
    
    run_phase() {
        local phase=$1; local name=$2
        echo -e "${RED}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
        echo -e "${WHITE}PHASE $phase: $name${RESET}"
        echo -e "${RED}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
    }
    
    if [ "$APT_PHASE" = "1" ] || [ "$APT_PHASE" = "7" ]; then
        run_phase 1 "RECONNAISSANCE"
        echo -e "${DIM}[*] OSINT gathering on $TARGET_ORG...${RESET}"; sleep 0.5
        echo -e "${GREEN}[+]${RESET} LinkedIn: 450 employees found"
        echo -e "${GREEN}[+]${RESET} Email format: firstname.lastname@acme.com"
        echo -e "${GREEN}[+]${RESET} Tech stack: Microsoft 365, Cisco, VMware"
        echo ""
    fi
    
    if [ "$APT_PHASE" = "2" ] || [ "$APT_PHASE" = "7" ]; then
        run_phase 2 "INITIAL COMPROMISE"
        echo -e "${DIM}[*] Sending spearphish to executives...${RESET}"; sleep 0.5
        echo -e "${GREEN}[+]${RESET} Payload delivered to cfo@acme.com"
        echo -e "${GREEN}[+]${RESET} Macro executed, beacon established"
        echo ""
    fi
    
    if [ "$APT_PHASE" = "3" ] || [ "$APT_PHASE" = "7" ]; then
        run_phase 3 "ESTABLISH FOOTHOLD"
        echo -e "${DIM}[*] Deploying persistence...${RESET}"; sleep 0.5
        echo -e "${GREEN}[+]${RESET} Registry run key installed"
        echo -e "${GREEN}[+]${RESET} Scheduled task created"
        echo -e "${GREEN}[+]${RESET} C2 beacon to $C2_SERVER every 5min"
        echo ""
    fi
    
    if [ "$APT_PHASE" = "4" ] || [ "$APT_PHASE" = "7" ]; then
        run_phase 4 "PRIVILEGE ESCALATION"
        echo -e "${DIM}[*] Escalating privileges...${RESET}"; sleep 0.5
        echo -e "${GREEN}[+]${RESET} UAC bypassed via fodhelper"
        echo -e "${GREEN}[+]${RESET} SYSTEM token obtained"
        echo -e "${GREEN}[+]${RESET} Credential dump: 15 hashes"
        echo ""
    fi
    
    if [ "$APT_PHASE" = "5" ] || [ "$APT_PHASE" = "7" ]; then
        run_phase 5 "LATERAL MOVEMENT"
        echo -e "${DIM}[*] Moving laterally in $TARGET_NET...${RESET}"; sleep 0.5
        echo -e "${GREEN}[+]${RESET} DC01.acme.local - compromised"
        echo -e "${GREEN}[+]${RESET} FILESRV.acme.local - compromised"
        echo -e "${GREEN}[+]${RESET} Domain Admin obtained"
        echo ""
    fi
    
    if [ "$APT_PHASE" = "6" ] || [ "$APT_PHASE" = "7" ]; then
        run_phase 6 "DATA EXFILTRATION"
        echo -e "${DIM}[*] Exfiltrating sensitive data...${RESET}"; sleep 0.5
        echo -e "${RED}[EXFIL]${RESET} /Finance/Q4_Reports.xlsx (2.5MB)"
        echo -e "${RED}[EXFIL]${RESET} /HR/Employee_Data.csv (15MB)"
        echo -e "${RED}[EXFIL]${RESET} /RnD/Patents/ (450MB)"
        echo -e "${GREEN}[+]${RESET} Total: 467.5MB exfiltrated via HTTPS"
        echo ""
    fi
    
    echo -e "${GREEN}[✓]${RESET} SIMULATION - APT campaign simulation complete"
else
    echo -e "${RED}[*]${RESET}"
    echo -e "${YELLOW}[*] Use Cobalt Strike, Sliver, or similar C2 framework${RESET}"
fi
