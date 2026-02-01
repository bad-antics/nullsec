#!/bin/sh
#===============================================================================
#  NULLSEC PROBE HARVESTER - Collect Probe Requests & Build Target Profiles
#===============================================================================

LOOT_DIR="/mmc/nullsec/probes"
LOG_FILE="/root/nullsec/logs/probes_$(date +%Y%m%d_%H%M%S).log"
IFACE="${IFACE:-wlan1mon}"

mkdir -p "$LOOT_DIR" "$(dirname $LOG_FILE)"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

# Capture probe requests
capture_probes() {
    local duration="${1:-60}"
    local output="$LOOT_DIR/probes_$(date +%Y%m%d_%H%M%S).txt"
    
    log "Capturing probe requests for ${duration}s..."
    
    # Use tcpdump to capture probe requests
    timeout "$duration" tcpdump -i "$IFACE" -e -s 256 type mgt subtype probe-req 2>/dev/null | \
    while read line; do
        # Extract MAC and SSID
        mac=$(echo "$line" | grep -oE '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
        ssid=$(echo "$line" | grep -oP 'Probe Request \(\K[^)]+')
        
        if [[ -n "$mac" && -n "$ssid" ]]; then
            echo "$(date '+%H:%M:%S') | $mac | $ssid" | tee -a "$output"
        fi
    done
    
    log "Probes saved to $output"
}

# Analyze captured probes
analyze_probes() {
    local file="${1:-$LOOT_DIR/probes_*.txt}"
    
    echo "=== PROBE ANALYSIS ==="
    echo ""
    
    echo "=== TOP PROBED SSIDs ==="
    cat $file 2>/dev/null | awk -F'|' '{print $3}' | sort | uniq -c | sort -rn | head -20
    
    echo ""
    echo "=== UNIQUE DEVICES ==="
    cat $file 2>/dev/null | awk -F'|' '{print $2}' | sort -u | wc -l | xargs echo "Total devices:"
    
    echo ""
    echo "=== DEVICE -> SSID MAPPING ==="
    cat $file 2>/dev/null | awk -F'|' '{print $2 " probes: " $3}' | sort -u | head -30
}

# Build SSID pool from probes
build_ssid_pool() {
    local file="${1:-$LOOT_DIR/probes_*.txt}"
    local pool_file="/root/nullsec/configs/ssid_pool.txt"
    
    log "Building SSID pool from captured probes..."
    
    cat $file 2>/dev/null | awk -F'|' '{print $3}' | tr -d ' ' | sort -u | grep -v '^$' > "$pool_file"
    
    local count=$(wc -l < "$pool_file")
    log "Created pool with $count unique SSIDs: $pool_file"
    
    echo ""
    echo "=== SSID POOL ==="
    head -20 "$pool_file"
}

# Real-time probe monitor with display
live_monitor() {
    log "Starting live probe monitor (Ctrl+C to stop)..."
    
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║              NULLSEC PROBE MONITOR - LIVE                     ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    
    tcpdump -i "$IFACE" -e -s 256 type mgt subtype probe-req 2>/dev/null | \
    while read line; do
        mac=$(echo "$line" | grep -oE '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
        ssid=$(echo "$line" | grep -oP 'Probe Request \(\K[^)]+')
        
        if [[ -n "$mac" ]]; then
            # Color output
            printf "\033[0;32m%s\033[0m | \033[0;36m%-17s\033[0m | \033[1;33m%s\033[0m\n" \
                "$(date '+%H:%M:%S')" "$mac" "${ssid:-<BROADCAST>}"
        fi
    done
}

# Target specific device
track_device() {
    local target_mac="$1"
    
    [[ -z "$target_mac" ]] && { echo "Usage: $0 track <MAC>"; exit 1; }
    
    log "Tracking device $target_mac..."
    
    tcpdump -i "$IFACE" -e -s 256 ether src "$target_mac" 2>/dev/null | \
    while read line; do
        echo "$(date '+%H:%M:%S') | $line" | tee -a "$LOOT_DIR/track_$(echo $target_mac | tr ':' '-').log"
    done
}

# Generate device intelligence report
intel_report() {
    local output="$LOOT_DIR/intel_report_$(date +%Y%m%d).txt"
    
    log "Generating intelligence report..."
    
    cat > "$output" << EOF
╔═══════════════════════════════════════════════════════════════════╗
║              NULLSEC PROBE INTELLIGENCE REPORT                    ║
║              Generated: $(date)                     ║
╚═══════════════════════════════════════════════════════════════════╝

=== SUMMARY ===
Total probe files: $(ls -1 $LOOT_DIR/probes_*.txt 2>/dev/null | wc -l)
Total entries: $(cat $LOOT_DIR/probes_*.txt 2>/dev/null | wc -l)
Unique devices: $(cat $LOOT_DIR/probes_*.txt 2>/dev/null | awk -F'|' '{print $2}' | sort -u | wc -l)
Unique SSIDs: $(cat $LOOT_DIR/probes_*.txt 2>/dev/null | awk -F'|' '{print $3}' | sort -u | wc -l)

=== TOP 20 PROBED NETWORKS ===
$(cat $LOOT_DIR/probes_*.txt 2>/dev/null | awk -F'|' '{print $3}' | sort | uniq -c | sort -rn | head -20)

=== INTERESTING PATTERNS ===
Corporate networks:
$(cat $LOOT_DIR/probes_*.txt 2>/dev/null | awk -F'|' '{print $3}' | grep -iE 'corp|office|enterprise|company|work' | sort -u)

Hotel/Travel:
$(cat $LOOT_DIR/probes_*.txt 2>/dev/null | awk -F'|' '{print $3}' | grep -iE 'hotel|marriott|hilton|airport|lounge|guest' | sort -u)

Home networks:
$(cat $LOOT_DIR/probes_*.txt 2>/dev/null | awk -F'|' '{print $3}' | grep -iE 'home|house|family|wifi|network' | sort -u | head -10)

=== DEVICE PROFILES ===
$(cat $LOOT_DIR/probes_*.txt 2>/dev/null | awk -F'|' '{mac=$2; ssid=$3; profiles[mac]=profiles[mac] ssid ", "} END {for (m in profiles) print m ": " profiles[m]}' | head -20)

EOF

    log "Report saved to $output"
    cat "$output"
}

case "${1:-live}" in
    capture) shift; capture_probes "$@" ;;
    analyze) shift; analyze_probes "$@" ;;
    pool) shift; build_ssid_pool "$@" ;;
    live) live_monitor ;;
    track) shift; track_device "$@" ;;
    report) intel_report ;;
    *)
        echo "NullSec Probe Harvester"
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  live              - Real-time probe monitor"
        echo "  capture [seconds] - Capture probes to file"
        echo "  analyze [file]    - Analyze captured probes"
        echo "  pool [file]       - Build SSID pool from probes"
        echo "  track <MAC>       - Track specific device"
        echo "  report            - Generate intel report"
        ;;
esac
