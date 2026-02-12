#!/bin/bash
#╔═══════════════════════════════════════════════════════════════════════════════╗
#║                                                                               ║
#║     ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗              ║
#║     ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝              ║
#║     ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║                   ║
#║     ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║                   ║
#║     ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗              ║
#║     ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝              ║
#║                                                                               ║
#║              WiFi Pineapple Pager Connection Manager v1.0                     ║
#║                     Developed by: bad-antics                                  ║
#║                                                                               ║
#╚═══════════════════════════════════════════════════════════════════════════════╝
#
# NullSec Connect - Easy connection and file transfer for WiFi Pineapple Pager
# 
# Usage: ./nullsec-connect.sh [command] [options]
#
# Commands:
#   connect     - Connect to Pineapple and get shell
#   push        - Upload file to Pineapple
#   pull        - Download file from Pineapple
#   sync        - Sync payloads folder
#   loot        - Download all loot
#   status      - Check Pineapple status
#   payloads    - List installed payloads
#   run         - Run a payload remotely
#   menu        - Interactive menu
#

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

PINEAPPLE_IP="172.16.52.1"
PINEAPPLE_USER="root"
PINEAPPLE_WIFI="Pineapple-Pager"
HOME_WIFI="lulzboat"
PAYLOAD_DIR="/root/payloads/user/nullsec"
LOOT_DIR="/mmc/nullsec"
LOCAL_LOOT="./loot"
LOCAL_PAYLOADS="./payloads"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ═══════════════════════════════════════════════════════════════════════════════
# SPINNER & UI FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

# Spinner frames
SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
SPINNER_PID=""

spinner_start() {
    local msg="${1:-Working...}"
    (
        i=0
        while true; do
            printf "\r${CYAN}${SPINNER_FRAMES[$i]}${NC} ${msg}"
            i=$(( (i + 1) % ${#SPINNER_FRAMES[@]} ))
            sleep 0.1
        done
    ) &
    SPINNER_PID=$!
    disown
}

spinner_stop() {
    if [ -n "$SPINNER_PID" ]; then
        kill $SPINNER_PID 2>/dev/null
        wait $SPINNER_PID 2>/dev/null
        SPINNER_PID=""
        printf "\r\033[K"
    fi
}

# Progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "]${NC} ${percent}%% "
}

# Print functions
print_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'BANNER'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║     ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗║
    ║     ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝║
    ║     ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║     ║
    ║     ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║     ║
    ║     ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗║
    ║     ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝║
    ║                                                               ║
    ║           WiFi Pineapple Pager Connection Manager             ║
    ║                  Developed by: bad-antics                     ║
    ╚═══════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_header() {
    echo -e "\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${WHITE}  $1${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# ═══════════════════════════════════════════════════════════════════════════════
# NETWORK FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

switch_to_pineapple() {
    spinner_start "Connecting to Pineapple WiFi..."
    nmcli connection up "$PINEAPPLE_WIFI" >/dev/null 2>&1
    sleep 2
    spinner_stop
    
    if ping -c 1 -W 2 $PINEAPPLE_IP >/dev/null 2>&1; then
        print_success "Connected to Pineapple"
        return 0
    else
        print_error "Failed to connect to Pineapple"
        return 1
    fi
}

switch_to_home() {
    spinner_start "Switching back to home WiFi..."
    nmcli connection down "$PINEAPPLE_WIFI" >/dev/null 2>&1
    nmcli connection up "$HOME_WIFI" >/dev/null 2>&1
    sleep 2
    spinner_stop
    print_success "Connected to home WiFi"
}

check_connection() {
    if ping -c 1 -W 2 $PINEAPPLE_IP >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

ensure_connection() {
    if ! check_connection; then
        switch_to_pineapple || return 1
    fi
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# CORE FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

cmd_connect() {
    print_header "PINEAPPLE SHELL"
    ensure_connection || return 1
    
    print_info "Opening SSH session to Pineapple..."
    echo -e "${GRAY}Type 'exit' to disconnect${NC}\n"
    
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        ${PINEAPPLE_USER}@${PINEAPPLE_IP} 2>/dev/null
    
    echo ""
    print_success "Session ended"
    switch_to_home
}

cmd_push() {
    local local_file="$1"
    local remote_path="$2"
    
    if [ -z "$local_file" ]; then
        print_error "Usage: $0 push <local_file> [remote_path]"
        return 1
    fi
    
    if [ ! -f "$local_file" ]; then
        print_error "File not found: $local_file"
        return 1
    fi
    
    [ -z "$remote_path" ] && remote_path="/root/$(basename $local_file)"
    
    print_header "UPLOAD FILE"
    ensure_connection || return 1
    
    local filesize=$(stat -f%z "$local_file" 2>/dev/null || stat -c%s "$local_file" 2>/dev/null)
    print_info "Uploading: $(basename $local_file) ($(numfmt --to=iec $filesize 2>/dev/null || echo ${filesize}B))"
    print_info "Destination: $remote_path"
    echo ""
    
    spinner_start "Transferring file..."
    
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$local_file" "${PINEAPPLE_USER}@${PINEAPPLE_IP}:${remote_path}" 2>/dev/null
    
    local result=$?
    spinner_stop
    
    if [ $result -eq 0 ]; then
        print_success "Upload complete!"
    else
        print_error "Upload failed"
    fi
    
    switch_to_home
    return $result
}

cmd_pull() {
    local remote_path="$1"
    local local_path="${2:-.}"
    
    if [ -z "$remote_path" ]; then
        print_error "Usage: $0 pull <remote_path> [local_path]"
        return 1
    fi
    
    print_header "DOWNLOAD FILE"
    ensure_connection || return 1
    
    print_info "Downloading: $remote_path"
    print_info "Destination: $local_path"
    echo ""
    
    spinner_start "Transferring file..."
    
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "${PINEAPPLE_USER}@${PINEAPPLE_IP}:${remote_path}" "$local_path" 2>/dev/null
    
    local result=$?
    spinner_stop
    
    if [ $result -eq 0 ]; then
        print_success "Download complete!"
    else
        print_error "Download failed"
    fi
    
    switch_to_home
    return $result
}

cmd_sync_payloads() {
    print_header "SYNC PAYLOADS"
    ensure_connection || return 1
    
    mkdir -p "$LOCAL_PAYLOADS"
    
    print_info "Syncing payloads from Pineapple..."
    echo ""
    
    # Get list of payloads
    PAYLOADS=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        ${PINEAPPLE_USER}@${PINEAPPLE_IP} "ls $PAYLOAD_DIR" 2>/dev/null)
    
    TOTAL=$(echo "$PAYLOADS" | wc -w)
    CURRENT=0
    
    for payload in $PAYLOADS; do
        ((CURRENT++))
        progress_bar $CURRENT $TOTAL
        echo -ne "${CYAN}$payload${NC}"
        
        mkdir -p "$LOCAL_PAYLOADS/$payload"
        scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r \
            "${PINEAPPLE_USER}@${PINEAPPLE_IP}:${PAYLOAD_DIR}/${payload}/*" \
            "$LOCAL_PAYLOADS/$payload/" 2>/dev/null
    done
    
    echo ""
    print_success "Synced $TOTAL payloads to $LOCAL_PAYLOADS/"
    switch_to_home
}

cmd_loot() {
    print_header "DOWNLOAD LOOT"
    ensure_connection || return 1
    
    mkdir -p "$LOCAL_LOOT"
    
    print_info "Downloading loot from Pineapple..."
    echo ""
    
    spinner_start "Grabbing loot..."
    
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r \
        "${PINEAPPLE_USER}@${PINEAPPLE_IP}:${LOOT_DIR}/*" "$LOCAL_LOOT/" 2>/dev/null
    
    spinner_stop
    
    # Count files
    LOOT_COUNT=$(find "$LOCAL_LOOT" -type f 2>/dev/null | wc -l)
    
    print_success "Downloaded $LOOT_COUNT loot files to $LOCAL_LOOT/"
    
    # Show summary
    echo ""
    print_info "Loot Summary:"
    for dir in "$LOCAL_LOOT"/*/; do
        if [ -d "$dir" ]; then
            count=$(find "$dir" -type f 2>/dev/null | wc -l)
            dirname=$(basename "$dir")
            echo -e "  ${CYAN}$dirname${NC}: $count files"
        fi
    done
    
    switch_to_home
}

cmd_status() {
    print_header "PINEAPPLE STATUS"
    
    if ! check_connection; then
        switch_to_pineapple || return 1
    fi
    
    spinner_start "Gathering status..."
    
    # Get various stats
    UPTIME=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        ${PINEAPPLE_USER}@${PINEAPPLE_IP} "uptime -p" 2>/dev/null)
    
    DISK=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        ${PINEAPPLE_USER}@${PINEAPPLE_IP} "df -h /mmc | tail -1 | awk '{print \$3\"/\"\$2\" (\"\$5\" used)\"}'" 2>/dev/null)
    
    MEM=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        ${PINEAPPLE_USER}@${PINEAPPLE_IP} "free -h | grep Mem | awk '{print \$3\"/\"\$2}'" 2>/dev/null)
    
    PAYLOAD_COUNT=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        ${PINEAPPLE_USER}@${PINEAPPLE_IP} "ls $PAYLOAD_DIR 2>/dev/null | wc -l" 2>/dev/null)
    
    LOOT_SIZE=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        ${PINEAPPLE_USER}@${PINEAPPLE_IP} "du -sh $LOOT_DIR 2>/dev/null | cut -f1" 2>/dev/null)
    
    spinner_stop
    
    echo -e "  ${WHITE}Uptime:${NC}      $UPTIME"
    echo -e "  ${WHITE}Storage:${NC}     $DISK"
    echo -e "  ${WHITE}Memory:${NC}      $MEM"
    echo -e "  ${WHITE}Payloads:${NC}    $PAYLOAD_COUNT installed"
    echo -e "  ${WHITE}Loot:${NC}        ${LOOT_SIZE:-0} collected"
    echo ""
    
    switch_to_home
}

cmd_payloads() {
    print_header "INSTALLED PAYLOADS"
    ensure_connection || return 1
    
    spinner_start "Loading payloads..."
    
    PAYLOADS=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        ${PINEAPPLE_USER}@${PINEAPPLE_IP} "ls $PAYLOAD_DIR" 2>/dev/null)
    
    spinner_stop
    
    echo -e "${CYAN}NullSec Payloads:${NC}"
    echo ""
    
    i=1
    for payload in $PAYLOADS; do
        printf "  ${WHITE}%2d.${NC} ${GREEN}%-25s${NC}" $i "$payload"
        ((i++))
        if [ $((i % 2)) -eq 1 ]; then
            echo ""
        fi
    done
    
    echo ""
    echo ""
    print_info "Total: $((i-1)) payloads"
    
    switch_to_home
}

cmd_run() {
    local payload="$1"
    
    if [ -z "$payload" ]; then
        print_error "Usage: $0 run <payload_name>"
        echo ""
        cmd_payloads
        return 1
    fi
    
    print_header "RUN PAYLOAD: $payload"
    ensure_connection || return 1
    
    # Check if payload exists
    EXISTS=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        ${PINEAPPLE_USER}@${PINEAPPLE_IP} "[ -f $PAYLOAD_DIR/$payload/payload.sh ] && echo yes" 2>/dev/null)
    
    if [ "$EXISTS" != "yes" ]; then
        print_error "Payload not found: $payload"
        switch_to_home
        return 1
    fi
    
    print_info "Executing $payload..."
    echo -e "${GRAY}─────────────────────────────────────${NC}"
    echo ""
    
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        ${PINEAPPLE_USER}@${PINEAPPLE_IP} "cd $PAYLOAD_DIR/$payload && bash payload.sh" 2>/dev/null
    
    echo ""
    echo -e "${GRAY}─────────────────────────────────────${NC}"
    print_success "Payload execution finished"
    
    switch_to_home
}

cmd_execute() {
    local command="$*"
    
    if [ -z "$command" ]; then
        print_error "Usage: $0 exec <command>"
        return 1
    fi
    
    ensure_connection || return 1
    
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        ${PINEAPPLE_USER}@${PINEAPPLE_IP} "$command" 2>/dev/null
    
    switch_to_home
}

# ═══════════════════════════════════════════════════════════════════════════════
# INTERACTIVE MENU
# ═══════════════════════════════════════════════════════════════════════════════

cmd_menu() {
    while true; do
        print_banner
        
        echo -e "${WHITE}  MAIN MENU${NC}"
        echo ""
        echo -e "  ${CYAN}1.${NC} Connect to Pineapple Shell"
        echo -e "  ${CYAN}2.${NC} Check Pineapple Status"
        echo -e "  ${CYAN}3.${NC} List Installed Payloads"
        echo -e "  ${CYAN}4.${NC} Run a Payload"
        echo -e "  ${CYAN}5.${NC} Upload File"
        echo -e "  ${CYAN}6.${NC} Download File"
        echo -e "  ${CYAN}7.${NC} Sync All Payloads"
        echo -e "  ${CYAN}8.${NC} Download All Loot"
        echo -e "  ${CYAN}9.${NC} Execute Remote Command"
        echo ""
        echo -e "  ${RED}0.${NC} Exit"
        echo ""
        echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -ne "  ${WHITE}Select option: ${NC}"
        
        read -r choice
        
        case $choice in
            1) cmd_connect ;;
            2) cmd_status ;;
            3) cmd_payloads ;;
            4) 
                echo -ne "  ${WHITE}Payload name: ${NC}"
                read -r payload
                cmd_run "$payload"
                ;;
            5)
                echo -ne "  ${WHITE}Local file: ${NC}"
                read -r local_file
                echo -ne "  ${WHITE}Remote path (optional): ${NC}"
                read -r remote_path
                cmd_push "$local_file" "$remote_path"
                ;;
            6)
                echo -ne "  ${WHITE}Remote file: ${NC}"
                read -r remote_file
                echo -ne "  ${WHITE}Local path (optional): ${NC}"
                read -r local_path
                cmd_pull "$remote_file" "$local_path"
                ;;
            7) cmd_sync_payloads ;;
            8) cmd_loot ;;
            9)
                echo -ne "  ${WHITE}Command: ${NC}"
                read -r command
                cmd_execute "$command"
                ;;
            0|q|Q) 
                echo ""
                print_info "Goodbye!"
                echo -e "${GRAY}  NullSec Connect - by bad-antics${NC}"
                echo ""
                exit 0
                ;;
            *)
                print_error "Invalid option"
                ;;
        esac
        
        echo ""
        echo -ne "${GRAY}Press Enter to continue...${NC}"
        read -r
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# HELP
# ═══════════════════════════════════════════════════════════════════════════════

show_help() {
    print_banner
    echo -e "${WHITE}USAGE:${NC}"
    echo "  $0 [command] [options]"
    echo ""
    echo -e "${WHITE}COMMANDS:${NC}"
    echo -e "  ${CYAN}menu${NC}              Interactive menu (default)"
    echo -e "  ${CYAN}connect${NC}           SSH shell to Pineapple"
    echo -e "  ${CYAN}status${NC}            Show Pineapple status"
    echo -e "  ${CYAN}payloads${NC}          List installed payloads"
    echo -e "  ${CYAN}run${NC} <name>        Execute a payload"
    echo -e "  ${CYAN}push${NC} <file> [dst] Upload file to Pineapple"
    echo -e "  ${CYAN}pull${NC} <file> [dst] Download file from Pineapple"
    echo -e "  ${CYAN}sync${NC}              Sync all payloads locally"
    echo -e "  ${CYAN}loot${NC}              Download all loot"
    echo -e "  ${CYAN}exec${NC} <command>    Run command on Pineapple"
    echo ""
    echo -e "${WHITE}EXAMPLES:${NC}"
    echo "  $0 menu                        # Interactive menu"
    echo "  $0 connect                     # SSH shell"
    echo "  $0 push exploit.sh             # Upload file"
    echo "  $0 pull /mmc/loot/creds.txt    # Download file"
    echo "  $0 run DeauthStorm             # Run payload"
    echo "  $0 exec 'ls -la /root'         # Run command"
    echo ""
    echo -e "${GRAY}NullSec Connect v1.0 - Developed by bad-antics${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    # Trap cleanup
    trap 'spinner_stop; echo ""; exit 130' INT TERM
    
    case "${1:-menu}" in
        menu|-m|--menu)
            cmd_menu
            ;;
        connect|-c|--connect|shell)
            cmd_connect
            ;;
        status|-s|--status)
            cmd_status
            ;;
        payloads|-p|--payloads|list)
            cmd_payloads
            ;;
        run|-r|--run)
            cmd_run "$2"
            ;;
        push|upload)
            cmd_push "$2" "$3"
            ;;
        pull|download)
            cmd_pull "$2" "$3"
            ;;
        sync)
            cmd_sync_payloads
            ;;
        loot)
            cmd_loot
            ;;
        exec|cmd|command)
            shift
            cmd_execute "$@"
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
