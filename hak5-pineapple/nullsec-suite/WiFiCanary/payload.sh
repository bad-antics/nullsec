#!/bin/bash
###############################################################################
# WiFiCanary — Wireless Honeypot & Early Warning System
# NullSec Suite | WiFi Pineapple Mark VII / Nano / Tetra
#
# Deploys decoy wireless networks to detect attackers and probe behavior:
# - Honeypot APs with realistic configurations (WPA2/Open/WPA3)
# - Client connection tracking with fingerprinting
# - Attack detection (deauth, probe floods, credential attempts)
# - Real-time alerting via LED, webhook, and log
# - Attacker behavior profiling & TTP classification
# - Automatic evidence collection for incident response
#
# Author : bad-antics (NullSec)
# Version: 1.0.0
# License: MIT
###############################################################################

LOOT_DIR="/mmc/nullsec/wificanary"
LOG_FILE="$LOOT_DIR/canary.log"
ALERT_LOG="$LOOT_DIR/alerts.json"
ATTACKER_DB="$LOOT_DIR/attackers.json"
REPORT_FILE="$LOOT_DIR/canary_report.html"
CONF_DIR="$LOOT_DIR/conf"
IFACE=""
WEBHOOK_URL=""

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
CYN='\033[0;36m'; MAG='\033[0;35m'; BLD='\033[1m'; RST='\033[0m'

log()   { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()    { log "${GRN}[✓]${RST} $*"; }
warn()  { log "${YEL}[!]${RST} $*"; }
fail()  { log "${RED}[✗]${RST} $*"; }
info()  { log "${CYN}[i]${RST} $*"; }
alert() { log "${RED}[🚨 ALERT]${RST} $*"; }

banner() {
    echo -e "${YEL}"
    cat << 'EOF'
 __        ___ _____ _  ____
 \ \      / (_)  ___(_)/ ___|__ _ _ __   __ _ _ __ _   _
  \ \ /\ / /| | |_  | | |   / _` | '_ \ / _` | '__| | | |
   \ V  V / | |  _| | | |__| (_| | | | | (_| | |  | |_| |
    \_/\_/  |_|_|   |_|\____\__,_|_| |_|\__,_|_|   \__, |
                                                    |___/
  NullSec Wireless Honeypot & Early Warning
EOF
    echo -e "${RST}"
}

setup() {
    mkdir -p "$LOOT_DIR" "$CONF_DIR"
    > "$LOG_FILE"
    echo '{"alerts":[],"stats":{"total":0,"critical":0,"connections":0,"attacks":0}}' > "$ALERT_LOG"
    echo '{"attackers":[]}' > "$ATTACKER_DB"

    IFACE=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
    [ -z "$IFACE" ] && { fail "No wireless interface"; exit 1; }

    ok "Interface: $IFACE"
}

fire_alert() {
    local sev="$1" type="$2" mac="$3" desc="$4"
    local ts; ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    alert "[$sev] $type: $desc (MAC: $mac)"

    if command -v jq &>/dev/null; then
        local tmp; tmp=$(mktemp)
        jq ".alerts += [{\"severity\":\"$sev\",\"type\":\"$type\",\"mac\":\"$mac\",\"description\":\"$desc\",\"timestamp\":\"$ts\"}] | .stats.total += 1" \
            "$ALERT_LOG" > "$tmp" && mv "$tmp" "$ALERT_LOG"
    fi

    # LED alert
    case "$sev" in
        critical) LED ATTACK 2>/dev/null ;;
        high)     LED FAIL 2>/dev/null ;;
        medium)   LED SPECIAL 2>/dev/null ;;
    esac

    # Webhook notification
    if [ -n "$WEBHOOK_URL" ]; then
        curl -sf -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"🚨 WiFiCanary Alert: [$sev] $type - $desc (MAC: $mac)\"}" &>/dev/null &
    fi
}

track_attacker() {
    local mac="$1" ttp="$2" evidence="$3"
    local ts; ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    if command -v jq &>/dev/null; then
        local exists; exists=$(jq -r ".attackers[] | select(.mac == \"$mac\") | .mac" "$ATTACKER_DB" 2>/dev/null)
        local tmp; tmp=$(mktemp)
        if [ -n "$exists" ]; then
            jq "(.attackers[] | select(.mac == \"$mac\")) |= . + {\"last_seen\":\"$ts\",\"ttp_count\":(.ttp_count + 1),\"ttps\":(.ttps + [\"$ttp\"])}" \
                "$ATTACKER_DB" > "$tmp" && mv "$tmp" "$ATTACKER_DB"
        else
            jq ".attackers += [{\"mac\":\"$mac\",\"first_seen\":\"$ts\",\"last_seen\":\"$ts\",\"ttp_count\":1,\"ttps\":[\"$ttp\"],\"evidence\":[\"$evidence\"]}]" \
                "$ATTACKER_DB" > "$tmp" && mv "$tmp" "$ATTACKER_DB"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# HONEYPOT CONFIGURATIONS
# ═══════════════════════════════════════════════════════════════════════════
CANARY_SSIDS=(
    "Corporate-WiFi|wpa2|canary_corp"
    "Guest-Network|open|canary_guest"
    "IT-Department|wpa2|canary_it"
    "PRINTER-NET|open|canary_printer"
    "CCTV-WiFi|wpa2|canary_cctv"
)

deploy_honeypot() {
    local ssid="$1" security="$2" tag="$3"
    info "Deploying honeypot: '$ssid' ($security) [tag: $tag]"

    local conf_file="$CONF_DIR/hostapd_${tag}.conf"
    local log_file="$LOOT_DIR/${tag}_clients.log"

    cat > "$conf_file" << CONFEOF
interface=$IFACE
driver=nl80211
ssid=$ssid
hw_mode=g
channel=$(shuf -i 1-11 -n 1)
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
logger_stdout=-1
logger_stdout_level=2
CONFEOF

    if [ "$security" = "wpa2" ]; then
        cat >> "$conf_file" << CONFEOF
wpa=2
wpa_passphrase=CanaryTrap2024!
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
CONFEOF
    fi

    # Start hostapd with logging
    hostapd "$conf_file" 2>&1 | while read -r line; do
        echo "[$(date '+%H:%M:%S')] $line" >> "$log_file"

        # Detect association
        if echo "$line" | grep -qi "associated\|AP-STA-CONNECTED"; then
            local client_mac; client_mac=$(echo "$line" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}')
            if [ -n "$client_mac" ]; then
                fire_alert "critical" "HONEYPOT_CONNECTION" "$client_mac" \
                    "Device connected to canary AP '$ssid'"
                track_attacker "$client_mac" "honeypot_connection" "Connected to $ssid"
            fi
        fi

        # Detect authentication attempts
        if echo "$line" | grep -qi "authentication\|WPA: pairwise"; then
            local attempt_mac; attempt_mac=$(echo "$line" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}')
            if [ -n "$attempt_mac" ]; then
                fire_alert "high" "AUTH_ATTEMPT" "$attempt_mac" \
                    "Authentication attempt on canary '$ssid'"
                track_attacker "$attempt_mac" "auth_attempt" "Auth attempt on $ssid"
            fi
        fi

        # Detect deauth directed at our honeypot
        if echo "$line" | grep -qi "deauthentication\|disassociation"; then
            local deauth_mac; deauth_mac=$(echo "$line" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}')
            if [ -n "$deauth_mac" ]; then
                fire_alert "high" "DEAUTH_ON_CANARY" "$deauth_mac" \
                    "Deauth attack targeting canary '$ssid'"
                track_attacker "$deauth_mac" "deauth_canary" "Deauth on $ssid"
            fi
        fi
    done &

    ok "Honeypot '$ssid' deployed (PID: $!)"
    echo "$!" >> "$LOOT_DIR/honeypot_pids.txt"
}

deploy_all_honeypots() {
    info "Deploying all canary networks..."
    > "$LOOT_DIR/honeypot_pids.txt"

    for entry in "${CANARY_SSIDS[@]}"; do
        IFS='|' read -r ssid security tag <<< "$entry"
        deploy_honeypot "$ssid" "$security" "$tag"
        sleep 2
    done

    ok "All honeypots deployed"
}

# ═══════════════════════════════════════════════════════════════════════════
# PASSIVE MONITORING
# ═══════════════════════════════════════════════════════════════════════════
passive_monitor() {
    info "Starting passive wireless monitoring..."

    local pcap="$LOOT_DIR/monitor.pcap"

    # Monitor for probe requests targeting our canary SSIDs
    airmon-ng start "$IFACE" &>/dev/null 2>&1
    local mon="${IFACE}mon"
    [ ! -d "/sys/class/net/$mon" ] && mon="$IFACE"

    timeout 300 tcpdump -i "$mon" -w "$pcap" \
        'type mgt subtype probe-req or type mgt subtype probe-resp or type mgt subtype deauth' \
        -c 5000 2>/dev/null &
    local cap_pid=$!

    # Process incoming data in real-time
    local check_interval=15
    local elapsed=0

    while [ $elapsed -lt 300 ] && kill -0 $cap_pid 2>/dev/null; do
        sleep $check_interval
        ((elapsed += check_interval))

        if command -v tshark &>/dev/null && [ -f "$pcap" ] && [ -s "$pcap" ]; then
            # Check for probes targeting our canary SSIDs
            for entry in "${CANARY_SSIDS[@]}"; do
                IFS='|' read -r ssid security tag <<< "$entry"
                local probe_macs
                probe_macs=$(tshark -r "$pcap" -T fields -e wlan.sa \
                    -Y "wlan.fc.type_subtype == 0x04 && wlan_mgt.ssid == \"$ssid\"" 2>/dev/null | sort -u)
                while read -r mac; do
                    [ -z "$mac" ] && continue
                    fire_alert "medium" "CANARY_PROBE" "$mac" \
                        "Device probing for canary SSID '$ssid'"
                    track_attacker "$mac" "canary_probe" "Probed for $ssid"
                done <<< "$probe_macs"
            done

            # Deauth rate detection
            local deauth_rate
            deauth_rate=$(tshark -r "$pcap" -Y "wlan.fc.type_subtype == 0x0c" 2>/dev/null | wc -l)
            if [ "$deauth_rate" -gt 50 ]; then
                fire_alert "critical" "DEAUTH_STORM" "environment" \
                    "High deauth rate: $deauth_rate frames detected"
            fi
        fi

        printf "\r  Monitoring: %d/300s | Alerts: " $elapsed
        if command -v jq &>/dev/null; then
            jq -r '.stats.total' "$ALERT_LOG" 2>/dev/null | tr -d '\n'
        fi
        printf "  "
    done
    echo ""

    kill $cap_pid 2>/dev/null; wait $cap_pid 2>/dev/null
    airmon-ng stop "$mon" &>/dev/null 2>&1

    ok "Passive monitoring complete"
}

# ═══════════════════════════════════════════════════════════════════════════
# REPORT
# ═══════════════════════════════════════════════════════════════════════════
generate_report() {
    info "Generating canary report..."

    local total crit connections attackers
    if command -v jq &>/dev/null; then
        total=$(jq '.stats.total' "$ALERT_LOG" 2>/dev/null || echo 0)
        crit=$(jq '.stats.critical' "$ALERT_LOG" 2>/dev/null || echo 0)
        connections=$(jq '[.alerts[] | select(.type == "HONEYPOT_CONNECTION")] | length' "$ALERT_LOG" 2>/dev/null || echo 0)
        attackers=$(jq '.attackers | length' "$ATTACKER_DB" 2>/dev/null || echo 0)
    else
        total=0; crit=0; connections=0; attackers=0
    fi

    cat > "$REPORT_FILE" << HTMLEOF
<!DOCTYPE html><html><head><meta charset="utf-8">
<title>WiFiCanary — Honeypot Report</title>
<style>
:root{--bg:#0a0e17;--card:#111827;--accent:#eab308;--red:#ef4444;--txt:#e0e0e0}
*{margin:0;padding:0;box-sizing:border-box}
body{background:var(--bg);color:var(--txt);font-family:'Segoe UI',system-ui,sans-serif;padding:24px}
h1{color:var(--accent);font-size:28px;margin-bottom:16px}
h2{color:var(--accent);font-size:20px;margin:24px 0 12px}
.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:32px}
.card{background:var(--card);border-radius:12px;padding:20px;text-align:center;border:1px solid #222}
.card .v{font-size:42px;font-weight:800;color:var(--accent)}
.card .k{font-size:12px;color:#888;margin-top:4px}
table{width:100%;border-collapse:collapse;background:var(--card);border-radius:12px;overflow:hidden;margin-bottom:24px}
th{background:#1a2332;color:var(--accent);padding:12px 16px;text-align:left;font-size:12px;text-transform:uppercase}
td{padding:10px 16px;border-bottom:1px solid #1a1a2e;font-size:13px}
.sev-critical{color:var(--red);font-weight:bold}
.sev-high{color:#f97316;font-weight:bold}
.sev-medium{color:#eab308}
.info-box{background:var(--card);border-radius:12px;padding:20px;border:1px solid #222;margin-bottom:24px;line-height:1.8}
.footer{margin-top:32px;text-align:center;color:#555;font-size:12px}
</style></head><body>

<h1>🐦 WiFiCanary — Honeypot Report</h1>
<p style="color:#888;margin-bottom:24px">Generated: $(date -u '+%Y-%m-%d %H:%M UTC')</p>

<div class="grid">
<div class="card"><div class="v">$total</div><div class="k">Total Alerts</div></div>
<div class="card"><div class="v" style="color:var(--red)">$crit</div><div class="k">Critical Alerts</div></div>
<div class="card"><div class="v" style="color:#f97316">$connections</div><div class="k">Honeypot Connections</div></div>
<div class="card"><div class="v" style="color:var(--red)">$attackers</div><div class="k">Unique Attackers</div></div>
</div>

<h2>🚨 Alert Timeline</h2>
<table><thead><tr><th>Time</th><th>Severity</th><th>Type</th><th>MAC</th><th>Description</th></tr></thead><tbody>
HTMLEOF

    if command -v jq &>/dev/null; then
        jq -r '.alerts[] | "<tr><td>\(.timestamp)</td><td class=\"sev-\(.severity)\">\(.severity)</td><td>\(.type)</td><td><code>\(.mac)</code></td><td>\(.description)</td></tr>"' \
            "$ALERT_LOG" >> "$REPORT_FILE" 2>/dev/null
    fi

    cat >> "$REPORT_FILE" << 'HTMLEOF'
</tbody></table>

<h2>👤 Attacker Profiles</h2>
<table><thead><tr><th>MAC</th><th>First Seen</th><th>Last Seen</th><th>TTPs</th><th>TTP Count</th></tr></thead><tbody>
HTMLEOF

    if command -v jq &>/dev/null; then
        jq -r '.attackers[] | "<tr><td><code>\(.mac)</code></td><td>\(.first_seen)</td><td>\(.last_seen)</td><td>\(.ttps | join(", "))</td><td>\(.ttp_count)</td></tr>"' \
            "$ATTACKER_DB" >> "$REPORT_FILE" 2>/dev/null
    fi

    cat >> "$REPORT_FILE" << 'HTMLEOF'
</tbody></table>

<h2>🍯 Deployed Canaries</h2>
<div class="info-box">
<strong>Corporate-WiFi:</strong> WPA2 honeypot simulating corporate infrastructure<br>
<strong>Guest-Network:</strong> Open network trap for opportunistic attackers<br>
<strong>IT-Department:</strong> WPA2 high-value target decoy<br>
<strong>PRINTER-NET:</strong> Open network mimicking IoT/printer infrastructure<br>
<strong>CCTV-WiFi:</strong> WPA2 decoy simulating security camera network<br>
</div>

<div class="footer">WiFiCanary v1.0.0 — NullSec Suite — For authorized security testing only</div>
</body></html>
HTMLEOF

    ok "Report: $REPORT_FILE"
}

kill_honeypots() {
    info "Stopping all honeypots..."
    if [ -f "$LOOT_DIR/honeypot_pids.txt" ]; then
        while read -r pid; do
            kill "$pid" 2>/dev/null
        done < "$LOOT_DIR/honeypot_pids.txt"
        rm -f "$LOOT_DIR/honeypot_pids.txt"
    fi
    killall hostapd 2>/dev/null
    ok "Honeypots stopped"
}

show_menu() {
    while true; do
        echo ""
        echo -e "${YEL}╔═══════════════════════════════════════════════╗${RST}"
        echo -e "${YEL}║     WiFiCanary — Wireless Honeypot System     ║${RST}"
        echo -e "${YEL}╠═══════════════════════════════════════════════╣${RST}"
        echo -e "${YEL}║${RST} [1] Deploy All Honeypots                     ${YEL}║${RST}"
        echo -e "${YEL}║${RST} [2] Start Passive Monitoring                 ${YEL}║${RST}"
        echo -e "${YEL}║${RST} [3] Full Deploy + Monitor                    ${YEL}║${RST}"
        echo -e "${YEL}║${RST} [4] Generate Report                         ${YEL}║${RST}"
        echo -e "${YEL}║${RST} [5] View Alerts                             ${YEL}║${RST}"
        echo -e "${YEL}║${RST} [6] View Attacker Profiles                  ${YEL}║${RST}"
        echo -e "${YEL}║${RST} [7] Kill All Honeypots                      ${YEL}║${RST}"
        echo -e "${YEL}║${RST} [0] Exit                                    ${YEL}║${RST}"
        echo -e "${YEL}╚═══════════════════════════════════════════════╝${RST}"
        echo ""
        read -rp "Select> " c
        case "$c" in
            1) deploy_all_honeypots ;;
            2) passive_monitor ;;
            3) deploy_all_honeypots; passive_monitor ;;
            4) generate_report ;;
            5) command -v jq &>/dev/null && jq '.' "$ALERT_LOG" || cat "$ALERT_LOG" ;;
            6) command -v jq &>/dev/null && jq '.' "$ATTACKER_DB" || cat "$ATTACKER_DB" ;;
            7) kill_honeypots ;;
            0) kill_honeypots; exit 0 ;;
            *) warn "Invalid" ;;
        esac
    done
}

main() {
    banner
    setup
    case "$1" in
        --deploy)  deploy_all_honeypots ;;
        --monitor) deploy_all_honeypots; passive_monitor ;;
        --report)  generate_report ;;
        *)         show_menu ;;
    esac
}

main "$@"
