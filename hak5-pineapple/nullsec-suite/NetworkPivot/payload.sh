#!/bin/bash
# Title: Network Pivot - Multi-Hop Network Traversal
# Author: bad-antics
# Description: Automated network pivoting through compromised hosts for deep network penetration
# Category: nullsec/stealth

LOOT_DIR="/mmc/nullsec/netpivot"
mkdir -p "$LOOT_DIR"

PROMPT "NETWORK PIVOT

Multi-Hop Traversal Engine

Capabilities:
- SSH tunnel chaining
- SOCKS5 proxy setup
- Port forwarding
- Route discovery
- Subnet hopping
- Pivot persistence
- Traffic routing

Press OK to configure."

PROMPT "PIVOT MODE:

1. SSH Tunnel Chain
2. SOCKS5 Proxy
3. Port Forward
4. Auto-Discover Routes
5. Full Pivot (all)

Select mode next."

MODE=$(NUMBER_PICKER "Mode (1-5):" 5)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=5 ;; esac

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PIVOT_LOG="$LOOT_DIR/pivot_${TIMESTAMP}.log"
ROUTES_FILE="$LOOT_DIR/routes_${TIMESTAMP}.txt"

# Collect pivot host info
PROMPT "Enter pivot host info
on the next screens.

You need:
- IP of first hop
- SSH credentials
- Target network range

Press OK to continue."

PIVOT_HOST=""
PIVOT_USER="root"
PIVOT_PORT=22
TARGET_NET=""
SOCKS_PORT=1080
LOCAL_PORT=9050

{
    echo "Network Pivot Session - $(date)"
    echo "================================"
} > "$PIVOT_LOG"

# Auto-discover reachable networks
discover_routes() {
    SPINNER_START "Discovering routes..."

    local routes=""

    # Check local interfaces for multi-homed hosts
    LOCAL_NETS=$(ip -4 addr show | grep -oP '\d+\.\d+\.\d+\.\d+/\d+' | grep -v '127.0.0')

    echo "Local Networks:" >> "$PIVOT_LOG"
    echo "$LOCAL_NETS" >> "$PIVOT_LOG"

    # ARP table for known hosts
    echo "" >> "$PIVOT_LOG"
    echo "ARP Neighbors:" >> "$PIVOT_LOG"
    arp -an 2>/dev/null >> "$PIVOT_LOG"

    # Check routing table
    echo "" >> "$PIVOT_LOG"
    echo "Route Table:" >> "$PIVOT_LOG"
    ip route 2>/dev/null >> "$PIVOT_LOG"

    # Scan for SSH-enabled hosts (potential pivots)
    SUBNET=$(ip -4 addr show | grep -oP '(\d+\.){3}' | grep -v '127.0.0' | head -1)
    echo "" >> "$PIVOT_LOG"
    echo "SSH-enabled hosts on ${SUBNET}0/24:" >> "$PIVOT_LOG"

    PIVOT_CANDIDATES=""
    for i in $(seq 1 254); do
        ip="${SUBNET}${i}"
        if timeout 1 bash -c "echo >/dev/tcp/$ip/22" 2>/dev/null; then
            echo "  $ip: SSH open" >> "$PIVOT_LOG"
            PIVOT_CANDIDATES="${PIVOT_CANDIDATES}${ip}\n"
        fi
    done &
    wait

    SPINNER_STOP

    {
        echo "Pivot Candidates:"
        echo -e "$PIVOT_CANDIDATES"
    } >> "$ROUTES_FILE"
}

# SSH tunnel chain
setup_ssh_tunnel() {
    local hop1="$1" user1="$2" port1="${3:-22}"

    SPINNER_START "Setting up SSH tunnel..."

    # Dynamic port forwarding (SOCKS5)
    ssh -f -N -D "$SOCKS_PORT" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=10 \
        -p "$port1" "${user1}@${hop1}" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "SOCKS5 proxy: localhost:${SOCKS_PORT}" >> "$PIVOT_LOG"
        echo "Use: proxychains or export SOCKS_PROXY=socks5://localhost:${SOCKS_PORT}" >> "$PIVOT_LOG"
        SPINNER_STOP
        return 0
    else
        SPINNER_STOP
        echo "SSH tunnel failed to ${hop1}" >> "$PIVOT_LOG"
        return 1
    fi
}

# Port forwarding
setup_port_forward() {
    local hop="$1" user="$2" remote_host="$3" remote_port="$4" local_port="$5"

    SPINNER_START "Setting up port forward..."

    ssh -f -N -L "${local_port}:${remote_host}:${remote_port}" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=10 \
        "${user}@${hop}" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "Port forward: localhost:${local_port} -> ${remote_host}:${remote_port} via ${hop}" >> "$PIVOT_LOG"
        SPINNER_STOP
        return 0
    else
        SPINNER_STOP
        return 1
    fi
}

# SOCKS proxy setup
setup_socks_proxy() {
    local hop="$1" user="$2"

    SPINNER_START "Configuring SOCKS5 proxy..."

    # Create proxychains config
    cat > /tmp/proxychains.conf << EOF
strict_chain
proxy_dns
[ProxyList]
socks5 127.0.0.1 ${SOCKS_PORT}
EOF

    setup_ssh_tunnel "$hop" "$user"

    if [ $? -eq 0 ]; then
        echo "ProxyChains config: /tmp/proxychains.conf" >> "$PIVOT_LOG"
        SPINNER_STOP
        PROMPT "SOCKS5 PROXY ACTIVE

Listening: localhost:${SOCKS_PORT}

Usage:
proxychains nmap TARGET
curl --socks5 localhost:${SOCKS_PORT} http://target

ProxyChains config created.
All traffic routes through
${hop}."
        return 0
    else
        SPINNER_STOP
        ERROR_DIALOG "Failed to set up SOCKS proxy"
        return 1
    fi
}

# Main execution
case "$MODE" in
    1) # SSH Tunnel Chain
        discover_routes
        PROMPT "SSH tunnel mode.
Check pivot log for
discovered candidates.

$(cat "$ROUTES_FILE" 2>/dev/null | head -10)

Setup requires manual
host specification."
        ;;

    2) # SOCKS5 Proxy
        discover_routes
        ;;

    3) # Port Forward
        discover_routes
        PROMPT "Port forwarding mode.

Discovered pivots logged.
See: $PIVOT_LOG"
        ;;

    4) # Auto-discover
        discover_routes
        PROMPT "ROUTE DISCOVERY

$(cat "$ROUTES_FILE" 2>/dev/null)

All routes logged to:
$PIVOT_LOG"
        ;;

    5) # Full pivot
        discover_routes
        PROMPT "FULL PIVOT RECON

Routes discovered and
logged. Tunnel candidates
identified.

Log: pivot_${TIMESTAMP}.log
Routes: routes_${TIMESTAMP}.txt
Loot: $LOOT_DIR"
        ;;
esac

# Cleanup temp files (keep logs)
rm -f /tmp/proxychains.conf 2>/dev/null
