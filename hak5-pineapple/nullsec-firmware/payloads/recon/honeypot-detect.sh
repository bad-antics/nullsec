#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Wireless Honeypot Detector
# Automated detection and alerting for rogue APs and honeypot networks
#
# For authorized security testing only!
# Credits: Built for Hak5 WiFi Pineapple - https://hak5.org
#═══════════════════════════════════════════════════════════════════════════════

VERSION="1.0"
LOOT_DIR="/mmc/nullsec/honeypot-detect"
DATE_TAG=$(date +%Y%m%d_%H%M%S)
IFACE="wlan0mon"
KNOWN_DB="/mmc/nullsec/honeypot-detect/known_aps.db"
ALERT_LOG="$LOOT_DIR/alerts_${DATE_TAG}.log"

mkdir -p "$LOOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║          NULLSEC HONEYPOT DETECTOR v1.0                       ║
    ║                                                               ║
    ║         Rogue AP & Wireless Honeypot Detection                ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$ALERT_LOG"
    echo -e "$1"
}

# Build baseline of known APs
build_baseline() {
    log "${CYAN}[BASELINE]${NC} Building known AP database..."
    
    SCAN_FILE="/tmp/honeypot_baseline.csv"
    airodump-ng --output-format csv -w /tmp/honeypot_base "$IFACE" &>/dev/null &
    PID=$!
    sleep 30
    kill $PID 2>/dev/null
    
    # Parse and store known APs
    > "$KNOWN_DB"
    grep -E "^[0-9A-F]{2}:" /tmp/honeypot_base*.csv 2>/dev/null | \
    while IFS=',' read -r bssid _ _ ch _ enc cipher auth power _ _ _ essid _; do
        bssid=$(echo "$bssid" | tr -d ' ')
        essid=$(echo "$essid" | tr -d ' ')
        ch=$(echo "$ch" | tr -d ' ')
        enc=$(echo "$enc" | tr -d ' ')
        echo "$bssid|$essid|$ch|$enc|$(date +%s)" >> "$KNOWN_DB"
    done
    
    KNOWN=$(wc -l < "$KNOWN_DB" 2>/dev/null)
    log "${GREEN}[BASELINE]${NC} $KNOWN APs cataloged"
    rm -f /tmp/honeypot_base* 2>/dev/null
}

# Detect duplicate SSIDs (evil twins)
detect_evil_twin() {
    log "${YELLOW}[SCAN]${NC} Checking for evil twins..."
    
    airodump-ng --output-format csv -w /tmp/honeypot_scan "$IFACE" &>/dev/null &
    PID=$!
    sleep 20
    kill $PID 2>/dev/null
    
    # Find SSIDs with multiple BSSIDs
    grep -E "^[0-9A-F]{2}:" /tmp/honeypot_scan*.csv 2>/dev/null | \
    awk -F',' '{gsub(/^ +| +$/, "", $14); gsub(/^ +| +$/, "", $1); print $14"|"$1}' | \
    sort | awk -F'|' '{
        if (prev_ssid == $1 && $1 != "") {
            print "EVIL_TWIN|"$1"|"prev_bssid"|"$2
        }
        prev_ssid=$1; prev_bssid=$2
    }' | while IFS='|' read -r type ssid bssid1 bssid2; do
        log "${RED}[ALERT] EVIL TWIN DETECTED!${NC}"
        log "  SSID: $ssid"
        log "  BSSID 1: $bssid1"
        log "  BSSID 2: $bssid2"
        
        # Check if one is in known DB
        if grep -q "$bssid1" "$KNOWN_DB" 2>/dev/null; then
            log "  ${GREEN}$bssid1 is KNOWN${NC} - $bssid2 is SUSPICIOUS"
        elif grep -q "$bssid2" "$KNOWN_DB" 2>/dev/null; then
            log "  ${GREEN}$bssid2 is KNOWN${NC} - $bssid1 is SUSPICIOUS"
        else
            log "  ${RED}Both BSSIDs are UNKNOWN${NC}"
        fi
    done
    
    rm -f /tmp/honeypot_scan* 2>/dev/null
}

# Detect open networks (potential honeypots)
detect_open_honeypots() {
    log "${YELLOW}[SCAN]${NC} Detecting open honeypots..."
    
    airodump-ng --encrypt OPN --output-format csv -w /tmp/honeypot_open "$IFACE" &>/dev/null &
    PID=$!
    sleep 15
    kill $PID 2>/dev/null
    
    grep -E "^[0-9A-F]{2}:" /tmp/honeypot_open*.csv 2>/dev/null | \
    while IFS=',' read -r bssid _ _ ch _ enc _ _ power _ _ _ essid _; do
        bssid=$(echo "$bssid" | tr -d ' ')
        essid=$(echo "$essid" | tr -d ' ')
        power=$(echo "$power" | tr -d ' ')
        
        # Check for suspicious open networks
        SUSPICIOUS=0
        
        # Strong signal open network (likely close/intentional)
        [ "$power" -gt -50 ] 2>/dev/null && SUSPICIOUS=$((SUSPICIOUS + 1))
        
        # Common honeypot SSIDs
        echo "$essid" | grep -qi "free\|guest\|public\|wifi\|hotspot\|open" && SUSPICIOUS=$((SUSPICIOUS + 1))
        
        # Not in known DB
        grep -q "$bssid" "$KNOWN_DB" 2>/dev/null || SUSPICIOUS=$((SUSPICIOUS + 1))
        
        if [ "$SUSPICIOUS" -ge 2 ]; then
            log "${RED}[ALERT] HONEYPOT SUSPECTED!${NC}"
            log "  SSID: $essid"
            log "  BSSID: $bssid"
            log "  Signal: ${power}dBm"
            log "  Risk: $SUSPICIOUS/3 indicators"
        fi
    done
    
    rm -f /tmp/honeypot_open* 2>/dev/null
}

# Detect karma/MANA attacks
detect_karma() {
    log "${YELLOW}[SCAN]${NC} Detecting karma/MANA attacks..."
    
    # Look for APs responding to multiple probe requests
    PROBE_CAP="/tmp/honeypot_probes.pcap"
    timeout 30 tcpdump -i "$IFACE" -w "$PROBE_CAP" \
        'type mgt subtype probe-resp' 2>/dev/null
    
    # Find BSSIDs responding with many different SSIDs
    tshark -r "$PROBE_CAP" -T fields -e wlan.sa -e wlan.ssid 2>/dev/null | \
    sort | awk -F'\t' '{
        bssid_ssids[$1]=bssid_ssids[$1]","$2
        count[$1]++
    } END {
        for (b in count) {
            if (count[b] > 3) {
                print "KARMA|"b"|"count[b]"|"bssid_ssids[b]
            }
        }
    }' | while IFS='|' read -r type bssid num ssids; do
        log "${RED}[ALERT] KARMA/MANA ATTACK!${NC}"
        log "  BSSID: $bssid responding to $num different SSIDs"
        log "  SSIDs: $ssids"
    done
    
    rm -f "$PROBE_CAP" 2>/dev/null
}

# Detect deauth attacks in progress
detect_deauth() {
    log "${YELLOW}[SCAN]${NC} Monitoring for deauth attacks..."
    
    DEAUTH_CAP="/tmp/honeypot_deauth.pcap"
    timeout 30 tcpdump -i "$IFACE" -w "$DEAUTH_CAP" \
        'type mgt subtype deauth or type mgt subtype disassoc' 2>/dev/null
    
    DEAUTH_COUNT=$(tcpdump -r "$DEAUTH_CAP" 2>/dev/null | wc -l)
    
    if [ "$DEAUTH_COUNT" -gt 10 ]; then
        log "${RED}[ALERT] DEAUTH ATTACK IN PROGRESS!${NC}"
        log "  Detected $DEAUTH_COUNT deauth/disassoc frames in 30s"
        
        tshark -r "$DEAUTH_CAP" -T fields -e wlan.sa -e wlan.da 2>/dev/null | \
        sort | uniq -c | sort -rn | head -5 | while read -r count src dst; do
            log "  Attacker: $src -> $dst ($count frames)"
        done
    fi
    
    rm -f "$DEAUTH_CAP" 2>/dev/null
}

# Main monitoring loop
main() {
    banner
    build_baseline
    
    ROUND=0
    while true; do
        ROUND=$((ROUND + 1))
        log "\n${CYAN}=== Scan Round $ROUND ===${NC}"
        
        detect_evil_twin
        detect_open_honeypots
        detect_karma
        detect_deauth
        
        ALERTS=$(grep -c "ALERT" "$ALERT_LOG" 2>/dev/null || echo 0)
        log "${CYAN}[STATUS]${NC} Round $ROUND complete. Total alerts: $ALERTS"
        
        sleep 60
    done
}

main "$@"
