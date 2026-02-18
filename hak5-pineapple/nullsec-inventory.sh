#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Inventory - Network Asset Inventory & Discovery
# Developed by: bad-antics
#
# Automated network asset discovery, fingerprinting, and inventory management.
# Scans subnets, identifies devices, tracks changes over time.
#═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

VERSION="1.0.0"
INVENTORY_DIR="${HOME}/.nullsec/inventory"
INVENTORY_DB="${INVENTORY_DIR}/assets.csv"
SCAN_LOG="${INVENTORY_DIR}/scan-$(date +%Y%m%d-%H%M%S).log"
SUBNET="${SUBNET:-192.168.40.0/24}"

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
CYN='\033[0;36m'; MAG='\033[0;35m'; BLD='\033[1m'; RST='\033[0m'
DIM='\033[2m'

mkdir -p "$INVENTORY_DIR"

log()  { echo -e "${CYN}[INVENTORY]${RST} $*"; }
ok()   { echo -e "${GRN}[✓]${RST} $*"; }
warn() { echo -e "${YEL}[!]${RST} $*"; }
err()  { echo -e "${RED}[✗]${RST} $*"; }

usage() {
    cat << EOF
${BLD}NullSec Inventory v${VERSION}${RST}

Usage: $(basename "$0") [COMMAND] [OPTIONS]

Commands:
  scan                   Scan network and update inventory
  list                   List all known assets
  diff                   Show changes since last scan
  export [json|csv|md]   Export inventory
  search TERM            Search inventory
  tag IP TAG             Tag an asset
  remove IP              Remove asset from inventory

Options:
  -s, --subnet CIDR      Override subnet (default: ${SUBNET})
  -d, --deep             Deep scan (OS detection, services)
  -h, --help             Show this help

Examples:
  $(basename "$0") scan                  # Quick network scan
  $(basename "$0") scan --deep           # Full fingerprinting
  $(basename "$0") list                  # Show all assets
  $(basename "$0") diff                  # What changed?
  $(basename "$0") export json           # Export as JSON
  $(basename "$0") search Dell           # Find Dell devices
EOF
    exit 0
}

# MAC vendor lookup (common vendors)
mac_vendor() {
    local mac="${1^^}"
    local prefix="${mac:0:8}"
    case "$prefix" in
        D4:BE:D9*|F8:BC:12*|B0:83:FE*|14:FE:B5*) echo "Dell" ;;
        B8:27:EB*|DC:A6:32*|E4:5F:01*) echo "Raspberry-Pi" ;;
        00:50:56*|00:0C:29*|00:15:5D*) echo "VMware/HyperV" ;;
        FC:34:97*|3C:7C:3F*) echo "ASRock" ;;
        00:1E:67*|D8:CB:8A*) echo "Intel" ;;
        AC:16:2D*|00:0D:B9*) echo "Hewlett-Packard" ;;
        60:45:CB*|78:7B:8A*) echo "Lenovo" ;;
        00:E0:4C*|52:54:00*) echo "Realtek/QEMU" ;;
        08:00:27*) echo "VirtualBox" ;;
        *) echo "Unknown" ;;
    esac
}

init_db() {
    if [[ ! -f "$INVENTORY_DB" ]]; then
        echo "ip,mac,hostname,vendor,os,services,first_seen,last_seen,tags" > "$INVENTORY_DB"
    fi
}

scan_network() {
    local deep="${1:-false}"
    init_db

    log "Scanning ${SUBNET}..."
    local prev_db="${INVENTORY_DIR}/assets-prev.csv"
    [[ -f "$INVENTORY_DB" ]] && cp "$INVENTORY_DB" "$prev_db"

    # ARP scan
    local arp_results
    if command -v nmap &>/dev/null; then
        if [[ "$deep" == true ]]; then
            log "Deep scan with OS detection..."
            arp_results=$(sudo nmap -sn -O --osscan-guess "$SUBNET" 2>/dev/null)
        else
            arp_results=$(sudo nmap -sn "$SUBNET" 2>/dev/null)
        fi
    elif command -v arp-scan &>/dev/null; then
        arp_results=$(sudo arp-scan "$SUBNET" 2>/dev/null)
    else
        # Fallback: ping sweep + arp table
        log "Using ping sweep (install nmap for better results)..."
        local net_prefix
        net_prefix=$(echo "$SUBNET" | cut -d'/' -f1 | sed 's/\.[0-9]*$//')
        for i in $(seq 1 254); do
            ping -c1 -W1 "${net_prefix}.${i}" &>/dev/null &
        done
        wait
        arp_results=$(arp -an 2>/dev/null)
    fi

    # Parse and update inventory
    local found=0 new=0
    local timestamp
    timestamp=$(date -Iseconds)

    # Process ARP table for results
    while read -r ip mac rest; do
        [[ -z "$ip" || -z "$mac" ]] && continue
        [[ "$mac" == "<incomplete>" ]] && continue

        # Clean IP from arp -an format
        ip=$(echo "$ip" | tr -d '()' | grep -oP '\d+\.\d+\.\d+\.\d+' || continue)
        [[ -z "$ip" ]] && continue

        # Try to resolve hostname
        local hostname
        hostname=$(ssh -o ConnectTimeout=2 -o BatchMode=yes "root@${ip}" "hostname" 2>/dev/null || \
                   getent hosts "$ip" 2>/dev/null | awk '{print $2}' || \
                   echo "unknown")

        local vendor
        vendor=$(mac_vendor "$mac")

        local os="unknown"
        if [[ "$deep" == true ]] && command -v nmap &>/dev/null; then
            os=$(sudo nmap -O --osscan-guess "$ip" 2>/dev/null | grep "OS details:" | sed 's/OS details: //' | head -1)
            [[ -z "$os" ]] && os="unknown"
        fi

        # Check if already in DB
        if grep -q "^${ip}," "$INVENTORY_DB" 2>/dev/null; then
            # Update last_seen
            sed -i "s|^${ip},\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),[^,]*,\(.*\)$|${ip},${mac},${hostname},${vendor},\4,\5,\6,${timestamp},\7|" "$INVENTORY_DB"
        else
            echo "${ip},${mac},${hostname},${vendor},${os},,${timestamp},${timestamp}," >> "$INVENTORY_DB"
            new=$((new + 1))
        fi
        found=$((found + 1))

    done < <(arp -an 2>/dev/null | awk '{gsub(/[()]/,"",$2); print $2, $4}')

    ok "Scan complete: ${found} hosts found, ${new} new"
    echo "$arp_results" > "$SCAN_LOG" 2>/dev/null || true
}

list_assets() {
    init_db

    if [[ ! -s "$INVENTORY_DB" ]] || [[ $(wc -l < "$INVENTORY_DB") -le 1 ]]; then
        warn "No assets in inventory. Run: $(basename "$0") scan"
        return
    fi

    echo -e "\n${BLD}${CYN}NullSec Network Asset Inventory${RST}"
    echo -e "${DIM}Last updated: $(stat -c %y "$INVENTORY_DB" 2>/dev/null | cut -d. -f1)${RST}\n"

    printf " ${BLD}%-16s %-18s %-16s %-14s %-10s${RST}\n" \
        "IP" "MAC" "HOSTNAME" "VENDOR" "TAGS"
    echo " ──────────────────────────────────────────────────────────────────────"

    tail -n +2 "$INVENTORY_DB" | sort -t. -k4 -n | while IFS=',' read -r ip mac hostname vendor os services first last tags; do
        [[ -z "$ip" ]] && continue
        printf " %-16s %-18s %-16s %-14s %-10s\n" \
            "$ip" "$mac" "${hostname:0:15}" "${vendor:0:13}" "${tags:-}"
    done

    local total
    total=$(($(wc -l < "$INVENTORY_DB") - 1))
    echo ""
    echo -e " ${BLD}Total assets: ${total}${RST}"
}

diff_inventory() {
    local prev="${INVENTORY_DIR}/assets-prev.csv"
    if [[ ! -f "$prev" ]]; then
        warn "No previous scan to compare against"
        return
    fi

    echo -e "\n${BLD}${CYN}Inventory Changes${RST}\n"

    # New devices
    local new_ips
    new_ips=$(comm -13 <(tail -n+2 "$prev" | cut -d, -f1 | sort) \
                       <(tail -n+2 "$INVENTORY_DB" | cut -d, -f1 | sort))
    if [[ -n "$new_ips" ]]; then
        echo -e " ${GRN}NEW DEVICES:${RST}"
        for ip in $new_ips; do
            local info
            info=$(grep "^${ip}," "$INVENTORY_DB")
            echo -e "   ${GRN}+${RST} $info"
        done
    fi

    # Gone devices
    local gone_ips
    gone_ips=$(comm -23 <(tail -n+2 "$prev" | cut -d, -f1 | sort) \
                        <(tail -n+2 "$INVENTORY_DB" | cut -d, -f1 | sort))
    if [[ -n "$gone_ips" ]]; then
        echo -e " ${RED}REMOVED DEVICES:${RST}"
        for ip in $gone_ips; do
            echo -e "   ${RED}-${RST} $ip"
        done
    fi

    [[ -z "$new_ips" && -z "$gone_ips" ]] && ok "No changes detected"
}

export_inventory() {
    local format="${1:-csv}"
    init_db

    case "$format" in
        json)
            echo "["
            local first=true
            tail -n+2 "$INVENTORY_DB" | while IFS=',' read -r ip mac hostname vendor os services first_seen last_seen tags; do
                [[ "$first" == true ]] || echo ","
                first=false
                cat << JEOF
  {
    "ip": "$ip",
    "mac": "$mac",
    "hostname": "$hostname",
    "vendor": "$vendor",
    "os": "$os",
    "first_seen": "$first_seen",
    "last_seen": "$last_seen",
    "tags": "$tags"
  }
JEOF
            done
            echo "]"
            ;;
        csv)
            cat "$INVENTORY_DB"
            ;;
        md)
            echo "# NullSec Network Inventory"
            echo ""
            echo "| IP | MAC | Hostname | Vendor | Tags |"
            echo "|---|---|---|---|---|"
            tail -n+2 "$INVENTORY_DB" | while IFS=',' read -r ip mac hostname vendor os services first last tags; do
                echo "| $ip | $mac | $hostname | $vendor | $tags |"
            done
            ;;
        *)
            err "Unknown format: $format (use json, csv, or md)"
            ;;
    esac
}

search_inventory() {
    local term="$1"
    init_db

    echo -e "\n${BLD}Search results for: ${term}${RST}\n"
    grep -i "$term" "$INVENTORY_DB" | while IFS=',' read -r ip mac hostname vendor os services first last tags; do
        echo -e "  ${CYN}${ip}${RST} | ${mac} | ${hostname} | ${vendor} | ${tags:-no tags}"
    done
}

tag_asset() {
    local ip="$1" tag="$2"
    init_db

    if grep -q "^${ip}," "$INVENTORY_DB"; then
        # Append tag
        sed -i "s|^${ip},\(.*\),\([^,]*\)$|${ip},\1,\2 ${tag}|" "$INVENTORY_DB"
        ok "Tagged ${ip} with: ${tag}"
    else
        err "Asset not found: ${ip}"
    fi
}

remove_asset() {
    local ip="$1"
    if grep -q "^${ip}," "$INVENTORY_DB"; then
        sed -i "/^${ip},/d" "$INVENTORY_DB"
        ok "Removed: ${ip}"
    else
        err "Asset not found: ${ip}"
    fi
}

# Parse arguments
COMMAND=""; DEEP=false; ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--subnet) SUBNET="$2"; shift ;;
        -d|--deep) DEEP=true ;;
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
    scan)     scan_network "$DEEP" ;;
    list)     list_assets ;;
    diff)     diff_inventory ;;
    export)   export_inventory "${ARGS[0]:-csv}" ;;
    search)   search_inventory "${ARGS[0]:-}" ;;
    tag)      tag_asset "${ARGS[0]:-}" "${ARGS[1]:-}" ;;
    remove)   remove_asset "${ARGS[0]:-}" ;;
    "")       usage ;;
    *)        err "Unknown: ${COMMAND}"; usage ;;
esac
