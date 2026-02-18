#!/bin/bash
# Title: PenReport
# Author: bad-antics
# Description: Automated wireless pentest report generator
# Category: nullsec/reporting
# Version: 1.0.0
# Firmware: 2.7+
#
# Aggregates all loot, scan results, and attack logs from NullSec Suite
# payloads into a professional HTML pentest report with findings,
# risk ratings, and remediation recommendations.
#
# No external dependencies — pure bash.

LOOT_DIR="/mmc/nullsec/penreport"
REPORT="$LOOT_DIR/wireless-pentest-report.html"
LOG="$LOOT_DIR/penreport.log"
mkdir -p "$LOOT_DIR"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"; }

# ─── LOOT DISCOVERY ──────────────────────────────────────────────────
# Scan all known loot directories for captured data

declare -A FINDINGS
FINDING_COUNT=0
CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0
INFO_COUNT=0

add_finding() {
    local severity="$1"  # critical, high, medium, low, info
    local title="$2"
    local detail="$3"
    local evidence="$4"
    local remediation="$5"
    
    FINDING_COUNT=$((FINDING_COUNT + 1))
    eval "FIND_SEV_${FINDING_COUNT}=\"$severity\""
    eval "FIND_TITLE_${FINDING_COUNT}=\"$title\""
    eval "FIND_DETAIL_${FINDING_COUNT}=\"$detail\""
    eval "FIND_EVIDENCE_${FINDING_COUNT}=\"$evidence\""
    eval "FIND_REMED_${FINDING_COUNT}=\"$remediation\""
    
    case "$severity" in
        critical) CRITICAL_COUNT=$((CRITICAL_COUNT + 1)) ;;
        high)     HIGH_COUNT=$((HIGH_COUNT + 1)) ;;
        medium)   MEDIUM_COUNT=$((MEDIUM_COUNT + 1)) ;;
        low)      LOW_COUNT=$((LOW_COUNT + 1)) ;;
        info)     INFO_COUNT=$((INFO_COUNT + 1)) ;;
    esac
}

# ─── SCAN FOR CAPTURED DATA ──────────────────────────────────────────

TOTAL_HANDSHAKES=0
TOTAL_CREDS=0
TOTAL_PCAPS=0
TOTAL_SCANS=0
NETWORKS_FOUND=0
CLIENTS_FOUND=0

discover_loot() {
    SPINNER_START "Scanning for loot across all payloads..."
    
    # Common loot directories
    LOOT_DIRS=("/root/loot" "/tmp/loot" "/mmc/nullsec" "/root/handshakes" "/tmp")
    
    for dir in "${LOOT_DIRS[@]}"; do
        [ ! -d "$dir" ] && continue
        
        # ── Handshake captures (.cap files) ──
        local caps=$(find "$dir" -name "*.cap" -o -name "*.pcap" -o -name "*.hccapx" 2>/dev/null)
        if [ -n "$caps" ]; then
            local cap_count=$(echo "$caps" | wc -l)
            TOTAL_HANDSHAKES=$((TOTAL_HANDSHAKES + cap_count))
            
            # Check each capture for valid handshakes
            while IFS= read -r capfile; do
                if command -v aircrack-ng >/dev/null 2>&1; then
                    local hs_check=$(aircrack-ng "$capfile" 2>/dev/null | grep -c "handshake" || echo 0)
                    if [ "$hs_check" -gt 0 ]; then
                        add_finding "critical" "WPA Handshake Captured" \
                            "Valid WPA/WPA2 handshake captured from network. Can be cracked offline." \
                            "File: $capfile ($(du -h "$capfile" | cut -f1))" \
                            "Enforce WPA3-SAE, use strong passphrases (>20 chars), enable 802.11w PMF"
                    fi
                else
                    # Can't verify, report as potential
                    add_finding "high" "Capture File Found" \
                        "Packet capture file found that may contain handshakes or credentials." \
                        "File: $capfile ($(du -h "$capfile" | cut -f1))" \
                        "Review captured traffic, rotate affected credentials"
                fi
            done <<< "$caps"
        fi
        
        # ── PMKID captures ──
        local pmkids=$(find "$dir" -name "*pmkid*" -o -name "*PMKID*" 2>/dev/null)
        if [ -n "$pmkids" ]; then
            local pmkid_count=$(echo "$pmkids" | wc -l)
            add_finding "critical" "PMKID Hash(es) Captured ($pmkid_count)" \
                "PMKID hashes captured — can be cracked offline without client deauth." \
                "Files in: $dir" \
                "Upgrade to WPA3-SAE (immune to PMKID), use strong passphrases"
        fi
        
        # ── Credential files ──
        local cred_files=$(find "$dir" -name "*cred*" -o -name "*password*" -o -name "*hash*" -o -name "*mana*" 2>/dev/null)
        if [ -n "$cred_files" ]; then
            while IFS= read -r credfile; do
                [ ! -s "$credfile" ] && continue
                local cred_count=$(wc -l < "$credfile" 2>/dev/null)
                TOTAL_CREDS=$((TOTAL_CREDS + cred_count))
                
                add_finding "critical" "Credentials Captured" \
                    "Credential file with $cred_count entries found." \
                    "File: $credfile" \
                    "Rotate all affected credentials immediately, enforce MFA"
            done <<< "$cred_files"
        fi
        
        # ── Enterprise reaper results ──
        if [ -d "$dir/enterprise-reaper" ]; then
            local eap_creds=$(find "$dir/enterprise-reaper" -name "*.txt" -o -name "*.log" 2>/dev/null | \
                xargs grep -l "identity\|mschapv2\|credential" 2>/dev/null)
            if [ -n "$eap_creds" ]; then
                add_finding "critical" "Enterprise EAP Credentials Harvested" \
                    "WPA-Enterprise credentials captured via rogue RADIUS server." \
                    "Directory: $dir/enterprise-reaper" \
                    "Enforce certificate pinning on supplicants, disable PEAP fallback, use EAP-TLS with mutual auth"
            fi
        fi
        
        # ── Evil twin results ──
        if [ -d "$dir/eviltwin" ] || [ -d "$dir/evil-twin" ]; then
            local et_dir=$(ls -d "$dir"/eviltwin "$dir"/evil-twin 2>/dev/null | head -1)
            if [ -n "$et_dir" ] && [ -d "$et_dir" ]; then
                local et_logs=$(find "$et_dir" -name "*.log" -o -name "*.txt" 2>/dev/null)
                if [ -n "$et_logs" ]; then
                    add_finding "high" "Evil Twin Attack Successful" \
                        "Rogue AP successfully attracted clients. Potential credential interception." \
                        "Logs: $et_dir" \
                        "Deploy wireless IDS (WIDS), enable 802.11w PMF, educate users about certificate warnings"
                fi
            fi
        fi
        
        # ── DNS hijack / siphon results ──
        for dns_dir in "dnshijack" "dns-hijack" "dnssiphon" "dns-siphon"; do
            if [ -d "$dir/$dns_dir" ]; then
                add_finding "high" "DNS Hijack/Interception" \
                    "DNS traffic was successfully intercepted or redirected." \
                    "Directory: $dir/$dns_dir" \
                    "Enforce DNS-over-HTTPS (DoH) or DNS-over-TLS (DoT), use DNSSEC"
            fi
        done
        
        # ── Scan results (CSV from airodump) ──
        local csvfiles=$(find "$dir" -name "*.csv" 2>/dev/null | head -20)
        if [ -n "$csvfiles" ]; then
            TOTAL_SCANS=$((TOTAL_SCANS + $(echo "$csvfiles" | wc -l)))
            
            # Parse for network/client counts
            while IFS= read -r csvfile; do
                [ ! -s "$csvfile" ] && continue
                local net_c=$(grep -c "^[0-9A-Fa-f][0-9A-Fa-f]:" "$csvfile" 2>/dev/null || echo 0)
                NETWORKS_FOUND=$((NETWORKS_FOUND + net_c))
            done <<< "$csvfiles"
        fi
        
        # ── WPA cracker results ──
        for crack_dir in "wpacracker" "wpa-cracker" "cracked"; do
            if [ -d "$dir/$crack_dir" ]; then
                local cracked=$(find "$dir/$crack_dir" -name "*.txt" 2>/dev/null | \
                    xargs grep -l "KEY FOUND\|passphrase\|password" 2>/dev/null)
                if [ -n "$cracked" ]; then
                    add_finding "critical" "WPA Password Cracked" \
                        "WPA/WPA2 password successfully cracked from captured handshake." \
                        "Files: $dir/$crack_dir" \
                        "Use strong passphrases (>20 chars), upgrade to WPA3-SAE, implement key rotation"
                fi
            fi
        done
        
        # ── SSL strip results ──
        if [ -d "$dir/sslstrip" ]; then
            add_finding "high" "SSL Stripping Successful" \
                "HTTPS connections were downgraded to HTTP, exposing credentials in plaintext." \
                "Directory: $dir/sslstrip" \
                "Implement HSTS preloading, enforce HTTPS-only, deploy certificate pinning"
        fi
        
        # ── Deauth evidence ──
        for deauth_dir in "deauth" "deauthstorm" "massdeauth"; do
            if [ -d "$dir/$deauth_dir" ]; then
                add_finding "medium" "Deauthentication Attack Evidence" \
                    "Deauth attacks were performed against target networks." \
                    "Directory: $dir/$deauth_dir" \
                    "Enable 802.11w Protected Management Frames (PMF), deploy WIDS"
            fi
        done
        
        # ── Hidden network findings ──
        if [ -d "$dir/hidden-nets" ] || [ -d "$dir/hiddennetfinder" ]; then
            add_finding "low" "Hidden Networks Discovered" \
                "Networks with hidden SSIDs were identified through probe response analysis." \
                "SSID hiding provides no real security." \
                "Don't rely on SSID hiding as a security measure"
        fi
        
        # ── WPS results ──
        for wps_dir in "wps" "wpsbrute" "wpsscanner"; do
            if [ -d "$dir/$wps_dir" ]; then
                local wps_pins=$(find "$dir/$wps_dir" -name "*.txt" 2>/dev/null | \
                    xargs grep -l "WPS PIN\|pin found" 2>/dev/null)
                if [ -n "$wps_pins" ]; then
                    add_finding "high" "WPS PIN Recovered" \
                        "WPS PIN cracked via brute force, allowing network access." \
                        "Directory: $dir/$wps_dir" \
                        "Disable WPS entirely on all access points"
                fi
            fi
        done
        
    done
    
    # If no findings at all, add an info finding
    if [ $FINDING_COUNT -eq 0 ]; then
        add_finding "info" "No Captured Data Found" \
            "No loot directories or capture files were found. Either no attacks were run or loot has been cleaned." \
            "Searched: ${LOOT_DIRS[*]}" \
            "N/A"
    fi
    
    SPINNER_STOP
    log "Discovery complete: $FINDING_COUNT findings ($CRITICAL_COUNT critical, $HIGH_COUNT high, $MEDIUM_COUNT medium)"
}

# ─── GENERATE HTML REPORT ────────────────────────────────────────────

generate_html_report() {
    local ENGAGEMENT_NAME="Wireless Penetration Test"
    local TESTER="NullSec Suite"
    local REPORT_DATE=$(date '+%B %d, %Y')
    local REPORT_TIME=$(date '+%H:%M:%S %Z')
    
    SPINNER_START "Generating report..."
    
    cat > "$REPORT" << 'HEADER'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Wireless Penetration Test Report</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #0a0a0a; color: #d0d0d0; line-height: 1.6; }
.container { max-width: 1100px; margin: 0 auto; padding: 2rem; }
.cover { text-align: center; padding: 6rem 2rem; border-bottom: 3px solid #ff0040; margin-bottom: 3rem; }
.cover h1 { font-size: 42px; color: #ff0040; margin-bottom: 1rem; letter-spacing: 3px; }
.cover .subtitle { font-size: 18px; color: #808080; }
.cover .meta { margin-top: 2rem; color: #555; }
h2 { color: #ff0040; font-size: 24px; margin: 2rem 0 1rem; padding-bottom: 0.5rem; border-bottom: 1px solid #333; }
h3 { color: #58a6ff; margin: 1.5rem 0 0.5rem; }
p { margin-bottom: 1rem; }
.stats { display: flex; gap: 1rem; flex-wrap: wrap; margin: 2rem 0; }
.stat-card { background: #1a1a1a; border: 1px solid #333; border-radius: 12px; padding: 1.5rem; min-width: 140px; text-align: center; flex: 1; }
.stat-card .number { font-size: 36px; font-weight: 700; }
.stat-card .label { font-size: 13px; color: #808080; margin-top: 4px; }
.critical .number { color: #f85149; }
.high .number { color: #ff6b35; }
.medium .number { color: #d29922; }
.low .number { color: #58a6ff; }
.info-card .number { color: #3fb950; }
table { width: 100%; border-collapse: collapse; margin: 1rem 0; background: #111; border-radius: 8px; overflow: hidden; }
th { background: #1a1a1a; color: #58a6ff; padding: 12px 16px; text-align: left; font-weight: 600; }
td { padding: 12px 16px; border-bottom: 1px solid #222; }
tr:hover td { background: #1a1a1a; }
.severity { display: inline-block; padding: 2px 10px; border-radius: 4px; font-weight: 600; font-size: 12px; text-transform: uppercase; }
.sev-critical { background: #f85149; color: #fff; }
.sev-high { background: #ff6b35; color: #fff; }
.sev-medium { background: #d29922; color: #000; }
.sev-low { background: #58a6ff; color: #000; }
.sev-info { background: #3fb950; color: #000; }
.finding { background: #111; border: 1px solid #333; border-radius: 8px; padding: 1.5rem; margin: 1rem 0; }
.finding-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; }
.finding h3 { margin: 0; }
.evidence { background: #0d0d0d; border: 1px solid #333; border-radius: 4px; padding: 1rem; font-family: 'Cascadia Code', 'JetBrains Mono', monospace; font-size: 13px; color: #3fb950; margin: 0.5rem 0; white-space: pre-wrap; word-break: break-all; }
.remediation { background: #0d1117; border-left: 3px solid #58a6ff; padding: 1rem; margin: 0.5rem 0; }
.footer { margin-top: 4rem; padding-top: 2rem; border-top: 1px solid #333; text-align: center; color: #555; font-size: 12px; }
.disclaimer { background: #1a1a1a; border: 1px solid #d29922; border-radius: 8px; padding: 1.5rem; margin: 2rem 0; }
.toc { background: #111; border-radius: 8px; padding: 1.5rem; margin: 2rem 0; }
.toc a { color: #58a6ff; text-decoration: none; display: block; padding: 4px 0; }
.toc a:hover { color: #ff0040; }
@media print { body { background: white; color: black; } .stat-card { border: 1px solid #ccc; } }
</style>
</head>
<body>
<div class="container">
HEADER

    cat >> "$REPORT" << EOF
<div class="cover">
    <h1>WIRELESS PENETRATION TEST REPORT</h1>
    <div class="subtitle">Automated Assessment by NullSec Suite</div>
    <div class="meta">
        <p>Date: $REPORT_DATE</p>
        <p>Generated: $REPORT_TIME</p>
        <p>Tool: PenReport v1.0 | NullSec Suite</p>
    </div>
</div>

<div class="toc">
    <h3>Table of Contents</h3>
    <a href="#summary">1. Executive Summary</a>
    <a href="#stats">2. Assessment Statistics</a>
    <a href="#findings">3. Detailed Findings</a>
    <a href="#remediation">4. Remediation Summary</a>
    <a href="#methodology">5. Methodology</a>
    <a href="#disclaimer">6. Disclaimer</a>
</div>

<h2 id="summary">1. Executive Summary</h2>
<p>This automated wireless security assessment identified <strong>$FINDING_COUNT findings</strong> across the tested environment. 
The assessment covered network reconnaissance, authentication attacks, credential capture, and infrastructure analysis.</p>

<p>Overall risk level: <span class="severity $([ $CRITICAL_COUNT -gt 0 ] && echo 'sev-critical' || ([ $HIGH_COUNT -gt 0 ] && echo 'sev-high' || echo 'sev-medium'))">$([ $CRITICAL_COUNT -gt 0 ] && echo 'CRITICAL' || ([ $HIGH_COUNT -gt 0 ] && echo 'HIGH' || echo 'MEDIUM'))</span></p>

<div class="stats">
    <div class="stat-card critical"><div class="number">$CRITICAL_COUNT</div><div class="label">Critical</div></div>
    <div class="stat-card high"><div class="number">$HIGH_COUNT</div><div class="label">High</div></div>
    <div class="stat-card medium"><div class="number">$MEDIUM_COUNT</div><div class="label">Medium</div></div>
    <div class="stat-card low"><div class="number">$LOW_COUNT</div><div class="label">Low</div></div>
    <div class="stat-card info-card"><div class="number">$INFO_COUNT</div><div class="label">Info</div></div>
</div>

<h2 id="stats">2. Assessment Statistics</h2>
<div class="stats">
    <div class="stat-card"><div class="number" style="color:#ff0040">$TOTAL_HANDSHAKES</div><div class="label">Capture Files</div></div>
    <div class="stat-card"><div class="number" style="color:#ff0040">$TOTAL_CREDS</div><div class="label">Credentials</div></div>
    <div class="stat-card"><div class="number" style="color:#58a6ff">$TOTAL_SCANS</div><div class="label">Scan Files</div></div>
    <div class="stat-card"><div class="number" style="color:#3fb950">$NETWORKS_FOUND</div><div class="label">Networks Seen</div></div>
</div>

<h2 id="findings">3. Detailed Findings</h2>

<table>
<tr><th>#</th><th>Severity</th><th>Finding</th></tr>
EOF

    # Summary table
    for i in $(seq 1 $FINDING_COUNT); do
        eval "local sev=\$FIND_SEV_${i}"
        eval "local title=\$FIND_TITLE_${i}"
        cat >> "$REPORT" << EOF
<tr><td>$i</td><td><span class="severity sev-$sev">$sev</span></td><td>$title</td></tr>
EOF
    done
    
    echo "</table>" >> "$REPORT"
    
    # Detailed findings
    for i in $(seq 1 $FINDING_COUNT); do
        eval "local sev=\$FIND_SEV_${i}"
        eval "local title=\$FIND_TITLE_${i}"
        eval "local detail=\$FIND_DETAIL_${i}"
        eval "local evidence=\$FIND_EVIDENCE_${i}"
        eval "local remed=\$FIND_REMED_${i}"
        
        cat >> "$REPORT" << EOF
<div class="finding">
    <div class="finding-header">
        <h3>Finding #$i: $title</h3>
        <span class="severity sev-$sev">$sev</span>
    </div>
    <p>$detail</p>
    <h4>Evidence</h4>
    <div class="evidence">$evidence</div>
    <h4>Remediation</h4>
    <div class="remediation">$remed</div>
</div>
EOF
    done

    cat >> "$REPORT" << 'EOF'
<h2 id="remediation">4. Remediation Summary</h2>
<table>
<tr><th>Priority</th><th>Action</th></tr>
<tr><td><span class="severity sev-critical">P1</span></td><td>Rotate all compromised credentials immediately</td></tr>
<tr><td><span class="severity sev-critical">P1</span></td><td>Upgrade to WPA3-SAE where possible</td></tr>
<tr><td><span class="severity sev-high">P2</span></td><td>Enable 802.11w Protected Management Frames</td></tr>
<tr><td><span class="severity sev-high">P2</span></td><td>Disable WPS on all access points</td></tr>
<tr><td><span class="severity sev-high">P2</span></td><td>Deploy Wireless IDS (WIDS) for rogue AP detection</td></tr>
<tr><td><span class="severity sev-medium">P3</span></td><td>Enforce DNS-over-HTTPS or DNS-over-TLS</td></tr>
<tr><td><span class="severity sev-medium">P3</span></td><td>Implement HSTS preloading on all web services</td></tr>
<tr><td><span class="severity sev-low">P4</span></td><td>Review network segmentation between wireless VLANs</td></tr>
<tr><td><span class="severity sev-low">P4</span></td><td>Conduct security awareness training on WiFi risks</td></tr>
</table>

<h2 id="methodology">5. Methodology</h2>
<p>This assessment was conducted using the NullSec Suite for Hak5 WiFi Pineapple. The following phases were performed:</p>
<ol style="padding-left: 2rem;">
    <li><strong>Reconnaissance</strong> — Passive and active scanning of wireless networks, client enumeration, and hidden network discovery</li>
    <li><strong>Authentication Attacks</strong> — WPA/WPA2 handshake capture, PMKID harvesting, WPS brute force, enterprise EAP credential capture</li>
    <li><strong>Man-in-the-Middle</strong> — Evil twin deployment, SSL stripping, DNS hijacking, ARP spoofing</li>
    <li><strong>Post-Exploitation</strong> — Credential cracking, data exfiltration testing, lateral movement assessment</li>
    <li><strong>Reporting</strong> — Automated aggregation of all findings with risk ratings and remediation guidance</li>
</ol>

<div class="disclaimer" id="disclaimer">
    <h3>6. Disclaimer</h3>
    <p>This report was generated automatically by the NullSec Suite PenReport tool. All findings should be manually verified before inclusion in a formal deliverable. This assessment was conducted under authorized penetration testing engagement terms. The tools and techniques described are for defensive security assessment only.</p>
    <p>Generated by: PenReport v1.0 | NullSec Suite | github.com/bad-antics/hak5-pineapple</p>
</div>

<div class="footer">
    <p>🏴 NullSec Suite — Wireless Security Assessment Toolkit</p>
    <p>github.com/bad-antics/hak5-pineapple</p>
</div>
</div>
</body>
</html>
EOF

    SPINNER_STOP
    log "Report generated: $REPORT"
}

# ═══════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════

PROMPT "╔══════════════════════════════╗
║      PENREPORT v1.0          ║
║  Wireless Pentest Reporter   ║
╚══════════════════════════════╝

Generates a professional HTML
pentest report by aggregating:

• Captured handshakes
• Credential files
• Attack logs
• Scan results
• PMKID hashes
• Enterprise EAP loot

No dependencies required.

Press OK to generate report."

log "PenReport starting..."

# Discover all loot
discover_loot

PROMPT "LOOT DISCOVERY COMPLETE

Findings: $FINDING_COUNT
  Critical: $CRITICAL_COUNT
  High: $HIGH_COUNT
  Medium: $MEDIUM_COUNT
  Low: $LOW_COUNT
  Info: $INFO_COUNT

Captures: $TOTAL_HANDSHAKES
Credentials: $TOTAL_CREDS
Scan files: $TOTAL_SCANS

Press OK to generate report."

# Generate the report
generate_html_report

PROMPT "═══ REPORT GENERATED ═══

File: $REPORT
Size: $(du -h "$REPORT" | cut -f1)

$FINDING_COUNT findings documented:
• $CRITICAL_COUNT critical
• $HIGH_COUNT high
• $MEDIUM_COUNT medium

Transfer to your machine:
scp root@172.16.42.1:$REPORT .

Or view on Pineapple:
http://172.16.42.1:1471/report

Press OK to exit."

log "PenReport complete. Report: $REPORT"
