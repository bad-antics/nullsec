#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# NullSec Cluster Watchdog
# Monitors all cluster nodes and takes corrective action
# Runs as systemd service — checks every 60 seconds
# ═══════════════════════════════════════════════════════════════════

CLUSTER_DIR="$HOME/.nullsec/cluster"
NODES_FILE="${CLUSTER_DIR}/nodes.conf"
LOG_FILE="${CLUSTER_DIR}/watchdog.log"
STATE_DIR="${CLUSTER_DIR}/watchdog-state"
SSH_OPTS="-o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"
CHECK_INTERVAL=60
MAX_FAILURES=3

mkdir -p "$STATE_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

check_node() {
    local hostname="$1" ip="$2" user="$3" port="$4" os="$5"
    local fail_file="${STATE_DIR}/${hostname}.fails"
    local last_ok_file="${STATE_DIR}/${hostname}.last_ok"

    # Skip local
    [[ "$ip" == "127.0.0.1" ]] && return 0

    # SSH check
    if ssh $SSH_OPTS -p "$port" "${user}@${ip}" "echo ok" </dev/null &>/dev/null; then
        # Node is online
        echo 0 > "$fail_file"
        date +%s > "$last_ok_file"
        return 0
    else
        # Node failed
        local fails=0
        [[ -f "$fail_file" ]] && fails=$(cat "$fail_file")
        fails=$((fails + 1))
        echo "$fails" > "$fail_file"

        if [[ $fails -ge $MAX_FAILURES ]]; then
            log "ALERT: ${hostname} (${ip}) — DOWN for ${fails} consecutive checks"

            # Try Wake-on-LAN if we have the MAC
            local mac
            mac=$(arp -a 2>/dev/null | grep "$ip" | awk '{print $4}')
            if [[ -n "$mac" && "$mac" != "<incomplete>" ]]; then
                log "  Attempting Wake-on-LAN: ${mac}"
                wakeonlan "$mac" 2>/dev/null || \
                    etherwake "$mac" 2>/dev/null || \
                    python3 -c "
import socket, struct
mac_bytes = bytes.fromhex('${mac}'.replace(':',''))
magic = b'\xff'*6 + mac_bytes*16
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
s.sendto(magic, ('255.255.255.255', 9))
s.close()
print('WOL sent')
" 2>/dev/null
            fi
        fi
        return 1
    fi
}

# ── Main Loop ──
log "Watchdog started — monitoring $(grep -c '|' "$NODES_FILE" 2>/dev/null || echo 0) nodes"

while true; do
    online=0
    offline=0
    total=0

    while IFS='|' read -r hostname ip user port os arch cores ram gpu role tags; do
        [[ -z "$hostname" || "$hostname" == "#"* ]] && continue
        [[ "$ip" == "127.0.0.1" ]] && { ((total++)); ((online++)); continue; }
        ((total++))

        if check_node "$hostname" "$ip" "$user" "$port" "$os"; then
            ((online++))
        else
            ((offline++))
        fi
    done < "$NODES_FILE"

    # Log status periodically (every 10 minutes)
    if [[ $((SECONDS % 600)) -lt $CHECK_INTERVAL ]]; then
        log "Status: ${online}/${total} online, ${offline} offline"
    fi

    sleep "$CHECK_INTERVAL"
done
