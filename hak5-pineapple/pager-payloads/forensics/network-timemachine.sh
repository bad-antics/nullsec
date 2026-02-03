#!/bin/bash
# ============================================================
# NullSec: Network Time Machine
# Author: bad-antics
# Description: Record and replay network sessions
# Category: pager/forensics
#
# UNIQUE FEATURES:
# - Full packet capture with smart filtering
# - Session reconstruction and replay
# - Credential extraction from pcaps
# - Traffic pattern analysis
# - Automated forensic timeline
# - First "time machine" concept for Pineapple
# ============================================================

PAYLOAD_NAME="Network Time Machine"
VERSION="1.0.0"
LOOT="/root/loot/timemachine"
LOG="$LOOT/timemachine.log"

# Capture settings
MAX_CAPTURE_SIZE="500M"
ROTATION_TIME="300"  # 5 minutes per file

init_payload() {
    mkdir -p "$LOOT"/{captures,sessions,credentials,timeline,replays}
    echo "[$(date)] $PAYLOAD_NAME started" >> "$LOG"
    NOTIFY "TIME MACHINE" "Initializing capture system..."
}

# Start continuous capture
start_capture() {
    local CAPTURE_NAME="${1:-capture}"
    local FILTER="${2:-}"
    
    NOTIFY "RECORDING" "Starting packet capture..."
    
    local PCAP_DIR="$LOOT/captures"
    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    # Rotating capture
    tcpdump -i wlan0 -w "${PCAP_DIR}/${CAPTURE_NAME}_${TIMESTAMP}_%Y%m%d_%H%M%S.pcap" \
        -G $ROTATION_TIME \
        -C 100 \
        ${FILTER:+-f "$FILTER"} \
        -Z root &
    
    CAPTURE_PID=$!
    echo $CAPTURE_PID > /tmp/timemachine_capture.pid
    
    NOTIFY "ACTIVE" "Capture PID: $CAPTURE_PID"
    
    # Monitor capture size
    (
        while kill -0 $CAPTURE_PID 2>/dev/null; do
            SIZE=$(du -sh "$PCAP_DIR" 2>/dev/null | cut -f1)
            NOTIFY "SIZE" "Capture size: $SIZE"
            sleep 60
        done
    ) &
}

# Stop capture
stop_capture() {
    if [ -f /tmp/timemachine_capture.pid ]; then
        PID=$(cat /tmp/timemachine_capture.pid)
        kill $PID 2>/dev/null
        rm /tmp/timemachine_capture.pid
        NOTIFY "STOPPED" "Capture stopped"
    else
        NOTIFY "ERROR" "No active capture"
    fi
}

# Extract sessions from pcap
extract_sessions() {
    local PCAP="$1"
    
    [ ! -f "$PCAP" ] && {
        NOTIFY "ERROR" "PCAP file not found"
        return 1
    }
    
    NOTIFY "EXTRACTING" "Reconstructing sessions..."
    
    local SESSION_DIR="$LOOT/sessions/$(basename $PCAP .pcap)"
    mkdir -p "$SESSION_DIR"
    
    # TCP sessions
    NOTIFY "TCP" "Extracting TCP streams..."
    tshark -r "$PCAP" -q -z conv,tcp > "$SESSION_DIR/tcp_conversations.txt" 2>/dev/null
    
    # HTTP sessions
    NOTIFY "HTTP" "Extracting HTTP sessions..."
    tshark -r "$PCAP" -Y "http" -T fields \
        -e frame.time -e ip.src -e ip.dst -e http.host -e http.request.uri \
        > "$SESSION_DIR/http_requests.txt" 2>/dev/null
    
    # DNS queries
    NOTIFY "DNS" "Extracting DNS queries..."
    tshark -r "$PCAP" -Y "dns.qry.name" -T fields \
        -e frame.time -e ip.src -e dns.qry.name \
        > "$SESSION_DIR/dns_queries.txt" 2>/dev/null
    
    # Extract files (images, docs, etc)
    NOTIFY "FILES" "Extracting transferred files..."
    mkdir -p "$SESSION_DIR/files"
    
    # Use tcpflow for file extraction
    if command -v tcpflow &>/dev/null; then
        tcpflow -r "$PCAP" -o "$SESSION_DIR/files" 2>/dev/null
    fi
    
    # Summarize
    HTTP_COUNT=$(wc -l < "$SESSION_DIR/http_requests.txt" 2>/dev/null || echo 0)
    DNS_COUNT=$(wc -l < "$SESSION_DIR/dns_queries.txt" 2>/dev/null || echo 0)
    FILE_COUNT=$(ls "$SESSION_DIR/files" 2>/dev/null | wc -l)
    
    NOTIFY "EXTRACTED" "HTTP: $HTTP_COUNT, DNS: $DNS_COUNT, Files: $FILE_COUNT"
}

# Extract credentials from pcap
extract_credentials() {
    local PCAP="$1"
    
    [ ! -f "$PCAP" ] && {
        NOTIFY "ERROR" "PCAP file not found"
        return 1
    }
    
    NOTIFY "CREDENTIALS" "Hunting for credentials..."
    
    local CRED_FILE="$LOOT/credentials/creds_$(basename $PCAP .pcap).txt"
    
    echo "=== Credentials Extracted from $PCAP ===" > "$CRED_FILE"
    echo "Time: $(date)" >> "$CRED_FILE"
    echo "" >> "$CRED_FILE"
    
    # HTTP Basic Auth
    echo "=== HTTP Basic Auth ===" >> "$CRED_FILE"
    tshark -r "$PCAP" -Y "http.authorization" -T fields \
        -e ip.src -e http.host -e http.authorization 2>/dev/null | \
        while read line; do
            # Decode base64
            AUTH=$(echo "$line" | awk '{print $3}' | sed 's/Basic //' | base64 -d 2>/dev/null)
            echo "$line -> $AUTH" >> "$CRED_FILE"
        done
    
    # HTTP POST data (login forms)
    echo "" >> "$CRED_FILE"
    echo "=== HTTP POST Credentials ===" >> "$CRED_FILE"
    tshark -r "$PCAP" -Y "http.request.method==POST" -T fields \
        -e ip.src -e http.host -e http.file_data 2>/dev/null | \
        grep -iE "user|pass|login|email|pwd" >> "$CRED_FILE"
    
    # FTP credentials
    echo "" >> "$CRED_FILE"
    echo "=== FTP Credentials ===" >> "$CRED_FILE"
    tshark -r "$PCAP" -Y "ftp.request.command==USER or ftp.request.command==PASS" \
        -T fields -e ip.src -e ftp.request.command -e ftp.request.arg 2>/dev/null >> "$CRED_FILE"
    
    # Telnet (plaintext)
    echo "" >> "$CRED_FILE"
    echo "=== Telnet Sessions ===" >> "$CRED_FILE"
    tshark -r "$PCAP" -Y "telnet" -T fields -e data 2>/dev/null | \
        xxd -r -p 2>/dev/null >> "$CRED_FILE"
    
    # SMTP Auth
    echo "" >> "$CRED_FILE"
    echo "=== SMTP Auth ===" >> "$CRED_FILE"
    tshark -r "$PCAP" -Y "smtp.auth.username or smtp.auth.password" \
        -T fields -e smtp.auth.username -e smtp.auth.password 2>/dev/null >> "$CRED_FILE"
    
    # Count findings
    CRED_COUNT=$(grep -cE "pass|login|AUTH" "$CRED_FILE" 2>/dev/null || echo 0)
    NOTIFY "FOUND" "$CRED_COUNT potential credentials"
}

# Create forensic timeline
create_timeline() {
    local PCAP="$1"
    
    NOTIFY "TIMELINE" "Building forensic timeline..."
    
    local TIMELINE="$LOOT/timeline/timeline_$(basename $PCAP .pcap).txt"
    
    echo "=== Network Forensic Timeline ===" > "$TIMELINE"
    echo "Source: $PCAP" >> "$TIMELINE"
    echo "Generated: $(date)" >> "$TIMELINE"
    echo "" >> "$TIMELINE"
    
    # Get pcap time range
    FIRST_PKT=$(tshark -r "$PCAP" -T fields -e frame.time -c 1 2>/dev/null)
    LAST_PKT=$(tshark -r "$PCAP" -T fields -e frame.time -Y "frame" 2>/dev/null | tail -1)
    
    echo "Capture Start: $FIRST_PKT" >> "$TIMELINE"
    echo "Capture End: $LAST_PKT" >> "$TIMELINE"
    echo "" >> "$TIMELINE"
    
    # Key events
    echo "=== Key Events ===" >> "$TIMELINE"
    
    # DHCP (device joining)
    echo "-- DHCP Activity (devices joining) --" >> "$TIMELINE"
    tshark -r "$PCAP" -Y "dhcp" -T fields \
        -e frame.time -e dhcp.hw.mac_addr -e dhcp.option.hostname 2>/dev/null | head -20 >> "$TIMELINE"
    
    # DNS (first queries indicate intent)
    echo "" >> "$TIMELINE"
    echo "-- First DNS Queries --" >> "$TIMELINE"
    tshark -r "$PCAP" -Y "dns.qry.name" -T fields \
        -e frame.time -e ip.src -e dns.qry.name 2>/dev/null | head -30 >> "$TIMELINE"
    
    # HTTP (websites visited)
    echo "" >> "$TIMELINE"
    echo "-- HTTP Activity --" >> "$TIMELINE"
    tshark -r "$PCAP" -Y "http.request" -T fields \
        -e frame.time -e ip.src -e http.host -e http.request.uri 2>/dev/null | head -50 >> "$TIMELINE"
    
    # SSL/TLS (encrypted connections)
    echo "" >> "$TIMELINE"
    echo "-- TLS Connections --" >> "$TIMELINE"
    tshark -r "$PCAP" -Y "tls.handshake.type==1" -T fields \
        -e frame.time -e ip.src -e ip.dst -e tls.handshake.extensions_server_name 2>/dev/null | head -30 >> "$TIMELINE"
    
    # Suspicious activity
    echo "" >> "$TIMELINE"
    echo "=== Potentially Suspicious ===" >> "$TIMELINE"
    
    # Port scans
    SCAN_COUNT=$(tshark -r "$PCAP" -Y "tcp.flags.syn==1 and tcp.flags.ack==0" 2>/dev/null | \
        awk '{print $3}' | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')
    
    [ "$SCAN_COUNT" -gt 100 ] && echo "Possible port scan detected ($SCAN_COUNT SYN packets)" >> "$TIMELINE"
    
    # ARP anomalies
    ARP_REPLIES=$(tshark -r "$PCAP" -Y "arp.opcode==2" 2>/dev/null | wc -l)
    [ "$ARP_REPLIES" -gt 50 ] && echo "High ARP activity ($ARP_REPLIES replies) - possible ARP spoofing" >> "$TIMELINE"
    
    NOTIFY "TIMELINE" "Forensic timeline created"
}

# Replay captured session
replay_session() {
    local PCAP="$1"
    local TARGET_IP="$2"
    
    [ ! -f "$PCAP" ] && {
        NOTIFY "ERROR" "PCAP file not found"
        return 1
    }
    
    NOTIFY "REPLAY" "Replaying traffic to $TARGET_IP..."
    
    # Use tcpreplay if available
    if command -v tcpreplay &>/dev/null; then
        # Rewrite IPs if needed
        if [ -n "$TARGET_IP" ]; then
            tcpreplay --intf1=wlan0 --dstipmap=0.0.0.0/0:$TARGET_IP "$PCAP" 2>/dev/null
        else
            tcpreplay --intf1=wlan0 "$PCAP" 2>/dev/null
        fi
        
        NOTIFY "REPLAYED" "Traffic replay complete"
    else
        NOTIFY "ERROR" "tcpreplay not installed"
    fi
}

# Traffic pattern analysis
analyze_patterns() {
    local PCAP="$1"
    
    NOTIFY "PATTERNS" "Analyzing traffic patterns..."
    
    local ANALYSIS="$LOOT/analysis_$(basename $PCAP .pcap).txt"
    
    echo "=== Traffic Pattern Analysis ===" > "$ANALYSIS"
    echo "" >> "$ANALYSIS"
    
    # Top talkers
    echo "=== Top 10 Talkers (by packets) ===" >> "$ANALYSIS"
    tshark -r "$PCAP" -T fields -e ip.src 2>/dev/null | \
        sort | uniq -c | sort -rn | head -10 >> "$ANALYSIS"
    
    # Protocol distribution
    echo "" >> "$ANALYSIS"
    echo "=== Protocol Distribution ===" >> "$ANALYSIS"
    tshark -r "$PCAP" -q -z io,phs 2>/dev/null >> "$ANALYSIS"
    
    # Bandwidth usage over time
    echo "" >> "$ANALYSIS"
    echo "=== Bandwidth Over Time ===" >> "$ANALYSIS"
    tshark -r "$PCAP" -q -z io,stat,60 2>/dev/null >> "$ANALYSIS"
    
    # Connection patterns
    echo "" >> "$ANALYSIS"
    echo "=== External Connections ===" >> "$ANALYSIS"
    tshark -r "$PCAP" -T fields -e ip.dst 2>/dev/null | \
        grep -v "^192\.168\.\|^10\.\|^172\.1[6-9]\.\|^172\.2[0-9]\.\|^172\.3[0-1]\." | \
        sort | uniq -c | sort -rn | head -20 >> "$ANALYSIS"
    
    NOTIFY "ANALYZED" "Pattern analysis complete"
    cat "$ANALYSIS"
}

# Main menu
main() {
    init_payload
    
    while true; do
        echo ""
        echo "=== Network Time Machine ==="
        echo "1. Start Capture"
        echo "2. Stop Capture"
        echo "3. Extract Sessions"
        echo "4. Extract Credentials"
        echo "5. Create Timeline"
        echo "6. Analyze Patterns"
        echo "7. Replay Session"
        echo "8. List Captures"
        echo "9. Exit"
        echo ""
        read -p "Choice: " choice
        
        case $choice in
            1)
                read -p "Capture name: " NAME
                read -p "Filter (blank for all): " FILTER
                start_capture "$NAME" "$FILTER"
                ;;
            2) stop_capture ;;
            3)
                ls -la "$LOOT/captures/"*.pcap 2>/dev/null
                read -p "PCAP file: " PCAP
                extract_sessions "$PCAP"
                ;;
            4)
                ls -la "$LOOT/captures/"*.pcap 2>/dev/null
                read -p "PCAP file: " PCAP
                extract_credentials "$PCAP"
                ;;
            5)
                ls -la "$LOOT/captures/"*.pcap 2>/dev/null
                read -p "PCAP file: " PCAP
                create_timeline "$PCAP"
                ;;
            6)
                ls -la "$LOOT/captures/"*.pcap 2>/dev/null
                read -p "PCAP file: " PCAP
                analyze_patterns "$PCAP"
                ;;
            7)
                ls -la "$LOOT/captures/"*.pcap 2>/dev/null
                read -p "PCAP file: " PCAP
                read -p "Target IP (blank for original): " TARGET
                replay_session "$PCAP" "$TARGET"
                ;;
            8) ls -la "$LOOT/captures/"*.pcap 2>/dev/null ;;
            9) exit 0 ;;
        esac
    done
}

NOTIFY() {
    echo -e "\033[0;34m[$1]\033[0m $2"
    echo "[$(date '+%H:%M:%S')] [$1] $2" >> "$LOG"
}

main "$@"
