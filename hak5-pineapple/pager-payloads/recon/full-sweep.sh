#!/bin/bash
# NullSec Full Recon Sweep
# Comprehensive network reconnaissance

LOOT_DIR="/root/loot/recon"
TARGET_RANGE="${1:-192.168.1.0/24}"

mkdir -p "$LOOT_DIR"
OUTPUT="$LOOT_DIR/sweep_$(date +%Y%m%d_%H%M%S)"

echo "[*] NullSec Recon Sweep"
echo "[*] Target: $TARGET_RANGE"
echo "[*] Output: $OUTPUT"

# Host discovery
echo "=== Live Hosts ===" > "${OUTPUT}_hosts.txt"
nmap -sn $TARGET_RANGE -oG - | grep "Up" >> "${OUTPUT}_hosts.txt"

# Port scan top 1000
echo "=== Port Scan ===" > "${OUTPUT}_ports.txt"
nmap -sT -T4 --top-ports 1000 $TARGET_RANGE -oN "${OUTPUT}_ports.txt" 2>/dev/null

# Service detection
echo "=== Services ===" > "${OUTPUT}_services.txt"
nmap -sV -T4 --top-ports 100 $TARGET_RANGE -oN "${OUTPUT}_services.txt" 2>/dev/null

# Interesting findings
grep -E "open|filtered" "${OUTPUT}_ports.txt" > "${OUTPUT}_interesting.txt"

# Generate summary
echo "=== Summary ===" > "${OUTPUT}_summary.txt"
echo "Hosts: $(grep -c "Up" ${OUTPUT}_hosts.txt)" >> "${OUTPUT}_summary.txt"
echo "Open Ports: $(grep -c "open" ${OUTPUT}_ports.txt)" >> "${OUTPUT}_summary.txt"
echo "Services: $(grep -c "open" ${OUTPUT}_services.txt)" >> "${OUTPUT}_summary.txt"

echo "[+] Sweep complete"
cat "${OUTPUT}_summary.txt"
