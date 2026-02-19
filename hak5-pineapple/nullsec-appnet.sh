#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# NullSec App Network — Unified Launcher
# Manages all NullSec web applications as a cohesive toolkit
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

NULLSEC_DIR="$HOME/nullsec"
LOG_DIR="$HOME/.nullsec/logs"
PID_DIR="$HOME/.nullsec/pids"
mkdir -p "$LOG_DIR" "$PID_DIR"

# App definitions: name|port|directory|venv_parent
declare -A APPS=(
    [webtools]="9000|${NULLSEC_DIR}/nullsec-webtools|${NULLSEC_DIR}/nullsec-webtools"
    [monitor]="9001|${NULLSEC_DIR}/nullsec-monitor|${NULLSEC_DIR}/nullsec-monitor"
    [scanner]="9002|${NULLSEC_DIR}/nullsec-scanner|${NULLSEC_DIR}/nullsec-scanner"
    [bench]="9003|${NULLSEC_DIR}/nullsec-bench|${NULLSEC_DIR}/nullsec-bench"
    [armor]="9004|${NULLSEC_DIR}/nullsec-prompt-armor|${NULLSEC_DIR}/nullsec-prompt-armor"
    [racer]="9005|${NULLSEC_DIR}/nullsec-race-audit|${NULLSEC_DIR}/nullsec-race-audit"
    [nightshift]="9006|${NULLSEC_DIR}/nullsec-nightshift|${NULLSEC_DIR}/nullsec-nightshift"
)

banner() {
    echo -e "${GREEN}"
    echo "  ╔═══════════════════════════════════════════════╗"
    echo "  ║     ⬡  NullSec App Network  v2.0             ║"
    echo "  ║                                               ║"
    echo "  ║  WebTools  :9000  │  Monitor   :9001          ║"
    echo "  ║  Scanner   :9002  │  Bench     :9003          ║"
    echo "  ║  Armor     :9004  │  Racer     :9005          ║"
    echo "  ║  NightShift:9006  │                           ║"
    echo "  ╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

get_port() { echo "${APPS[$1]}" | cut -d'|' -f1; }
get_dir()  { echo "${APPS[$1]}" | cut -d'|' -f2; }
get_venv() { echo "${APPS[$1]}" | cut -d'|' -f3; }

is_running() {
    local port=$(get_port "$1")
    ss -tlnp 2>/dev/null | grep -q ":${port} " && return 0 || return 1
}

get_pid() {
    local port=$(get_port "$1")
    ss -tlnp 2>/dev/null | grep ":${port} " | grep -oP 'pid=\K[0-9]+' | head -1
}

setup_app() {
    local name=$1
    local dir=$(get_dir "$name")
    local venv_dir=$(get_venv "$name")
    local src_dir="${NULLSEC_DIR}/hak5-pineapple/nullsec-${name}"

    echo -e "  ${CYAN}Setting up ${BOLD}${name}${NC}${CYAN}...${NC}"

    # Deploy from workspace if needed
    if [[ -d "$src_dir" ]] && [[ "$dir" != "$src_dir" ]]; then
        mkdir -p "$dir"
        # Copy app files (don't overwrite venv)
        rsync -a --exclude='venv' --exclude='__pycache__' --exclude='.pyc' \
            "$src_dir/" "$dir/" 2>/dev/null || cp -ru "$src_dir/"* "$dir/" 2>/dev/null || true
    fi

    # Create venv if it doesn't exist
    if [[ ! -d "${venv_dir}/venv" ]]; then
        echo -e "    ${DIM}Creating virtual environment...${NC}"
        python3 -m venv "${venv_dir}/venv"
    fi

    # Install requirements
    if [[ -f "${dir}/requirements.txt" ]]; then
        echo -e "    ${DIM}Installing dependencies...${NC}"
        "${venv_dir}/venv/bin/pip" install -q -r "${dir}/requirements.txt" 2>/dev/null
    fi

    echo -e "    ${GREEN}✓ ${name} ready${NC}"
}

start_app() {
    local name=$1
    local port=$(get_port "$name")
    local dir=$(get_dir "$name")
    local venv_dir=$(get_venv "$name")

    if is_running "$name"; then
        echo -e "  ${YELLOW}⚡ ${name} already running on :${port} (pid $(get_pid "$name"))${NC}"
        return 0
    fi

    if [[ ! -f "${dir}/run.py" ]]; then
        echo -e "  ${RED}✗ ${name}: run.py not found at ${dir}${NC}"
        return 1
    fi

    echo -e "  ${CYAN}Starting ${BOLD}${name}${NC}${CYAN} on :${port}...${NC}"
    cd "$dir"
    "${venv_dir}/venv/bin/python" run.py \
        >> "${LOG_DIR}/${name}.log" 2>&1 &
    local pid=$!
    echo "$pid" > "${PID_DIR}/${name}.pid"

    # Wait for startup
    for i in {1..15}; do
        if is_running "$name"; then
            echo -e "  ${GREEN}✓ ${name} started on :${port} (pid ${pid})${NC}"
            return 0
        fi
        sleep 1
    done

    echo -e "  ${RED}✗ ${name} failed to start. Check ${LOG_DIR}/${name}.log${NC}"
    return 1
}

stop_app() {
    local name=$1
    local port=$(get_port "$name")

    if ! is_running "$name"; then
        echo -e "  ${DIM}${name} not running${NC}"
        return 0
    fi

    local pid=$(get_pid "$name")
    echo -e "  ${YELLOW}Stopping ${name} (pid ${pid})...${NC}"
    kill "$pid" 2>/dev/null || true

    for i in {1..5}; do
        if ! is_running "$name"; then
            echo -e "  ${GREEN}✓ ${name} stopped${NC}"
            rm -f "${PID_DIR}/${name}.pid"
            return 0
        fi
        sleep 1
    done

    # Force kill
    kill -9 "$pid" 2>/dev/null || true
    echo -e "  ${RED}✓ ${name} force-killed${NC}"
    rm -f "${PID_DIR}/${name}.pid"
}

status_all() {
    echo -e "\n  ${BOLD}Service Status:${NC}\n"
    printf "  ${DIM}%-12s %-6s %-8s %-10s${NC}\n" "APP" "PORT" "STATUS" "PID"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"

    for name in webtools monitor scanner bench armor racer nightshift; do
        local port=$(get_port "$name")
        if is_running "$name"; then
            local pid=$(get_pid "$name")
            printf "  %-12s %-6s ${GREEN}%-8s${NC} %-10s\n" "$name" ":$port" "RUNNING" "$pid"
        else
            printf "  %-12s %-6s ${RED}%-8s${NC} %-10s\n" "$name" ":$port" "STOPPED" "—"
        fi
    done
    echo ""
}

start_all() {
    banner
    echo -e "  ${BOLD}Starting NullSec App Network...${NC}\n"

    for name in webtools monitor scanner bench armor racer nightshift; do
        setup_app "$name"
        start_app "$name"
    done

    echo ""
    status_all

    echo -e "  ${GREEN}${BOLD}Dashboard:${NC}   ${CYAN}http://localhost:9000${NC}"
    echo -e "  ${GREEN}${BOLD}Monitor:${NC}    ${CYAN}http://localhost:9001${NC}"
    echo -e "  ${GREEN}${BOLD}Scanner:${NC}    ${CYAN}http://localhost:9002${NC}"
    echo -e "  ${GREEN}${BOLD}Bench:${NC}      ${CYAN}http://localhost:9003${NC}"
    echo -e "  ${GREEN}${BOLD}Armor:${NC}      ${CYAN}http://localhost:9004${NC}"
    echo -e "  ${GREEN}${BOLD}Racer:${NC}      ${CYAN}http://localhost:9005${NC}"
    echo -e "  ${GREEN}${BOLD}NightShift:${NC} ${CYAN}http://localhost:9006${NC}"
    echo ""
}

stop_all() {
    echo -e "\n  ${BOLD}Stopping NullSec App Network...${NC}\n"
    for name in nightshift racer armor bench scanner monitor webtools; do
        stop_app "$name"
    done
    echo ""
}

restart_all() {
    stop_all
    sleep 2
    start_all
}

logs() {
    local name=${1:-webtools}
    local log="${LOG_DIR}/${name}.log"
    if [[ -f "$log" ]]; then
        tail -f "$log"
    else
        echo "No log file for $name"
    fi
}

# ─── CLI ─────────────────────────────────────────────────────────────────────

case "${1:-help}" in
    start)
        if [[ -n "${2:-}" ]]; then
            setup_app "$2"
            start_app "$2"
        else
            start_all
        fi
        ;;
    stop)
        if [[ -n "${2:-}" ]]; then
            stop_app "$2"
        else
            stop_all
        fi
        ;;
    restart)
        if [[ -n "${2:-}" ]]; then
            stop_app "$2"
            sleep 1
            setup_app "$2"
            start_app "$2"
        else
            restart_all
        fi
        ;;
    status)
        banner
        status_all
        ;;
    setup)
        banner
        echo -e "  ${BOLD}Setting up all apps...${NC}\n"
        for name in webtools monitor scanner bench armor racer nightshift; do
            setup_app "$name"
        done
        echo -e "\n  ${GREEN}✓ All apps set up. Run '$0 start' to launch.${NC}\n"
        ;;
    logs)
        logs "${2:-webtools}"
        ;;
    *)
        banner
        echo -e "  ${BOLD}Usage:${NC}"
        echo -e "    $0 start [app]     Start all apps (or specific app)"
        echo -e "    $0 stop [app]      Stop all apps (or specific app)"
        echo -e "    $0 restart [app]   Restart all apps (or specific app)"
        echo -e "    $0 status          Show status of all apps"
        echo -e "    $0 setup           Set up/install all apps"
        echo -e "    $0 logs [app]      Tail logs (default: webtools)"
        echo ""
        echo -e "  ${DIM}Apps: webtools, monitor, scanner, bench, armor, racer, nightshift${NC}"
        echo ""
        ;;
esac
