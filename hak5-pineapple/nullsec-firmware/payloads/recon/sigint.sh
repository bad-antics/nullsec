#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Signal Intelligence (SIGINT) Payload
# Passive reconnaissance and signal monitoring
#
# For Hak5 WiFi Pineapple Pager
# Educational purposes only - Use responsibly
#
# Credits: Built for Hak5 devices - https://hak5.org
#═══════════════════════════════════════════════════════════════════════════════

LOOT_DIR="/mmc/loot/sigint"
PROBE_LOG="$LOOT_DIR/probes.log"
CLIENT_LOG="$LOOT_DIR/clients.log"
AP_LOG="$LOOT_DIR/access_points.log"
SIGNAL_LOG="$LOOT_DIR/signal_strength.log"
REPORT="$LOOT_DIR/sigint_report_$(date +%Y%m%d_%H%M%S).txt"
INTERFACE="wlan0"
MON_INTERFACE="wlan0mon"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
    echo -e "${RED}"
    cat << 'EOF'
   _____ _____ _____ _____ _   _ _______ 
  / ____|_   _/ ____|_   _| \ | |__   __|
 | (___   | || |  __  | | |  \| |  | |   
  \___ \  | || | |_ | | | | . ` |  | |   
  ____) |_| || |__| |_| |_| |\  |  | |   
 |_____/|_____\_____|_____|_| \_|  |_|   
                                         
    SIGNAL INTELLIGENCE // NULLSEC
EOF
    echo -e "${NC}"
}

log() { echo -e "${GREEN}[SIGINT]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }

setup() {
    mkdir -p "$LOOT_DIR"
    > "$PROBE_LOG"
    > "$CLIENT_LOG"
    > "$AP_LOG"
    > "$SIGNAL_LOG"
}

# Enable monitor mode
enable_monitor() {
    log "Enabling monitor mode..."
    
    # Try airmon-ng first
    if command -v airmon-ng &>/dev/null; then
        airmon-ng check kill &>/dev/null
        airmon-ng start "$INTERFACE" &>/dev/null
        
        if iw dev | grep -q "${INTERFACE}mon\|mon0"; then
            MON_INTERFACE=$(iw dev | grep -oP '(wlan\d+mon|mon\d+)' | head -1)
            log "Monitor mode enabled: $MON_INTERFACE"
            return 0
        fi
    fi
    
    # Fallback to manual monitor mode
    ip link set "$INTERFACE" down 2>/dev/null
    iw dev "$INTERFACE" set type monitor 2>/dev/null
    ip link set "$INTERFACE" up 2>/dev/null
    
    if iw dev "$INTERFACE" info | grep -q "type monitor"; then
        MON_INTERFACE="$INTERFACE"
        log "Monitor mode enabled: $MON_INTERFACE"
        return 0
    fi
    
    warn "Could not enable monitor mode"
    return 1
}

# Disable monitor mode
disable_monitor() {
    log "Disabling monitor mode..."
    
    if command -v airmon-ng &>/dev/null; then
        airmon-ng stop "$MON_INTERFACE" &>/dev/null
    else
        ip link set "$INTERFACE" down 2>/dev/null
        iw dev "$INTERFACE" set type managed 2>/dev/null
        ip link set "$INTERFACE" up 2>/dev/null
    fi
}

# Channel hopper
channel_hop() {
    log "Starting channel hopper..."
    
    while true; do
        for channel in 1 2 3 4 5 6 7 8 9 10 11 12 13; do
            iw dev "$MON_INTERFACE" set channel "$channel" 2>/dev/null
            sleep 0.3
        done
    done &
    HOPPER_PID=$!
}

# Capture probe requests
capture_probes() {
    log "Capturing probe requests..."
    
    # Use tcpdump to capture probe requests
    timeout "${1:-60}" tcpdump -i "$MON_INTERFACE" -e -s 256 \
        'type mgt subtype probe-req' 2>/dev/null | \
        while read -r line; do
            local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            local mac=$(echo "$line" | grep -oP '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
            local ssid=$(echo "$line" | grep -oP 'Probe Request \([^\)]+\)' | sed 's/Probe Request (//' | sed 's/)//')
            
            if [ -n "$mac" ]; then
                echo "$timestamp | MAC: $mac | SSID: $ssid" >> "$PROBE_LOG"
                info "Probe: $mac -> $ssid"
            fi
        done
}

# Scan for access points
scan_access_points() {
    log "Scanning for access points..."
    
    local duration="${1:-30}"
    
    # Use tcpdump to capture beacons
    timeout "$duration" tcpdump -i "$MON_INTERFACE" -e -s 256 \
        'type mgt subtype beacon' 2>/dev/null | \
        while read -r line; do
            local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            local bssid=$(echo "$line" | grep -oP '([0-9a-f]{2}:){5}[0-9a-f]{2}' | tail -1)
            local ssid=$(echo "$line" | grep -oP 'Beacon \([^\)]+\)' | sed 's/Beacon (//' | sed 's/)//')
            local signal=$(echo "$line" | grep -oP '-\d+dBm' | head -1)
            
            if [ -n "$bssid" ]; then
                echo "$timestamp | BSSID: $bssid | SSID: $ssid | Signal: $signal" >> "$AP_LOG"
            fi
        done
    
    # Sort and dedupe
    sort -u "$AP_LOG" -o "$AP_LOG"
    
    log "Found $(wc -l < "$AP_LOG") unique access points"
}

# Track client devices
track_clients() {
    log "Tracking client devices..."
    
    local duration="${1:-60}"
    
    # Capture all traffic to identify clients
    timeout "$duration" tcpdump -i "$MON_INTERFACE" -e -s 64 2>/dev/null | \
        while read -r line; do
            local macs=$(echo "$line" | grep -oP '([0-9a-f]{2}:){5}[0-9a-f]{2}')
            
            for mac in $macs; do
                # Filter out broadcast and multicast
                if [[ ! "$mac" =~ ^(ff:ff:ff:ff:ff:ff|33:33|01:00:5e) ]]; then
                    local vendor=$(lookup_vendor "$mac")
                    echo "$(date '+%Y-%m-%d %H:%M:%S') | $mac | $vendor" >> "$CLIENT_LOG"
                fi
            done
        done
    
    # Sort and dedupe
    sort -u "$CLIENT_LOG" -o "$CLIENT_LOG"
    
    log "Tracked $(wc -l < "$CLIENT_LOG") unique clients"
}

# Lookup MAC vendor
lookup_vendor() {
    local mac=$(echo "$1" | tr '[:lower:]' '[:upper:]' | cut -d':' -f1-3 | tr ':' '-')
    
    # Common vendor prefixes
    case "$mac" in
        "00-03-93"|"00-17-C4"|"00-1C-B3") echo "Apple" ;;
        "3C-5A-B4"|"F0-B4-29"|"F8-1E-DF") echo "Google" ;;
        "AC-37-43"|"74-DA-38"|"98-52-B1") echo "Samsung" ;;
        "CC-46-D6"|"C4-E9-84"|"D0-03-4B") echo "Microsoft" ;;
        "00-50-56"|"00-0C-29"|"00-05-69") echo "VMware" ;;
        "08-00-27") echo "VirtualBox" ;;
        "B8-27-EB"|"DC-A6-32"|"E4-5F-01") echo "Raspberry Pi" ;;
        *) echo "Unknown" ;;
    esac
}

# Signal strength monitor
monitor_signal() {
    local target_mac="$1"
    local duration="${2:-60}"
    
    log "Monitoring signal strength for: $target_mac"
    
    timeout "$duration" sh -c "
        while true; do
            signal=\$(iw dev $MON_INTERFACE station get $target_mac 2>/dev/null | grep signal | awk '{print \$2}')
            if [ -n \"\$signal\" ]; then
                echo \"\$(date '+%H:%M:%S') | $target_mac | \$signal dBm\" >> \"$SIGNAL_LOG\"
            fi
            sleep 1
        done
    " &
}

# Generate intelligence report
generate_report() {
    log "Generating intelligence report..."
    
    cat > "$REPORT" << EOF
═══════════════════════════════════════════════════════════════════════════════
                    NULLSEC SIGNAL INTELLIGENCE REPORT
═══════════════════════════════════════════════════════════════════════════════

Report Generated: $(date)
Duration: $DURATION seconds

═══════════════════════════════════════════════════════════════════════════════
                           EXECUTIVE SUMMARY
═══════════════════════════════════════════════════════════════════════════════

Total Access Points Detected:  $(wc -l < "$AP_LOG" 2>/dev/null || echo "0")
Total Client Devices Tracked:  $(wc -l < "$CLIENT_LOG" 2>/dev/null || echo "0")
Total Probe Requests Captured: $(wc -l < "$PROBE_LOG" 2>/dev/null || echo "0")

═══════════════════════════════════════════════════════════════════════════════
                         ACCESS POINTS DETECTED
═══════════════════════════════════════════════════════════════════════════════

$(cat "$AP_LOG" 2>/dev/null | head -50 || echo "No data")

═══════════════════════════════════════════════════════════════════════════════
                          CLIENT DEVICES TRACKED
═══════════════════════════════════════════════════════════════════════════════

$(cat "$CLIENT_LOG" 2>/dev/null | head -50 || echo "No data")

═══════════════════════════════════════════════════════════════════════════════
                      PROBE REQUESTS (SSID HISTORY)
═══════════════════════════════════════════════════════════════════════════════

Top SSIDs Probed:
$(cat "$PROBE_LOG" 2>/dev/null | awk -F'SSID: ' '{print $2}' | sort | uniq -c | sort -rn | head -20)

═══════════════════════════════════════════════════════════════════════════════
                         DEVICE VENDOR ANALYSIS
═══════════════════════════════════════════════════════════════════════════════

$(cat "$CLIENT_LOG" 2>/dev/null | awk -F'|' '{print $3}' | sort | uniq -c | sort -rn)

═══════════════════════════════════════════════════════════════════════════════
                              TIMELINE
═══════════════════════════════════════════════════════════════════════════════

Activity by Hour:
$(cat "$CLIENT_LOG" "$PROBE_LOG" 2>/dev/null | awk -F' ' '{print $2}' | cut -d':' -f1 | sort | uniq -c)

═══════════════════════════════════════════════════════════════════════════════

Report saved to: $REPORT

Credits: Built for Hak5 WiFi Pineapple - https://hak5.org
         For authorized security testing only.
═══════════════════════════════════════════════════════════════════════════════
EOF

    log "Report saved: $REPORT"
}

# Quick scan mode
quick_scan() {
    log "Starting quick SIGINT scan (60 seconds)..."
    DURATION=60
    
    enable_monitor || exit 1
    channel_hop
    
    capture_probes 30 &
    sleep 5
    scan_access_points 25
    track_clients 25
    
    kill $HOPPER_PID 2>/dev/null
    wait 2>/dev/null
    
    disable_monitor
    generate_report
}

# Full scan mode
full_scan() {
    local duration="${1:-300}"
    log "Starting full SIGINT scan (${duration} seconds)..."
    DURATION=$duration
    
    enable_monitor || exit 1
    channel_hop
    
    # Run all captures in parallel
    capture_probes "$((duration - 30))" &
    PROBE_PID=$!
    
    sleep 10
    scan_access_points "$((duration / 3))"
    track_clients "$((duration / 2))"
    
    # Wait for probe capture to complete
    wait $PROBE_PID 2>/dev/null
    
    kill $HOPPER_PID 2>/dev/null
    wait 2>/dev/null
    
    disable_monitor
    generate_report
}

# Stealth mode - minimal activity
stealth_scan() {
    log "Starting stealth SIGINT scan..."
    DURATION=120
    
    enable_monitor || exit 1
    
    # Slow channel hopping
    (
        while true; do
            for channel in 1 6 11; do
                iw dev "$MON_INTERFACE" set channel "$channel" 2>/dev/null
                sleep 5
            done
        done
    ) &
    HOPPER_PID=$!
    
    # Passive capture only
    capture_probes 90 &
    wait $!
    
    kill $HOPPER_PID 2>/dev/null
    disable_monitor
    generate_report
}

# Targeted surveillance
target_device() {
    local target="$1"
    local duration="${2:-300}"
    
    log "Starting targeted surveillance on: $target"
    DURATION=$duration
    
    enable_monitor || exit 1
    
    # Find target's preferred channel
    log "Locating target..."
    
    # Monitor specific MAC
    tcpdump -i "$MON_INTERFACE" -c 1000 -e ether host "$target" 2>/dev/null | \
        while read -r line; do
            local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            echo "$timestamp | $line" >> "$CLIENT_LOG"
        done &
    
    monitor_signal "$target" "$duration"
    wait
    
    disable_monitor
    generate_report
}

# Show help
usage() {
    echo "NullSec SIGINT - Signal Intelligence Tool"
    echo ""
    echo "Usage: $0 <mode> [options]"
    echo ""
    echo "Modes:"
    echo "  quick              Quick 60-second scan"
    echo "  full [duration]    Full scan (default: 5 minutes)"
    echo "  stealth            Stealth mode with minimal activity"
    echo "  target <MAC>       Target specific device"
    echo "  probes [duration]  Capture probe requests only"
    echo "  aps [duration]     Scan access points only"
    echo "  clients [duration] Track clients only"
    echo "  report             Generate report from existing data"
    echo ""
    echo "Examples:"
    echo "  $0 quick"
    echo "  $0 full 600"
    echo "  $0 target AA:BB:CC:DD:EE:FF"
    echo ""
    echo "Credits: Built for Hak5 WiFi Pineapple - https://hak5.org"
}

# Cleanup on exit
cleanup() {
    kill $HOPPER_PID 2>/dev/null
    kill $PROBE_PID 2>/dev/null
    disable_monitor
    exit 0
}

trap cleanup INT TERM

# Main
main() {
    banner
    setup
    
    case "${1:-quick}" in
        quick)
            quick_scan
            ;;
        full)
            full_scan "${2:-300}"
            ;;
        stealth)
            stealth_scan
            ;;
        target)
            [ -z "$2" ] && { echo "Usage: $0 target <MAC>"; exit 1; }
            target_device "$2" "${3:-300}"
            ;;
        probes)
            enable_monitor && channel_hop
            capture_probes "${2:-60}"
            disable_monitor
            ;;
        aps)
            enable_monitor && channel_hop
            scan_access_points "${2:-30}"
            disable_monitor
            ;;
        clients)
            enable_monitor && channel_hop
            track_clients "${2:-60}"
            disable_monitor
            ;;
        report)
            generate_report
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            usage
            exit 1
            ;;
    esac
    
    echo ""
    log "Loot saved to: $LOOT_DIR"
}

main "$@"
