#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Cluster Health Dashboard
# Developed by: bad-antics
#
# Real-time health monitoring for all cluster nodes.
# Checks: SSH connectivity, CPU/RAM/disk, services, uptime, temps
#═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

VERSION="1.0.0"
NODES_CONF="${HOME}/.nullsec/cluster/nodes.conf"
LOG_DIR="${HOME}/.nullsec/cluster/health-logs"
REPORT_FILE="${LOG_DIR}/health-$(date +%Y%m%d-%H%M%S).txt"
SSH_TIMEOUT=5
WARN_CPU=80
WARN_RAM=85
WARN_DISK=90
COLOR=true

# Colors
if [[ "$COLOR" == true ]]; then
    RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
    CYN='\033[0;36m'; MAG='\033[0;35m'; BLD='\033[1m'; RST='\033[0m'
    DIM='\033[2m'
else
    RED=''; GRN=''; YEL=''; CYN=''; MAG=''; BLD=''; RST=''; DIM=''
fi

mkdir -p "$LOG_DIR"

usage() {
    cat << EOF
${BLD}NullSec Cluster Health Dashboard v${VERSION}${RST}

Usage: $(basename "$0") [OPTIONS]

Options:
  -w, --watch          Continuous monitoring (refresh every 10s)
  -j, --json           Output as JSON
  -c, --csv            Output as CSV
  -n, --node HOST      Check specific node only
  -q, --quick          Quick check (connectivity only)
  -a, --alerts         Show only nodes with warnings
  -l, --log            Save report to log file
  -h, --help           Show this help

Examples:
  $(basename "$0")              # Full dashboard
  $(basename "$0") --watch      # Live monitoring
  $(basename "$0") --alerts     # Show problems only
  $(basename "$0") -n r420      # Check specific node
EOF
    exit 0
}

# Parse arguments
WATCH=false; JSON=false; CSV=false; TARGET_NODE=""; QUICK=false; ALERTS_ONLY=false; SAVE_LOG=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--watch) WATCH=true ;;
        -j|--json) JSON=true ;;
        -c|--csv) CSV=true ;;
        -n|--node) TARGET_NODE="$2"; shift ;;
        -q|--quick) QUICK=true ;;
        -a|--alerts) ALERTS_ONLY=true ;;
        -l|--log) SAVE_LOG=true ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
    shift
done

check_node() {
    local hostname="$1" ip="$2" user="$3" port="$4" cores="$5" ram_mb="$6" gpu="$7"
    local status="ONLINE" alerts=()

    # SSH connectivity
    if ! ssh -o ConnectTimeout="$SSH_TIMEOUT" -o BatchMode=yes -o StrictHostKeyChecking=no \
         -p "$port" "${user}@${ip}" "echo ok" &>/dev/null; then
        echo "OFFLINE|${hostname}|${ip}|0|0|0|0|DOWN"
        return
    fi

    if [[ "$QUICK" == true ]]; then
        echo "ONLINE|${hostname}|${ip}|0|0|0|0|OK"
        return
    fi

    # Gather metrics via single SSH call
    local metrics
    metrics=$(ssh -o ConnectTimeout="$SSH_TIMEOUT" -o BatchMode=yes -o StrictHostKeyChecking=no \
        -p "$port" "${user}@${ip}" '
        # CPU usage (1-min load avg as percentage of cores)
        cores=$(nproc 2>/dev/null || echo 1)
        load=$(cat /proc/loadavg | cut -d" " -f1)
        cpu_pct=$(awk "BEGIN{printf \"%.0f\", ($load/$cores)*100}")
        
        # RAM
        read -r total used free <<< $(free -m | awk "/^Mem:/{print \$2,\$3,\$4}")
        ram_pct=$((used * 100 / total))
        
        # Disk (root partition)
        disk_pct=$(df / | awk "NR==2{gsub(/%/,\"\"); print \$5}")
        
        # Uptime
        uptime_str=$(uptime -p 2>/dev/null | sed "s/up //" || echo "unknown")
        
        # Temperature (if available)
        temp="N/A"
        if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
            raw=$(cat /sys/class/thermal/thermal_zone0/temp)
            temp="$((raw/1000))C"
        fi
        
        # Docker containers running
        docker_count=$(docker ps -q 2>/dev/null | wc -l || echo 0)
        
        echo "$cpu_pct|$ram_pct|$disk_pct|$uptime_str|$temp|$docker_count|${total}|${used}"
    ' 2>/dev/null || echo "ERR|ERR|ERR|ERR|ERR|0|0|0")

    IFS='|' read -r cpu_pct ram_pct disk_pct uptime_str temp docker_count total_ram used_ram <<< "$metrics"

    # Generate alerts
    [[ "$cpu_pct" =~ ^[0-9]+$ ]] && [[ "$cpu_pct" -ge "$WARN_CPU" ]] && alerts+=("HIGH-CPU")
    [[ "$ram_pct" =~ ^[0-9]+$ ]] && [[ "$ram_pct" -ge "$WARN_RAM" ]] && alerts+=("HIGH-RAM")
    [[ "$disk_pct" =~ ^[0-9]+$ ]] && [[ "$disk_pct" -ge "$WARN_DISK" ]] && alerts+=("DISK-FULL")

    local alert_str="OK"
    [[ ${#alerts[@]} -gt 0 ]] && alert_str=$(IFS=','; echo "${alerts[*]}")

    echo "ONLINE|${hostname}|${ip}|${cpu_pct}|${ram_pct}|${disk_pct}|${uptime_str}|${alert_str}|${temp}|${docker_count}|${total_ram}|${used_ram}"
}

render_dashboard() {
    local results=("$@")
    local online=0 offline=0 warnings=0 total_cores=0 total_ram=0

    clear 2>/dev/null || true
    echo -e "${BLD}${CYN}"
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║           ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗║"
    echo "║           ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝║"
    echo "║           ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║     ║"
    echo "║           ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║     ║"
    echo "║           ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗║"
    echo "║           ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝║"
    echo "║                    CLUSTER HEALTH DASHBOARD v${VERSION}                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo -e "${RST}"
    echo -e " ${DIM}$(date '+%Y-%m-%d %H:%M:%S')${RST}"
    echo ""

    # Table header
    printf " ${BLD}%-14s %-15s %-6s %-6s %-6s %-5s %-18s %-10s${RST}\n" \
        "NODE" "IP" "CPU%" "RAM%" "DISK%" "TEMP" "UPTIME" "STATUS"
    echo " ─────────────────────────────────────────────────────────────────────────"

    for result in "${results[@]}"; do
        IFS='|' read -r status host ip cpu ram disk uptime alerts temp docker total_r used_r <<< "$result"

        if [[ "$status" == "OFFLINE" ]]; then
            offline=$((offline + 1))
            [[ "$ALERTS_ONLY" == false ]] || true
            printf " ${RED}%-14s %-15s %-6s %-6s %-6s %-5s %-18s %-10s${RST}\n" \
                "$host" "$ip" "---" "---" "---" "---" "---" "⛔ OFFLINE"
            continue
        fi

        online=$((online + 1))

        # Color-code metrics
        local cpu_c="$GRN" ram_c="$GRN" disk_c="$GRN" status_c="$GRN"
        [[ "$cpu" =~ ^[0-9]+$ ]] && [[ "$cpu" -ge 60 ]] && cpu_c="$YEL"
        [[ "$cpu" =~ ^[0-9]+$ ]] && [[ "$cpu" -ge "$WARN_CPU" ]] && cpu_c="$RED"
        [[ "$ram" =~ ^[0-9]+$ ]] && [[ "$ram" -ge 70 ]] && ram_c="$YEL"
        [[ "$ram" =~ ^[0-9]+$ ]] && [[ "$ram" -ge "$WARN_RAM" ]] && ram_c="$RED"
        [[ "$disk" =~ ^[0-9]+$ ]] && [[ "$disk" -ge 75 ]] && disk_c="$YEL"
        [[ "$disk" =~ ^[0-9]+$ ]] && [[ "$disk" -ge "$WARN_DISK" ]] && disk_c="$RED"
        [[ "$alerts" != "OK" ]] && { status_c="$YEL"; warnings=$((warnings + 1)); }

        local status_icon="✅ OK"
        [[ "$alerts" != "OK" ]] && status_icon="⚠️  $alerts"

        if [[ "$ALERTS_ONLY" == true ]] && [[ "$alerts" == "OK" ]]; then
            continue
        fi

        printf " %-14s %-15s ${cpu_c}%-6s${RST} ${ram_c}%-6s${RST} ${disk_c}%-6s${RST} %-5s %-18s ${status_c}%-10s${RST}\n" \
            "$host" "$ip" "${cpu}%" "${ram}%" "${disk}%" "$temp" "$uptime" "$status_icon"
    done

    echo " ─────────────────────────────────────────────────────────────────────────"
    echo ""
    echo -e " ${BLD}Summary:${RST} ${GRN}${online} online${RST} | ${RED}${offline} offline${RST} | ${YEL}${warnings} warnings${RST}"
    echo ""
}

render_json() {
    local results=("$@")
    echo "{"
    echo '  "timestamp": "'$(date -Iseconds)'",'
    echo '  "nodes": ['
    local first=true
    for result in "${results[@]}"; do
        IFS='|' read -r status host ip cpu ram disk uptime alerts temp docker total_r used_r <<< "$result"
        [[ "$first" == true ]] || echo ","
        first=false
        cat << JEOF
    {
      "hostname": "$host",
      "ip": "$ip",
      "status": "$status",
      "cpu_percent": "$cpu",
      "ram_percent": "$ram",
      "disk_percent": "$disk",
      "temperature": "$temp",
      "uptime": "$uptime",
      "alerts": "$alerts",
      "docker_containers": "$docker"
    }
JEOF
    done
    echo ""
    echo "  ]"
    echo "}"
}

render_csv() {
    local results=("$@")
    echo "timestamp,hostname,ip,status,cpu_pct,ram_pct,disk_pct,temp,uptime,alerts"
    local ts
    ts=$(date -Iseconds)
    for result in "${results[@]}"; do
        IFS='|' read -r status host ip cpu ram disk uptime alerts temp docker total_r used_r <<< "$result"
        echo "$ts,$host,$ip,$status,$cpu,$ram,$disk,$temp,$uptime,$alerts"
    done
}

run_checks() {
    if [[ ! -f "$NODES_CONF" ]]; then
        echo -e "${RED}ERROR: Node config not found: ${NODES_CONF}${RST}"
        echo "Run nullsec-cluster.sh to configure nodes first."
        exit 1
    fi

    local results=()

    while IFS='|' read -r hostname ip user port os arch cores ram_mb gpu role tags; do
        [[ "$hostname" =~ ^#.*$ || -z "$hostname" ]] && continue

        if [[ -n "$TARGET_NODE" ]] && [[ "$hostname" != "$TARGET_NODE" ]]; then
            continue
        fi

        local result
        result=$(check_node "$hostname" "$ip" "$user" "$port" "$cores" "$ram_mb" "$gpu")
        results+=("$result")
    done < "$NODES_CONF"

    if [[ "$JSON" == true ]]; then
        render_json "${results[@]}"
    elif [[ "$CSV" == true ]]; then
        render_csv "${results[@]}"
    else
        render_dashboard "${results[@]}"
    fi

    if [[ "$SAVE_LOG" == true ]]; then
        {
            echo "NullSec Cluster Health Report - $(date)"
            echo "========================================="
            for result in "${results[@]}"; do
                echo "$result"
            done
        } > "$REPORT_FILE"
        echo -e " ${DIM}Report saved: ${REPORT_FILE}${RST}"
    fi
}

# Main
if [[ "$WATCH" == true ]]; then
    while true; do
        run_checks
        echo -e " ${DIM}Refreshing in 10s... (Ctrl+C to stop)${RST}"
        sleep 10
    done
else
    run_checks
fi
