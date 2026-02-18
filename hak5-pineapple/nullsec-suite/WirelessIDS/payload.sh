#!/bin/bash
###############################################################################
# WirelessIDS — Real-Time Wireless Intrusion Detection System
# NullSec Suite | WiFi Pineapple Mark VII / Nano / Tetra
#
# Continuous wireless threat monitoring with real-time alerting:
# - Deauthentication flood detection
# - Evil twin / rogue AP detection
# - Karma attack detection
# - WPS bruteforce detection
# - Client tracking anomaly detection
# - PMKID/EAPOL attack detection
# Outputs to syslog, LED alerts, and HTML dashboard.
#
# Author : bad-antics (NullSec)
# Version: 1.0.0
# License: MIT
###############################################################################

PAYLOAD_DIR="/root/payloads/WirelessIDS"
LOOT_DIR="/mmc/nullsec/wirelessids"
LOG_FILE="$LOOT_DIR/ids.log"
ALERT_FILE="$LOOT_DIR/alerts.csv"
BASELINE_FILE="$LOOT_DIR/baseline.json"
DASHBOARD_FILE="$LOOT_DIR/ids_dashboard.html"
IFACE=""
IFACE_MON=""

# Thresholds
DEAUTH_THRESHOLD=10      # deauths per minute to alert
BEACON_FLOOD_THRESHOLD=50 # unique SSIDs per scan to alert
WPS_THRESHOLD=15          # WPS attempts per minute
EAPOL_THRESHOLD=30        # EAPOL frames per minute
PROBE_FLOOD_THRESHOLD=100 # probes from single MAC per minute

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
CYN='\033[0;36m'; BLU='\033[0;34m'; RST='\033[0m'

log()  { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { log "${GRN}[✓]${RST} $*"; }
warn() { log "${YEL}[!]${RST} $*"; }
fail() { log "${RED}[✗]${RST} $*"; }
info() { log "${CYN}[i]${RST} $*"; }
alert(){ log "${RED}[⚠ ALERT]${RST} $*"; }

banner() {
    echo -e "${RED}"
    cat << 'EOF'
 __        ___          _               ___ ____  ____
 \ \      / (_)_ __ ___| | ___  ___ ___|_ _|  _ \/ ___|
  \ \ /\ / /| | '__/ _ \ |/ _ \/ __/ __|| || | | \___ \
   \ V  V / | | | |  __/ |  __/\__ \__ \| || |_| |___) |
    \_/\_/  |_|_|  \___|_|\___||___/___/___|____/|____/
              NullSec Threat Detection
EOF
    echo -e "${RST}"
}

# ── Pre-flight ─────────────────────────────────────────────────────────────
preflight() {
    mkdir -p "$LOOT_DIR"
    > "$LOG_FILE"
    echo "timestamp,severity,type,source,target,detail,action" > "$ALERT_FILE"

    IFACE=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
    if [ -z "$IFACE" ]; then
        fail "No wireless interface found"
        exit 1
    fi

    # Enable monitor mode
    airmon-ng start "$IFACE" &>/dev/null
    IFACE_MON="${IFACE}mon"
    [ ! -d "/sys/class/net/$IFACE_MON" ] && IFACE_MON="$IFACE"
    ok "Monitor mode: $IFACE_MON"
}

# ── Baseline learning ─────────────────────────────────────────────────────
learn_baseline() {
    info "Learning wireless environment baseline (60 seconds)..."

    local scan_prefix="$LOOT_DIR/baseline_scan"
    timeout 60 airodump-ng "$IFACE_MON" --output-format csv -w "$scan_prefix" 2>/dev/null &
    local pid=$!

    local elapsed=0
    while [ "$elapsed" -lt 60 ] && kill -0 "$pid" 2>/dev/null; do
        printf "\r  Learning... %d/60s  " "$elapsed"
        sleep 5
        ((elapsed+=5))
    done
    echo ""
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null

    # Parse baseline APs
    local baseline_aps="$LOOT_DIR/baseline_aps.txt"
    > "$baseline_aps"
    if [ -f "${scan_prefix}-01.csv" ]; then
        local ap_count=0
        while IFS=',' read -r bssid first last ch sp priv cipher auth pwr bcn iv lip idlen essid rest; do
            bssid=$(echo "$bssid" | xargs)
            essid=$(echo "$essid" | xargs)
            ch=$(echo "$ch" | xargs)
            [[ "$bssid" == "BSSID" ]] && continue
            [[ "$bssid" == "Station"* ]] && break
            [ -z "$bssid" ] && continue
            echo "$bssid|$essid|$ch|$priv" >> "$baseline_aps"
            ((ap_count++))
        done < "${scan_prefix}-01.csv"
        ok "Baseline: $ap_count known access points"
    fi
}

# ── Detection modules ─────────────────────────────────────────────────────

detect_deauth_flood() {
    local pcap="$1"
    local deauth_count
    deauth_count=$(tshark -r "$pcap" -Y "wlan.fc.type_subtype == 0x0c" 2>/dev/null | wc -l)

    if [ "$deauth_count" -gt "$DEAUTH_THRESHOLD" ]; then
        local sources
        sources=$(tshark -r "$pcap" -Y "wlan.fc.type_subtype == 0x0c" -T fields -e wlan.sa 2>/dev/null | sort | uniq -c | sort -rn | head -3)
        alert "DEAUTH FLOOD: $deauth_count frames detected!"
        echo "$sources" | while read -r count mac; do
            raise_alert "critical" "DEAUTH_FLOOD" "$mac" "broadcast" "$count deauth frames in monitoring window" "investigate"
        done
        return 0
    fi
    return 1
}

detect_evil_twin() {
    local pcap="$1"
    local baseline_aps="$LOOT_DIR/baseline_aps.txt"
    [ ! -f "$baseline_aps" ] && return 1

    # Get current SSIDs and their BSSIDs
    local current_aps
    current_aps=$(tshark -r "$pcap" -Y "wlan.fc.type_subtype == 0x08" \
        -T fields -e wlan.bssid -e wlan.ssid 2>/dev/null | sort -u)

    while IFS=$'\t' read -r bssid ssid; do
        [ -z "$bssid" ] || [ -z "$ssid" ] && continue

        # Check if SSID exists in baseline with different BSSID
        if grep -q "|$ssid|" "$baseline_aps" 2>/dev/null; then
            if ! grep -qi "$bssid" "$baseline_aps" 2>/dev/null; then
                alert "EVIL TWIN: '$ssid' from unknown BSSID $bssid"
                raise_alert "critical" "EVIL_TWIN" "$bssid" "$ssid" "Known SSID from unauthorized BSSID" "block_and_investigate"
            fi
        fi
    done <<< "$current_aps"
}

detect_karma() {
    local pcap="$1"
    
    # Karma attack: AP responds to ALL probe requests with matching beacons
    local probe_ssids
    probe_ssids=$(tshark -r "$pcap" -Y "wlan.fc.type_subtype == 0x04" \
        -T fields -e wlan.ssid 2>/dev/null | sort -u | head -20)

    local responding_aps
    responding_aps=$(tshark -r "$pcap" -Y "wlan.fc.type_subtype == 0x05" \
        -T fields -e wlan.bssid 2>/dev/null | sort | uniq -c | sort -rn)

    # If one AP responds to many different SSIDs, it's likely karma
    while read -r count bssid; do
        [ -z "$bssid" ] && continue
        if [ "$count" -gt 10 ]; then
            alert "KARMA ATTACK: $bssid responding to $count different probe requests"
            raise_alert "critical" "KARMA_ATTACK" "$bssid" "multiple_clients" "AP responding to $count unique probes" "disconnect_and_block"
        fi
    done <<< "$responding_aps"
}

detect_wps_bruteforce() {
    local pcap="$1"
    local wps_count
    wps_count=$(tshark -r "$pcap" -Y "wps" 2>/dev/null | wc -l)

    if [ "$wps_count" -gt "$WPS_THRESHOLD" ]; then
        local sources
        sources=$(tshark -r "$pcap" -Y "wps" -T fields -e wlan.sa 2>/dev/null | sort | uniq -c | sort -rn | head -3)
        alert "WPS BRUTEFORCE: $wps_count WPS frames detected"
        echo "$sources" | while read -r count mac; do
            raise_alert "high" "WPS_BRUTEFORCE" "$mac" "" "$count WPS frames" "disable_wps"
        done
    fi
}

detect_pmkid_attack() {
    local pcap="$1"
    
    # PMKID attacks show up as EAPOL key frames from new stations
    local eapol_count
    eapol_count=$(tshark -r "$pcap" -Y "eapol" 2>/dev/null | wc -l)

    if [ "$eapol_count" -gt "$EAPOL_THRESHOLD" ]; then
        local sources
        sources=$(tshark -r "$pcap" -Y "eapol" -T fields -e wlan.sa 2>/dev/null | sort | uniq -c | sort -rn | head -5)
        alert "PMKID/EAPOL ATTACK: $eapol_count EAPOL frames"
        echo "$sources" | while read -r count mac; do
            [ -n "$mac" ] && raise_alert "high" "PMKID_ATTACK" "$mac" "" "$count EAPOL frames" "monitor"
        done
    fi
}

detect_probe_flood() {
    local pcap="$1"

    # Single device sending excessive probes (recon tool)
    tshark -r "$pcap" -Y "wlan.fc.type_subtype == 0x04" \
        -T fields -e wlan.sa 2>/dev/null | sort | uniq -c | sort -rn | head -5 | \
    while read -r count mac; do
        [ -z "$mac" ] && continue
        if [ "$count" -gt "$PROBE_FLOOD_THRESHOLD" ]; then
            alert "PROBE FLOOD: $mac sent $count probe requests"
            raise_alert "medium" "PROBE_FLOOD" "$mac" "" "$count probes (recon tool suspected)" "monitor"
        fi
    done
}

# ── Alert management ──────────────────────────────────────────────────────
ALERT_COUNT=0
raise_alert() {
    local severity="$1" type="$2" source="$3" target="$4" detail="$5" action="$6"
    local ts
    ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    echo "$ts,$severity,$type,$source,$target,$detail,$action" >> "$ALERT_FILE"
    ((ALERT_COUNT++))

    # LED feedback
    case "$severity" in
        critical) LED CUSTOM 255 0 0 VERYFAST 2>/dev/null ;;
        high)     LED CUSTOM 255 128 0 FAST 2>/dev/null ;;
        medium)   LED CUSTOM 255 255 0 SLOW 2>/dev/null ;;
    esac
}

# ── Main monitoring loop ──────────────────────────────────────────────────
monitor() {
    local interval="${1:-30}"  # Capture window in seconds
    local max_rounds="${2:-0}" # 0 = infinite
    local round=0

    info "Starting WirelessIDS monitoring (${interval}s windows)..."
    info "Thresholds: Deauth=$DEAUTH_THRESHOLD Beacon=$BEACON_FLOOD_THRESHOLD WPS=$WPS_THRESHOLD"

    while true; do
        ((round++))
        [ "$max_rounds" -gt 0 ] && [ "$round" -gt "$max_rounds" ] && break

        local pcap="$LOOT_DIR/ids_window_${round}.pcap"
        info "── Monitor Window $round ──"

        # Capture window
        timeout "$interval" tshark -i "$IFACE_MON" -w "$pcap" \
            -f "type mgt or type ctl or ether proto 0x888e" 2>/dev/null

        if [ ! -f "$pcap" ] || [ ! -s "$pcap" ]; then
            warn "Empty capture window, continuing..."
            continue
        fi

        # Run all detection modules
        detect_deauth_flood "$pcap"
        detect_evil_twin "$pcap"
        detect_karma "$pcap"
        detect_wps_bruteforce "$pcap"
        detect_pmkid_attack "$pcap"
        detect_probe_flood "$pcap"

        # Clean up old captures (keep last 5)
        local keep=$((round - 5))
        [ "$keep" -gt 0 ] && rm -f "$LOOT_DIR/ids_window_${keep}.pcap"

        # Status
        local total_alerts
        total_alerts=$(tail -n +2 "$ALERT_FILE" | wc -l)
        info "Window $round complete | Total alerts: $total_alerts"

        # Update dashboard every 5 rounds
        [ $((round % 5)) -eq 0 ] && generate_dashboard
    done

    generate_dashboard
    ok "Monitoring complete after $round windows"
}

# ── Dashboard generation ──────────────────────────────────────────────────
generate_dashboard() {
    local total_alerts critical_count high_count medium_count
    total_alerts=$(tail -n +2 "$ALERT_FILE" 2>/dev/null | wc -l || echo 0)
    critical_count=$(grep -c "critical" "$ALERT_FILE" 2>/dev/null || echo 0)
    high_count=$(grep -c ",high," "$ALERT_FILE" 2>/dev/null || echo 0)
    medium_count=$(grep -c ",medium," "$ALERT_FILE" 2>/dev/null || echo 0)

    cat > "$DASHBOARD_FILE" << HTMLEOF
<!DOCTYPE html><html><head><meta charset="utf-8">
<meta http-equiv="refresh" content="30">
<title>WirelessIDS Dashboard — NullSec</title>
<style>
:root{--bg:#0a0e17;--card:#111827;--accent:#ef4444;--red:#dc2626;--org:#f97316;--yel:#eab308;--grn:#22c55e;--txt:#e0e0e0}
*{margin:0;padding:0;box-sizing:border-box}
body{background:var(--bg);color:var(--txt);font-family:'Segoe UI',system-ui,sans-serif;padding:24px}
h1{color:var(--accent);font-size:28px;margin-bottom:4px}
.sub{color:#888;margin-bottom:24px;font-size:14px}
.live{display:inline-block;width:8px;height:8px;background:var(--red);border-radius:50%;animation:pulse 1s infinite;margin-right:8px}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:0.3}}
.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:32px}
.card{background:var(--card);border-radius:12px;padding:20px;text-align:center;border:1px solid #222}
.card .n{font-size:42px;font-weight:700}
.card .l{font-size:13px;color:#888;margin-top:4px}
.crit .n{color:var(--red)}
.high .n{color:var(--org)}
.med .n{color:var(--yel)}
.total .n{color:var(--accent)}
h2{color:var(--accent);margin:24px 0 12px}
table{width:100%;border-collapse:collapse;background:var(--card);border-radius:12px;overflow:hidden;margin-bottom:24px}
th{background:#1a2332;color:var(--accent);padding:12px 16px;text-align:left;font-size:12px;text-transform:uppercase}
td{padding:10px 16px;border-bottom:1px solid #1a1a2e;font-size:13px}
.sev-critical{color:var(--red);font-weight:bold}
.sev-high{color:var(--org);font-weight:bold}
.sev-medium{color:var(--yel)}
.footer{margin-top:32px;text-align:center;color:#555;font-size:12px}
</style></head><body>
<h1><span class="live"></span>WirelessIDS — Live Threat Dashboard</h1>
<p class="sub">Last updated: $(date -u '+%Y-%m-%d %H:%M:%S UTC') — Auto-refresh: 30s</p>

<div class="grid">
<div class="card total"><div class="n">$total_alerts</div><div class="l">Total Alerts</div></div>
<div class="card crit"><div class="n">$critical_count</div><div class="l">Critical</div></div>
<div class="card high"><div class="n">$high_count</div><div class="l">High</div></div>
<div class="card med"><div class="n">$medium_count</div><div class="l">Medium</div></div>
</div>

<h2>Recent Alerts</h2>
<table><thead><tr><th>Time</th><th>Severity</th><th>Type</th><th>Source</th><th>Target</th><th>Detail</th><th>Action</th></tr></thead><tbody>
HTMLEOF

    tail -n +2 "$ALERT_FILE" 2>/dev/null | tail -50 | tac | while IFS=',' read -r ts sev type src tgt detail action; do
        echo "<tr><td>$ts</td><td class=\"sev-$sev\">$sev</td><td>$type</td><td><code>$src</code></td><td>$tgt</td><td>$detail</td><td>$action</td></tr>" >> "$DASHBOARD_FILE"
    done

    cat >> "$DASHBOARD_FILE" << 'HTMLEOF'
</tbody></table>
<div class="footer">WirelessIDS v1.0.0 — NullSec Suite — Real-time wireless threat detection</div>
</body></html>
HTMLEOF
}

LED() { command -v LED &>/dev/null && command LED "$@" 2>/dev/null; true; }

# ── Cleanup ────────────────────────────────────────────────────────────────
cleanup() {
    info "Stopping IDS..."
    airmon-ng stop "$IFACE_MON" &>/dev/null 2>&1
    generate_dashboard
    ok "IDS stopped — $ALERT_COUNT alerts raised"
}
trap cleanup EXIT

# ── Menu ───────────────────────────────────────────────────────────────────
show_menu() {
    while true; do
        echo ""
        echo -e "${RED}╔═══════════════════════════════════════════╗${RST}"
        echo -e "${RED}║    WirelessIDS — Threat Detection         ║${RST}"
        echo -e "${RED}╠═══════════════════════════════════════════╣${RST}"
        echo -e "${RED}║${RST} [1] Learn Environment Baseline             ${RED}║${RST}"
        echo -e "${RED}║${RST} [2] Start Monitoring (default: 30s window) ${RED}║${RST}"
        echo -e "${RED}║${RST} [3] Start Monitoring (custom interval)     ${RED}║${RST}"
        echo -e "${RED}║${RST} [4] Quick Scan (5 rounds)                  ${RED}║${RST}"
        echo -e "${RED}║${RST} [5] View Alerts                            ${RED}║${RST}"
        echo -e "${RED}║${RST} [6] Generate Dashboard                     ${RED}║${RST}"
        echo -e "${RED}║${RST} [7] Set Detection Thresholds               ${RED}║${RST}"
        echo -e "${RED}║${RST} [0] Exit                                   ${RED}║${RST}"
        echo -e "${RED}╚═══════════════════════════════════════════╝${RST}"
        echo ""
        read -rp "Select> " choice

        case "$choice" in
            1) learn_baseline ;;
            2) learn_baseline; monitor 30 ;;
            3) read -rp "Window interval (s): " i; read -rp "Max rounds (0=∞): " r; monitor "$i" "$r" ;;
            4) learn_baseline; monitor 30 5 ;;
            5) column -t -s',' "$ALERT_FILE" 2>/dev/null | tail -30 ;;
            6) generate_dashboard; ok "Dashboard: $DASHBOARD_FILE" ;;
            7)
                read -rp "Deauth threshold [$DEAUTH_THRESHOLD]: " t; [ -n "$t" ] && DEAUTH_THRESHOLD=$t
                read -rp "WPS threshold [$WPS_THRESHOLD]: " t; [ -n "$t" ] && WPS_THRESHOLD=$t
                read -rp "EAPOL threshold [$EAPOL_THRESHOLD]: " t; [ -n "$t" ] && EAPOL_THRESHOLD=$t
                read -rp "Probe flood threshold [$PROBE_FLOOD_THRESHOLD]: " t; [ -n "$t" ] && PROBE_FLOOD_THRESHOLD=$t
                ok "Thresholds updated"
                ;;
            0) exit 0 ;;
            *) warn "Invalid" ;;
        esac
    done
}

main() {
    banner
    preflight
    case "$1" in
        --auto)     learn_baseline; monitor 30 ;;
        --quick)    learn_baseline; monitor 30 5 ;;
        --baseline) learn_baseline ;;
        *)          show_menu ;;
    esac
}

main "$@"
