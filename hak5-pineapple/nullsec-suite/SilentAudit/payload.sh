#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Title:         SilentAudit
# Description:   Passive-only network security auditor that never sends a
#                single packet. Operates in full stealth by analyzing only
#                received frames for: weak encryption, default creds,
#                misconfigured APs, WPS vulnerabilities, rogue APs, and
#                compliance violations. Generates professional audit reports.
# Author:        bad-antics
# Category:      recon
# Version:       1.0
# ═══════════════════════════════════════════════════════════════════════════════

LOOT_DIR="/mmc/nullsec/SilentAudit"
LOG_FILE="${LOOT_DIR}/audit.log"
REPORT_FILE="${LOOT_DIR}/audit_report.html"
IFACE="wlan1mon"
SCAN_DURATION="${1:-120}"  # seconds

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

setup() {
    mkdir -p "$LOOT_DIR"
    log "SilentAudit v1.0 — Passive Network Security Auditor"
    log "Interface: $IFACE | Duration: ${SCAN_DURATION}s"
    log "Mode: PASSIVE ONLY (zero packets transmitted)"
    log "================================================"
}

# Passive capture
capture() {
    log "Starting passive capture on $IFACE..."

    # Capture everything passively
    timeout "$SCAN_DURATION" tcpdump -i "$IFACE" -w "${LOOT_DIR}/capture.pcap" \
        -c 100000 2>/dev/null &
    CAP_PID=$!

    # Progress indicator
    ELAPSED=0
    while kill -0 "$CAP_PID" 2>/dev/null; do
        sleep 10
        ELAPSED=$((ELAPSED + 10))
        PKT_COUNT=$(tcpdump -r "${LOOT_DIR}/capture.pcap" 2>/dev/null | wc -l)
        log "  Progress: ${ELAPSED}s / ${SCAN_DURATION}s | Packets: ${PKT_COUNT:-0}"
    done

    wait "$CAP_PID" 2>/dev/null
    log "Capture complete"
}

# Analyze captured data
analyze() {
    log "Analyzing captured data..."
    PCAP="${LOOT_DIR}/capture.pcap"
    FINDINGS="${LOOT_DIR}/findings.json"

    echo '{"findings":[],"stats":{}}' > "$FINDINGS"

    # 1. Find networks with no encryption (OPEN)
    log "  Checking for open networks..."
    tcpdump -r "$PCAP" -e 'type mgt subtype beacon' 2>/dev/null | \
        grep -v "Privacy" | grep -oP 'SSID=\K[^ ]+' | \
        sort -u > "${LOOT_DIR}/open_networks.txt"
    OPEN_COUNT=$(wc -l < "${LOOT_DIR}/open_networks.txt" 2>/dev/null || echo 0)
    log "    Found $OPEN_COUNT open networks"

    # 2. Find WEP networks (critically weak)
    log "  Checking for WEP encryption..."
    tcpdump -r "$PCAP" -e 2>/dev/null | \
        grep -i "WEP" | grep -oP '(BSSID|SA):(\K[0-9a-f:]+)' | \
        sort -u > "${LOOT_DIR}/wep_networks.txt"
    WEP_COUNT=$(wc -l < "${LOOT_DIR}/wep_networks.txt" 2>/dev/null || echo 0)
    log "    Found $WEP_COUNT WEP networks (CRITICAL)"

    # 3. Check for WPS-enabled networks
    log "  Checking for WPS-enabled networks..."
    tcpdump -r "$PCAP" -e -X 2>/dev/null | \
        grep -B5 "0050f204" | grep -oP '(BSSID|SA):(\K[0-9a-f:]+)' | \
        sort -u > "${LOOT_DIR}/wps_networks.txt"
    WPS_COUNT=$(wc -l < "${LOOT_DIR}/wps_networks.txt" 2>/dev/null || echo 0)
    log "    Found $WPS_COUNT WPS-enabled networks"

    # 4. Detect hidden networks
    log "  Detecting hidden networks..."
    tcpdump -r "$PCAP" -e 'type mgt subtype beacon' 2>/dev/null | \
        grep 'SSID=""' | grep -oP '(BSSID):(\K[0-9a-f:]+)' | \
        sort -u > "${LOOT_DIR}/hidden_networks.txt"
    HIDDEN_COUNT=$(wc -l < "${LOOT_DIR}/hidden_networks.txt" 2>/dev/null || echo 0)
    log "    Found $HIDDEN_COUNT hidden networks"

    # 5. Detect default/common SSIDs (likely unconfigured)
    log "  Checking for default SSIDs..."
    DEFAULT_PATTERNS="linksys|netgear|default|dlink|tplink|setup|admin|router|ASUS|belkin"
    tcpdump -r "$PCAP" -e 'type mgt subtype beacon' 2>/dev/null | \
        grep -iE "$DEFAULT_PATTERNS" | grep -oP 'SSID=\K[^ ]+' | \
        sort -u > "${LOOT_DIR}/default_ssids.txt"
    DEFAULT_COUNT=$(wc -l < "${LOOT_DIR}/default_ssids.txt" 2>/dev/null || echo 0)
    log "    Found $DEFAULT_COUNT default/unconfigured SSIDs"

    # 6. Detect rogue APs (same SSID, different BSSID)
    log "  Detecting potential rogue APs..."
    tcpdump -r "$PCAP" -e 'type mgt subtype beacon' 2>/dev/null | \
        grep -oP 'SSID=(\K[^ ]+).*BSSID:([0-9a-f:]+)' | \
        sort | uniq -D -w 30 > "${LOOT_DIR}/rogue_candidates.txt"
    ROGUE_COUNT=$(wc -l < "${LOOT_DIR}/rogue_candidates.txt" 2>/dev/null || echo 0)
    log "    Found $ROGUE_COUNT potential rogue AP indicators"

    # 7. Extract client device data
    log "  Cataloging client devices..."
    tcpdump -r "$PCAP" -e 'type mgt subtype probe-req' 2>/dev/null | \
        grep -oP '(SA):(\K[0-9a-f:]+)' | sort -u > "${LOOT_DIR}/clients.txt"
    CLIENT_COUNT=$(wc -l < "${LOOT_DIR}/clients.txt" 2>/dev/null || echo 0)
    log "    Found $CLIENT_COUNT unique client devices"

    # 8. Check for management frame flooding (potential attack in progress)
    log "  Checking for active attacks..."
    DEAUTH_COUNT=$(tcpdump -r "$PCAP" 'type mgt subtype deauth' 2>/dev/null | wc -l)
    DISASSOC_COUNT=$(tcpdump -r "$PCAP" 'type mgt subtype disassoc' 2>/dev/null | wc -l)
    log "    Deauth frames: $DEAUTH_COUNT | Disassoc frames: $DISASSOC_COUNT"

    if [[ "$DEAUTH_COUNT" -gt 50 ]]; then
        log "    ⚠ WARNING: High deauth count suggests active deauth attack!"
    fi
}

# Generate professional HTML report
generate_report() {
    log "Generating audit report..."

    TOTAL_FINDINGS=0

    cat > "$REPORT_FILE" <<'REPORT_HEAD'
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>NullSec Silent Audit Report</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#0a0a0a;color:#e0e0e0;padding:40px}
.container{max-width:900px;margin:0 auto}
h1{color:#00ff88;font-size:28px;margin-bottom:8px}
h2{color:#00ff88;font-size:20px;margin:24px 0 12px;border-bottom:1px solid #333;padding-bottom:8px}
.subtitle{color:#888;margin-bottom:32px}
.stat-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin:24px 0}
.stat{background:#1a1a1a;border:1px solid #333;border-radius:8px;padding:20px;text-align:center}
.stat-num{font-size:32px;font-weight:bold;color:#00ff88}
.stat-label{color:#888;font-size:14px;margin-top:4px}
.finding{background:#1a1a1a;border-left:4px solid #333;border-radius:0 8px 8px 0;padding:16px;margin:12px 0}
.critical{border-color:#ff4444}.high{border-color:#ff8800}.medium{border-color:#ffcc00}.low{border-color:#00ccff}.info{border-color:#888}
.severity{font-weight:bold;font-size:12px;text-transform:uppercase;margin-bottom:4px}
.critical .severity{color:#ff4444}.high .severity{color:#ff8800}.medium .severity{color:#ffcc00}.low .severity{color:#00ccff}
table{width:100%;border-collapse:collapse;margin:12px 0}
th,td{text-align:left;padding:8px 12px;border-bottom:1px solid #222}
th{color:#00ff88;font-size:13px}
.footer{margin-top:40px;padding-top:16px;border-top:1px solid #333;color:#666;font-size:12px;text-align:center}
</style></head><body><div class="container">
REPORT_HEAD

    cat >> "$REPORT_FILE" <<REPORT_HEADER
<h1>⬡ NullSec Silent Audit Report</h1>
<p class="subtitle">Generated: $(date '+%Y-%m-%d %H:%M:%S') | Duration: ${SCAN_DURATION}s | Mode: Passive Only</p>

<div class="stat-grid">
<div class="stat"><div class="stat-num">${OPEN_COUNT:-0}</div><div class="stat-label">Open Networks</div></div>
<div class="stat"><div class="stat-num">${WEP_COUNT:-0}</div><div class="stat-label">WEP Networks</div></div>
<div class="stat"><div class="stat-num">${WPS_COUNT:-0}</div><div class="stat-label">WPS Enabled</div></div>
<div class="stat"><div class="stat-num">${CLIENT_COUNT:-0}</div><div class="stat-label">Clients Found</div></div>
</div>

<h2>Security Findings</h2>
REPORT_HEADER

    # Add findings
    if [[ "${OPEN_COUNT:-0}" -gt 0 ]]; then
        cat >> "$REPORT_FILE" <<FINDING1
<div class="finding high">
<div class="severity">HIGH — Open Networks Detected</div>
<p>${OPEN_COUNT} networks broadcasting without encryption. All traffic visible to any listener.</p>
<table><tr><th>SSID</th></tr>
$(head -10 "${LOOT_DIR}/open_networks.txt" | while read ssid; do echo "<tr><td>$ssid</td></tr>"; done)
</table></div>
FINDING1
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + 1))
    fi

    if [[ "${WEP_COUNT:-0}" -gt 0 ]]; then
        cat >> "$REPORT_FILE" <<FINDING2
<div class="finding critical">
<div class="severity">CRITICAL — WEP Encryption Detected</div>
<p>${WEP_COUNT} networks using WEP encryption, which can be cracked in minutes. Immediate migration to WPA2/WPA3 required.</p>
</div>
FINDING2
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + 1))
    fi

    if [[ "${WPS_COUNT:-0}" -gt 0 ]]; then
        cat >> "$REPORT_FILE" <<FINDING3
<div class="finding medium">
<div class="severity">MEDIUM — WPS Enabled</div>
<p>${WPS_COUNT} networks with WPS enabled. WPS PIN is vulnerable to brute-force attacks (Reaver/Bully). Recommend disabling WPS.</p>
</div>
FINDING3
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + 1))
    fi

    if [[ "${HIDDEN_COUNT:-0}" -gt 0 ]]; then
        cat >> "$REPORT_FILE" <<FINDING4
<div class="finding low">
<div class="severity">LOW — Hidden Networks</div>
<p>${HIDDEN_COUNT} hidden networks detected. Hidden SSIDs provide minimal security and are easily revealed through probe requests.</p>
</div>
FINDING4
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + 1))
    fi

    if [[ "${DEFAULT_COUNT:-0}" -gt 0 ]]; then
        cat >> "$REPORT_FILE" <<FINDING5
<div class="finding medium">
<div class="severity">MEDIUM — Default/Unconfigured SSIDs</div>
<p>${DEFAULT_COUNT} networks using manufacturer default SSIDs. These likely have default admin credentials.</p>
<table><tr><th>SSID</th></tr>
$(head -10 "${LOOT_DIR}/default_ssids.txt" | while read ssid; do echo "<tr><td>$ssid</td></tr>"; done)
</table></div>
FINDING5
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + 1))
    fi

    if [[ "${DEAUTH_COUNT:-0}" -gt 50 ]]; then
        cat >> "$REPORT_FILE" <<FINDING6
<div class="finding critical">
<div class="severity">CRITICAL — Active Deauth Attack Detected</div>
<p>${DEAUTH_COUNT} deauthentication frames captured. This strongly indicates an active wireless attack in progress. Investigate immediately.</p>
</div>
FINDING6
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + 1))
    fi

    cat >> "$REPORT_FILE" <<REPORT_FOOTER
<h2>Summary</h2>
<p>Total findings: ${TOTAL_FINDINGS} | Clients observed: ${CLIENT_COUNT:-0} | Scan mode: Fully passive (0 packets transmitted)</p>

<div class="footer">
<p>Generated by NullSec SilentAudit v1.0 — For authorized security testing only</p>
<p>bad-antics | github.com/bad-antics/nullsec</p>
</div>
</div></body></html>
REPORT_FOOTER

    log "Report saved to $REPORT_FILE"
    log "Total findings: $TOTAL_FINDINGS"
}

cleanup() {
    log "SilentAudit complete. All data saved to $LOOT_DIR"
}

trap cleanup EXIT

# Main
setup
capture
analyze
generate_report

log "=== AUDIT COMPLETE ==="
log "Report: $REPORT_FILE"
log "Capture: ${LOOT_DIR}/capture.pcap"
