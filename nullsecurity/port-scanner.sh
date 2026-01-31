#!/bin/bash
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# █  NULLSEC ADVANCED PORT SCANNER - Full Network Reconnaissance Suite     █
# █                    [ bad-antics development ]                           █
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# FULLY FUNCTIONAL - Production Ready


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

# Output directory
OUTPUT_DIR="/home/antics/nullsec/logs/scans"
mkdir -p "$OUTPUT_DIR"

clear
echo -e "${RED}"
cat << 'BANNER'
    ██▓███   ▒█████   ██▀███  ▄▄▄█████▓     ██████  ▄████▄   ▄▄▄       ███▄    █ 
   ▓██░  ██▒▒██▒  ██▒▓██ ▒ ██▒▓  ██▒ ▓▒   ▒██    ▒ ▒██▀ ▀█  ▒████▄     ██ ▀█   █ 
   ▓██░ ██▓▒▒██░  ██▒▓██ ░▄█ ▒▒ ▓██░ ▒░   ░ ▓██▄   ▒▓█    ▄ ▒██  ▀█▄  ▓██  ▀█ ██▒
   ▒██▄█▓▒ ▒▒██   ██░▒██▀▀█▄  ░ ▓██▓ ░      ▒   ██▒▒▓▓▄ ▄██▒░██▄▄▄▄██ ▓██▒  ▐▌██▒
   ▒██▒ ░  ░░ ████▓▒░░██▓ ▒██▒  ▒██▒ ░    ▒██████▒▒▒ ▓███▀ ░ ▓█   ▓██▒▒██░   ▓██░
BANNER
echo -e "${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}              ☠  ADVANCED NETWORK RECONNAISSANCE  ☠${RESET}"
echo -e "${DIM}                 Comprehensive Port & Service Analysis${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Check for Shodan target
SHODAN_TARGET="/home/antics/nullsec/.shodan_target"
if [ -f "$SHODAN_TARGET" ]; then
    source "$SHODAN_TARGET"
    if [ ! -z "$TARGET" ]; then
        echo -e "${GREEN}[+]${RESET} Shodan target loaded: ${GREEN}$TARGET${RESET}"
        [ ! -z "$PORTS" ] && echo -e "${DIM}    Known ports: $PORTS${RESET}"
        echo ""
        read -p "$(echo -e ${YELLOW}'  [?] Use Shodan target? (Y/n): '${RESET})" USE_SHODAN
        if [[ "$USE_SHODAN" =~ ^[Nn]$ ]]; then
            unset TARGET
        fi
    fi
fi

echo -e "${YELLOW}  SELECT SCAN MODE:${RESET}"
echo ""
echo -e "  ${RED}[1]${RESET}  🔍 Quick Scan        - Top 100 ports, fast"
echo -e "  ${RED}[2]${RESET}  📊 Standard Scan     - Top 1000 ports + version"
echo -e "  ${RED}[3]${RESET}  🔬 Deep Scan         - All ports + OS + scripts"
echo -e "  ${RED}[4]${RESET}  🎯 Stealth Scan      - SYN + decoys + timing"
echo -e "  ${RED}[5]${RESET}  💀 Aggressive Scan   - Everything + vuln scripts"
echo -e "  ${RED}[6]${RESET}  🌐 Web Server Scan   - HTTP/HTTPS focused"
echo -e "  ${RED}[7]${RESET}  🔐 Service Enum      - Detailed service analysis"
echo -e "  ${RED}[8]${RESET}  📡 UDP Scan          - Top UDP services"
echo -e "  ${RED}[9]${RESET}  🖥️  SMB/NetBIOS Scan  - Windows enumeration"
echo -e "  ${RED}[10]${RESET} 🗄️  Database Scan     - DB ports + auth check"
echo -e "  ${RED}[11]${RESET} 🛡️  Vulnerability Scan - CVE detection"
echo -e "  ${RED}[12]${RESET} 🏭 ICS/SCADA Scan    - Industrial systems"
echo -e "  ${RED}[13]${RESET} ⚙️  Custom Scan       - Build your own"
echo -e "  ${RED}[14]${RESET} 📋 Batch Scan        - Multiple targets"
echo ""
echo -e "  ${GREEN}[Q]${RESET}  Back to menu"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
read -p "$(echo -e ${WHITE}'  [>] Select mode [1-14]: '${RESET})" SCAN_MODE

[[ "$SCAN_MODE" =~ ^[Qq]$ ]] && exit 0
[ -z "$SCAN_MODE" ] && SCAN_MODE="2"

# Get target if not set
if [ -z "$TARGET" ]; then
    echo ""
    read -p "$(echo -e ${WHITE}'  [>] Target (IP/CIDR/hostname/range): '${RESET})" TARGET
    [ -z "$TARGET" ] && TARGET="192.168.1.1"
fi

# Timestamp for output files
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_BASE="$OUTPUT_DIR/scan_${TARGET/\//_}_$TIMESTAMP"

echo ""
echo -e "${YELLOW}  OUTPUT OPTIONS:${RESET}"
echo -e "  ${DIM}1) Terminal only${RESET}"
echo -e "  ${DIM}2) Save to file (text)${RESET}"
echo -e "  ${DIM}3) Save all formats (txt, xml, json)${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select [1-3]: '${RESET})" OUTPUT_OPT
[ -z "$OUTPUT_OPT" ] && OUTPUT_OPT="2"

echo ""
read -p "$(echo -e ${YELLOW}'  [!] Demo mode? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}  EXECUTING RECONNAISSANCE${RESET}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Build nmap command based on mode
build_nmap_cmd() {
    local mode=$1
    local base_cmd="nmap"
    
    case $OUTPUT_OPT in
        2) base_cmd="$base_cmd -oN ${OUTPUT_BASE}.txt" ;;
        3) base_cmd="$base_cmd -oA ${OUTPUT_BASE}" ;;
    esac
    
    case $mode in
        1) echo "$base_cmd --top-ports 100 -T4 -Pn" ;;
        2) echo "$base_cmd --top-ports 1000 -sV -T4 -Pn" ;;
        3) echo "$base_cmd -p- -sV -sC -O -T4 -Pn" ;;
        4) echo "$base_cmd -sS -T2 -f --mtu 24 -D RND:5 --data-length 200 --randomize-hosts -Pn" ;;
        5) echo "$base_cmd -p- -A -T4 --script=vuln,exploit,auth -Pn" ;;
        6) echo "$base_cmd -p 80,443,8080,8443,8000,8888,3000,5000,9000 -sV --script=http-enum,http-title,http-headers,http-methods,http-vuln*,ssl-cert,ssl-enum-ciphers -Pn" ;;
        7) echo "$base_cmd --top-ports 1000 -sV --version-intensity 5 -sC -Pn" ;;
        8) echo "$base_cmd -sU --top-ports 50 -sV -Pn" ;;
        9) echo "$base_cmd -p 139,445,137,138,135,389,636,3268,3269 -sV --script=smb-enum*,smb-vuln*,smb-os-discovery,smb-protocols,smb-security-mode,nbstat -Pn" ;;
        10) echo "$base_cmd -p 1433,1434,3306,5432,27017,6379,9200,11211,5984,1521,1830 -sV --script=mysql*,ms-sql*,mongodb*,redis*,oracle* -Pn" ;;
        11) echo "$base_cmd -sV --script=vuln,vulners --script-args mincvss=5.0 -Pn" ;;
        12) echo "$base_cmd -p 102,502,1089,1091,2222,4000,4840,20000,34962,34963,34964,44818,47808,55000,55003 -sV --script=modbus-discover,s7-info,enip-info,fox-info,bacnet-info -Pn" ;;
        13) echo "custom" ;;
        14) echo "batch" ;;
    esac
}

# Simulate output for demo mode
simulate_scan() {
    local mode=$1
    echo -e "${YELLOW}[*]${RESET} Running simulated scan on $TARGET"
    echo ""
    sleep 0.5
    
    echo -e "${DIM}Starting Nmap 7.94 ( https://nmap.org )${RESET}"
    echo -e "${DIM}Nmap scan report for $TARGET${RESET}"
    echo -e "${DIM}Host is up (0.0032s latency).${RESET}"
    echo ""
    
    case $mode in
        1|2|3|5|7)
            ports=(21 22 23 25 53 80 110 139 143 443 445 993 995 1433 3306 3389 5432 8080 8443)
            services=("ftp" "ssh" "telnet" "smtp" "domain" "http" "pop3" "netbios-ssn" "imap" "https" "microsoft-ds" "imaps" "pop3s" "ms-sql-s" "mysql" "ms-wbt-server" "postgresql" "http-proxy" "https-alt")
            versions=("vsftpd 3.0.5" "OpenSSH 8.9p1" "Linux telnetd" "Postfix smtpd" "ISC BIND 9.18" "Apache httpd 2.4.54" "Dovecot pop3d" "Samba 4.16" "Dovecot imapd" "Apache httpd 2.4.54" "Samba 4.16" "Dovecot imaps" "Dovecot pop3s" "Microsoft SQL Server 2019" "MySQL 8.0.32" "Microsoft Terminal Services" "PostgreSQL 15.2" "Squid 5.7" "Apache Tomcat")
            
            echo -e "${WHITE}PORT      STATE    SERVICE        VERSION${RESET}"
            for i in ${!ports[@]}; do
                port=${ports[$i]}; service=${services[$i]}; version=${versions[$i]}
                state="open"; [ $((RANDOM % 5)) -eq 0 ] && state="filtered"
                if [ "$state" = "open" ]; then
                    printf "${GREEN}%-9s${RESET} %-8s %-14s %s\n" "$port/tcp" "$state" "$service" "${version}"
                else
                    printf "${YELLOW}%-9s${RESET} %-8s %-14s\n" "$port/tcp" "$state" "$service"
                fi
                sleep 0.03
            done
            ;;
        6)
            echo -e "${WHITE}PORT      STATE  SERVICE   VERSION${RESET}"
            echo -e "${GREEN}80/tcp    ${RESET}open   http      Apache httpd 2.4.54 ((Ubuntu))"
            echo -e "${GREEN}443/tcp   ${RESET}open   ssl/http  Apache httpd 2.4.54 ((Ubuntu))"
            echo -e "${GREEN}8080/tcp  ${RESET}open   http      nginx 1.24.0"
            echo ""
            echo -e "${CYAN}| http-enum:${RESET}"
            echo -e "|   /admin/: Admin portal"
            echo -e "|   /login.php: Login page"
            echo -e "|   /api/: API endpoint"
            echo -e "|   /backup/: Directory listing"
            echo -e "|   /.git/: Git repository"
            echo ""
            echo -e "${CYAN}| http-title:${RESET} Welcome to Example Site"
            echo -e "${CYAN}| ssl-cert:${RESET} CN=example.com, Issuer: Let's Encrypt"
            ;;
        9)
            echo -e "${WHITE}PORT      STATE  SERVICE       VERSION${RESET}"
            echo -e "${GREEN}139/tcp   ${RESET}open   netbios-ssn   Samba 4.16.4"
            echo -e "${GREEN}445/tcp   ${RESET}open   microsoft-ds  Samba 4.16.4"
            echo ""
            echo -e "${RED}| smb-vuln-ms17-010: VULNERABLE${RESET}"
            echo -e "|   Remote Code Execution (EternalBlue)"
            echo ""
            echo -e "${CYAN}| smb-os-discovery:${RESET}"
            echo -e "|   OS: Windows Server 2019 Standard 17763"
            echo -e "|   Computer: WIN-DC01"
            echo ""
            echo -e "${CYAN}| smb-enum-shares:${RESET}"
            echo -e "|   \\\\$TARGET\\ADMIN$ (admin only)"
            echo -e "|   \\\\$TARGET\\Public (READ access)"
            echo -e "|   \\\\$TARGET\\HR_Data (READ access)"
            ;;
        10)
            echo -e "${WHITE}PORT      STATE  SERVICE       VERSION${RESET}"
            echo -e "${GREEN}3306/tcp  ${RESET}open   mysql         MySQL 8.0.32"
            echo -e "${GREEN}5432/tcp  ${RESET}open   postgresql    PostgreSQL 15.2"
            echo -e "${GREEN}27017/tcp ${RESET}open   mongodb       MongoDB 6.0.4"
            echo -e "${GREEN}6379/tcp  ${RESET}open   redis         Redis 7.0.8"
            echo ""
            echo -e "${RED}| mysql-info: Anonymous login allowed${RESET}"
            echo -e "${RED}| redis-info: No authentication required${RESET}"
            ;;
        11)
            echo -e "${WHITE}PORT      STATE  SERVICE${RESET}"
            echo -e "${GREEN}22/tcp    ${RESET}open   ssh"
            echo -e "${GREEN}80/tcp    ${RESET}open   http"
            echo -e "${GREEN}443/tcp   ${RESET}open   https"
            echo ""
            echo -e "${RED}█ VULNERABILITIES DETECTED █${RESET}"
            echo ""
            echo -e "${RED}[CRITICAL]${RESET} CVE-2023-44487 - HTTP/2 Rapid Reset Attack (CVSS: 7.5)"
            echo -e "${RED}[HIGH]${RESET} CVE-2023-25690 - Apache mod_proxy_uwsgi (CVSS: 9.8)"
            echo -e "${YELLOW}[MEDIUM]${RESET} CVE-2023-28321 - OpenSSH Username Enumeration (CVSS: 5.3)"
            ;;
        12)
            echo -e "${WHITE}PORT       STATE  SERVICE       VERSION${RESET}"
            echo -e "${GREEN}102/tcp    ${RESET}open   iso-tsap      Siemens S7 PLC"
            echo -e "${GREEN}502/tcp    ${RESET}open   modbus        Modbus/TCP"
            echo ""
            echo -e "${RED}| s7-info:${RESET} Siemens S7-1500 CPU 1516F-3 PN/DP V2.9.4"
            echo -e "${RED}| modbus-discover: No authentication enabled${RESET}"
            ;;
    esac
    
    echo ""
    if [ "$mode" = "3" ] || [ "$mode" = "5" ]; then
        echo -e "${CYAN}OS Detection:${RESET} Linux 5.4.0-150-generic (Ubuntu 20.04)"
        echo ""
    fi
    echo -e "${DIM}Nmap done: 1 IP address (1 host up) scanned in 24.73 seconds${RESET}"
}

# Execute the scan
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    simulate_scan "$SCAN_MODE"
else
    if ! command -v nmap &> /dev/null; then
        echo -e "${RED}[!] ERROR: nmap is not installed${RESET}"
        echo -e "${YELLOW}[*] Install with: sudo apt install nmap${RESET}"
        exit 1
    fi
    
    NMAP_CMD=$(build_nmap_cmd "$SCAN_MODE")
    
    if [ "$NMAP_CMD" = "custom" ]; then
        echo -e "${YELLOW}[*] Custom Scan Configuration${RESET}"
        echo ""
        read -p "$(echo -e ${WHITE}'  [>] Ports (22,80,443 or 1-1000 or -): '${RESET})" CUSTOM_PORTS
        [ -z "$CUSTOM_PORTS" ] && CUSTOM_PORTS="1-1000"
        
        echo -e "${DIM}  Scan types: s=SYN, t=Connect, u=UDP, a=ACK, f=FIN${RESET}"
        read -p "$(echo -e ${WHITE}'  [>] Scan type [s]: '${RESET})" CUSTOM_TYPE
        [ -z "$CUSTOM_TYPE" ] && CUSTOM_TYPE="s"
        
        read -p "$(echo -e ${WHITE}'  [>] Version detection? (y/N): '${RESET})" CUSTOM_VERSION
        read -p "$(echo -e ${WHITE}'  [>] OS detection? (y/N): '${RESET})" CUSTOM_OS
        read -p "$(echo -e ${WHITE}'  [>] Script scan? (y/N): '${RESET})" CUSTOM_SCRIPT
        read -p "$(echo -e ${WHITE}'  [>] Timing (0-5) [4]: '${RESET})" CUSTOM_TIMING
        [ -z "$CUSTOM_TIMING" ] && CUSTOM_TIMING="4"
        read -p "$(echo -e ${WHITE}'  [>] Use decoys? (y/N): '${RESET})" CUSTOM_DECOY
        
        NMAP_CMD="nmap -p $CUSTOM_PORTS -s${CUSTOM_TYPE^^} -T$CUSTOM_TIMING"
        [[ "$CUSTOM_VERSION" =~ ^[Yy]$ ]] && NMAP_CMD="$NMAP_CMD -sV"
        [[ "$CUSTOM_OS" =~ ^[Yy]$ ]] && NMAP_CMD="$NMAP_CMD -O"
        [[ "$CUSTOM_SCRIPT" =~ ^[Yy]$ ]] && NMAP_CMD="$NMAP_CMD -sC"
        [[ "$CUSTOM_DECOY" =~ ^[Yy]$ ]] && NMAP_CMD="$NMAP_CMD -D RND:5"
        NMAP_CMD="$NMAP_CMD -Pn"
        
        case $OUTPUT_OPT in
            2) NMAP_CMD="$NMAP_CMD -oN ${OUTPUT_BASE}.txt" ;;
            3) NMAP_CMD="$NMAP_CMD -oA ${OUTPUT_BASE}" ;;
        esac
        
    elif [ "$NMAP_CMD" = "batch" ]; then
        echo -e "${YELLOW}[*] Batch Scan Mode${RESET}"
        read -p "$(echo -e ${WHITE}'  [>] Target file path (or enter for manual): '${RESET})" TARGET_FILE
        
        if [ -f "$TARGET_FILE" ]; then
            echo -e "${GREEN}[+]${RESET} Loading targets from $TARGET_FILE"
            NMAP_CMD="nmap -iL $TARGET_FILE --top-ports 100 -sV -T4 -Pn"
        else
            echo -e "${YELLOW}[*]${RESET} Enter targets (one per line, blank to finish):"
            BATCH_TARGETS=""
            while true; do read -p "  > " T; [ -z "$T" ] && break; BATCH_TARGETS="$BATCH_TARGETS $T"; done
            NMAP_CMD="nmap $BATCH_TARGETS --top-ports 100 -sV -T4 -Pn"
        fi
        
        case $OUTPUT_OPT in
            2) NMAP_CMD="$NMAP_CMD -oN ${OUTPUT_BASE}.txt" ;;
            3) NMAP_CMD="$NMAP_CMD -oA ${OUTPUT_BASE}" ;;
        esac
        TARGET="batch"
    fi
    
    [ "$TARGET" != "batch" ] && NMAP_CMD="$NMAP_CMD $TARGET"
    
    echo -e "${CYAN}[*] Command: $NMAP_CMD${RESET}"
    echo ""
    
    if [[ "$NMAP_CMD" =~ -s[SAFXNU] ]] || [[ "$NMAP_CMD" =~ "-O" ]]; then
        if [ "$EUID" -ne 0 ]; then
            echo -e "${YELLOW}[!] Privileged scan requires sudo${RESET}"
            sudo $NMAP_CMD
        else
            eval $NMAP_CMD
        fi
    else
        eval $NMAP_CMD
    fi
    
    if [ "$OUTPUT_OPT" != "1" ]; then
        echo ""
        echo -e "${GREEN}[+]${RESET} Results saved to:"
        [ -f "${OUTPUT_BASE}.txt" ] && echo -e "    Text: ${OUTPUT_BASE}.txt"
        [ -f "${OUTPUT_BASE}.xml" ] && echo -e "    XML:  ${OUTPUT_BASE}.xml"
    fi
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}█${RESET}  ${WHITE}RECONNAISSANCE COMPLETE${RESET} - Target: $TARGET"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
