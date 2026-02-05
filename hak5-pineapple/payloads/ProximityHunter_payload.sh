#!/bin/bash
# Title: Proximity Hunter
# Author: bad-antics  
# Description: Track and profile devices by WiFi/BLE proximity patterns
# Category: nullsec/recon
# Version: 1.0.0

LOOT_DIR="/mmc/nullsec/proximity"
DEVICES_DB="$LOOT_DIR/devices.db"
TIMELINE_FILE="$LOOT_DIR/timeline.csv"
LOG_FILE="$LOOT_DIR/session.log"

mkdir -p "$LOOT_DIR"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

PROMPT "📡 PROXIMITY HUNTER

Advanced device tracking:

• WiFi probe requests
• Bluetooth LE beacons
• Device fingerprinting
• Movement patterns
• Dwell time analysis

Track targets across space
and time.

⚠️ Authorized testing only!"

# Check for BLE support
HAS_BLE=false
if hciconfig hci0 &>/dev/null; then
    HAS_BLE=true
fi

# Initialize database
sqlite3 "$DEVICES_DB" << 'SQL'
CREATE TABLE IF NOT EXISTS devices (
    mac TEXT PRIMARY KEY,
    vendor TEXT,
    device_type TEXT,
    first_seen TEXT,
    last_seen TEXT,
    probe_count INTEGER DEFAULT 0,
    ssids TEXT,
    signal_avg INTEGER,
    ble_name TEXT
);

CREATE TABLE IF NOT EXISTS sightings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    mac TEXT,
    timestamp TEXT,
    signal INTEGER,
    channel INTEGER,
    ssid TEXT,
    frame_type TEXT
);

CREATE TABLE IF NOT EXISTS patterns (
    mac TEXT,
    day_of_week INTEGER,
    hour INTEGER,
    avg_duration INTEGER,
    visit_count INTEGER,
    PRIMARY KEY (mac, day_of_week, hour)
);
SQL

# OUI lookup for vendor
get_vendor() {
    local mac="$1"
    local oui=$(echo "$mac" | tr -d ':' | cut -c1-6 | tr 'a-f' 'A-F')
    grep -i "^$oui" /usr/share/ieee-oui.txt 2>/dev/null | cut -f3 || echo "Unknown"
}

# Device type heuristics
guess_device_type() {
    local vendor="$1"
    local probes="$2"
    
    case "$vendor" in
        *Apple*) echo "iPhone/iPad/Mac" ;;
        *Samsung*) echo "Samsung Phone/Tablet" ;;
        *Google*) echo "Pixel/Nest" ;;
        *Intel*|*Dell*|*HP*|*Lenovo*) echo "Laptop" ;;
        *Espressif*|*Raspberry*) echo "IoT Device" ;;
        *Ring*|*Nest*|*Wyze*) echo "Smart Home" ;;
        *) echo "Unknown" ;;
    esac
}

# Start monitoring
INTERFACE="${1:-wlan0}"

# Initialize CSV header
echo "timestamp,mac,signal,channel,ssid,type" > "$TIMELINE_FILE"

SPINNER_START "Initializing proximity tracking..."

# Put interface in monitor mode
airmon-ng check kill &>/dev/null
airmon-ng start $INTERFACE &>/dev/null
MON_IFACE="${INTERFACE}mon"
if ! iwconfig $MON_IFACE &>/dev/null; then
    MON_IFACE="$INTERFACE"
    iw dev $INTERFACE set type monitor 2>/dev/null
    ifconfig $INTERFACE up
fi

SPINNER_STOP

# Process probe requests
process_probes() {
    tcpdump -i $MON_IFACE -e -l type mgt subtype probe-req 2>/dev/null | while read line; do
        # Extract MAC and SSID
        MAC=$(echo "$line" | grep -oP '(SA:|BSSID:)\K[0-9a-f:]{17}' | head -1)
        SSID=$(echo "$line" | grep -oP 'Probe Request \(\K[^)]+')
        SIGNAL=$(echo "$line" | grep -oP '(-[0-9]+)dBm' | head -1 | tr -d 'dBm')
        
        if [ -n "$MAC" ]; then
            TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
            VENDOR=$(get_vendor "$MAC")
            
            # Log to timeline
            echo "$TIMESTAMP,$MAC,$SIGNAL,,$SSID,probe" >> "$TIMELINE_FILE"
            
            # Update database
            sqlite3 "$DEVICES_DB" << SQL
INSERT OR REPLACE INTO devices (mac, vendor, first_seen, last_seen, probe_count, ssids, signal_avg)
VALUES (
    '$MAC',
    '$VENDOR',
    COALESCE((SELECT first_seen FROM devices WHERE mac='$MAC'), '$TIMESTAMP'),
    '$TIMESTAMP',
    COALESCE((SELECT probe_count FROM devices WHERE mac='$MAC'), 0) + 1,
    CASE 
        WHEN '$SSID' != '' AND (SELECT ssids FROM devices WHERE mac='$MAC') NOT LIKE '%$SSID%'
        THEN COALESCE((SELECT ssids FROM devices WHERE mac='$MAC') || ',$SSID', '$SSID')
        ELSE COALESCE((SELECT ssids FROM devices WHERE mac='$MAC'), '$SSID')
    END,
    COALESCE(((SELECT signal_avg FROM devices WHERE mac='$MAC') + $SIGNAL) / 2, $SIGNAL)
);

INSERT INTO sightings (mac, timestamp, signal, ssid, frame_type)
VALUES ('$MAC', '$TIMESTAMP', $SIGNAL, '$SSID', 'probe');
SQL
            
            echo "[$TIMESTAMP] $MAC ($VENDOR) -> $SSID [$SIGNAL dBm]"
        fi
    done
}

# BLE scanning
scan_ble() {
    if [ "$HAS_BLE" = "true" ]; then
        hciconfig hci0 up
        timeout 10 hcitool lescan 2>/dev/null | while read line; do
            MAC=$(echo "$line" | grep -oP '[0-9A-F:]{17}')
            NAME=$(echo "$line" | sed 's/[0-9A-F:]\{17\}//g' | xargs)
            if [ -n "$MAC" ]; then
                TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
                echo "$TIMESTAMP,$MAC,,,,ble" >> "$TIMELINE_FILE"
                sqlite3 "$DEVICES_DB" "UPDATE devices SET ble_name='$NAME', last_seen='$TIMESTAMP' WHERE mac='$MAC';"
            fi
        done
    fi
}

# Background probe capture
process_probes &
PROBE_PID=$!

log "Proximity tracking started on $MON_IFACE"

PROMPT "🔴 TRACKING ACTIVE

Interface: $MON_IFACE
BLE: $([ "$HAS_BLE" = "true" ] && echo "Enabled" || echo "Disabled")

Capturing:
• WiFi probe requests
• Device signatures
• Network affiliations

Press OK for dashboard."

# Dashboard loop
while true; do
    # Get stats
    TOTAL_DEVICES=$(sqlite3 "$DEVICES_DB" "SELECT COUNT(*) FROM devices;")
    ACTIVE_5MIN=$(sqlite3 "$DEVICES_DB" "SELECT COUNT(*) FROM devices WHERE last_seen > datetime('now', '-5 minutes');")
    TOP_SSIDS=$(sqlite3 "$DEVICES_DB" "SELECT ssids FROM devices WHERE ssids != '' ORDER BY probe_count DESC LIMIT 3;" | tr ',' '\n' | sort | uniq -c | sort -rn | head -3)
    
    # Recent devices
    RECENT=$(sqlite3 "$DEVICES_DB" "SELECT mac, vendor, probe_count FROM devices ORDER BY last_seen DESC LIMIT 5;")
    
    DIALOG "📊 PROXIMITY DASHBOARD

Total Devices: $TOTAL_DEVICES
Active (5min): $ACTIVE_5MIN

Recent Devices:
$(echo "$RECENT" | while IFS='|' read mac vendor count; do
    echo "• ${mac:0:8}... $vendor ($count)"
done)

Top Probed SSIDs:
$TOP_SSIDS

[1] Device List
[2] Target Track
[3] Heatmap
[4] Export Data
[5] Stop" --default-button 1 --timeout 30 CHOICE

    case $CHOICE in
        1)
            # Full device list
            DEVICES=$(sqlite3 "$DEVICES_DB" "SELECT mac, vendor, probe_count, last_seen FROM devices ORDER BY last_seen DESC LIMIT 20;")
            PAGER_CONTENT=""
            while IFS='|' read mac vendor count last; do
                PAGER_CONTENT="$PAGER_CONTENT\n$mac | $vendor | $count probes | $last"
            done <<< "$DEVICES"
            echo -e "$PAGER_CONTENT" | PAGER
            ;;
        2)
            # Target specific MAC
            KEYBOARD "Enter target MAC:" TARGET_MAC
            if [ -n "$TARGET_MAC" ]; then
                TARGET_INFO=$(sqlite3 "$DEVICES_DB" "SELECT * FROM devices WHERE mac LIKE '%$TARGET_MAC%';")
                SIGHTINGS=$(sqlite3 "$DEVICES_DB" "SELECT timestamp, signal, ssid FROM sightings WHERE mac LIKE '%$TARGET_MAC%' ORDER BY timestamp DESC LIMIT 10;")
                
                PROMPT "🎯 TARGET: $TARGET_MAC

Info: $TARGET_INFO

Recent Sightings:
$SIGHTINGS"
            fi
            ;;
        3)
            # Signal heatmap (text-based)
            HEATMAP=$(sqlite3 "$DEVICES_DB" "
                SELECT 
                    CASE 
                        WHEN signal_avg > -50 THEN '████ Very Close'
                        WHEN signal_avg > -60 THEN '███░ Close'
                        WHEN signal_avg > -70 THEN '██░░ Medium'
                        WHEN signal_avg > -80 THEN '█░░░ Far'
                        ELSE '░░░░ Very Far'
                    END as proximity,
                    COUNT(*) as count
                FROM devices
                WHERE signal_avg IS NOT NULL
                GROUP BY proximity
                ORDER BY signal_avg DESC;
            ")
            
            PROMPT "📶 PROXIMITY HEATMAP

$HEATMAP"
            ;;
        4)
            # Export
            EXPORT_FILE="$LOOT_DIR/export_$(date +%Y%m%d_%H%M%S).csv"
            sqlite3 -header -csv "$DEVICES_DB" "SELECT * FROM devices;" > "$EXPORT_FILE"
            NOTIFY "Exported to $EXPORT_FILE"
            ;;
        5|timeout|255)
            break
            ;;
    esac
    
    # Periodic BLE scan
    if [ "$HAS_BLE" = "true" ]; then
        scan_ble &
    fi
done

# Cleanup
kill $PROBE_PID 2>/dev/null
airmon-ng stop $MON_IFACE &>/dev/null 2>&1

# Generate final report
FINAL_DEVICES=$(sqlite3 "$DEVICES_DB" "SELECT COUNT(*) FROM devices;")
FINAL_SIGHTINGS=$(sqlite3 "$DEVICES_DB" "SELECT COUNT(*) FROM sightings;")

PROMPT "✅ TRACKING COMPLETE

Devices tracked: $FINAL_DEVICES
Total sightings: $FINAL_SIGHTINGS

Data saved:
• $DEVICES_DB
• $TIMELINE_FILE

Use SQLite to analyze
movement patterns."

log "Session complete. $FINAL_DEVICES devices, $FINAL_SIGHTINGS sightings."
