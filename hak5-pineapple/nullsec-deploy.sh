#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Deploy - Automated Payload & Tool Deployment
# Developed by: bad-antics
#
# Deploy payloads, tools, and configs to WiFi Pineapple devices and
# cluster nodes in a single command.
#═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

VERSION="1.0.0"
SUITE_DIR="$(cd "$(dirname "$0")" && pwd)/nullsec-suite"
PAGER_DIR="$(cd "$(dirname "$0")" && pwd)/pager-payloads"
LIB_DIR="$(cd "$(dirname "$0")" && pwd)/lib"
NODES_CONF="${HOME}/.nullsec/cluster/nodes.conf"
PINEAPPLE_IP="${PINEAPPLE_IP:-172.16.52.1}"
PINEAPPLE_USER="root"
SSH_TIMEOUT=5

# Colors
RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
CYN='\033[0;36m'; BLD='\033[1m'; RST='\033[0m'

log()  { echo -e "${CYN}[DEPLOY]${RST} $*"; }
ok()   { echo -e "${GRN}[✓]${RST} $*"; }
warn() { echo -e "${YEL}[!]${RST} $*"; }
err()  { echo -e "${RED}[✗]${RST} $*"; }

usage() {
    cat << EOF
${BLD}NullSec Deploy v${VERSION}${RST}

Usage: $(basename "$0") [COMMAND] [OPTIONS]

Commands:
  pineapple              Deploy full suite to WiFi Pineapple
  payload NAME           Deploy single payload to Pineapple
  cluster-tools          Deploy tools to all cluster nodes
  node HOST SCRIPT       Deploy script to specific node
  sync                   Sync local changes to Pineapple
  backup                 Backup Pineapple payloads locally

Options:
  -i, --ip IP            Override Pineapple IP (default: ${PINEAPPLE_IP})
  -d, --dry-run          Show what would be deployed
  -f, --force            Overwrite without confirmation
  -v, --verbose          Verbose output
  -h, --help             Show this help

Examples:
  $(basename "$0") pineapple                    # Deploy all payloads
  $(basename "$0") payload Specter              # Deploy single payload
  $(basename "$0") cluster-tools                # Deploy to all nodes
  $(basename "$0") node r420 setup.sh           # Deploy to specific node
EOF
    exit 0
}

check_pineapple() {
    log "Checking Pineapple connectivity at ${PINEAPPLE_IP}..."
    if ssh -o ConnectTimeout="$SSH_TIMEOUT" -o BatchMode=yes \
       "${PINEAPPLE_USER}@${PINEAPPLE_IP}" "echo ok" &>/dev/null; then
        ok "Pineapple connected"
        return 0
    else
        err "Cannot reach Pineapple at ${PINEAPPLE_IP}"
        echo "  Connect via USB and ensure SSH is available."
        return 1
    fi
}

deploy_pineapple() {
    check_pineapple || return 1

    local payload_count
    payload_count=$(find "$SUITE_DIR" -name payload.sh | wc -l)
    log "Deploying ${payload_count} payloads to Pineapple..."

    # Create remote directories
    ssh "${PINEAPPLE_USER}@${PINEAPPLE_IP}" "mkdir -p /root/payloads/user/nullsec /mmc/nullsec/lib"

    # Deploy shared library
    if [[ -f "${LIB_DIR}/nullsec-scanner.sh" ]]; then
        scp -q "${LIB_DIR}/nullsec-scanner.sh" "${PINEAPPLE_USER}@${PINEAPPLE_IP}:/mmc/nullsec/lib/"
        ok "Deployed shared library"
    fi

    # Deploy each payload
    local deployed=0 failed=0
    for payload_dir in "$SUITE_DIR"/*/; do
        [[ -f "${payload_dir}/payload.sh" ]] || continue
        local name
        name=$(basename "$payload_dir")

        if [[ "$DRY_RUN" == true ]]; then
            log "Would deploy: ${name}"
            continue
        fi

        ssh "${PINEAPPLE_USER}@${PINEAPPLE_IP}" "mkdir -p /root/payloads/user/nullsec/${name}"

        if scp -q -r "${payload_dir}"/* "${PINEAPPLE_USER}@${PINEAPPLE_IP}:/root/payloads/user/nullsec/${name}/" 2>/dev/null; then
            deployed=$((deployed + 1))
            [[ "$VERBOSE" == true ]] && ok "Deployed: ${name}"
        else
            failed=$((failed + 1))
            err "Failed: ${name}"
        fi
    done

    # Set permissions
    ssh "${PINEAPPLE_USER}@${PINEAPPLE_IP}" "chmod +x /root/payloads/user/nullsec/*/payload.sh"

    echo ""
    ok "Deployment complete: ${deployed} deployed, ${failed} failed"
}

deploy_single_payload() {
    local name="$1"
    local payload_dir="${SUITE_DIR}/${name}"

    if [[ ! -d "$payload_dir" ]]; then
        err "Payload not found: ${name}"
        echo "Available payloads:"
        ls -1 "$SUITE_DIR" | column
        return 1
    fi

    check_pineapple || return 1

    log "Deploying ${name}..."
    ssh "${PINEAPPLE_USER}@${PINEAPPLE_IP}" "mkdir -p /root/payloads/user/nullsec/${name}"
    scp -r "${payload_dir}"/* "${PINEAPPLE_USER}@${PINEAPPLE_IP}:/root/payloads/user/nullsec/${name}/"
    ssh "${PINEAPPLE_USER}@${PINEAPPLE_IP}" "chmod +x /root/payloads/user/nullsec/${name}/payload.sh"
    ok "Deployed: ${name}"
}

deploy_cluster_tools() {
    if [[ ! -f "$NODES_CONF" ]]; then
        err "No cluster config found at ${NODES_CONF}"
        return 1
    fi

    local tools_dir
    tools_dir="$(cd "$(dirname "$0")" && pwd)/cluster-output/tools"

    if [[ ! -d "$tools_dir" ]]; then
        err "No cluster tools directory found"
        return 1
    fi

    log "Deploying tools to cluster nodes..."
    local deployed=0

    while IFS='|' read -r hostname ip user port os arch cores ram_mb gpu role tags; do
        [[ "$hostname" =~ ^#.*$ || -z "$hostname" ]] && continue
        [[ "$hostname" == "$(hostname)" ]] && continue  # Skip local

        log "Deploying to ${hostname} (${ip})..."
        if ssh -o ConnectTimeout="$SSH_TIMEOUT" -o BatchMode=yes \
           -p "$port" "${user}@${ip}" "mkdir -p ~/nullsec-tools" 2>/dev/null; then

            if scp -P "$port" -q "${tools_dir}"/*.sh "${user}@${ip}:~/nullsec-tools/" 2>/dev/null; then
                ssh -p "$port" "${user}@${ip}" "chmod +x ~/nullsec-tools/*.sh"
                ok "${hostname}: tools deployed"
                deployed=$((deployed + 1))
            else
                err "${hostname}: transfer failed"
            fi
        else
            warn "${hostname}: unreachable, skipping"
        fi
    done < "$NODES_CONF"

    ok "Deployed to ${deployed} nodes"
}

deploy_to_node() {
    local target_host="$1"
    local script_path="$2"

    if [[ ! -f "$script_path" ]]; then
        err "Script not found: ${script_path}"
        return 1
    fi

    if [[ ! -f "$NODES_CONF" ]]; then
        err "No cluster config"
        return 1
    fi

    while IFS='|' read -r hostname ip user port os arch cores ram_mb gpu role tags; do
        [[ "$hostname" == "$target_host" ]] || continue

        log "Deploying $(basename "$script_path") to ${hostname} (${ip})..."
        scp -P "$port" "$script_path" "${user}@${ip}:~/"
        ssh -p "$port" "${user}@${ip}" "chmod +x ~/$(basename "$script_path")"
        ok "Deployed to ${hostname}"
        return 0
    done < "$NODES_CONF"

    err "Node not found: ${target_host}"
    return 1
}

sync_changes() {
    check_pineapple || return 1
    log "Syncing changes to Pineapple..."
    rsync -avz --delete \
        --exclude='*.md' --exclude='.git*' --exclude='info.json' \
        "${SUITE_DIR}/" "${PINEAPPLE_USER}@${PINEAPPLE_IP}:/root/payloads/user/nullsec/"
    ok "Sync complete"
}

backup_pineapple() {
    check_pineapple || return 1
    local backup_dir="backups/pineapple-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"

    log "Backing up Pineapple payloads..."
    scp -r "${PINEAPPLE_USER}@${PINEAPPLE_IP}:/root/payloads/user/nullsec/" "$backup_dir/" 2>/dev/null || true
    scp -r "${PINEAPPLE_USER}@${PINEAPPLE_IP}:/mmc/nullsec/" "$backup_dir/mmc-nullsec/" 2>/dev/null || true
    ok "Backup saved to ${backup_dir}"
}

# Parse options
DRY_RUN=false; VERBOSE=false; COMMAND=""; ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--ip) PINEAPPLE_IP="$2"; shift ;;
        -d|--dry-run) DRY_RUN=true ;;
        -f|--force) FORCE=true ;;
        -v|--verbose) VERBOSE=true ;;
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
    pineapple)      deploy_pineapple ;;
    payload)        deploy_single_payload "${ARGS[0]:-}" ;;
    cluster-tools)  deploy_cluster_tools ;;
    node)           deploy_to_node "${ARGS[0]:-}" "${ARGS[1]:-}" ;;
    sync)           sync_changes ;;
    backup)         backup_pineapple ;;
    "")             usage ;;
    *)              err "Unknown command: ${COMMAND}"; usage ;;
esac
