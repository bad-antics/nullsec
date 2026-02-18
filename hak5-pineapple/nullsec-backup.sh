#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Backup - Cluster & Pineapple Backup System
# Developed by: bad-antics
#
# Automated backup of cluster nodes, Pineapple loot, configs, and payloads.
# Supports incremental, encrypted, and distributed backups.
#═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

VERSION="1.0.0"
BACKUP_ROOT="${HOME}/.nullsec/backups"
NODES_CONF="${HOME}/.nullsec/cluster/nodes.conf"
PINEAPPLE_IP="${PINEAPPLE_IP:-172.16.52.1}"
SSH_TIMEOUT=10
RETENTION_DAYS=30

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
CYN='\033[0;36m'; BLD='\033[1m'; RST='\033[0m'; DIM='\033[2m'

log()  { echo -e "${CYN}[BACKUP]${RST} $*"; }
ok()   { echo -e "${GRN}[✓]${RST} $*"; }
warn() { echo -e "${YEL}[!]${RST} $*"; }
err()  { echo -e "${RED}[✗]${RST} $*"; }

mkdir -p "$BACKUP_ROOT"

usage() {
    cat << EOF
${BLD}NullSec Backup v${VERSION}${RST}

Usage: $(basename "$0") [COMMAND] [OPTIONS]

Commands:
  all                    Backup everything (cluster + pineapple)
  cluster                Backup all cluster node configs
  pineapple              Backup Pineapple loot and payloads
  node HOST              Backup specific node
  loot                   Backup captured loot only
  configs                Backup NullSec configs only
  restore FILE           Restore from backup archive
  list                   List available backups
  prune                  Remove backups older than ${RETENTION_DAYS} days

Options:
  -e, --encrypt          Encrypt backup with GPG
  -c, --compress         Use xz compression (slower, smaller)
  -o, --output DIR       Override backup directory
  -r, --retention DAYS   Override retention period
  -h, --help             Show this help

Examples:
  $(basename "$0") all                       # Full backup
  $(basename "$0") pineapple --encrypt       # Encrypted Pineapple backup
  $(basename "$0") cluster                   # Cluster configs only
  $(basename "$0") list                      # Show backups
  $(basename "$0") prune                     # Clean old backups
EOF
    exit 0
}

timestamp() { date +%Y%m%d-%H%M%S; }

backup_pineapple() {
    log "Backing up WiFi Pineapple..."
    local ts
    ts=$(timestamp)
    local backup_dir="${BACKUP_ROOT}/pineapple-${ts}"
    mkdir -p "$backup_dir"

    if ! ssh -o ConnectTimeout="$SSH_TIMEOUT" -o BatchMode=yes \
         "${PINEAPPLE_IP}" "echo ok" &>/dev/null 2>&1; then
        err "Pineapple not reachable at ${PINEAPPLE_IP}"
        return 1
    fi

    # Backup payloads
    log "  Backing up payloads..."
    scp -r "root@${PINEAPPLE_IP}:/root/payloads/" "$backup_dir/payloads/" 2>/dev/null || warn "No payloads found"

    # Backup loot
    log "  Backing up loot..."
    scp -r "root@${PINEAPPLE_IP}:/mmc/nullsec/" "$backup_dir/loot/" 2>/dev/null || warn "No loot found"

    # Backup configs
    log "  Backing up configs..."
    ssh "root@${PINEAPPLE_IP}" "cat /etc/config/wireless" > "$backup_dir/wireless.conf" 2>/dev/null || true
    ssh "root@${PINEAPPLE_IP}" "cat /etc/config/network" > "$backup_dir/network.conf" 2>/dev/null || true
    ssh "root@${PINEAPPLE_IP}" "cat /etc/config/pineapple" > "$backup_dir/pineapple.conf" 2>/dev/null || true

    # Create archive
    local archive="${BACKUP_ROOT}/pineapple-${ts}.tar"
    if [[ "$COMPRESS_XZ" == true ]]; then
        tar cf - -C "$backup_dir" . | xz -9 > "${archive}.xz"
        archive="${archive}.xz"
    else
        tar czf "${archive}.gz" -C "$backup_dir" .
        archive="${archive}.gz"
    fi

    if [[ "$ENCRYPT" == true ]]; then
        gpg --symmetric --cipher-algo AES256 "$archive"
        rm -f "$archive"
        archive="${archive}.gpg"
    fi

    rm -rf "$backup_dir"
    local size
    size=$(du -h "$archive" | cut -f1)
    ok "Pineapple backup: ${archive} (${size})"
}

backup_cluster() {
    if [[ ! -f "$NODES_CONF" ]]; then
        err "No cluster config: ${NODES_CONF}"
        return 1
    fi

    log "Backing up cluster nodes..."
    local ts
    ts=$(timestamp)
    local backup_dir="${BACKUP_ROOT}/cluster-${ts}"
    mkdir -p "$backup_dir"

    # Backup cluster config
    cp "$NODES_CONF" "$backup_dir/"

    # Backup each node
    while IFS='|' read -r hostname ip user port os arch cores ram_mb gpu role tags; do
        [[ "$hostname" =~ ^#.*$ || -z "$hostname" ]] && continue

        log "  Backing up ${hostname} (${ip})..."
        local node_dir="${backup_dir}/${hostname}"
        mkdir -p "$node_dir"

        if ssh -o ConnectTimeout="$SSH_TIMEOUT" -o BatchMode=yes \
           -p "$port" "${user}@${ip}" "echo ok" &>/dev/null; then

            # System info
            ssh -p "$port" "${user}@${ip}" "uname -a; hostname; uptime; df -h; free -h" \
                > "$node_dir/system-info.txt" 2>/dev/null || true

            # Crontabs
            ssh -p "$port" "${user}@${ip}" "crontab -l" \
                > "$node_dir/crontab.txt" 2>/dev/null || true

            # NullSec tools
            scp -P "$port" -r "${user}@${ip}:~/nullsec-tools/" "$node_dir/tools/" 2>/dev/null || true

            ok "  ${hostname}: backed up"
        else
            warn "  ${hostname}: unreachable"
        fi
    done < "$NODES_CONF"

    # Archive
    local archive="${BACKUP_ROOT}/cluster-${ts}.tar"
    if [[ "$COMPRESS_XZ" == true ]]; then
        tar cf - -C "$backup_dir" . | xz -9 > "${archive}.xz"
        archive="${archive}.xz"
    else
        tar czf "${archive}.gz" -C "$backup_dir" .
        archive="${archive}.gz"
    fi

    if [[ "$ENCRYPT" == true ]]; then
        gpg --symmetric --cipher-algo AES256 "$archive"
        rm -f "$archive"
        archive="${archive}.gpg"
    fi

    rm -rf "$backup_dir"
    local size
    size=$(du -h "$archive" | cut -f1)
    ok "Cluster backup: ${archive} (${size})"
}

backup_configs() {
    local ts
    ts=$(timestamp)
    local archive="${BACKUP_ROOT}/configs-${ts}.tar.gz"

    log "Backing up NullSec configs..."
    tar czf "$archive" \
        -C "$HOME" \
        .nullsec/ \
        2>/dev/null || true

    local size
    size=$(du -h "$archive" | cut -f1)
    ok "Config backup: ${archive} (${size})"
}

backup_loot() {
    if ! ssh -o ConnectTimeout="$SSH_TIMEOUT" -o BatchMode=yes \
         "root@${PINEAPPLE_IP}" "echo ok" &>/dev/null; then
        err "Pineapple not reachable"
        return 1
    fi

    local ts
    ts=$(timestamp)
    local loot_dir="${BACKUP_ROOT}/loot-${ts}"
    mkdir -p "$loot_dir"

    log "Backing up loot..."
    scp -r "root@${PINEAPPLE_IP}:/mmc/nullsec/" "$loot_dir/" 2>/dev/null

    local archive="${BACKUP_ROOT}/loot-${ts}.tar.gz"
    tar czf "$archive" -C "$loot_dir" .
    rm -rf "$loot_dir"

    if [[ "$ENCRYPT" == true ]]; then
        gpg --symmetric --cipher-algo AES256 "$archive"
        rm -f "$archive"
        archive="${archive}.gpg"
    fi

    local size
    size=$(du -h "$archive" | cut -f1)
    ok "Loot backup: ${archive} (${size})"
}

backup_node() {
    local target="$1"
    if [[ -z "$target" ]]; then
        err "Specify a node hostname"
        return 1
    fi

    while IFS='|' read -r hostname ip user port os arch cores ram_mb gpu role tags; do
        [[ "$hostname" == "$target" ]] || continue

        local ts
        ts=$(timestamp)
        local node_dir="${BACKUP_ROOT}/node-${hostname}-${ts}"
        mkdir -p "$node_dir"

        log "Backing up ${hostname}..."
        if ssh -o ConnectTimeout="$SSH_TIMEOUT" -o BatchMode=yes \
           -p "$port" "${user}@${ip}" "echo ok" &>/dev/null; then
            ssh -p "$port" "${user}@${ip}" "uname -a; df -h; free -h" > "$node_dir/info.txt"
            scp -P "$port" -r "${user}@${ip}:~/nullsec-tools/" "$node_dir/tools/" 2>/dev/null || true
            ssh -p "$port" "${user}@${ip}" "crontab -l" > "$node_dir/crontab.txt" 2>/dev/null || true

            local archive="${BACKUP_ROOT}/node-${hostname}-${ts}.tar.gz"
            tar czf "$archive" -C "$node_dir" .
            rm -rf "$node_dir"
            ok "Node backup: ${archive}"
        else
            err "${hostname} unreachable"
        fi
        return 0
    done < "$NODES_CONF"

    err "Node not found: $target"
}

restore_backup() {
    local archive="$1"
    if [[ ! -f "$archive" ]]; then
        err "File not found: $archive"
        return 1
    fi

    log "Restoring from ${archive}..."

    # Decrypt if needed
    if [[ "$archive" == *.gpg ]]; then
        local decrypted="${archive%.gpg}"
        gpg --decrypt "$archive" > "$decrypted"
        archive="$decrypted"
    fi

    local restore_dir="${BACKUP_ROOT}/restore-$(timestamp)"
    mkdir -p "$restore_dir"

    if [[ "$archive" == *.xz ]]; then
        xz -d -c "$archive" | tar xf - -C "$restore_dir"
    else
        tar xzf "$archive" -C "$restore_dir"
    fi

    ok "Restored to: ${restore_dir}"
    echo "  Review contents and manually copy files where needed."
    ls -la "$restore_dir"
}

list_backups() {
    echo -e "\n${BLD}${CYN}NullSec Backups${RST}\n"

    if [[ -z "$(ls -A "$BACKUP_ROOT" 2>/dev/null)" ]]; then
        warn "No backups found"
        return
    fi

    printf " ${BLD}%-45s %-8s %-20s${RST}\n" "FILE" "SIZE" "DATE"
    echo " ──────────────────────────────────────────────────────────────────"

    for f in "$BACKUP_ROOT"/*.tar.* "$BACKUP_ROOT"/*.gpg; do
        [[ -f "$f" ]] || continue
        local name size date_str
        name=$(basename "$f")
        size=$(du -h "$f" | cut -f1)
        date_str=$(stat -c %y "$f" | cut -d. -f1)
        printf " %-45s %-8s %-20s\n" "$name" "$size" "$date_str"
    done

    local total_size
    total_size=$(du -sh "$BACKUP_ROOT" | cut -f1)
    echo ""
    echo -e " ${BLD}Total: ${total_size}${RST}"
}

prune_backups() {
    log "Pruning backups older than ${RETENTION_DAYS} days..."
    local removed=0

    find "$BACKUP_ROOT" -name "*.tar.*" -o -name "*.gpg" | while read -r f; do
        if [[ $(find "$f" -mtime "+${RETENTION_DAYS}" 2>/dev/null) ]]; then
            rm -f "$f"
            removed=$((removed + 1))
            log "  Removed: $(basename "$f")"
        fi
    done

    ok "Pruning complete"
}

# Parse options
COMMAND=""; ENCRYPT=false; COMPRESS_XZ=false; ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--encrypt) ENCRYPT=true ;;
        -c|--compress) COMPRESS_XZ=true ;;
        -o|--output) BACKUP_ROOT="$2"; mkdir -p "$BACKUP_ROOT"; shift ;;
        -r|--retention) RETENTION_DAYS="$2"; shift ;;
        -h|--help) usage ;;
        *)
            if [[ -z "$COMMAND" ]]; then
                COMMAND="$1"
            else
                ARGS+=("$1")
            fi
            ;;
    esac
    shift
done

case "${COMMAND:-}" in
    all)       backup_pineapple; backup_cluster; backup_configs ;;
    cluster)   backup_cluster ;;
    pineapple) backup_pineapple ;;
    node)      backup_node "${ARGS[0]:-}" ;;
    loot)      backup_loot ;;
    configs)   backup_configs ;;
    restore)   restore_backup "${ARGS[0]:-}" ;;
    list)      list_backups ;;
    prune)     prune_backups ;;
    "")        usage ;;
    *)         err "Unknown: ${COMMAND}"; usage ;;
esac
