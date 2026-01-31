#!/bin/bash
# NULLSEC Social Engineering - bad-antics development

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
echo -e "${RED}█${RESET}          ${WHITE}🎭  NULLSEC SOCIAL ENGINEERING  🎭${RESET}"
echo -e "${RED}█${RESET}                  ${CYAN}[ bad-antics development ]${RESET}"
echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
echo ""

echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${CYAN}${RESET}  ${WHITE}CAMPAIGN CONFIGURATION${RESET}                                               ${CYAN}${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo ""

echo -e "  ${YELLOW}Attack vector:${RESET}"
echo -e "    ${DIM}1) Phishing email campaign${RESET}"
echo -e "    ${DIM}2) Credential harvesting page${RESET}"
echo -e "    ${DIM}3) Pretexting call script${RESET}"
echo -e "    ${DIM}4) USB drop attack${RESET}"
echo -e "    ${DIM}5) Spear phishing${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select vector [1-5]: '${RESET})" VECTOR
[ -z "$VECTOR" ] && VECTOR="1"

case $VECTOR in
    1|5)
        read -p "$(echo -e ${WHITE}'  [>] Target email(s): '${RESET})" TARGET_EMAIL
        [ -z "$TARGET_EMAIL" ] && TARGET_EMAIL="victim@company.com"
        read -p "$(echo -e ${WHITE}'  [>] Sender email: '${RESET})" SENDER
        [ -z "$SENDER" ] && SENDER="it-support@company.com"
        read -p "$(echo -e ${WHITE}'  [>] Subject: '${RESET})" SUBJECT
        [ -z "$SUBJECT" ] && SUBJECT="Urgent: Password Reset Required"
        read -p "$(echo -e ${WHITE}'  [>] Phishing URL: '${RESET})" PHISH_URL
        [ -z "$PHISH_URL" ] && PHISH_URL="http://company-login.evil.com"
        ;;
    2)
        read -p "$(echo -e ${WHITE}'  [>] Clone target (URL): '${RESET})" CLONE_URL
        [ -z "$CLONE_URL" ] && CLONE_URL="https://login.microsoft.com"
        read -p "$(echo -e ${WHITE}'  [>] Listen port: '${RESET})" PORT
        [ -z "$PORT" ] && PORT="8080"
        ;;
    3)
        read -p "$(echo -e ${WHITE}'  [>] Target phone: '${RESET})" TARGET_PHONE
        [ -z "$TARGET_PHONE" ] && TARGET_PHONE="+1-555-0123"
        read -p "$(echo -e ${WHITE}'  [>] Pretext (IT/HR/Vendor): '${RESET})" PRETEXT
        [ -z "$PRETEXT" ] && PRETEXT="IT Support"
        ;;
    4)
        read -p "$(echo -e ${WHITE}'  [>] Payload type (doc/exe/hta): '${RESET})" PAYLOAD_TYPE
        [ -z "$PAYLOAD_TYPE" ] && PAYLOAD_TYPE="doc"
        read -p "$(echo -e ${WHITE}'  [>] File name: '${RESET})" FILENAME
        [ -z "$FILENAME" ] && FILENAME="Employee_Salaries_2024"
        ;;
esac

echo ""
read -p "$(echo -e ${YELLOW}'  [!] Demo mode? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}  SOCIAL ENGINEERING ATTACK${RESET}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing social engineering attack"
    echo ""
    
    case $VECTOR in
        1|5)
            echo -e "${DIM}[*] Preparing phishing email...${RESET}"
            sleep 0.5
            echo ""
            echo -e "${WHITE}━━━ EMAIL PREVIEW ━━━${RESET}"
            echo -e "${CYAN}From:${RESET} $SENDER"
            echo -e "${CYAN}To:${RESET} $TARGET_EMAIL"
            echo -e "${CYAN}Subject:${RESET} $SUBJECT"
            echo ""
            echo -e "${DIM}Dear Employee,${RESET}"
            echo -e "${DIM}Your password will expire in 24 hours.${RESET}"
            echo -e "${DIM}Click here to reset: $PHISH_URL${RESET}"
            echo ""
            sleep 1
            echo -e "${GREEN}[+]${RESET} Email queued for delivery"
            echo -e "${GREEN}[+]${RESET} Tracking pixel embedded"
            ;;
        2)
            echo -e "${DIM}[*] Cloning $CLONE_URL...${RESET}"
            sleep 1
            echo -e "${GREEN}[+]${RESET} Page cloned successfully"
            echo -e "${GREEN}[+]${RESET} Credential harvester injected"
            echo -e "${GREEN}[+]${RESET} Server ready on port $PORT"
            echo ""
            echo -e "${WHITE}━━━ CAPTURED CREDENTIALS ━━━${RESET}"
            sleep 1.5
            echo -e "${RED}[CRED]${RESET} admin@company.com : P@ssw0rd123"
            echo -e "${RED}[CRED]${RESET} john.doe@company.com : Summer2024!"
            ;;
        3)
            echo -e "${DIM}[*] Generating call script for $PRETEXT...${RESET}"
            sleep 0.5
            echo ""
            echo -e "${WHITE}━━━ CALL SCRIPT ━━━${RESET}"
            echo -e "${CYAN}Target:${RESET} $TARGET_PHONE"
            echo ""
            echo -e "${DIM}\"Hello, this is $PRETEXT calling about an urgent"
            echo -e "security matter with your account. We've detected"
            echo -e "suspicious activity and need to verify your identity."
            echo -e "Can you please confirm your employee ID and"
            echo -e "the last 4 digits of your SSN?\"${RESET}"
            ;;
        4)
            echo -e "${DIM}[*] Creating USB drop payload...${RESET}"
            sleep 0.5
            echo -e "${GREEN}[+]${RESET} Payload: ${FILENAME}.${PAYLOAD_TYPE}"
            echo -e "${GREEN}[+]${RESET} Macro embedded with reverse shell"
            echo -e "${GREEN}[+]${RESET} AutoRun configured"
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} - live social engineering setup"
    echo ""
    
    case $VECTOR in
        2)
            if command -v goclone &> /dev/null || command -v httrack &> /dev/null; then
                echo -e "${YELLOW}[*] Cloning target page...${RESET}"
                # httrack "$CLONE_URL" -O /tmp/phish 2>/dev/null
            else
                echo -e "${YELLOW}[*] Use SET (Social Engineering Toolkit) for full functionality${RESET}"
                echo -e "${DIM}    sudo setoolkit${RESET}"
            fi
            ;;
        *)
            echo -e "${YELLOW}[*] Use SET or Gophish for production campaigns${RESET}"
            ;;
    esac
fi

echo ""
echo -e "${GREEN}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
echo -e "${GREEN}█${RESET}  ${WHITE}CAMPAIGN COMPLETE${RESET}                                                    ${GREEN}█${RESET}"
echo -e "${GREEN}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
