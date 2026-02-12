#!/bin/bash
###############################################################################
# BlueBorne — Bluetooth Proximity Attack Scanner
# NullSec Suite | WiFi Pineapple Mark VII / Nano / Tetra
#
# Discovers Bluetooth devices within range, identifies vulnerable firmware
# versions, maps device capabilities (BLE vs Classic), and generates a
# tactical proximity map.  Integrates with hcitool/bluetoothctl when a
# USB Bluetooth adapter is attached to the Pineapple.
#
# Author : bad-antics (NullSec)
# Version: 1.0.0
# License: MIT
###############################################################################

# ── NullSec Framework ──────────────────────────────────────────────────────
PAYLOAD_DIR="/root/payloads/BlueBorne"
LOOT_DIR="/root/loot/blueborne"
LOG_FILE="$LOOT_DIR/blueborne.log"
REPORT_FILE="$LOOT_DIR/blueborne_report.html"
SCAN_INTERVAL=15
MAX_SCAN_ROUNDS=20
DEVICE_DB="$LOOT_DIR/devices.json"

# ── Colour helpers ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
CYN='\033[0;36m'; RST='\033[0m'

log()  { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { log "${GRN}[✓]${RST} $*"; }
warn() { log "${YEL}[!]${RST} $*"; }
fail() { log "${RED}[✗]${RST} $*"; }
info() { log "${CYN}[i]${RST} $*"; }

banner() {
    echo -e "${CYN}"
    cat << 'EOF'
  ____  _            ____
 | __ )| |_   _  ___| __ )  ___  _ __ _ __   ___
 |  _ \| | | | |/ _ \  _ \ / _ \| '__| '_ \ / _ \
 | |_) | | |_| |  __/ |_) | (_) | |  | | | |  __/
 |____/|_|\__,_|\___|____/ \___/|_|  |_| |_|\___|
              NullSec Bluetooth Scanner
EOF
    echo -e "${RST}"
}

# ── Pre-flight ─────────────────────────────────────────────────────────────
preflight() {
    mkdir -p "$LOOT_DIR"
    echo "[]" > "$DEVICE_DB"

    # Check for Bluetooth adapter
    if ! command -v hcitool &>/dev/null; then
        warn "hcitool not found — installing bluetooth tools"
        opkg update &>/dev/null
        opkg install bluez-utils bluez-libs kmod-bluetooth 2>/dev/null
    fi

    if ! command -v hciconfig &>/dev/null && ! command -v bluetoothctl &>/dev/null; then
        fail "No Bluetooth stack available. Attach a USB BT adapter."
        LED FAIL
        exit 1
    fi

    # Bring up adapter
    local adapter
    adapter=$(hciconfig 2>/dev/null | head -1 | awk '{print $1}' | tr -d ':')
    if [ -z "$adapter" ]; then
        fail "No Bluetooth adapter detected"
        LED FAIL
        exit 1
    fi

    hciconfig "$adapter" up 2>/dev/null
    ok "Bluetooth adapter $adapter is UP"
    BT_ADAPTER="$adapter"
}

# ── Known vulnerable firmware database ─────────────────────────────────────
declare -A VULN_DB
VULN_DB["BlueBorne CVE-2017-0781"]="Android.*[4-7]\."
VULN_DB["BlueBorne CVE-2017-0782"]="Android.*[4-6]\."
VULN_DB["BlueBorne CVE-2017-0785"]="Android.*[4-7]\."
VULN_DB["BlueBorne CVE-2017-1000251"]="Linux.*[3-4]\."
VULN_DB["BlueBorne CVE-2017-1000250"]="Linux.*[3-4]\."
VULN_DB["KNOB CVE-2019-9506"]="Bluetooth.*[4-5]\.[0-1]"
VULN_DB["BrakTooth CVE-2021-28139"]="ESP32"
VULN_DB["BIAS CVE-2020-10135"]="Bluetooth.*[2-5]\."

# ── Device scanning ───────────────────────────────────────────────────────
scan_classic() {
    info "Scanning Classic Bluetooth..."
    local results
    results=$(hcitool scan --flush 2>/dev/null | tail -n +2)
    
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local addr name
        addr=$(echo "$line" | awk '{print $1}')
        name=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ //')
        [ -z "$addr" ] && continue

        process_device "$addr" "$name" "Classic"
    done <<< "$results"
}

scan_ble() {
    info "Scanning BLE (Low Energy)..."
    timeout 10 hcitool lescan --duplicates 2>/dev/null | while IFS= read -r line; do
        [ -z "$line" ] && continue
        [[ "$line" == *"LE Scan"* ]] && continue
        local addr name
        addr=$(echo "$line" | awk '{print $1}')
        name=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ //')
        [ -z "$addr" ] && continue
        [ "$name" == "(unknown)" ] && name="BLE-$addr"

        process_device "$addr" "$name" "BLE"
    done
}

# ── Device processing ──────────────────────────────────────────────────────
process_device() {
    local addr="$1" name="$2" bt_type="$3"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Deduplicate
    if grep -q "\"$addr\"" "$DEVICE_DB" 2>/dev/null; then
        return
    fi

    ok "Found $bt_type device: $name ($addr)"

    # Get extended info via hcitool
    local dev_class="" manufacturer="" rssi=""
    if [ "$bt_type" == "Classic" ]; then
        dev_class=$(hcitool info "$addr" 2>/dev/null | grep "Device Class" | awk -F: '{print $2}' | xargs)
        manufacturer=$(hcitool info "$addr" 2>/dev/null | grep "Manufacturer" | awk -F: '{print $2}' | xargs)
        rssi=$(hcitool rssi "$addr" 2>/dev/null | awk '{print $NF}')
    fi

    # Identify device type from class
    local device_type="Unknown"
    case "$dev_class" in
        *"0x200408"*|*"Audio"*) device_type="Headphones/Speaker" ;;
        *"0x5a020c"*|*"Phone"*) device_type="Smartphone" ;;
        *"0x3a010c"*|*"Computer"*) device_type="Laptop/PC" ;;
        *"0x000540"*|*"Keyboard"*) device_type="Keyboard" ;;
        *"0x002580"*|*"Mouse"*) device_type="Mouse" ;;
        *"0x100c"*|*"Watch"*) device_type="Wearable" ;;
        *"0x0704"*|*"Printer"*) device_type="Printer" ;;
        *"0x7a020c"*) device_type="Tablet" ;;
    esac

    # Check for known vulnerabilities
    local vulns=""
    local vuln_count=0
    for vuln_name in "${!VULN_DB[@]}"; do
        local pattern="${VULN_DB[$vuln_name]}"
        if [[ "$name $manufacturer $dev_class" =~ $pattern ]]; then
            vulns="$vulns$vuln_name;"
            ((vuln_count++))
        fi
    done

    # Signal strength assessment
    local proximity="Unknown"
    if [ -n "$rssi" ]; then
        if [ "$rssi" -gt -40 ]; then proximity="Very Close (<1m)"
        elif [ "$rssi" -gt -60 ]; then proximity="Near (1-5m)"
        elif [ "$rssi" -gt -80 ]; then proximity="Medium (5-15m)"
        else proximity="Far (>15m)"; fi
    fi

    # Append to device database
    local json_entry
    json_entry=$(cat <<JEOF
{
  "address": "$addr",
  "name": "$name",
  "type": "$bt_type",
  "device_type": "$device_type",
  "class": "$dev_class",
  "manufacturer": "$manufacturer",
  "rssi": "$rssi",
  "proximity": "$proximity",
  "vulnerabilities": "$vulns",
  "vuln_count": $vuln_count,
  "first_seen": "$timestamp",
  "last_seen": "$timestamp"
}
JEOF
)

    # Update JSON database
    local tmp
    tmp=$(mktemp)
    if [ -s "$DEVICE_DB" ] && [ "$(cat "$DEVICE_DB")" != "[]" ]; then
        # Remove trailing ] and append
        sed '$ s/]$//' "$DEVICE_DB" > "$tmp"
        echo ",$json_entry]" >> "$tmp"
    else
        echo "[$json_entry]" > "$tmp"
    fi
    mv "$tmp" "$DEVICE_DB"

    # Alert on vulnerable devices
    if [ "$vuln_count" -gt 0 ]; then
        warn "⚠ VULNERABLE DEVICE: $name ($addr) — $vuln_count known CVEs"
        LED ATTACK
    fi
}

# ── Service enumeration ───────────────────────────────────────────────────
enumerate_services() {
    local addr="$1"
    info "Enumerating services on $addr..."
    
    local services
    services=$(sdptool browse "$addr" 2>/dev/null)
    
    if [ -n "$services" ]; then
        echo "$services" >> "$LOOT_DIR/services_${addr//:/}.txt"
        local svc_count
        svc_count=$(echo "$services" | grep -c "Service Name:")
        ok "Found $svc_count services on $addr"
    fi
}

# ── HTML report generation ─────────────────────────────────────────────────
generate_report() {
    info "Generating tactical report..."
    
    local total_devices
    total_devices=$(python3 -c "import json; d=json.load(open('$DEVICE_DB')); print(len(d))" 2>/dev/null || echo "0")
    local vuln_devices
    vuln_devices=$(python3 -c "import json; d=json.load(open('$DEVICE_DB')); print(sum(1 for x in d if x.get('vuln_count',0)>0))" 2>/dev/null || echo "0")
    local ble_count
    ble_count=$(python3 -c "import json; d=json.load(open('$DEVICE_DB')); print(sum(1 for x in d if x.get('type')=='BLE'))" 2>/dev/null || echo "0")
    local classic_count
    classic_count=$(python3 -c "import json; d=json.load(open('$DEVICE_DB')); print(sum(1 for x in d if x.get('type')=='Classic'))" 2>/dev/null || echo "0")

    cat > "$REPORT_FILE" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>BlueBorne Scan Report — NullSec</title>
<style>
:root{--bg:#0a0e17;--card:#111827;--accent:#00d4ff;--red:#ff4757;--grn:#00ff88;--txt:#e0e0e0}
*{margin:0;padding:0;box-sizing:border-box}
body{background:var(--bg);color:var(--txt);font-family:'Segoe UI',system-ui,sans-serif;padding:24px}
h1{color:var(--accent);font-size:28px;margin-bottom:4px}
.subtitle{color:#888;margin-bottom:24px}
.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:32px}
.stat{background:var(--card);border-radius:12px;padding:20px;text-align:center;border:1px solid #222}
.stat .num{font-size:36px;font-weight:700;color:var(--accent)}
.stat .lbl{font-size:13px;color:#888;margin-top:4px}
.vuln .num{color:var(--red)}
table{width:100%;border-collapse:collapse;background:var(--card);border-radius:12px;overflow:hidden}
th{background:#1a2332;color:var(--accent);padding:14px 16px;text-align:left;font-size:13px;text-transform:uppercase}
td{padding:12px 16px;border-bottom:1px solid #1a1a2e;font-size:14px}
tr:hover td{background:rgba(0,212,255,0.05)}
.vuln-badge{background:var(--red);color:#fff;padding:2px 8px;border-radius:4px;font-size:11px;font-weight:600}
.safe-badge{background:var(--grn);color:#000;padding:2px 8px;border-radius:4px;font-size:11px;font-weight:600}
.ble{color:#a78bfa}.classic{color:#f59e0b}
.footer{margin-top:32px;text-align:center;color:#555;font-size:12px}
</style>
</head>
<body>
<h1>🔵 BlueBorne Scan Report</h1>
<p class="subtitle">Generated $(date -u '+%Y-%m-%d %H:%M UTC') — NullSec Bluetooth Scanner</p>

<div class="stats">
<div class="stat"><div class="num">$total_devices</div><div class="lbl">Total Devices</div></div>
<div class="stat vuln"><div class="num">$vuln_devices</div><div class="lbl">Vulnerable</div></div>
<div class="stat"><div class="num">$classic_count</div><div class="lbl">Classic BT</div></div>
<div class="stat"><div class="num">$ble_count</div><div class="lbl">BLE Devices</div></div>
</div>

<table>
<thead><tr>
<th>Device</th><th>Address</th><th>Type</th><th>Category</th><th>Proximity</th><th>RSSI</th><th>Status</th>
</tr></thead>
<tbody>
HTMLEOF

    # Populate device rows
    python3 -c "
import json, html
try:
    devices = json.load(open('$DEVICE_DB'))
except:
    devices = []
for d in devices:
    name = html.escape(d.get('name','?'))
    addr = html.escape(d.get('address','?'))
    bt   = d.get('type','?')
    cls  = '<span class=\"ble\">BLE</span>' if bt=='BLE' else '<span class=\"classic\">Classic</span>'
    cat  = html.escape(d.get('device_type','Unknown'))
    prox = html.escape(d.get('proximity','?'))
    rssi = d.get('rssi','?')
    vc   = d.get('vuln_count',0)
    badge= f'<span class=\"vuln-badge\">{vc} CVEs</span>' if vc>0 else '<span class=\"safe-badge\">Clean</span>'
    print(f'<tr><td>{name}</td><td><code>{addr}</code></td><td>{cls}</td><td>{cat}</td><td>{prox}</td><td>{rssi} dBm</td><td>{badge}</td></tr>')
" >> "$REPORT_FILE" 2>/dev/null

    cat >> "$REPORT_FILE" << 'HTMLEOF'
</tbody>
</table>
<div class="footer">BlueBorne Scanner v1.0.0 — NullSec Suite — For authorized testing only</div>
</body></html>
HTMLEOF

    ok "Report saved: $REPORT_FILE"
}

# ── LED feedback ───────────────────────────────────────────────────────────
led_status() {
    case "$1" in
        SCANNING) LED CUSTOM 0 0 255 SOLID 2>/dev/null || true ;;
        FOUND)    LED CUSTOM 0 255 0 FLASH 2>/dev/null || true ;;
        ATTACK)   LED CUSTOM 255 0 0 VERYFAST 2>/dev/null || true ;;
        DONE)     LED CUSTOM 0 255 136 SOLID 2>/dev/null || true ;;
        FAIL)     LED CUSTOM 255 0 0 SOLID 2>/dev/null || true ;;
    esac
}

LED() { led_status "$1"; }

# ── Interactive menu ───────────────────────────────────────────────────────
show_menu() {
    while true; do
        echo ""
        echo -e "${CYN}╔═══════════════════════════════════════╗${RST}"
        echo -e "${CYN}║     BlueBorne — NullSec Scanner       ║${RST}"
        echo -e "${CYN}╠═══════════════════════════════════════╣${RST}"
        echo -e "${CYN}║${RST} [1] Full Scan (Classic + BLE)         ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [2] Classic Bluetooth Only            ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [3] BLE Low Energy Only               ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [4] Continuous Monitoring             ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [5] Enumerate Services (addr)         ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [6] Generate Report                   ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [7] View Device Database              ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [0] Exit                              ${CYN}║${RST}"
        echo -e "${CYN}╚═══════════════════════════════════════╝${RST}"
        echo ""
        read -rp "Select> " choice

        case "$choice" in
            1)  LED SCANNING; scan_classic; scan_ble; generate_report; LED DONE ;;
            2)  LED SCANNING; scan_classic; LED DONE ;;
            3)  LED SCANNING; scan_ble; LED DONE ;;
            4)  continuous_scan ;;
            5)  read -rp "BT Address: " addr; enumerate_services "$addr" ;;
            6)  generate_report ;;
            7)  python3 -m json.tool "$DEVICE_DB" 2>/dev/null || cat "$DEVICE_DB" ;;
            0)  ok "Exiting BlueBorne"; LED DONE; exit 0 ;;
            *)  warn "Invalid selection" ;;
        esac
    done
}

continuous_scan() {
    info "Starting continuous monitoring ($MAX_SCAN_ROUNDS rounds, ${SCAN_INTERVAL}s interval)"
    LED SCANNING
    for ((r=1; r<=MAX_SCAN_ROUNDS; r++)); do
        info "── Scan Round $r/$MAX_SCAN_ROUNDS ──"
        scan_classic
        scan_ble
        sleep "$SCAN_INTERVAL"
    done
    generate_report
    LED DONE
    ok "Continuous monitoring complete"
}

# ── Main ───────────────────────────────────────────────────────────────────
main() {
    banner
    preflight

    if [ "$1" == "--auto" ]; then
        info "Auto-mode: full scan + report"
        LED SCANNING
        scan_classic
        scan_ble
        generate_report
        LED DONE
    elif [ "$1" == "--continuous" ]; then
        continuous_scan
    else
        show_menu
    fi
}

main "$@"
