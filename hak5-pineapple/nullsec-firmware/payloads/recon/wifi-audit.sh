#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec WiFi Audit Suite
# Comprehensive wireless security assessment tool
#
# For authorized security testing only!
# Credits: Built for Hak5 WiFi Pineapple - https://hak5.org
#═══════════════════════════════════════════════════════════════════════════════

VERSION="1.0"
LOOT_DIR="/mmc/nullsec/audits"
REPORT_DIR="/mmc/nullsec/reports"
DATE_TAG=$(date +%Y%m%d_%H%M%S)

# Colors (for terminal output)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Ensure directories exist
mkdir -p "$LOOT_DIR" "$REPORT_DIR"

banner() {
    echo -e "${RED}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║              NULLSEC WIFI AUDIT SUITE v1.0                    ║
    ║                                                               ║
    ║      Comprehensive Wireless Security Assessment               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "    ${CYAN}Built for Hak5 WiFi Pineapple - https://hak5.org${NC}"
    echo ""
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --target BSSID    Target specific network"
    echo "  -c, --channel NUM     Lock to specific channel"
    echo "  -d, --duration MINS   Scan duration (default: 5)"
    echo "  -o, --output FILE     Output report filename"
    echo "  -f, --full            Full audit (all tests)"
    echo "  -q, --quick           Quick scan only"
    echo "  -h, --help            Show this help"
    echo ""
    echo "Audit Types:"
    echo "  --scan                Basic network discovery"
    echo "  --clients             Client enumeration"
    echo "  --probes              Probe request capture"
    echo "  --hidden              Hidden SSID detection"
    echo "  --wps                 WPS vulnerability check"
    echo "  --pmkid               PMKID capture attempt"
    echo "  --security            Security assessment"
    echo ""
}

log() {
    local level=$1
    shift
    local msg="$@"
    local timestamp=$(date '+%H:%M:%S')
    
    case $level in
        INFO)  echo -e "${GREEN}[$timestamp INFO]${NC} $msg" ;;
        WARN)  echo -e "${YELLOW}[$timestamp WARN]${NC} $msg" ;;
        ERROR) echo -e "${RED}[$timestamp ERROR]${NC} $msg" ;;
        *)     echo -e "[$timestamp] $msg" ;;
    esac
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log ERROR "Please run as root"
        exit 1
    fi
}

# Get monitor interface
get_monitor_interface() {
    local mon_if=$(iw dev | grep -A 1 "type monitor" | grep Interface | awk '{print $2}' | head -1)
    if [ -z "$mon_if" ]; then
        # Try to use wlan1mon
        mon_if="wlan1mon"
    fi
    echo "$mon_if"
}

# Network Discovery Scan
scan_networks() {
    local duration=${1:-30}
    local output_file="$LOOT_DIR/scan_${DATE_TAG}.csv"
    
    log INFO "Starting network discovery scan (${duration}s)..."
    
    local mon_if=$(get_monitor_interface)
    
    # Run airodump-ng for scanning
    timeout "$duration" airodump-ng "$mon_if" -w "$LOOT_DIR/scan_${DATE_TAG}" --output-format csv 2>/dev/null &
    local scan_pid=$!
    
    # Show progress
    local elapsed=0
    while [ $elapsed -lt $duration ] && kill -0 $scan_pid 2>/dev/null; do
        echo -ne "\r  Scanning... ${elapsed}/${duration}s"
        sleep 1
        ((elapsed++))
    done
    echo ""
    
    wait $scan_pid 2>/dev/null
    
    # Parse results
    if [ -f "${LOOT_DIR}/scan_${DATE_TAG}-01.csv" ]; then
        mv "${LOOT_DIR}/scan_${DATE_TAG}-01.csv" "$output_file"
        
        local ap_count=$(grep -c "^[0-9A-F]" "$output_file" 2>/dev/null || echo "0")
        log INFO "Discovered $ap_count access points"
        
        echo "$output_file"
    else
        log WARN "No scan results captured"
        echo ""
    fi
}

# Client Enumeration
enumerate_clients() {
    local duration=${1:-60}
    local target_bssid=${2:-""}
    
    log INFO "Enumerating connected clients..."
    
    local mon_if=$(get_monitor_interface)
    local output_file="$LOOT_DIR/clients_${DATE_TAG}.csv"
    
    local cmd="airodump-ng $mon_if -w $LOOT_DIR/clients_${DATE_TAG} --output-format csv"
    
    if [ -n "$target_bssid" ]; then
        cmd="$cmd --bssid $target_bssid"
    fi
    
    timeout "$duration" $cmd 2>/dev/null &
    local scan_pid=$!
    
    local elapsed=0
    while [ $elapsed -lt $duration ] && kill -0 $scan_pid 2>/dev/null; do
        echo -ne "\r  Capturing clients... ${elapsed}/${duration}s"
        sleep 1
        ((elapsed++))
    done
    echo ""
    
    wait $scan_pid 2>/dev/null
    
    if [ -f "${LOOT_DIR}/clients_${DATE_TAG}-01.csv" ]; then
        mv "${LOOT_DIR}/clients_${DATE_TAG}-01.csv" "$output_file"
        
        # Count unique clients (station MACs after first empty line)
        local client_count=$(awk '/^Station MAC/{found=1;next} found && /^[0-9A-F]/{count++} END{print count+0}' "$output_file")
        log INFO "Enumerated $client_count clients"
        
        echo "$output_file"
    fi
}

# Probe Request Capture
capture_probes() {
    local duration=${1:-120}
    
    log INFO "Capturing probe requests (${duration}s)..."
    
    local mon_if=$(get_monitor_interface)
    local output_file="$LOOT_DIR/probes_${DATE_TAG}.txt"
    
    # Use tcpdump to capture probe requests
    timeout "$duration" tcpdump -i "$mon_if" -e -s 256 'type mgt subtype probe-req' 2>/dev/null | \
        tee "$output_file" | \
        while read line; do
            local ssid=$(echo "$line" | grep -oP 'Probe Request \(\K[^)]+')
            local mac=$(echo "$line" | grep -oP 'SA:[0-9a-f:]+' | cut -d: -f2-)
            if [ -n "$ssid" ] && [ "$ssid" != "Broadcast" ]; then
                echo -e "  ${CYAN}→${NC} $mac probing for: $ssid"
            fi
        done &
    
    local cap_pid=$!
    
    sleep "$duration"
    kill $cap_pid 2>/dev/null
    
    local probe_count=$(grep -c "Probe Request" "$output_file" 2>/dev/null || echo "0")
    log INFO "Captured $probe_count probe requests"
    
    # Extract unique SSIDs
    grep -oP 'Probe Request \(\K[^)]+' "$output_file" 2>/dev/null | \
        sort -u > "$LOOT_DIR/unique_ssids_${DATE_TAG}.txt"
    
    echo "$output_file"
}

# Hidden SSID Detection
detect_hidden() {
    local duration=${1:-60}
    
    log INFO "Detecting hidden SSIDs..."
    
    local mon_if=$(get_monitor_interface)
    local scan_file="$LOOT_DIR/hidden_scan_${DATE_TAG}.csv"
    
    timeout "$duration" airodump-ng "$mon_if" -w "$LOOT_DIR/hidden_scan_${DATE_TAG}" --output-format csv 2>/dev/null
    
    if [ -f "${LOOT_DIR}/hidden_scan_${DATE_TAG}-01.csv" ]; then
        mv "${LOOT_DIR}/hidden_scan_${DATE_TAG}-01.csv" "$scan_file"
        
        # Find networks with hidden SSIDs (length 0 or <length: N>)
        local hidden=$(grep -E ",\s*$|<length:" "$scan_file" | wc -l)
        
        if [ "$hidden" -gt 0 ]; then
            log WARN "Found $hidden networks with hidden/cloaked SSIDs"
            grep -E ",\s*$|<length:" "$scan_file" | while read line; do
                local bssid=$(echo "$line" | cut -d',' -f1)
                local channel=$(echo "$line" | cut -d',' -f4)
                echo "  Hidden network: $bssid (Channel $channel)"
            done
        else
            log INFO "No hidden SSIDs detected"
        fi
    fi
}

# WPS Vulnerability Check
check_wps() {
    log INFO "Checking for WPS vulnerabilities..."
    
    local mon_if=$(get_monitor_interface)
    local output_file="$LOOT_DIR/wps_${DATE_TAG}.txt"
    
    # Check if wash is available
    if ! command -v wash &>/dev/null; then
        log WARN "wash not installed, skipping WPS check"
        return
    fi
    
    timeout 30 wash -i "$mon_if" 2>/dev/null | tee "$output_file"
    
    local wps_count=$(grep -c "^[0-9A-F]" "$output_file" 2>/dev/null || echo "0")
    
    if [ "$wps_count" -gt 0 ]; then
        log WARN "Found $wps_count networks with WPS enabled"
        
        # Check for WPS locked status
        local unlocked=$(grep -c "No" "$output_file" 2>/dev/null || echo "0")
        if [ "$unlocked" -gt 0 ]; then
            log WARN "$unlocked networks have WPS unlocked (potentially vulnerable)"
        fi
    else
        log INFO "No WPS-enabled networks found"
    fi
    
    echo "$output_file"
}

# PMKID Capture Attempt
capture_pmkid() {
    local target_bssid=${1:-""}
    local duration=${2:-60}
    
    log INFO "Attempting PMKID capture..."
    
    local mon_if=$(get_monitor_interface)
    local output_file="$LOOT_DIR/pmkid_${DATE_TAG}.pcapng"
    
    # Check for hcxdumptool
    if ! command -v hcxdumptool &>/dev/null; then
        log WARN "hcxdumptool not installed, using alternative method"
        
        # Fall back to basic capture
        local cmd="timeout $duration airodump-ng $mon_if -w $LOOT_DIR/pmkid_${DATE_TAG}"
        if [ -n "$target_bssid" ]; then
            cmd="$cmd --bssid $target_bssid"
        fi
        $cmd 2>/dev/null
        return
    fi
    
    local cmd="hcxdumptool -i $mon_if -o $output_file --enable_status=1"
    if [ -n "$target_bssid" ]; then
        # Create filter file
        echo "$target_bssid" > /tmp/pmkid_filter.txt
        cmd="$cmd --filterlist_ap=/tmp/pmkid_filter.txt --filtermode=2"
    fi
    
    timeout "$duration" $cmd 2>/dev/null &
    local cap_pid=$!
    
    local elapsed=0
    while [ $elapsed -lt $duration ] && kill -0 $cap_pid 2>/dev/null; do
        echo -ne "\r  Capturing PMKIDs... ${elapsed}/${duration}s"
        sleep 1
        ((elapsed++))
    done
    echo ""
    
    wait $cap_pid 2>/dev/null
    
    if [ -f "$output_file" ]; then
        # Convert to hashcat format
        if command -v hcxpcapngtool &>/dev/null; then
            hcxpcapngtool -o "$LOOT_DIR/pmkid_${DATE_TAG}.22000" "$output_file" 2>/dev/null
            local pmkid_count=$(wc -l < "$LOOT_DIR/pmkid_${DATE_TAG}.22000" 2>/dev/null || echo "0")
            log INFO "Captured $pmkid_count PMKID(s)"
        fi
    fi
    
    echo "$output_file"
}

# Security Assessment
assess_security() {
    local scan_file=$1
    
    log INFO "Performing security assessment..."
    
    if [ ! -f "$scan_file" ]; then
        log ERROR "No scan file provided"
        return
    fi
    
    local report_file="$REPORT_DIR/security_assessment_${DATE_TAG}.txt"
    
    cat > "$report_file" << EOF
═══════════════════════════════════════════════════════════════════════════════
                    NULLSEC WIFI SECURITY ASSESSMENT REPORT
═══════════════════════════════════════════════════════════════════════════════
Generated: $(date)
Device: $(cat /etc/hostname 2>/dev/null || echo "Unknown")

Credits: Built for Hak5 WiFi Pineapple - https://hak5.org
───────────────────────────────────────────────────────────────────────────────

SUMMARY
═══════

EOF

    # Count encryption types
    local open_count=$(grep -c "OPN" "$scan_file" 2>/dev/null || echo "0")
    local wep_count=$(grep -c "WEP" "$scan_file" 2>/dev/null || echo "0")
    local wpa_count=$(grep -c "WPA[^2]" "$scan_file" 2>/dev/null || echo "0")
    local wpa2_count=$(grep -c "WPA2" "$scan_file" 2>/dev/null || echo "0")
    local wpa3_count=$(grep -c "WPA3" "$scan_file" 2>/dev/null || echo "0")
    
    cat >> "$report_file" << EOF
Network Security Distribution:
  Open Networks (No Encryption):  $open_count $([ "$open_count" -gt 0 ] && echo "[CRITICAL]")
  WEP Encrypted:                  $wep_count $([ "$wep_count" -gt 0 ] && echo "[HIGH RISK]")
  WPA Encrypted:                  $wpa_count $([ "$wpa_count" -gt 0 ] && echo "[MEDIUM RISK]")
  WPA2 Encrypted:                 $wpa2_count
  WPA3 Encrypted:                 $wpa3_count [SECURE]

───────────────────────────────────────────────────────────────────────────────

FINDINGS
════════

EOF

    # Critical findings - Open networks
    if [ "$open_count" -gt 0 ]; then
        cat >> "$report_file" << EOF
[CRITICAL] OPEN NETWORKS DETECTED
The following networks have no encryption and are vulnerable to eavesdropping:

EOF
        grep "OPN" "$scan_file" | while read line; do
            local bssid=$(echo "$line" | cut -d',' -f1)
            local ssid=$(echo "$line" | cut -d',' -f14 | tr -d ' ')
            echo "  - $ssid ($bssid)" >> "$report_file"
        done
        echo "" >> "$report_file"
    fi
    
    # High risk - WEP
    if [ "$wep_count" -gt 0 ]; then
        cat >> "$report_file" << EOF
[HIGH] WEP ENCRYPTION DETECTED
WEP is cryptographically broken and can be cracked in minutes:

EOF
        grep "WEP" "$scan_file" | while read line; do
            local bssid=$(echo "$line" | cut -d',' -f1)
            local ssid=$(echo "$line" | cut -d',' -f14 | tr -d ' ')
            echo "  - $ssid ($bssid)" >> "$report_file"
        done
        echo "" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF
───────────────────────────────────────────────────────────────────────────────

RECOMMENDATIONS
═══════════════

1. Immediately secure or disable any open networks
2. Upgrade WEP networks to WPA2/WPA3
3. Consider implementing 802.1X for enterprise networks
4. Enable client isolation where appropriate
5. Regularly audit wireless infrastructure

───────────────────────────────────────────────────────────────────────────────

EOF

    log INFO "Security report saved to: $report_file"
    cat "$report_file"
    
    echo "$report_file"
}

# Generate Full Report
generate_report() {
    local output_file="$REPORT_DIR/full_audit_${DATE_TAG}.html"
    
    log INFO "Generating audit report..."
    
    cat > "$output_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>NullSec WiFi Audit Report</title>
    <style>
        body { font-family: 'Courier New', monospace; background: #1a1a1a; color: #00ff00; padding: 20px; }
        .header { color: #ff3333; text-align: center; border: 2px solid #ff3333; padding: 20px; margin-bottom: 20px; }
        .section { background: #0a0a0a; border: 1px solid #333; padding: 15px; margin: 10px 0; }
        .critical { color: #ff3333; }
        .warning { color: #ffaa00; }
        .info { color: #00ff00; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #333; padding: 8px; text-align: left; }
        th { background: #333; }
        .footer { text-align: center; color: #666; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>NULLSEC WIFI AUDIT REPORT</h1>
        <p>Generated: $(date)</p>
    </div>
    
    <div class="section">
        <h2>Scan Results</h2>
        <p>Data files saved to: $LOOT_DIR</p>
    </div>
    
    <div class="footer">
        <p>Built for Hak5 WiFi Pineapple - https://hak5.org</p>
        <p>NullSec Security Tools</p>
    </div>
</body>
</html>
EOF

    log INFO "HTML report saved to: $output_file"
    echo "$output_file"
}

# Full Audit
full_audit() {
    local duration=${1:-300}
    
    banner
    log INFO "Starting full WiFi security audit..."
    log INFO "Duration: ${duration}s per phase"
    echo ""
    
    # Phase 1: Network Discovery
    echo -e "${CYAN}═══ PHASE 1: Network Discovery ═══${NC}"
    local scan_file=$(scan_networks 60)
    echo ""
    
    # Phase 2: Client Enumeration
    echo -e "${CYAN}═══ PHASE 2: Client Enumeration ═══${NC}"
    enumerate_clients 60
    echo ""
    
    # Phase 3: Probe Capture
    echo -e "${CYAN}═══ PHASE 3: Probe Request Capture ═══${NC}"
    capture_probes 60
    echo ""
    
    # Phase 4: Hidden SSID Detection
    echo -e "${CYAN}═══ PHASE 4: Hidden SSID Detection ═══${NC}"
    detect_hidden 30
    echo ""
    
    # Phase 5: WPS Check
    echo -e "${CYAN}═══ PHASE 5: WPS Vulnerability Check ═══${NC}"
    check_wps
    echo ""
    
    # Phase 6: PMKID Capture
    echo -e "${CYAN}═══ PHASE 6: PMKID Capture Attempt ═══${NC}"
    capture_pmkid "" 60
    echo ""
    
    # Phase 7: Security Assessment
    echo -e "${CYAN}═══ PHASE 7: Security Assessment ═══${NC}"
    if [ -n "$scan_file" ]; then
        assess_security "$scan_file"
    fi
    echo ""
    
    # Generate Report
    echo -e "${CYAN}═══ Generating Report ═══${NC}"
    generate_report
    
    echo ""
    log INFO "Full audit complete!"
    log INFO "Results saved to: $LOOT_DIR"
    log INFO "Reports saved to: $REPORT_DIR"
}

# Quick Scan
quick_scan() {
    banner
    log INFO "Running quick network scan..."
    
    scan_networks 30
    
    log INFO "Quick scan complete!"
}

# Main
main() {
    check_root
    
    # Parse arguments
    local duration=300
    local target=""
    local channel=""
    local mode="interactive"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--target) target="$2"; shift 2 ;;
            -c|--channel) channel="$2"; shift 2 ;;
            -d|--duration) duration="$2"; shift 2 ;;
            -f|--full) mode="full"; shift ;;
            -q|--quick) mode="quick"; shift ;;
            --scan) mode="scan"; shift ;;
            --clients) mode="clients"; shift ;;
            --probes) mode="probes"; shift ;;
            --hidden) mode="hidden"; shift ;;
            --wps) mode="wps"; shift ;;
            --pmkid) mode="pmkid"; shift ;;
            --security) mode="security"; shift ;;
            -h|--help) usage; exit 0 ;;
            *) echo "Unknown option: $1"; usage; exit 1 ;;
        esac
    done
    
    case $mode in
        full) full_audit "$duration" ;;
        quick) quick_scan ;;
        scan) banner; scan_networks "$duration" ;;
        clients) banner; enumerate_clients "$duration" "$target" ;;
        probes) banner; capture_probes "$duration" ;;
        hidden) banner; detect_hidden "$duration" ;;
        wps) banner; check_wps ;;
        pmkid) banner; capture_pmkid "$target" "$duration" ;;
        interactive)
            banner
            echo "Select audit type:"
            echo "  1) Full Audit"
            echo "  2) Quick Scan"
            echo "  3) Network Discovery"
            echo "  4) Client Enumeration"
            echo "  5) Probe Capture"
            echo "  6) PMKID Capture"
            echo "  7) Security Assessment"
            echo ""
            read -p "Choice [1-7]: " choice
            
            case $choice in
                1) full_audit ;;
                2) quick_scan ;;
                3) scan_networks 60 ;;
                4) enumerate_clients 60 ;;
                5) capture_probes 120 ;;
                6) capture_pmkid "" 60 ;;
                7) 
                    local sf=$(scan_networks 30)
                    assess_security "$sf"
                    ;;
                *) echo "Invalid choice" ;;
            esac
            ;;
    esac
}

main "$@"
