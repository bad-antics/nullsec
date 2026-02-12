#!/bin/bash
###############################################################################
# WiFiForensics — Wireless Incident Response & Evidence Collection
# NullSec Suite | WiFi Pineapple Mark VII / Nano / Tetra
#
# Performs forensic-grade wireless evidence collection: full PCAP capture
# with chain-of-custody logging, timeline reconstruction, device inventory,
# rogue AP detection, and generates court-admissible evidence reports.
# Designed for blue-team IR and compliance auditing.
#
# Author : bad-antics (NullSec)
# Version: 1.0.0
# License: MIT
###############################################################################

# ── NullSec Framework ──────────────────────────────────────────────────────
PAYLOAD_DIR="/root/payloads/WiFiForensics"
LOOT_DIR="/root/loot/wififorensics"
LOG_FILE="$LOOT_DIR/forensics.log"
EVIDENCE_DIR="$LOOT_DIR/evidence"
REPORT_FILE="$LOOT_DIR/forensic_report.html"
TIMELINE_FILE="$LOOT_DIR/timeline.csv"
CHAIN_FILE="$LOOT_DIR/chain_of_custody.txt"
IFACE=""
CASE_ID=""
EXAMINER=""

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
CYN='\033[0;36m'; BLU='\033[0;34m'; RST='\033[0m'

log()  { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { log "${GRN}[✓]${RST} $*"; }
warn() { log "${YEL}[!]${RST} $*"; }
fail() { log "${RED}[✗]${RST} $*"; }
info() { log "${CYN}[i]${RST} $*"; }

banner() {
    echo -e "${BLU}"
    cat << 'EOF'
 __        _____ _____ _ _____                        _
 \ \      / / _ \_   _(_)  ___|__  _ __ ___ _ __  ___(_) ___ ___
  \ \ /\ / / /_\ \| | | | |_ / _ \| '__/ _ \ '_ \/ __| |/ __/ __|
   \ V  V /  _  || | | |  _| (_) | | |  __/ | | \__ \ | (__\__ \
    \_/\_/ |_| |_||_| |_|_|  \___/|_|  \___|_| |_|___/_|\___|___/
                NullSec Incident Response
EOF
    echo -e "${RST}"
}

# ── Chain of custody ──────────────────────────────────────────────────────
init_chain_of_custody() {
    read -rp "Case ID (e.g., CASE-2024-001): " CASE_ID
    [ -z "$CASE_ID" ] && CASE_ID="CASE-$(date '+%Y%m%d-%H%M%S')"
    read -rp "Examiner name: " EXAMINER
    [ -z "$EXAMINER" ] && EXAMINER="NullSec Analyst"

    mkdir -p "$EVIDENCE_DIR/$CASE_ID"
    EVIDENCE_DIR="$EVIDENCE_DIR/$CASE_ID"

    cat > "$CHAIN_FILE" << CEOF
═══════════════════════════════════════════════════════════════════
           CHAIN OF CUSTODY — WIRELESS FORENSIC EVIDENCE
═══════════════════════════════════════════════════════════════════
Case ID     : $CASE_ID
Examiner    : $EXAMINER
Start Time  : $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Device      : $(cat /proc/sys/kernel/hostname 2>/dev/null || echo "Pineapple")
Device S/N  : $(cat /sys/class/net/wlan0/address 2>/dev/null || echo "Unknown")
Kernel      : $(uname -r)
Tool        : WiFiForensics v1.0.0 (NullSec Suite)
═══════════════════════════════════════════════════════════════════

EVIDENCE LOG:
─────────────────────────────────────────────────────────────────
CEOF

    ok "Chain of custody initialized: $CASE_ID"
}

custody_log() {
    local action="$1" detail="$2"
    local ts
    ts=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    echo "[$ts] $action | $detail | Examiner: $EXAMINER" >> "$CHAIN_FILE"
}

# ── Evidence hashing ──────────────────────────────────────────────────────
hash_evidence() {
    local file="$1"
    if [ -f "$file" ]; then
        local md5 sha256
        md5=$(md5sum "$file" | awk '{print $1}')
        sha256=$(sha256sum "$file" | awk '{print $1}')
        custody_log "HASH" "File: $(basename "$file") | MD5: $md5 | SHA256: $sha256"
        ok "Evidence hashed: $(basename "$file")"
        echo "$md5  $sha256  $file" >> "$EVIDENCE_DIR/hashes.txt"
    fi
}

# ── Pre-flight ─────────────────────────────────────────────────────────────
preflight() {
    mkdir -p "$LOOT_DIR" "$EVIDENCE_DIR"
    > "$LOG_FILE"

    # Timeline header
    echo "timestamp,event_type,source,detail,severity" > "$TIMELINE_FILE"

    IFACE=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
    if [ -z "$IFACE" ]; then
        fail "No wireless interface found"
        exit 1
    fi
    ok "Interface: $IFACE"

    # Verify forensic tools
    for tool in tshark airodump-ng md5sum sha256sum; do
        if ! command -v "$tool" &>/dev/null; then
            warn "Missing: $tool"
        fi
    done
}

# ── Full spectrum PCAP capture ─────────────────────────────────────────────
forensic_capture() {
    local duration="${1:-300}"  # Default 5 minutes
    info "Starting forensic PCAP capture ($duration seconds)..."
    custody_log "CAPTURE_START" "Duration: ${duration}s, Interface: $IFACE"

    # Enable monitor mode
    airmon-ng start "$IFACE" &>/dev/null
    local mon_iface="${IFACE}mon"
    [ ! -d "/sys/class/net/$mon_iface" ] && mon_iface="$IFACE"

    local pcap_file="$EVIDENCE_DIR/${CASE_ID}_fullcapture_$(date '+%Y%m%d_%H%M%S').pcap"

    # Channel-hopping capture for full spectrum
    tshark -i "$mon_iface" -w "$pcap_file" -a "duration:$duration" \
        -f "type mgt or type data or type ctl" 2>/dev/null &
    local cap_pid=$!

    # Progress display
    local elapsed=0
    while [ "$elapsed" -lt "$duration" ] && kill -0 "$cap_pid" 2>/dev/null; do
        printf "\r  Capturing... %d/%ds  " "$elapsed" "$duration"
        sleep 5
        ((elapsed += 5))
    done
    echo ""

    wait "$cap_pid" 2>/dev/null

    # Hash evidence
    hash_evidence "$pcap_file"
    custody_log "CAPTURE_END" "File: $(basename "$pcap_file"), Size: $(du -h "$pcap_file" | awk '{print $1}')"

    airmon-ng stop "$mon_iface" &>/dev/null 2>&1
    ok "Forensic capture complete: $pcap_file"

    LAST_PCAP="$pcap_file"
}

# ── AP inventory ───────────────────────────────────────────────────────────
inventory_aps() {
    info "Building access point inventory..."
    custody_log "INVENTORY" "Scanning for all access points"

    airmon-ng start "$IFACE" &>/dev/null
    local mon_iface="${IFACE}mon"
    [ ! -d "/sys/class/net/$mon_iface" ] && mon_iface="$IFACE"

    local scan_prefix="$EVIDENCE_DIR/${CASE_ID}_apscan"
    timeout 60 airodump-ng "$mon_iface" --wps --output-format csv -w "$scan_prefix" 2>/dev/null &
    local scan_pid=$!
    sleep 55
    kill "$scan_pid" 2>/dev/null
    wait "$scan_pid" 2>/dev/null

    local ap_file="$EVIDENCE_DIR/${CASE_ID}_ap_inventory.csv"
    echo "bssid,essid,channel,encryption,cipher,auth,power,beacons,clients,first_seen,last_seen" > "$ap_file"

    if [ -f "${scan_prefix}-01.csv" ]; then
        local ap_count=0
        while IFS=',' read -r bssid first last ch sp priv cipher auth pwr bcn iv lip idlen essid rest; do
            bssid=$(echo "$bssid" | xargs)
            essid=$(echo "$essid" | xargs)
            ch=$(echo "$ch" | xargs)
            priv=$(echo "$priv" | xargs)
            [[ "$bssid" == "BSSID" ]] && continue
            [[ "$bssid" == "Station"* ]] && break
            [ -z "$bssid" ] && continue
            echo "$bssid,$essid,$ch,$priv,$cipher,$auth,$pwr,$bcn,,$first,$last" >> "$ap_file"
            ((ap_count++))

            # Timeline entry
            echo "$(echo "$first" | xargs),AP_DETECTED,$bssid,$essid (CH:$ch $priv),info" >> "$TIMELINE_FILE"
        done < "${scan_prefix}-01.csv"

        ok "Inventoried $ap_count access points"
        hash_evidence "$ap_file"
        custody_log "AP_INVENTORY" "Found $ap_count access points"
    fi

    airmon-ng stop "$mon_iface" &>/dev/null 2>&1
}

# ── Client device inventory ───────────────────────────────────────────────
inventory_clients() {
    info "Building client device inventory..."

    local client_file="$EVIDENCE_DIR/${CASE_ID}_client_inventory.csv"
    echo "mac,bssid,associated_essid,first_seen,last_seen,packets,probe_requests" > "$client_file"

    local scan_prefix="$EVIDENCE_DIR/${CASE_ID}_apscan"
    if [ -f "${scan_prefix}-01.csv" ]; then
        local in_clients=0
        local client_count=0
        while IFS=',' read -r field1 field2 rest; do
            if echo "$field1" | grep -q "Station MAC"; then
                in_clients=1
                continue
            fi
            [ "$in_clients" -eq 0 ] && continue

            local mac bssid first last pwr pkt probes
            mac=$(echo "$field1" | xargs)
            [ -z "$mac" ] && continue

            IFS=',' read -r mac first last pwr pkt bssid probes <<< "$field1,$field2,$rest"
            mac=$(echo "$mac" | xargs)
            bssid=$(echo "$bssid" | xargs)
            probes=$(echo "$probes" | xargs)

            echo "$mac,$bssid,,$first,$last,$pkt,$probes" >> "$client_file"
            ((client_count++))

            echo "$(echo "$first" | xargs),CLIENT_DETECTED,$mac,BSSID:$bssid Probes:$probes,info" >> "$TIMELINE_FILE"
        done < "${scan_prefix}-01.csv"

        ok "Inventoried $client_count client devices"
        hash_evidence "$client_file"
        custody_log "CLIENT_INVENTORY" "Found $client_count client devices"
    fi
}

# ── Rogue AP detection ────────────────────────────────────────────────────
detect_rogue_aps() {
    info "Scanning for rogue access points..."

    local authorized_file="$PAYLOAD_DIR/authorized_aps.txt"
    local rogue_file="$EVIDENCE_DIR/${CASE_ID}_rogue_aps.csv"
    echo "bssid,essid,channel,encryption,classification,reason" > "$rogue_file"

    local rogue_count=0
    local ap_file="$EVIDENCE_DIR/${CASE_ID}_ap_inventory.csv"

    if [ ! -f "$ap_file" ]; then
        warn "Run AP inventory first"
        inventory_aps
    fi

    while IFS=',' read -r bssid essid channel enc cipher auth rest; do
        [ "$bssid" == "bssid" ] && continue
        local classification="UNKNOWN"
        local reason=""

        # Check for common rogue indicators
        # 1. Open networks that share names with known enterprise SSIDs
        if [[ "$enc" == *"OPN"* ]] && [[ "$essid" != "" ]]; then
            # Check if there's an encrypted version of same ESSID
            if grep -q "$essid" "$ap_file" | grep -qv "OPN"; then
                classification="SUSPECT"
                reason="Open network mimicking enterprise SSID"
                ((rogue_count++))
            fi
        fi

        # 2. Evil twin detection: same ESSID, different BSSID
        local ssid_count
        ssid_count=$(grep -c ",$essid," "$ap_file" 2>/dev/null || echo 0)
        if [ "$ssid_count" -gt 1 ]; then
            classification="SUSPECT"
            reason="Multiple BSSIDs for same ESSID (possible evil twin)"
            ((rogue_count++))
        fi

        # 3. Check against authorized list
        if [ -f "$authorized_file" ]; then
            if ! grep -qi "$bssid" "$authorized_file"; then
                classification="UNAUTHORIZED"
                reason="Not in authorized AP list"
                ((rogue_count++))
            fi
        fi

        # 4. Unusual channel usage
        if [ -n "$channel" ] && [ "$channel" -gt 14 ] 2>/dev/null; then
            if [[ "$channel" -gt 48 ]] && [[ "$channel" -lt 149 ]]; then
                classification="SUSPECT"
                reason="Unusual 5GHz channel (DFS band)"
                ((rogue_count++))
            fi
        fi

        [ "$classification" != "UNKNOWN" ] && echo "$bssid,$essid,$channel,$enc,$classification,$reason" >> "$rogue_file"
    done < "$ap_file"

    if [ "$rogue_count" -gt 0 ]; then
        warn "⚠ Detected $rogue_count suspicious/rogue APs"
        custody_log "ROGUE_DETECTION" "Found $rogue_count suspicious access points"
    else
        ok "No rogue APs detected"
    fi

    hash_evidence "$rogue_file"
}

# ── Deauth attack detection ──────────────────────────────────────────────
detect_attacks() {
    local pcap_file="${1:-$LAST_PCAP}"
    info "Analyzing capture for attack signatures..."

    if [ ! -f "$pcap_file" ]; then
        warn "No PCAP file to analyze"
        return
    fi

    local attacks_file="$EVIDENCE_DIR/${CASE_ID}_attacks.csv"
    echo "timestamp,attack_type,source,target,detail,severity" > "$attacks_file"

    # Count deauth frames
    local deauth_count
    deauth_count=$(tshark -r "$pcap_file" -Y "wlan.fc.type_subtype == 0x0c" 2>/dev/null | wc -l)
    if [ "$deauth_count" -gt 20 ]; then
        warn "Detected $deauth_count deauthentication frames (possible deauth attack)"
        echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ'),DEAUTH_FLOOD,Unknown,Broadcast,$deauth_count deauth frames,critical" >> "$attacks_file"
        echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ'),DEAUTH_FLOOD,,,$deauth_count frames detected,critical" >> "$TIMELINE_FILE"
    fi

    # Count disassociation frames
    local disassoc_count
    disassoc_count=$(tshark -r "$pcap_file" -Y "wlan.fc.type_subtype == 0x0a" 2>/dev/null | wc -l)
    if [ "$disassoc_count" -gt 20 ]; then
        warn "Detected $disassoc_count disassociation frames"
        echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ'),DISASSOC_FLOOD,Unknown,Broadcast,$disassoc_count frames,high" >> "$attacks_file"
    fi

    # Beacon flood detection
    local beacon_ssids
    beacon_ssids=$(tshark -r "$pcap_file" -Y "wlan.fc.type_subtype == 0x08" -T fields -e wlan.ssid 2>/dev/null | sort -u | wc -l)
    if [ "$beacon_ssids" -gt 50 ]; then
        warn "Detected $beacon_ssids unique SSIDs in beacons (possible beacon flood)"
        echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ'),BEACON_FLOOD,Unknown,Broadcast,$beacon_ssids unique SSIDs,high" >> "$attacks_file"
    fi

    # EAPOL spray detection
    local eapol_count
    eapol_count=$(tshark -r "$pcap_file" -Y "eapol" 2>/dev/null | wc -l)
    if [ "$eapol_count" -gt 100 ]; then
        warn "Detected $eapol_count EAPOL frames (possible auth bruteforce)"
        echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ'),EAPOL_SPRAY,Unknown,Network,$eapol_count EAPOL frames,medium" >> "$attacks_file"
    fi

    hash_evidence "$attacks_file"
    custody_log "ATTACK_ANALYSIS" "Deauth:$deauth_count Disassoc:$disassoc_count Beacons:$beacon_ssids EAPOL:$eapol_count"
}

# ── Timeline reconstruction ──────────────────────────────────────────────
sort_timeline() {
    info "Reconstructing event timeline..."
    local sorted_file="$EVIDENCE_DIR/${CASE_ID}_timeline_sorted.csv"
    head -1 "$TIMELINE_FILE" > "$sorted_file"
    tail -n +2 "$TIMELINE_FILE" | sort -t',' -k1 >> "$sorted_file"
    mv "$sorted_file" "$TIMELINE_FILE"
    hash_evidence "$TIMELINE_FILE"
    ok "Timeline sorted with $(( $(wc -l < "$TIMELINE_FILE") - 1 )) events"
}

# ── HTML forensic report ──────────────────────────────────────────────────
generate_report() {
    sort_timeline
    info "Generating forensic evidence report..."

    local ap_count client_count rogue_count event_count
    ap_count=$(tail -n +2 "$EVIDENCE_DIR/${CASE_ID}_ap_inventory.csv" 2>/dev/null | wc -l || echo 0)
    client_count=$(tail -n +2 "$EVIDENCE_DIR/${CASE_ID}_client_inventory.csv" 2>/dev/null | wc -l || echo 0)
    rogue_count=$(tail -n +2 "$EVIDENCE_DIR/${CASE_ID}_rogue_aps.csv" 2>/dev/null | wc -l || echo 0)
    event_count=$(tail -n +2 "$TIMELINE_FILE" 2>/dev/null | wc -l || echo 0)

    cat > "$REPORT_FILE" << HTMLEOF
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>Forensic Report — $CASE_ID — NullSec</title>
<style>
:root{--bg:#0a0e17;--card:#111827;--accent:#3b82f6;--red:#ef4444;--grn:#22c55e;--yel:#eab308;--txt:#e0e0e0}
*{margin:0;padding:0;box-sizing:border-box}
body{background:var(--bg);color:var(--txt);font-family:'Segoe UI',system-ui,sans-serif;padding:24px}
h1{color:var(--accent);font-size:28px;margin-bottom:4px}
.meta{color:#888;margin-bottom:24px;font-size:14px;line-height:1.6}
.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:32px}
.card{background:var(--card);border-radius:12px;padding:20px;text-align:center;border:1px solid #222}
.card .n{font-size:36px;font-weight:700;color:var(--accent)}
.card .l{font-size:13px;color:#888;margin-top:4px}
.danger .n{color:var(--red)}
h2{color:var(--accent);margin:24px 0 12px;font-size:20px}
table{width:100%;border-collapse:collapse;background:var(--card);border-radius:12px;overflow:hidden;margin-bottom:24px}
th{background:#1a2332;color:var(--accent);padding:14px 16px;text-align:left;font-size:12px;text-transform:uppercase}
td{padding:10px 16px;border-bottom:1px solid #1a1a2e;font-size:13px}
tr:hover td{background:rgba(59,130,246,0.05)}
.critical{color:var(--red);font-weight:bold}
.high{color:#f97316;font-weight:bold}
.medium{color:var(--yel)}
.info{color:#888}
.chain{background:var(--card);border-radius:12px;padding:20px;white-space:pre-wrap;font-family:monospace;font-size:12px;border:1px solid #222}
.footer{margin-top:32px;text-align:center;color:#555;font-size:12px}
</style></head><body>

<h1>📋 Wireless Forensic Evidence Report</h1>
<div class="meta">
<strong>Case ID:</strong> $CASE_ID<br>
<strong>Examiner:</strong> $EXAMINER<br>
<strong>Report Generated:</strong> $(date -u '+%Y-%m-%d %H:%M:%S UTC')<br>
<strong>Collection Device:</strong> $(cat /proc/sys/kernel/hostname 2>/dev/null || echo "Pineapple") ($(uname -r))<br>
<strong>Tool:</strong> WiFiForensics v1.0.0 — NullSec Suite
</div>

<div class="grid">
<div class="card"><div class="n">$ap_count</div><div class="l">Access Points</div></div>
<div class="card"><div class="n">$client_count</div><div class="l">Client Devices</div></div>
<div class="card danger"><div class="n">$rogue_count</div><div class="l">Rogue/Suspect APs</div></div>
<div class="card"><div class="n">$event_count</div><div class="l">Timeline Events</div></div>
</div>

<h2>📅 Event Timeline</h2>
<table><thead><tr><th>Timestamp</th><th>Event</th><th>Source</th><th>Detail</th><th>Severity</th></tr></thead><tbody>
HTMLEOF

    tail -n +2 "$TIMELINE_FILE" 2>/dev/null | head -100 | while IFS=',' read -r ts etype src detail sev; do
        echo "<tr><td>$ts</td><td>$etype</td><td>$src</td><td>$detail</td><td class=\"$sev\">$sev</td></tr>" >> "$REPORT_FILE"
    done

    cat >> "$REPORT_FILE" << HTMLEOF
</tbody></table>

<h2>🔗 Chain of Custody</h2>
<div class="chain">$(cat "$CHAIN_FILE" 2>/dev/null || echo "No chain of custody recorded")</div>

<h2>📎 Evidence Files</h2>
<table><thead><tr><th>File</th><th>Size</th><th>MD5</th><th>SHA256</th></tr></thead><tbody>
HTMLEOF

    if [ -f "$EVIDENCE_DIR/hashes.txt" ]; then
        while read -r md5 sha256 filepath; do
            local fname size
            fname=$(basename "$filepath")
            size=$(du -h "$filepath" 2>/dev/null | awk '{print $1}')
            echo "<tr><td>$fname</td><td>$size</td><td><code>$md5</code></td><td><code>${sha256:0:32}...</code></td></tr>" >> "$REPORT_FILE"
        done < "$EVIDENCE_DIR/hashes.txt"
    fi

    cat >> "$REPORT_FILE" << 'HTMLEOF'
</tbody></table>
<div class="footer">WiFiForensics v1.0.0 — NullSec Suite — For authorized incident response only</div>
</body></html>
HTMLEOF

    hash_evidence "$REPORT_FILE"
    custody_log "REPORT_GENERATED" "File: $(basename "$REPORT_FILE")"
    ok "Forensic report: $REPORT_FILE"
}

LED() { command -v LED &>/dev/null && command LED "$@" 2>/dev/null; true; }

# ── Interactive menu ───────────────────────────────────────────────────────
show_menu() {
    while true; do
        echo ""
        echo -e "${BLU}╔═══════════════════════════════════════════╗${RST}"
        echo -e "${BLU}║   WiFiForensics — Incident Response       ║${RST}"
        echo -e "${BLU}╠═══════════════════════════════════════════╣${RST}"
        echo -e "${BLU}║${RST} [1] Initialize Case & Chain of Custody     ${BLU}║${RST}"
        echo -e "${BLU}║${RST} [2] Full Spectrum PCAP Capture              ${BLU}║${RST}"
        echo -e "${BLU}║${RST} [3] AP Inventory                            ${BLU}║${RST}"
        echo -e "${BLU}║${RST} [4] Client Device Inventory                 ${BLU}║${RST}"
        echo -e "${BLU}║${RST} [5] Rogue AP Detection                      ${BLU}║${RST}"
        echo -e "${BLU}║${RST} [6] Attack Signature Analysis               ${BLU}║${RST}"
        echo -e "${BLU}║${RST} [7] Full Investigation (Auto)               ${BLU}║${RST}"
        echo -e "${BLU}║${RST} [8] Generate Forensic Report                ${BLU}║${RST}"
        echo -e "${BLU}║${RST} [0] Exit                                    ${BLU}║${RST}"
        echo -e "${BLU}╚═══════════════════════════════════════════╝${RST}"
        echo ""
        read -rp "Select> " choice

        case "$choice" in
            1) init_chain_of_custody ;;
            2) read -rp "Capture duration (seconds) [300]: " dur; forensic_capture "${dur:-300}" ;;
            3) inventory_aps ;;
            4) inventory_clients ;;
            5) detect_rogue_aps ;;
            6) detect_attacks ;;
            7) full_investigation ;;
            8) generate_report ;;
            0) ok "Exiting WiFiForensics"; exit 0 ;;
            *) warn "Invalid selection" ;;
        esac
    done
}

full_investigation() {
    info "Starting full forensic investigation..."
    [ -z "$CASE_ID" ] && init_chain_of_custody
    forensic_capture 120
    inventory_aps
    inventory_clients
    detect_rogue_aps
    detect_attacks
    generate_report
    ok "Full investigation complete — all evidence hashed and catalogued"
}

# ── Main ───────────────────────────────────────────────────────────────────
main() {
    banner
    preflight

    case "$1" in
        --auto)    CASE_ID="AUTO-$(date '+%Y%m%d-%H%M%S')"; EXAMINER="NullSec Auto"; full_investigation ;;
        --capture) forensic_capture "${2:-300}" ;;
        *)         show_menu ;;
    esac
}

main "$@"
