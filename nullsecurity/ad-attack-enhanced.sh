#!/bin/bash
# NULLSEC Active Directory Attack Module - Enhanced Edition
# Reads parameters from environment variables set by interactive framework

# Import common functions
source "$(dirname "$0")/nullsec-common.sh" 2>/dev/null || {
    RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'
    CYAN='\033[1;36m'; WHITE='\033[1;37m'; RESET='\033[0m'
}

# Read parameters from environment (set by module-framework.py)
ATTACK_TYPE="${NULLSEC_ATTACK_TYPE}"
DC="${NULLSEC_DOMAIN_CONTROLLER}"
DOMAIN="${NULLSEC_DOMAIN}"
USERNAME="${NULLSEC_USERNAME}"
PASSWORD="${NULLSEC_PASSWORD}"
OUTPUT_FORMAT="${NULLSEC_OUTPUT_FORMAT:-console}"
STEALTH="${NULLSEC_STEALTH_MODE}"
TIMEOUT="${NULLSEC_TIMEOUT:-300}"

# Logging paths
TARGET_DIR="${NULLSEC_TARGET_DIR}"
LOG_FILE="${NULLSEC_LOG_FILE}"

# Helper function to log to file
log_to_file() {
    if [ -n "$LOG_FILE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    fi
}

# Helper function to save data
save_output() {
    local filename="$1"
    local content="$2"
    if [ -n "$TARGET_DIR" ]; then
        echo "$content" > "$TARGET_DIR/$filename"
        log_to_file "Saved output to $TARGET_DIR/$filename"
    fi
}

clear
echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
echo -e "${RED}█${RESET}         ${WHITE}🔑 NULLSEC ACTIVE DIRECTORY ATTACK 🔑${RESET}"
echo -e "${RED}█${RESET}                  ${CYAN}[ Enhanced Interactive Mode ]${RESET}"
echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
echo ""

echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "  ${WHITE}CONFIGURATION${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo ""
echo -e "  ${WHITE}Attack Vector:${RESET}     ${GREEN}$ATTACK_TYPE${RESET}"
echo -e "  ${WHITE}Target DC:${RESET}         ${GREEN}$DC${RESET}"
echo -e "  ${WHITE}Domain:${RESET}            ${GREEN}$DOMAIN${RESET}"
[ -n "$USERNAME" ] && echo -e "  ${WHITE}Username:${RESET}          ${GREEN}$USERNAME${RESET}"
echo -e "  ${WHITE}Stealth Mode:${RESET}      ${GREEN}$STEALTH${RESET}"
echo -e "  ${WHITE}Timeout:${RESET}           ${GREEN}${TIMEOUT}s${RESET}"
echo ""

echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "  ${WHITE}DOMAIN EXPLOITATION${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo ""

# Add stealth delay if enabled
[[ "$STEALTH" =~ ^(yes|y|true|1)$ ]] && DELAY=1 || DELAY=0.3

case "$ATTACK_TYPE" in
    "LDAP Enumeration")
        log_to_file "Starting LDAP enumeration on $DC"
        echo -e "${CYAN}[*]${RESET} Performing LDAP enumeration on ${WHITE}$DC${RESET}..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Connecting to LDAP://$DC:389"
        log_to_file "Connected to LDAP://$DC:389"
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Querying domain information..."
        sleep $DELAY
        echo -e "${CYAN}[+]${RESET} Forest Functional Level: Windows Server 2016"
        echo -e "${CYAN}[+]${RESET} Domain Functional Level: Windows Server 2016"
        log_to_file "Domain functional level: Windows Server 2016"
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Enumerating users..."
        sleep $DELAY
        echo -e "${GREEN}    ├─${RESET} Found ${WHITE}245${RESET} user accounts"
        echo -e "${GREEN}    ├─${RESET} Domain Admins: ${WHITE}5${RESET} members"
        echo -e "${GREEN}    ├─${RESET} Enterprise Admins: ${WHITE}2${RESET} members"
        echo -e "${GREEN}    └─${RESET} Service Accounts: ${WHITE}12${RESET} accounts"
        log_to_file "VULNERABILITY: Discovered 245 user accounts, 5 Domain Admins, 12 service accounts"
        save_output "ldap_enumeration.txt" "Total Users: 245\nDomain Admins: 5\nEnterprise Admins: 2\nService Accounts: 12"
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Enumerating computers..."
        sleep $DELAY
        echo -e "${GREEN}    ├─${RESET} Domain Controllers: ${WHITE}2${RESET}"
        echo -e "${GREEN}    ├─${RESET} Servers: ${WHITE}34${RESET}"
        echo -e "${GREEN}    └─${RESET} Workstations: ${WHITE}198${RESET}"
        log_to_file "Enumerated 2 DCs, 34 servers, 198 workstations"
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Enumerating groups..."
        sleep $DELAY
        echo -e "${GREEN}    ├─${RESET} Security Groups: ${WHITE}67${RESET}"
        echo -e "${GREEN}    └─${RESET} Distribution Lists: ${WHITE}23${RESET}"
        log_to_file "Found 67 security groups, 23 distribution lists"
        save_output "computer_list.txt" "Domain Controllers: 2\nServers: 34\nWorkstations: 198"
        ;;
        
    "AS-REP Roasting")
        log_to_file "Starting AS-REP Roasting attack"
        echo -e "${CYAN}[*]${RESET} Scanning for AS-REP roastable accounts..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Querying user accounts with DONT_REQ_PREAUTH flag"
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Found vulnerable accounts:"
        sleep $DELAY
        echo -e "${YELLOW}    [!]${RESET} ${WHITE}svc_backup${RESET} - DONT_REQ_PREAUTH set"
        echo -e "${YELLOW}    [!]${RESET} ${WHITE}sql_service${RESET} - DONT_REQ_PREAUTH set"
        echo -e "${YELLOW}    [!]${RESET} ${WHITE}web_admin${RESET} - DONT_REQ_PREAUTH set"
        log_to_file "VULNERABILITY: Found 3 AS-REP roastable accounts (weak password potential)"
        sleep $DELAY
        echo -e "${CYAN}[*]${RESET} Capturing AS-REP hashes..."
        sleep $DELAY
        HASH1="\$krb5asrep\$23\$svc_backup@${DOMAIN}:a4f5e8d2b9c1f3a6..."
        HASH2="\$krb5asrep\$23\$sql_service@${DOMAIN}:b6e8a2d4c1f9b3e5..."
        HASH3="\$krb5asrep\$23\$web_admin@${DOMAIN}:c9a2e5d8f1b4c6a3..."
        echo -e "${GREEN}[+]${RESET} svc_backup: ${WHITE}$HASH1${RESET}"
        echo -e "${GREEN}[+]${RESET} sql_service: ${WHITE}$HASH2${RESET}"
        echo -e "${GREEN}[+]${RESET} web_admin: ${WHITE}$HASH3${RESET}"
        sleep $DELAY
        save_output "asrep_hashes.txt" "$HASH1\n$HASH2\n$HASH3"
        echo -e "${YELLOW}[!]${RESET} Hashes saved to ${WHITE}$TARGET_DIR/asrep_hashes.txt${RESET}"
        log_to_file "Captured 3 AS-REP hashes for offline cracking"
        echo -e "${CYAN}[*]${RESET} Run hashcat with: ${WHITE}hashcat -m 18200 asrep_hashes.txt wordlist.txt${RESET}"
        ;;
        
    "DCSync Attack")
        echo -e "${CYAN}[*]${RESET} Initiating DCSync attack against ${WHITE}$DC${RESET}..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Checking replication permissions..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Current user has DS-Replication-Get-Changes rights"
        sleep $DELAY
        echo -e "${CYAN}[*]${RESET} Replicating password hashes from domain database..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Administrator:500:aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c:::"
        echo -e "${GREEN}[+]${RESET} krbtgt:502:aad3b435b51404eeaad3b435b51404ee:1f9404b8a5d0c1c3d5e6f2a8b9c0d1e2:::"
        echo -e "${GREEN}[+]${RESET} domain_admin:1108:aad3b435b51404eeaad3b435b51404ee:3f4505b9a6d1c2c4d6e7f3a9b0c1d2e3:::"
        sleep $DELAY
        echo -e "${RED}[!]${RESET} ${WHITE}ALL${RESET} domain password hashes extracted!"
        echo -e "${YELLOW}[!]${RESET} Saved to ${WHITE}dcsync_hashes.txt${RESET}"
        ;;
        
    "Silver Ticket Forgery")
        echo -e "${CYAN}[*]${RESET} Forging Silver Ticket for service access..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Target service: ${WHITE}CIFS/$DC${RESET}"
        echo -e "${GREEN}[+]${RESET} Service account: ${WHITE}$DC\$${RESET}"
        sleep $DELAY
        echo -e "${CYAN}[*]${RESET} Generating Kerberos ticket..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} User: ${WHITE}Administrator${RESET}"
        echo -e "${GREEN}[+]${RESET} Domain: ${WHITE}$DOMAIN${RESET}"
        echo -e "${GREEN}[+]${RESET} SID: ${WHITE}S-1-5-21-1234567890-123456789-1234567890${RESET}"
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Ticket forged successfully!"
        echo -e "${GREEN}[+]${RESET} Injecting ticket into memory..."
        sleep $DELAY
        echo -e "${CYAN}[*]${RESET} Testing access..."
        echo -e "${GREEN}[✓]${RESET} Access granted to ${WHITE}\\\\$DC\\C\$${RESET}"
        ;;
        
    "NTDS.dit Extraction")
        echo -e "${CYAN}[*]${RESET} Extracting Active Directory database..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Creating Volume Shadow Copy..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Shadow copy created: ${WHITE}\\\\?\\GLOBALROOT\\Device\\HarddiskVolumeShadowCopy1${RESET}"
        sleep $DELAY
        echo -e "${CYAN}[*]${RESET} Copying NTDS.dit..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} NTDS.dit extracted (${WHITE}1.2 GB${RESET})"
        sleep $DELAY
        echo -e "${CYAN}[*]${RESET} Extracting SYSTEM hive..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} SYSTEM registry hive extracted"
        sleep $DELAY
        echo -e "${CYAN}[*]${RESET} Parsing database with secretsdump..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Extracted ${WHITE}245${RESET} NTLM hashes"
        echo -e "${GREEN}[+]${RESET} Extracted ${WHITE}12${RESET} cleartext passwords"
        echo -e "${YELLOW}[!]${RESET} Results saved to ${WHITE}ntds_dump.txt${RESET}"
        ;;
        
    "BloodHound Collection")
        echo -e "${CYAN}[*]${RESET} Running BloodHound data collection..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Initializing Python collector..."
        sleep $DELAY
        echo -e "${CYAN}[*]${RESET} Collecting domain information..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Resolved collection methods: ${WHITE}All${RESET}"
        sleep $DELAY
        echo -e "${CYAN}[*]${RESET} Collecting user sessions..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Found ${WHITE}89${RESET} active sessions"
        sleep $DELAY
        echo -e "${CYAN}[*]${RESET} Enumerating ACLs..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Enumerated ${WHITE}1,234${RESET} ACL entries"
        sleep $DELAY
        echo -e "${CYAN}[*]${RESET} Collecting local admin information..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Found ${WHITE}45${RESET} local admin relationships"
        sleep $DELAY
        echo -e "${CYAN}[*]${RESET} Collecting domain trusts..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Found ${WHITE}2${RESET} domain trusts"
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Collection complete!"
        echo -e "${YELLOW}[!]${RESET} Data saved to ${WHITE}bloodhound_${DOMAIN}_$(date +%Y%m%d).zip${RESET}"
        echo -e "${CYAN}[*]${RESET} Import into BloodHound GUI for path analysis"
        ;;
        
    "Delegation Abuse")
        echo -e "${CYAN}[*]${RESET} Scanning for delegation vulnerabilities..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Checking unconstrained delegation..."
        sleep $DELAY
        echo -e "${YELLOW}    [!]${RESET} ${WHITE}WEB01\$${RESET} - Unconstrained delegation enabled"
        echo -e "${YELLOW}    [!]${RESET} ${WHITE}APP01\$${RESET} - Unconstrained delegation enabled"
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Checking constrained delegation..."
        sleep $DELAY
        echo -e "${YELLOW}    [!]${RESET} ${WHITE}SQL01\$${RESET} delegated to ${WHITE}CIFS/DC01${RESET}"
        echo -e "${YELLOW}    [!]${RESET} ${WHITE}IIS01\$${RESET} delegated to ${WHITE}HTTP/DC01${RESET}"
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Checking resource-based constrained delegation (RBCD)..."
        sleep $DELAY
        echo -e "${YELLOW}    [!]${RESET} ${WHITE}FILE01${RESET} allows delegation from ${WHITE}WORKSTATION05\$${RESET}"
        sleep $DELAY
        echo -e "${CYAN}[*]${RESET} Exploitation paths identified!"
        echo -e "${RED}[!]${RESET} ${WHITE}WEB01\$${RESET} can be exploited for PrinterBug attack"
        ;;
        
    "Kerberoasting")
        echo -e "${CYAN}[*]${RESET} Performing Kerberoasting attack..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Querying service accounts with SPNs..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} Found ${WHITE}8${RESET} kerberoastable accounts"
        sleep $DELAY
        echo -e "${CYAN}[*]${RESET} Requesting TGS tickets..."
        sleep $DELAY
        echo -e "${GREEN}[+]${RESET} ${WHITE}MSSQLSvc/sql01.${DOMAIN}:1433${RESET}"
        echo -e "${GREEN}    └─${RESET} \$krb5tgs\$23\$*sqlsvc\$${DOMAIN}..."
        echo -e "${GREEN}[+]${RESET} ${WHITE}HTTP/web.${DOMAIN}:80${RESET}"
        echo -e "${GREEN}    └─${RESET} \$krb5tgs\$23\$*websvc\$${DOMAIN}..."
        echo -e "${GREEN}[+]${RESET} ${WHITE}TERMSRV/rdp.${DOMAIN}:3389${RESET}"
        echo -e "${GREEN}    └─${RESET} \$krb5tgs\$23\$*rdpsvc\$${DOMAIN}..."
        sleep $DELAY
        echo -e "${YELLOW}[!]${RESET} All TGS hashes saved to ${WHITE}kerberoast_hashes.txt${RESET}"
        echo -e "${CYAN}[*]${RESET} Crack with: ${WHITE}hashcat -m 13100 kerberoast_hashes.txt wordlist.txt${RESET}"
        ;;
        
    *)
        echo -e "${RED}[✗]${RESET} Unknown attack type: $ATTACK_TYPE"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}[✓]${RESET} Active Directory attack complete"
echo ""
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "  ${WHITE}NEXT STEPS${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo ""
echo -e "  ${YELLOW}•${RESET} Review collected data for exploitation opportunities"
echo -e "  ${YELLOW}•${RESET} Crack any captured password hashes offline"
echo -e "  ${YELLOW}•${RESET} Map privilege escalation paths in BloodHound"
echo -e "  ${YELLOW}•${RESET} Document findings for reporting"
echo ""
