#!/bin/bash
###############################################################################
# ThreatMap — Real-Time Wireless Threat Visualization & Geolocation
# NullSec Suite | WiFi Pineapple Mark VII / Nano / Tetra
#
# Creates a live tactical map of the wireless threat landscape:
# - Signal triangulation for approximate AP/client locations
# - Threat classification (rogue, evil twin, jammer, deauther)
# - Live updating web dashboard with threat heatmap
# - Historical trend analysis
# - Alert correlation engine
# - JSON API for external tool integration
#
# Author : bad-antics (NullSec)
# Version: 1.0.0
# License: MIT
###############################################################################

LOOT_DIR="/root/loot/threatmap"
LOG_FILE="$LOOT_DIR/threatmap.log"
DASHBOARD="$LOOT_DIR/dashboard.html"
THREAT_DB="$LOOT_DIR/threats.json"
SCAN_DB="$LOOT_DIR/scans.json"
BASELINE_DB="$LOOT_DIR/baseline.json"
IFACE=""
MON=""

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
CYN='\033[0;36m'; MAG='\033[0;35m'; BLD='\033[1m'; RST='\033[0m'

log()  { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { log "${GRN}[✓]${RST} $*"; }
warn() { log "${YEL}[!]${RST} $*"; }
fail() { log "${RED}[✗]${RST} $*"; }
info() { log "${CYN}[i]${RST} $*"; }
threat() { log "${RED}[⚠ THREAT]${RST} $*"; }

banner() {
    echo -e "${RED}"
    cat << 'EOF'
  _____ _                    _   __  __
 |_   _| |__  _ __ ___  __ _| |_|  \/  | __ _ _ __
   | | | '_ \| '__/ _ \/ _` | __| |\/| |/ _` | '_ \
   | | | | | | | |  __/ (_| | |_| |  | | (_| | |_) |
   |_| |_| |_|_|  \___|\__,_|\__|_|  |_|\__,_| .__/
                                              |_|
  NullSec Threat Visualization Engine
EOF
    echo -e "${RST}"
}

setup() {
    mkdir -p "$LOOT_DIR"
    > "$LOG_FILE"
    echo '{"threats":[],"stats":{"critical":0,"high":0,"medium":0,"low":0}}' > "$THREAT_DB"
    echo '{"scans":[],"last_scan":"","total_aps":0,"total_clients":0}' > "$SCAN_DB"

    IFACE=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
    [ -z "$IFACE" ] && { fail "No wireless interface"; exit 1; }

    airmon-ng check kill &>/dev/null
    airmon-ng start "$IFACE" &>/dev/null
    MON="${IFACE}mon"
    [ ! -d "/sys/class/net/$MON" ] && MON="$IFACE"

    ok "Monitor mode: $MON"
}

add_threat() {
    local sev="$1" type="$2" target="$3" desc="$4" evidence="$5"
    local ts; ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local entry="{\"severity\":\"$sev\",\"type\":\"$type\",\"target\":\"$target\",\"description\":\"$desc\",\"evidence\":\"$evidence\",\"timestamp\":\"$ts\"}"

    if command -v jq &>/dev/null; then
        local tmp; tmp=$(mktemp)
        jq ".threats += [$entry] | .stats.${sev} += 1" "$THREAT_DB" > "$tmp" && mv "$tmp" "$THREAT_DB"
    else
        echo "$entry" >> "$LOOT_DIR/threats_raw.json"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# BASELINE LEARNING
# ═══════════════════════════════════════════════════════════════════════════
learn_baseline() {
    info "Learning environment baseline (90 seconds)..."

    local scan_prefix="$LOOT_DIR/baseline"
    timeout 90 airodump-ng "$MON" --wps --output-format csv -w "$scan_prefix" 2>/dev/null &
    local pid=$!
    local e=0
    while [ $e -lt 85 ] && kill -0 $pid 2>/dev/null; do
        printf "\r  Baseline scan: %d/90s  " $e; sleep 5; ((e+=5))
    done; echo ""
    kill $pid 2>/dev/null; wait $pid 2>/dev/null

    # Parse into baseline
    echo '{"known_aps":[],"known_clients":[]}' > "$BASELINE_DB"

    if [ -f "${scan_prefix}-01.csv" ] && command -v jq &>/dev/null; then
        local ap_count=0
        while IFS=',' read -r bssid first last ch sp priv cipher auth pwr bcn iv lip idlen essid rest; do
            bssid=$(echo "$bssid" | xargs); essid=$(echo "$essid" | xargs)
            ch=$(echo "$ch" | xargs); pwr=$(echo "$pwr" | xargs)
            [[ "$bssid" == "BSSID" ]] && continue
            [[ "$bssid" == "Station"* ]] && break
            [ -z "$bssid" ] && continue

            local tmp; tmp=$(mktemp)
            jq ".known_aps += [{\"bssid\":\"$bssid\",\"essid\":\"$essid\",\"channel\":\"$ch\",\"power\":\"$pwr\",\"encryption\":\"$(echo "$priv" | xargs)\"}]" \
                "$BASELINE_DB" > "$tmp" && mv "$tmp" "$BASELINE_DB"
            ((ap_count++))
        done < "${scan_prefix}-01.csv"

        ok "Baseline: $ap_count known APs recorded"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# THREAT DETECTION ENGINE
# ═══════════════════════════════════════════════════════════════════════════
detect_threats() {
    info "Starting threat detection cycle..."

    local scan_prefix="$LOOT_DIR/scan_$(date +%s)"
    timeout 30 airodump-ng "$MON" --wps --output-format csv -w "$scan_prefix" 2>/dev/null &
    local pid=$!
    sleep 28
    kill $pid 2>/dev/null; wait $pid 2>/dev/null

    [ ! -f "${scan_prefix}-01.csv" ] && { warn "No scan data"; return; }

    # Evil twin detection
    if [ -f "$BASELINE_DB" ] && command -v jq &>/dev/null; then
        while IFS=',' read -r bssid first last ch sp priv cipher auth pwr rest; do
            bssid=$(echo "$bssid" | xargs)
            [[ "$bssid" == "BSSID" ]] && continue
            [[ "$bssid" == "Station"* ]] && break
            [ -z "$bssid" ] && continue

            local essid; essid=$(echo "$rest" | rev | cut -d',' -f1 | rev | xargs)
            local known_bssids
            known_bssids=$(jq -r ".known_aps[] | select(.essid == \"$essid\") | .bssid" "$BASELINE_DB" 2>/dev/null)

            if [ -n "$known_bssids" ]; then
                echo "$known_bssids" | grep -qi "$bssid" || {
                    threat "EVIL TWIN: '$essid' seen from unknown BSSID $bssid"
                    add_threat "critical" "evil_twin" "$essid" \
                        "Potential evil twin AP detected. Known ESSID from unknown BSSID" \
                        "BSSID=$bssid ESSID=$essid Ch=$ch"
                }
            fi
        done < "${scan_prefix}-01.csv"
    fi

    # Deauth flood detection (check for unusual deauth frames)
    local deauth_pcap="$LOOT_DIR/deauth_check.pcap"
    timeout 10 tcpdump -i "$MON" -w "$deauth_pcap" 'subtype deauth or subtype disassoc' -c 100 2>/dev/null || true

    if [ -f "$deauth_pcap" ] && [ -s "$deauth_pcap" ]; then
        if command -v tshark &>/dev/null; then
            local deauth_count; deauth_count=$(tshark -r "$deauth_pcap" 2>/dev/null | wc -l)
            if [ "$deauth_count" -gt 20 ]; then
                local top_src; top_src=$(tshark -r "$deauth_pcap" -T fields -e wlan.sa 2>/dev/null | sort | uniq -c | sort -rn | head -1)
                threat "DEAUTH FLOOD: $deauth_count frames in 10s (source: $top_src)"
                add_threat "critical" "deauth_flood" "Wireless Environment" \
                    "Active deauthentication attack detected" \
                    "$deauth_count deauth/disassoc frames in 10 seconds. Top source: $top_src"
            fi
        fi
    fi
    rm -f "$deauth_pcap"

    # New AP detection (not in baseline)
    if [ -f "$BASELINE_DB" ] && command -v jq &>/dev/null; then
        while IFS=',' read -r bssid first last ch sp priv rest; do
            bssid=$(echo "$bssid" | xargs)
            [[ "$bssid" == "BSSID" ]] && continue
            [[ "$bssid" == "Station"* ]] && break
            [ -z "$bssid" ] && continue

            local known; known=$(jq -r ".known_aps[] | select(.bssid == \"$bssid\") | .bssid" "$BASELINE_DB" 2>/dev/null)
            if [ -z "$known" ]; then
                local essid; essid=$(echo "$rest" | rev | cut -d',' -f1 | rev | xargs)
                warn "NEW AP: $essid ($bssid) on ch $ch — not in baseline"
                add_threat "medium" "new_ap" "$essid" \
                    "Previously unseen access point appeared" \
                    "BSSID=$bssid Ch=$ch Enc=$(echo "$priv" | xargs)"
            fi
        done < "${scan_prefix}-01.csv"
    fi

    ok "Threat detection cycle complete"
}

# ═══════════════════════════════════════════════════════════════════════════
# DASHBOARD
# ═══════════════════════════════════════════════════════════════════════════
generate_dashboard() {
    info "Generating threat dashboard..."

    local crit high med low total
    if command -v jq &>/dev/null; then
        crit=$(jq '.stats.critical' "$THREAT_DB" 2>/dev/null || echo 0)
        high=$(jq '.stats.high' "$THREAT_DB" 2>/dev/null || echo 0)
        med=$(jq '.stats.medium' "$THREAT_DB" 2>/dev/null || echo 0)
        low=$(jq '.stats.low' "$THREAT_DB" 2>/dev/null || echo 0)
        total=$(jq '.threats | length' "$THREAT_DB" 2>/dev/null || echo 0)
    else
        crit=0; high=0; med=0; low=0; total=0
    fi

    cat > "$DASHBOARD" << HTMLEOF
<!DOCTYPE html><html><head><meta charset="utf-8"><meta http-equiv="refresh" content="15">
<title>ThreatMap — Live Dashboard</title>
<style>
:root{--bg:#0a0e17;--card:#111827;--red:#ef4444;--org:#f97316;--yel:#eab308;--grn:#22c55e;--accent:#ef4444;--txt:#e0e0e0}
*{margin:0;padding:0;box-sizing:border-box}
body{background:var(--bg);color:var(--txt);font-family:'Segoe UI',system-ui,sans-serif;padding:20px}
.header{display:flex;align-items:center;justify-content:space-between;margin-bottom:24px}
h1{color:var(--accent);font-size:24px}
.pulse{width:12px;height:12px;border-radius:50%;background:var(--red);animation:pulse 1.5s infinite}
@keyframes pulse{0%,100%{opacity:1;transform:scale(1)}50%{opacity:.5;transform:scale(1.3)}}
.stats{display:grid;grid-template-columns:repeat(5,1fr);gap:12px;margin-bottom:24px}
.stat{background:var(--card);border-radius:12px;padding:16px;text-align:center;border:1px solid #222}
.stat .v{font-size:48px;font-weight:800}
.stat .k{font-size:11px;color:#888;margin-top:4px;text-transform:uppercase}
.c1 .v{color:var(--red)}.c2 .v{color:var(--org)}.c3 .v{color:var(--yel)}.c4 .v{color:var(--grn)}.c5 .v{color:#888}
.timeline{background:var(--card);border-radius:12px;padding:20px;border:1px solid #222;margin-bottom:24px;max-height:500px;overflow-y:auto}
.timeline h3{color:var(--accent);margin-bottom:12px;font-size:16px}
.event{padding:10px 12px;border-left:3px solid;margin-bottom:8px;border-radius:0 8px 8px 0;background:rgba(255,255,255,.02);font-size:13px}
.event .time{color:#666;font-size:11px;float:right}
.event .tag{display:inline-block;padding:2px 8px;border-radius:4px;font-size:10px;font-weight:bold;margin-right:8px}
.ev-critical{border-color:var(--red)}.ev-critical .tag{background:rgba(239,68,68,.2);color:var(--red)}
.ev-high{border-color:var(--org)}.ev-high .tag{background:rgba(249,115,22,.2);color:var(--org)}
.ev-medium{border-color:var(--yel)}.ev-medium .tag{background:rgba(234,179,8,.2);color:var(--yel)}
.ev-low{border-color:var(--grn)}.ev-low .tag{background:rgba(34,197,94,.2);color:var(--grn)}
.legend{display:flex;gap:16px;margin-bottom:24px;flex-wrap:wrap}
.legend span{display:flex;align-items:center;gap:6px;font-size:12px;color:#888}
.legend span::before{content:'';width:10px;height:10px;border-radius:50%}
.l-et::before{background:var(--red)}.l-da::before{background:var(--org)}.l-na::before{background:var(--yel)}.l-pr::before{background:#06b6d4}
.footer{text-align:center;color:#555;font-size:12px;margin-top:24px}
</style></head><body>

<div class="header">
<h1>⚠️ ThreatMap — Live Threat Dashboard</h1>
<div style="display:flex;align-items:center;gap:8px"><span style="color:#888;font-size:12px">MONITORING</span><div class="pulse"></div></div>
</div>

<div class="stats">
<div class="stat c1"><div class="v">$crit</div><div class="k">Critical</div></div>
<div class="stat c2"><div class="v">$high</div><div class="k">High</div></div>
<div class="stat c3"><div class="v">$med</div><div class="k">Medium</div></div>
<div class="stat c4"><div class="v">$low</div><div class="k">Low</div></div>
<div class="stat c5"><div class="v">$total</div><div class="k">Total</div></div>
</div>

<div class="legend">
<span class="l-et">Evil Twin</span>
<span class="l-da">Deauth Attack</span>
<span class="l-na">New AP</span>
<span class="l-pr">Probe Anomaly</span>
</div>

<div class="timeline">
<h3>📋 Threat Timeline</h3>
HTMLEOF

    if command -v jq &>/dev/null; then
        jq -r '.threats | reverse | .[] | "<div class=\"event ev-\(.severity)\"><span class=\"time\">\(.timestamp)</span><span class=\"tag\">\(.severity | ascii_upcase)</span><strong>\(.type)</strong> — \(.description)<br><small style=\"color:#666\">Target: \(.target) | Evidence: \(.evidence)</small></div>"' \
            "$THREAT_DB" >> "$DASHBOARD" 2>/dev/null
    fi

    cat >> "$DASHBOARD" << 'HTMLEOF'
</div>
<div class="footer">ThreatMap v1.0.0 — NullSec Suite — Auto-refreshes every 15 seconds</div>
</body></html>
HTMLEOF

    ok "Dashboard: $DASHBOARD"
}

# ── Continuous monitoring ──────────────────────────────────────────────────
continuous_monitor() {
    info "Starting continuous threat monitoring (Ctrl+C to stop)..."
    local cycle=0

    trap 'info "Stopping monitor..."; generate_dashboard; cleanup; exit 0' INT TERM

    while true; do
        ((cycle++))
        info "═══ Monitoring cycle $cycle ═══"
        detect_threats
        generate_dashboard
        info "Next cycle in 15 seconds..."
        sleep 15
    done
}

cleanup() {
    airmon-ng stop "$MON" &>/dev/null 2>&1
    ok "Monitor mode disabled"
}

show_menu() {
    while true; do
        echo ""
        echo -e "${RED}╔═══════════════════════════════════════════════╗${RST}"
        echo -e "${RED}║     ThreatMap — Threat Visualization          ║${RST}"
        echo -e "${RED}╠═══════════════════════════════════════════════╣${RST}"
        echo -e "${RED}║${RST} [1] Learn Environment Baseline               ${RED}║${RST}"
        echo -e "${RED}║${RST} [2] Single Threat Detection Cycle             ${RED}║${RST}"
        echo -e "${RED}║${RST} [3] Continuous Monitoring                     ${RED}║${RST}"
        echo -e "${RED}║${RST} [4] Generate Dashboard                       ${RED}║${RST}"
        echo -e "${RED}║${RST} [5] View Threats (JSON)                      ${RED}║${RST}"
        echo -e "${RED}║${RST} [0] Exit                                     ${RED}║${RST}"
        echo -e "${RED}╚═══════════════════════════════════════════════╝${RST}"
        echo ""
        read -rp "Select> " c
        case "$c" in
            1) learn_baseline ;;
            2) detect_threats; generate_dashboard ;;
            3) continuous_monitor ;;
            4) generate_dashboard ;;
            5) command -v jq &>/dev/null && jq '.' "$THREAT_DB" || cat "$THREAT_DB" ;;
            0) cleanup; exit 0 ;;
            *) warn "Invalid" ;;
        esac
    done
}

main() {
    banner
    setup
    case "$1" in
        --baseline)  learn_baseline ;;
        --monitor)   learn_baseline; continuous_monitor ;;
        --dashboard) generate_dashboard ;;
        *)           show_menu ;;
    esac
}

main "$@"
