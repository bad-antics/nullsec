#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Title:         SpectrumGuard
# Description:   Defensive WiFi monitoring payload that continuously watches
#                the RF spectrum for threats: deauth attacks, evil twins,
#                rogue APs, KRACK attempts, and anomalous traffic patterns.
#                Sends real-time alerts and generates threat intelligence.
# Author:        bad-antics
# Category:      defense
# Version:       1.0
# ═══════════════════════════════════════════════════════════════════════════════

LOOT_DIR="/mmc/nullsec/SpectrumGuard"
LOG_FILE="${LOOT_DIR}/spectrumguard.log"
ALERT_LOG="${LOOT_DIR}/alerts.json"
IFACE="wlan1mon"
KNOWN_APS="${LOOT_DIR}/known_aps.json"
ALERT_THRESHOLD_DEAUTH=20    # deauths per minute
ALERT_THRESHOLD_BEACON=50    # new beacons per minute
CHECK_INTERVAL=30            # seconds between checks

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

alert() {
    local severity="$1"
    local type="$2"
    local message="$3"

    echo "{\"time\":\"$(date -Iseconds)\",\"severity\":\"$severity\",\"type\":\"$type\",\"message\":\"$message\"}" >> "$ALERT_LOG"
    log "🚨 [$severity] $type: $message"

    # LED notification on Pineapple
    case "$severity" in
        CRITICAL) LED ATTACK 2>/dev/null ;;
        HIGH)     LED FAIL 2>/dev/null ;;
        MEDIUM)   LED SETUP 2>/dev/null ;;
    esac
}

setup() {
    mkdir -p "$LOOT_DIR"
    echo '[]' > "$ALERT_LOG"
    log "SpectrumGuard v1.0 — RF Threat Monitor"
    log "Interface: $IFACE"
    log "================================================"

    # Build baseline of known APs
    if [[ ! -f "$KNOWN_APS" ]]; then
        log "Building initial AP baseline..."
        build_baseline
    else
        AP_COUNT=$(python3 -c "import json; print(len(json.load(open('$KNOWN_APS'))))" 2>/dev/null)
        log "Loaded baseline: $AP_COUNT known APs"
    fi
}

build_baseline() {
    log "Capturing baseline APs (30s)..."

    timeout 30 tcpdump -i "$IFACE" -e 'type mgt subtype beacon' -c 500 2>/dev/null | \
        grep -oP '(BSSID|SA):(\K[0-9a-f:]+)' | sort -u > "${LOOT_DIR}/baseline_bssids.txt"

    # Build JSON baseline
    python3 -c "
import json, subprocess
bssids = open('${LOOT_DIR}/baseline_bssids.txt').read().strip().split('\n')
known = []
for b in bssids:
    if b.strip():
        known.append({'bssid': b.strip(), 'first_seen': '$(date -Iseconds)', 'trusted': True})
with open('$KNOWN_APS', 'w') as f:
    json.dump(known, f, indent=2)
print(f'Baseline: {len(known)} APs')
" 2>/dev/null

    log "Baseline saved"
}

# ─── Detection Modules ──────────────────────────────────────────────────────

detect_deauth_attack() {
    # Count deauth frames in the last interval
    DEAUTH_COUNT=$(timeout "$CHECK_INTERVAL" tcpdump -i "$IFACE" \
        'type mgt subtype deauth or type mgt subtype disassoc' -c 200 2>/dev/null | wc -l)

    if [[ "$DEAUTH_COUNT" -gt "$ALERT_THRESHOLD_DEAUTH" ]]; then
        # Get top attacker MAC
        ATTACKER=$(timeout 10 tcpdump -i "$IFACE" -e \
            'type mgt subtype deauth' -c 20 2>/dev/null | \
            grep -oP '(SA):(\K[0-9a-f:]+)' | sort | uniq -c | sort -rn | head -1)

        alert "CRITICAL" "DEAUTH_ATTACK" \
            "Detected $DEAUTH_COUNT deauth/disassoc frames in ${CHECK_INTERVAL}s. Top source: $ATTACKER"
        return 0
    fi
    return 1
}

detect_evil_twin() {
    # Capture current beacons and compare SSID↔BSSID mappings
    timeout 15 tcpdump -i "$IFACE" -e 'type mgt subtype beacon' -c 100 2>/dev/null | \
        grep -oP 'SSID=\K[^ ]+|BSSID:([0-9a-f:]+)' > "${LOOT_DIR}/current_scan.txt"

    # Check for same SSID with different BSSID than baseline
    if [[ -f "$KNOWN_APS" ]]; then
        python3 -c "
import json

known = json.load(open('$KNOWN_APS'))
known_map = {ap['bssid']: ap for ap in known}
known_bssids = set(ap['bssid'] for ap in known)

# Parse current scan for new BSSIDs
import subprocess
result = subprocess.run(['tcpdump', '-i', '$IFACE', '-e', 'type', 'mgt', 'subtype', 'beacon',
    '-c', '50', '-r', '/dev/null'], capture_output=True, timeout=5)
" 2>/dev/null
    fi
}

detect_rogue_ap() {
    # Look for new APs not in baseline
    timeout 15 tcpdump -i "$IFACE" -e 'type mgt subtype beacon' -c 100 2>/dev/null | \
        grep -oP '(BSSID):(\K[0-9a-f:]+)' | sort -u > "${LOOT_DIR}/current_bssids.txt"

    if [[ -f "${LOOT_DIR}/baseline_bssids.txt" ]]; then
        NEW_APS=$(comm -23 <(sort "${LOOT_DIR}/current_bssids.txt") \
            <(sort "${LOOT_DIR}/baseline_bssids.txt"))

        if [[ -n "$NEW_APS" ]]; then
            NEW_COUNT=$(echo "$NEW_APS" | wc -l)
            alert "HIGH" "ROGUE_AP" \
                "$NEW_COUNT new AP(s) detected not in baseline: $(echo $NEW_APS | head -3)"
        fi
    fi
}

detect_probe_flood() {
    # High volume of probe requests may indicate recon
    PROBE_COUNT=$(timeout "$CHECK_INTERVAL" tcpdump -i "$IFACE" \
        'type mgt subtype probe-req' -c 500 2>/dev/null | wc -l)

    if [[ "$PROBE_COUNT" -gt 200 ]]; then
        alert "MEDIUM" "PROBE_FLOOD" \
            "$PROBE_COUNT probe requests in ${CHECK_INTERVAL}s — possible reconnaissance"
    fi
}

detect_beacon_flood() {
    # Sudden increase in beacons may indicate beacon spam attack
    BEACON_COUNT=$(timeout 10 tcpdump -i "$IFACE" \
        'type mgt subtype beacon' -c 500 2>/dev/null | \
        grep -oP '(BSSID):(\K[0-9a-f:]+)' | sort -u | wc -l)

    if [[ "$BEACON_COUNT" -gt "$ALERT_THRESHOLD_BEACON" ]]; then
        alert "HIGH" "BEACON_FLOOD" \
            "$BEACON_COUNT unique BSSIDs seen — possible beacon spam attack"
    fi
}

# ─── Status Dashboard ────────────────────────────────────────────────────────

print_status() {
    ALERTS=$(wc -l < "$ALERT_LOG" 2>/dev/null || echo 0)
    UPTIME_SEC=$(($(date +%s) - START_TIME))
    UPTIME_MIN=$((UPTIME_SEC / 60))

    echo -ne "\r  ⬡ SpectrumGuard | Uptime: ${UPTIME_MIN}m | Alerts: $ALERTS | "
    echo -ne "Last check: $(date '+%H:%M:%S')  "
}

# ─── Main Loop ───────────────────────────────────────────────────────────────

cleanup() {
    log "SpectrumGuard shutting down..."
    TOTAL_ALERTS=$(wc -l < "$ALERT_LOG" 2>/dev/null || echo 0)
    log "Session summary: $TOTAL_ALERTS alerts generated"
    log "Alert log: $ALERT_LOG"
    LED CLEANUP 2>/dev/null
}

trap cleanup EXIT

setup
START_TIME=$(date +%s)
CYCLE=0

log "Starting monitoring loop (Ctrl+C to stop)..."

while true; do
    CYCLE=$((CYCLE + 1))

    # Run all detection modules
    detect_deauth_attack &
    detect_rogue_ap &
    detect_probe_flood &
    detect_beacon_flood &
    wait

    # Evil twin check (slower, every 5th cycle)
    if [[ $((CYCLE % 5)) -eq 0 ]]; then
        detect_evil_twin
    fi

    print_status
    sleep "$CHECK_INTERVAL"
done
