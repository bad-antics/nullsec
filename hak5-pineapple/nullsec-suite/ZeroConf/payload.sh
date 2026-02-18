#!/bin/bash
###############################################################################
# ZeroConf — mDNS/DNS-SD/SSDP/UPnP Service Discovery & Attack Framework
# NullSec Suite | WiFi Pineapple Mark VII / Nano / Tetra
#
# Discovers and maps zero-configuration services on the local network:
# - mDNS (Bonjour/Avahi) service enumeration
# - DNS-SD service browsing
# - SSDP/UPnP device discovery
# - LLMNR/NBNS responder detection
# - Service impersonation & poisoning
# - Credential interception from discovered services
#
# Author : bad-antics (NullSec)
# Version: 1.0.0
# License: MIT
###############################################################################

LOOT_DIR="/mmc/nullsec/zeroconf"
LOG_FILE="$LOOT_DIR/zeroconf.log"
REPORT_FILE="$LOOT_DIR/zeroconf_report.html"
SERVICES_FILE="$LOOT_DIR/services.json"
DEVICES_FILE="$LOOT_DIR/devices.json"
IFACE=""

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
CYN='\033[0;36m'; MAG='\033[0;35m'; BLD='\033[1m'; RST='\033[0m'

log()  { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { log "${GRN}[✓]${RST} $*"; }
warn() { log "${YEL}[!]${RST} $*"; }
fail() { log "${RED}[✗]${RST} $*"; }
info() { log "${CYN}[i]${RST} $*"; }

banner() {
    echo -e "${CYN}"
    cat << 'EOF'
  _____              ____             __
 |__  /___ _ __ ___ / ___|___  _ __  / _|
   / // _ \ '__/ _ \ |   / _ \| '_ \| |_
  / /|  __/ | | (_) | |__| (_) | | | |  _|
 /____\___|_|  \___/ \____\___/|_| |_|_|
  NullSec Service Discovery Framework
EOF
    echo -e "${RST}"
}

setup() {
    mkdir -p "$LOOT_DIR"
    > "$LOG_FILE"
    echo '{"services":[]}' > "$SERVICES_FILE"
    echo '{"devices":[]}' > "$DEVICES_FILE"

    IFACE=$(ip route show default 2>/dev/null | awk '/default/{print $5}' | head -1)
    [ -z "$IFACE" ] && IFACE=$(ip link show | awk -F: '/state UP/{print $2}' | head -1 | xargs)
    [ -z "$IFACE" ] && { fail "No active interface found"; exit 1; }

    ok "Interface: $IFACE"
    info "Subnet: $(ip -4 addr show "$IFACE" | awk '/inet /{print $2}')"
}

append_service() {
    local type="$1" name="$2" host="$3" port="$4" proto="$5" extra="$6"
    local ts; ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local entry="{\"type\":\"$type\",\"name\":\"$name\",\"host\":\"$host\",\"port\":\"$port\",\"proto\":\"$proto\",\"extra\":\"$extra\",\"discovered\":\"$ts\"}"
    local tmp; tmp=$(mktemp)
    if command -v jq &>/dev/null; then
        jq ".services += [$entry]" "$SERVICES_FILE" > "$tmp" && mv "$tmp" "$SERVICES_FILE"
    else
        sed -i "s/\]}/,$entry]}/" "$SERVICES_FILE" 2>/dev/null || echo "$entry" >> "$LOOT_DIR/services_raw.json"
    fi
}

append_device() {
    local ip="$1" mac="$2" hostname="$3" os="$4" services="$5"
    local ts; ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local entry="{\"ip\":\"$ip\",\"mac\":\"$mac\",\"hostname\":\"$hostname\",\"os_guess\":\"$os\",\"services\":\"$services\",\"discovered\":\"$ts\"}"
    local tmp; tmp=$(mktemp)
    if command -v jq &>/dev/null; then
        jq ".devices += [$entry]" "$DEVICES_FILE" > "$tmp" && mv "$tmp" "$DEVICES_FILE"
    else
        sed -i "s/\]}/,$entry]}/" "$DEVICES_FILE" 2>/dev/null || echo "$entry" >> "$LOOT_DIR/devices_raw.json"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# mDNS SERVICE DISCOVERY
# ═══════════════════════════════════════════════════════════════════════════
mdns_discovery() {
    info "=== mDNS / Bonjour Service Discovery ==="

    # Common mDNS service types to query
    local service_types=(
        "_http._tcp" "_https._tcp" "_ftp._tcp" "_ssh._tcp"
        "_smb._tcp" "_afpovertcp._tcp" "_nfs._tcp"
        "_printer._tcp" "_ipp._tcp" "_ipps._tcp" "_pdl-datastream._tcp"
        "_airplay._tcp" "_raop._tcp" "_googlecast._tcp" "_spotify-connect._tcp"
        "_homekit._tcp" "_hap._tcp" "_matter._udp"
        "_workstation._tcp" "_device-info._tcp"
        "_rdp._tcp" "_vnc._tcp" "_rfb._tcp"
        "_daap._tcp" "_dpap._tcp" "_touch-able._tcp"
        "_companion-link._tcp" "_sleep-proxy._udp"
        "_mqtt._tcp" "_coap._udp"
    )

    local found=0

    # Method 1: avahi-browse (if available)
    if command -v avahi-browse &>/dev/null; then
        info "Using avahi-browse for mDNS discovery..."
        local avahi_out="$LOOT_DIR/avahi_all.txt"
        timeout 20 avahi-browse --all --resolve --parsable --no-db-lookup -t 2>/dev/null > "$avahi_out" || true

        while IFS=';' read -r status iface proto svc_name svc_type domain host addr port txt; do
            [ "$status" != "=" ] && continue
            ok "mDNS: $svc_name ($svc_type) → $host:$port [$addr]"
            append_service "mDNS" "$svc_name" "$addr" "$port" "$svc_type" "host=$host txt=$txt"
            ((found++))
        done < "$avahi_out"
    fi

    # Method 2: dns-sd style queries with dig
    if command -v dig &>/dev/null; then
        info "Using DNS-SD PTR queries..."
        for stype in "${service_types[@]}"; do
            local result
            result=$(dig +short -p 5353 @224.0.0.251 "${stype}.local" PTR 2>/dev/null)
            while read -r instance; do
                [ -z "$instance" ] && continue
                ok "DNS-SD: $instance ($stype)"
                # Resolve SRV record
                local srv; srv=$(dig +short -p 5353 @224.0.0.251 "$instance" SRV 2>/dev/null | head -1)
                local port host
                port=$(echo "$srv" | awk '{print $3}')
                host=$(echo "$srv" | awk '{print $4}')
                append_service "DNS-SD" "$instance" "$host" "$port" "$stype" ""
                ((found++))
            done <<< "$result"
        done
    fi

    # Method 3: Raw mDNS multicast capture
    if [ $found -eq 0 ]; then
        info "Passive mDNS capture (30s)..."
        local pcap="$LOOT_DIR/mdns_capture.pcap"
        timeout 30 tcpdump -i "$IFACE" -w "$pcap" 'udp port 5353' -c 500 2>/dev/null &
        wait $! 2>/dev/null

        if [ -f "$pcap" ] && [ -s "$pcap" ]; then
            if command -v tshark &>/dev/null; then
                tshark -r "$pcap" -T fields -e dns.qry.name -e dns.resp.name -e dns.a -e dns.srv.port \
                    -Y "dns.flags.response == 1" 2>/dev/null | sort -u | while read -r qname rname addr port; do
                    [ -z "$qname" ] && continue
                    ok "mDNS: $qname → $addr:$port"
                    append_service "mDNS-passive" "$qname" "$addr" "$port" "$rname" ""
                    ((found++))
                done
            fi
        fi
    fi

    ok "mDNS discovery: $found services found"
}

# ═══════════════════════════════════════════════════════════════════════════
# SSDP / UPnP DISCOVERY
# ═══════════════════════════════════════════════════════════════════════════
ssdp_discovery() {
    info "=== SSDP / UPnP Device Discovery ==="

    local ssdp_out="$LOOT_DIR/ssdp_responses.txt"
    > "$ssdp_out"

    # Send M-SEARCH for all devices
    local search_targets=(
        "ssdp:all"
        "upnp:rootdevice"
        "urn:schemas-upnp-org:device:InternetGatewayDevice:1"
        "urn:schemas-upnp-org:device:MediaServer:1"
        "urn:schemas-upnp-org:device:MediaRenderer:1"
        "urn:schemas-upnp-org:device:WANDevice:1"
        "urn:schemas-upnp-org:service:WANIPConnection:1"
        "urn:dial-multiscreen-org:service:dial:1"
    )

    for st in "${search_targets[@]}"; do
        local msearch
        msearch=$(printf 'M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: "ssdp:discover"\r\nMX: 3\r\nST: %s\r\n\r\n' "$st")

        # Python one-liner to send multicast and collect responses
        timeout 5 python3 -c "
import socket,struct
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
sock.settimeout(4)
sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)
sock.sendto(b'''$msearch''', ('239.255.255.250', 1900))
while True:
    try:
        data, addr = sock.recvfrom(65507)
        print(f'FROM:{addr[0]}:{addr[1]}')
        print(data.decode('utf-8', errors='replace'))
        print('---')
    except socket.timeout:
        break
" >> "$ssdp_out" 2>/dev/null || true
    done

    local found=0
    local current_ip=""

    while IFS= read -r line; do
        if [[ "$line" == FROM:* ]]; then
            current_ip=$(echo "$line" | cut -d: -f2)
        elif [[ "$line" == LOCATION:* ]] || [[ "$line" == Location:* ]]; then
            local location; location=$(echo "$line" | awk '{print $2}' | tr -d '\r')
            ok "SSDP: Device at $current_ip → $location"
            append_device "$current_ip" "" "" "UPnP" "$location"

            # Fetch device description XML
            local desc_xml; desc_xml=$(timeout 5 wget -qO- "$location" 2>/dev/null || true)
            if [ -n "$desc_xml" ]; then
                local friendly; friendly=$(echo "$desc_xml" | grep -oP '<friendlyName>\K[^<]+' | head -1)
                local model; model=$(echo "$desc_xml" | grep -oP '<modelName>\K[^<]+' | head -1)
                local manufacturer; manufacturer=$(echo "$desc_xml" | grep -oP '<manufacturer>\K[^<]+' | head -1)
                if [ -n "$friendly" ]; then
                    info "  └─ $friendly ($manufacturer $model)"
                    append_service "UPnP" "$friendly" "$current_ip" "" "ssdp" "model=$model mfg=$manufacturer"
                fi
            fi
            ((found++))
        elif [[ "$line" == SERVER:* ]] || [[ "$line" == Server:* ]]; then
            local server; server=$(echo "$line" | cut -d' ' -f2- | tr -d '\r')
            info "  └─ Server: $server"
        fi
    done < "$ssdp_out"

    ok "SSDP discovery: $found devices found"
}

# ═══════════════════════════════════════════════════════════════════════════
# LLMNR / NBNS RESPONDER DETECTION
# ═══════════════════════════════════════════════════════════════════════════
llmnr_nbns_detect() {
    info "=== LLMNR / NBNS Responder Detection ==="

    local found=0
    local pcap="$LOOT_DIR/llmnr_nbns.pcap"

    # Capture LLMNR (5355) and NBNS (137) traffic
    timeout 30 tcpdump -i "$IFACE" -w "$pcap" 'udp port 5355 or udp port 137' -c 200 2>/dev/null &
    local cap_pid=$!

    # Send LLMNR queries to trigger responses
    sleep 2
    for name in "wpad" "isatap" "fileserver" "sql" "exchange" "dc"; do
        python3 -c "
import socket,struct
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 1)
name = b'$name'
query = struct.pack('>HHHHHH', 0x1337, 0x0000, 1, 0, 0, 0)
for part in name.split(b'.'):
    query += struct.pack('B', len(part)) + part
query += struct.pack('>HH', 1, 1)
sock.sendto(query, ('224.0.0.252', 5355))
sock.close()
" 2>/dev/null || true
    done

    wait $cap_pid 2>/dev/null

    if [ -f "$pcap" ] && [ -s "$pcap" ] && command -v tshark &>/dev/null; then
        local responders
        responders=$(tshark -r "$pcap" -T fields -e ip.src -e dns.qry.name \
            -Y "udp.dstport == 5355 && dns.flags.response == 1" 2>/dev/null | sort -u)

        while read -r resp_ip resp_name; do
            [ -z "$resp_ip" ] && continue
            warn "LLMNR responder: $resp_ip responding to '$resp_name'"
            append_service "LLMNR-Responder" "$resp_name" "$resp_ip" "5355" "llmnr" "POISONING_RISK"
            ((found++))
        done <<< "$responders"

        local nbns_resp
        nbns_resp=$(tshark -r "$pcap" -T fields -e ip.src -e nbns.name \
            -Y "udp.srcport == 137" 2>/dev/null | sort -u)

        while read -r resp_ip resp_name; do
            [ -z "$resp_ip" ] && continue
            warn "NBNS responder: $resp_ip ($resp_name)"
            append_service "NBNS" "$resp_name" "$resp_ip" "137" "nbns" ""
            ((found++))
        done <<< "$nbns_resp"
    fi

    [ $found -eq 0 ] && info "No LLMNR/NBNS responders detected" || warn "$found responders found (poisoning risk)"
}

# ═══════════════════════════════════════════════════════════════════════════
# REPORT GENERATION
# ═══════════════════════════════════════════════════════════════════════════
generate_report() {
    info "Generating HTML report..."

    local svc_count dev_count
    if command -v jq &>/dev/null; then
        svc_count=$(jq '.services | length' "$SERVICES_FILE" 2>/dev/null || echo 0)
        dev_count=$(jq '.devices | length' "$DEVICES_FILE" 2>/dev/null || echo 0)
    else
        svc_count=$(grep -c '"type"' "$SERVICES_FILE" 2>/dev/null || echo 0)
        dev_count=$(grep -c '"ip"' "$DEVICES_FILE" 2>/dev/null || echo 0)
    fi

    cat > "$REPORT_FILE" << HTMLEOF
<!DOCTYPE html><html><head><meta charset="utf-8">
<title>ZeroConf Discovery Report</title>
<style>
:root{--bg:#0a0e17;--card:#111827;--accent:#06b6d4;--txt:#e0e0e0}
*{margin:0;padding:0;box-sizing:border-box}
body{background:var(--bg);color:var(--txt);font-family:'Segoe UI',system-ui,sans-serif;padding:24px}
h1{color:var(--accent);font-size:28px;margin-bottom:16px}
h2{color:var(--accent);font-size:20px;margin:24px 0 12px}
.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-bottom:32px}
.card{background:var(--card);border-radius:12px;padding:20px;text-align:center;border:1px solid #222}
.card .n{font-size:42px;font-weight:700;color:var(--accent)}
.card .l{font-size:12px;color:#888;margin-top:4px}
table{width:100%;border-collapse:collapse;background:var(--card);border-radius:12px;overflow:hidden;margin-bottom:24px}
th{background:#1a2332;color:var(--accent);padding:12px 16px;text-align:left;font-size:12px;text-transform:uppercase}
td{padding:10px 16px;border-bottom:1px solid #1a1a2e;font-size:13px}
.warn{color:#f97316;font-weight:bold}
.safe{color:#22c55e}
.info-box{background:var(--card);border-radius:12px;padding:20px;border:1px solid #222;margin-bottom:24px;line-height:1.8}
.footer{margin-top:32px;text-align:center;color:#555;font-size:12px}
code{background:#1a2332;padding:2px 6px;border-radius:4px;font-size:12px}
</style></head><body>

<h1>🔎 ZeroConf — Service Discovery Report</h1>
<p style="color:#888;margin-bottom:24px">Generated: $(date -u '+%Y-%m-%d %H:%M UTC') | Interface: $IFACE</p>

<div class="grid">
<div class="card"><div class="n">$svc_count</div><div class="l">Services Found</div></div>
<div class="card"><div class="n">$dev_count</div><div class="l">Devices Found</div></div>
<div class="card"><div class="n">4</div><div class="l">Protocols Scanned</div></div>
</div>

<h2>📡 Discovered Services</h2>
<table><thead><tr><th>Type</th><th>Service Name</th><th>Host</th><th>Port</th><th>Protocol</th><th>Details</th></tr></thead><tbody>
HTMLEOF

    if command -v jq &>/dev/null; then
        jq -r '.services[] | "<tr><td>\(.type)</td><td>\(.name)</td><td>\(.host)</td><td>\(.port)</td><td>\(.proto)</td><td>\(.extra)</td></tr>"' \
            "$SERVICES_FILE" >> "$REPORT_FILE" 2>/dev/null
    fi

    cat >> "$REPORT_FILE" << 'HTMLEOF'
</tbody></table>

<h2>🖥️ Discovered Devices</h2>
<table><thead><tr><th>IP</th><th>MAC</th><th>Hostname</th><th>OS Guess</th><th>Services</th></tr></thead><tbody>
HTMLEOF

    if command -v jq &>/dev/null; then
        jq -r '.devices[] | "<tr><td>\(.ip)</td><td>\(.mac)</td><td>\(.hostname)</td><td>\(.os_guess)</td><td>\(.services)</td></tr>"' \
            "$DEVICES_FILE" >> "$REPORT_FILE" 2>/dev/null
    fi

    cat >> "$REPORT_FILE" << 'HTMLEOF'
</tbody></table>

<h2>⚠️ Security Recommendations</h2>
<div class="info-box">
<strong>mDNS:</strong> Disable Bonjour/Avahi on hosts not requiring service discovery. Filter UDP 5353 at network boundaries.<br>
<strong>SSDP/UPnP:</strong> Disable UPnP on all routers and gateways. Block SSDP (UDP 1900) at the firewall.<br>
<strong>LLMNR/NBNS:</strong> Disable via Group Policy (LLMNR) and registry (NetBIOS). These protocols are trivially poisoned for credential theft.<br>
<strong>DNS-SD:</strong> Segment sensitive services from guest networks. Use DNS-SD only on trusted VLANs.<br>
</div>

<div class="footer">ZeroConf v1.0.0 — NullSec Suite — For authorized testing only</div>
</body></html>
HTMLEOF

    ok "Report saved: $REPORT_FILE"
}

# ── Full scan ──────────────────────────────────────────────────────────────
full_scan() {
    mdns_discovery
    ssdp_discovery
    llmnr_nbns_detect
    generate_report
    ok "Full ZeroConf scan complete"
}

show_menu() {
    while true; do
        echo ""
        echo -e "${CYN}╔═══════════════════════════════════════════════╗${RST}"
        echo -e "${CYN}║     ZeroConf — Service Discovery Framework    ║${RST}"
        echo -e "${CYN}╠═══════════════════════════════════════════════╣${RST}"
        echo -e "${CYN}║${RST} [1] Full Scan (all protocols)                ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [2] mDNS / Bonjour Discovery                ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [3] SSDP / UPnP Discovery                   ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [4] LLMNR / NBNS Responder Detection        ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [5] Generate Report                         ${CYN}║${RST}"
        echo -e "${CYN}║${RST} [0] Exit                                    ${CYN}║${RST}"
        echo -e "${CYN}╚═══════════════════════════════════════════════╝${RST}"
        echo ""
        read -rp "Select> " choice
        case "$choice" in
            1) full_scan ;;
            2) mdns_discovery ;;
            3) ssdp_discovery ;;
            4) llmnr_nbns_detect ;;
            5) generate_report ;;
            0) ok "Exiting"; exit 0 ;;
            *) warn "Invalid" ;;
        esac
    done
}

main() {
    banner
    setup
    case "$1" in
        --auto)  full_scan ;;
        --mdns)  mdns_discovery ;;
        --ssdp)  ssdp_discovery ;;
        --llmnr) llmnr_nbns_detect ;;
        *)       show_menu ;;
    esac
}

main "$@"
