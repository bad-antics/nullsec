#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# NULLSEC SSH TRANSFER UTILITY v2.1
# Advanced file transfer for NULLSEC deployments
# GitHub: https://github.com/bad-antics/nullsec
# ═══════════════════════════════════════════════════════════════════════════════
# 
# Features:
#   - Transfer files to remote hosts via SSH/SCP
#   - Support for Windows, Linux, and Mac targets
#   - NULLSEC Windows edition deployment
#   - Batch file transfers
#   - Progress monitoring
#   - Auto-detection of remote OS
#
# Author: bad-antics development
# Version: 2.1
# ═══════════════════════════════════════════════════════════════════════════════

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WINDOWS_DIR="${SCRIPT_DIR}/windows"
LOG_FILE="${SCRIPT_DIR}/logs/transfer.log"

# Default configurations
SSH_PORT=22
SSH_USER=""
SSH_HOST=""
SSH_PASS=""
SSH_KEY=""
REMOTE_OS=""
REMOTE_PATH=""

banner() {
    echo -e "${RED}"
    echo " ███▄    █  █    ██  ██▓     ██▓      ██████ ▓█████  ▄████▄  "
    echo " ██ ▀█   █  ██  ▓██▒▓██▒    ▓██▒    ▒██    ▒ ▓█   ▀ ▒██▀ ▀█  "
    echo "▓██  ▀█ ██▒▓██  ▒██░▒██░    ▒██░    ░ ▓██▄   ▒███   ▒▓█    ▄ "
    echo "▓██▒  ▐▌██▒▓▓█  ░██░▒██░    ▒██░      ▒   ██▒▒▓█  ▄ ▒▓▓▄ ▄██▒"
    echo "▒██░   ▓██░▒▒█████▓ ░██████▒░██████▒▒██████▒▒░▒████▒▒ ▓███▀ ░"
    echo -e "${CYAN}"
    echo "  ═══════════════════════════════════════════════════════════════════"
    echo "  ☠  SSH TRANSFER UTILITY v2.0  ☠"
    echo "  File deployment for NULLSEC Framework"
    echo "  ═══════════════════════════════════════════════════════════════════"
    echo -e "${RESET}"
}

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
    
    case "$level" in
        "INFO") echo -e "${GREEN}[+]${RESET} ${message}" ;;
        "WARN") echo -e "${YELLOW}[!]${RESET} ${message}" ;;
        "ERROR") echo -e "${RED}[-]${RESET} ${message}" ;;
        *) echo -e "${WHITE}[*]${RESET} ${message}" ;;
    esac
}

check_dependencies() {
    local deps=("ssh" "scp" "rsync")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log "WARN" "Missing dependencies: ${missing[*]}"
        log "INFO" "Installing missing dependencies..."
        sudo apt-get update && sudo apt-get install -y openssh-client rsync sshpass
    fi
}

detect_remote_os() {
    local host="$1"
    local user="$2"
    local auth="$3"
    
    log "INFO" "Detecting remote OS..."
    
    local cmd_result
    if [ -n "$SSH_KEY" ]; then
        cmd_result=$(ssh -i "$SSH_KEY" -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${user}@${host}" "uname -s 2>/dev/null || echo Windows" 2>/dev/null)
    elif [ -n "$SSH_PASS" ]; then
        cmd_result=$(sshpass -p "$SSH_PASS" ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${user}@${host}" "uname -s 2>/dev/null || echo Windows" 2>/dev/null)
    else
        cmd_result=$(ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${user}@${host}" "uname -s 2>/dev/null || echo Windows" 2>/dev/null)
    fi
    
    case "$cmd_result" in
        Linux*) REMOTE_OS="linux" ;;
        Darwin*) REMOTE_OS="macos" ;;
        *Windows*|*MINGW*|*CYGWIN*) REMOTE_OS="windows" ;;
        *) REMOTE_OS="unknown" ;;
    esac
    
    log "INFO" "Remote OS detected: ${REMOTE_OS}"
}

test_connection() {
    local host="$1"
    local user="$2"
    
    log "INFO" "Testing SSH connection to ${user}@${host}:${SSH_PORT}..."
    
    local result
    if [ -n "$SSH_KEY" ]; then
        result=$(ssh -i "$SSH_KEY" -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${user}@${host}" "echo SUCCESS" 2>/dev/null)
    elif [ -n "$SSH_PASS" ]; then
        result=$(sshpass -p "$SSH_PASS" ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${user}@${host}" "echo SUCCESS" 2>/dev/null)
    else
        result=$(ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${user}@${host}" "echo SUCCESS" 2>/dev/null)
    fi
    
    if [ "$result" == "SUCCESS" ]; then
        log "INFO" "Connection successful!"
        return 0
    else
        log "ERROR" "Connection failed!"
        return 1
    fi
}

transfer_file() {
    local local_path="$1"
    local remote_path="$2"
    local host="$3"
    local user="$4"
    
    if [ ! -e "$local_path" ]; then
        log "ERROR" "Local file not found: ${local_path}"
        return 1
    fi
    
    log "INFO" "Transferring: ${local_path} -> ${user}@${host}:${remote_path}"
    
    local scp_opts="-P ${SSH_PORT} -o StrictHostKeyChecking=no"
    
    if [ -d "$local_path" ]; then
        scp_opts="${scp_opts} -r"
    fi
    
    if [ -n "$SSH_KEY" ]; then
        scp ${scp_opts} -i "$SSH_KEY" "$local_path" "${user}@${host}:${remote_path}"
    elif [ -n "$SSH_PASS" ]; then
        sshpass -p "$SSH_PASS" scp ${scp_opts} "$local_path" "${user}@${host}:${remote_path}"
    else
        scp ${scp_opts} "$local_path" "${user}@${host}:${remote_path}"
    fi
    
    if [ $? -eq 0 ]; then
        log "INFO" "Transfer successful!"
        return 0
    else
        log "ERROR" "Transfer failed!"
        return 1
    fi
}

transfer_directory() {
    local local_dir="$1"
    local remote_dir="$2"
    local host="$3"
    local user="$4"
    
    log "INFO" "Syncing directory: ${local_dir} -> ${user}@${host}:${remote_dir}"
    
    local rsync_opts="-avz --progress -e"
    
    if [ -n "$SSH_KEY" ]; then
        rsync ${rsync_opts} "ssh -i ${SSH_KEY} -p ${SSH_PORT} -o StrictHostKeyChecking=no" "$local_dir" "${user}@${host}:${remote_dir}"
    elif [ -n "$SSH_PASS" ]; then
        sshpass -p "$SSH_PASS" rsync ${rsync_opts} "ssh -p ${SSH_PORT} -o StrictHostKeyChecking=no" "$local_dir" "${user}@${host}:${remote_dir}"
    else
        rsync ${rsync_opts} "ssh -p ${SSH_PORT} -o StrictHostKeyChecking=no" "$local_dir" "${user}@${host}:${remote_dir}"
    fi
}

remote_exec() {
    local host="$1"
    local user="$2"
    local command="$3"
    
    log "INFO" "Executing remote command: ${command}"
    
    if [ -n "$SSH_KEY" ]; then
        ssh -i "$SSH_KEY" -p "$SSH_PORT" -o StrictHostKeyChecking=no "${user}@${host}" "$command"
    elif [ -n "$SSH_PASS" ]; then
        sshpass -p "$SSH_PASS" ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no "${user}@${host}" "$command"
    else
        ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no "${user}@${host}" "$command"
    fi
}

deploy_nullsec_windows() {
    log "INFO" "Deploying NULLSEC Windows Edition..."
    
    if [ -z "$SSH_HOST" ] || [ -z "$SSH_USER" ]; then
        log "ERROR" "Host and user required for deployment"
        return 1
    fi
    
    # Check if Windows directory exists
    if [ ! -d "$WINDOWS_DIR" ]; then
        log "ERROR" "Windows directory not found: ${WINDOWS_DIR}"
        return 1
    fi
    
    # Test connection first
    if ! test_connection "$SSH_HOST" "$SSH_USER"; then
        return 1
    fi
    
    # Detect remote OS
    detect_remote_os "$SSH_HOST" "$SSH_USER"
    
    # Set default remote path based on OS
    if [ -z "$REMOTE_PATH" ]; then
        case "$REMOTE_OS" in
            "windows") REMOTE_PATH="C:/nullsec" ;;
            "linux") REMOTE_PATH="/opt/nullsec" ;;
            "macos") REMOTE_PATH="/opt/nullsec" ;;
            *) REMOTE_PATH="~/nullsec" ;;
        esac
    fi
    
    log "INFO" "Remote path: ${REMOTE_PATH}"
    
    # Create remote directory
    remote_exec "$SSH_HOST" "$SSH_USER" "mkdir -p ${REMOTE_PATH} 2>/dev/null || md ${REMOTE_PATH} 2>NUL"
    
    # Transfer Windows files
    echo -e "\n${CYAN}Transferring NULLSEC Windows Edition...${RESET}\n"
    
    transfer_file "${WINDOWS_DIR}/nullsec-launcher-windows.py" "${REMOTE_PATH}/" "$SSH_HOST" "$SSH_USER"
    transfer_file "${WINDOWS_DIR}/nullsec-ai-windows.py" "${REMOTE_PATH}/" "$SSH_HOST" "$SSH_USER"
    transfer_file "${WINDOWS_DIR}/nullsec-desktop-windows.py" "${REMOTE_PATH}/" "$SSH_HOST" "$SSH_USER"
    transfer_file "${WINDOWS_DIR}/install-windows.bat" "${REMOTE_PATH}/" "$SSH_HOST" "$SSH_USER"
    transfer_file "${WINDOWS_DIR}/README-WINDOWS.md" "${REMOTE_PATH}/" "$SSH_HOST" "$SSH_USER"
    
    # Transfer PowerShell modules if they exist
    if [ -d "${WINDOWS_DIR}/powershell-modules" ]; then
        transfer_directory "${WINDOWS_DIR}/powershell-modules/" "${REMOTE_PATH}/powershell-modules" "$SSH_HOST" "$SSH_USER"
    fi
    
    log "INFO" "Deployment complete!"
    
    echo -e "\n${GREEN}═══════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${GREEN}  NULLSEC Windows Edition deployed successfully!${RESET}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${RESET}"
    echo -e "\n${YELLOW}Remote path:${RESET} ${REMOTE_PATH}"
    echo -e "\n${CYAN}To run on Windows:${RESET}"
    echo -e "  python ${REMOTE_PATH}/nullsec-launcher-windows.py"
    echo -e "  python ${REMOTE_PATH}/nullsec-ai-windows.py"
    echo -e "  python ${REMOTE_PATH}/nullsec-desktop-windows.py"
    echo -e "\n${CYAN}Or run the installer:${RESET}"
    echo -e "  ${REMOTE_PATH}/install-windows.bat"
    echo ""
}

interactive_menu() {
    while true; do
        clear
        banner
        
        echo -e "${CYAN}Current Configuration:${RESET}"
        echo -e "  Host: ${SSH_HOST:-not set}"
        echo -e "  User: ${SSH_USER:-not set}"
        echo -e "  Port: ${SSH_PORT}"
        echo -e "  Auth: ${SSH_KEY:+SSH Key}${SSH_PASS:+Password}${SSH_KEY:-${SSH_PASS:-Interactive}}"
        echo ""
        
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${RESET}"
        echo -e "  ${RED}[1]${RESET} Set connection details"
        echo -e "  ${RED}[2]${RESET} Test SSH connection"
        echo -e "  ${RED}[3]${RESET} Deploy NULLSEC Windows Edition"
        echo -e "  ${RED}[4]${RESET} Transfer single file"
        echo -e "  ${RED}[5]${RESET} Transfer directory"
        echo -e "  ${RED}[6]${RESET} Execute remote command"
        echo -e "  ${RED}[7]${RESET} Open SSH session"
        echo -e "  ${RED}[Q]${RESET} Quit"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${RESET}"
        echo ""
        
        read -p "$(echo -e ${WHITE}'Select option: '${RESET})" choice
        
        case "$choice" in
            1)
                echo ""
                read -p "$(echo -e ${CYAN}'SSH Host: '${RESET})" SSH_HOST
                read -p "$(echo -e ${CYAN}'SSH User: '${RESET})" SSH_USER
                read -p "$(echo -e ${CYAN}'SSH Port [22]: '${RESET})" port
                [ -n "$port" ] && SSH_PORT="$port"
                read -p "$(echo -e ${CYAN}'SSH Key path (or leave empty for password): '${RESET})" SSH_KEY
                
                if [ -z "$SSH_KEY" ]; then
                    read -sp "$(echo -e ${CYAN}'SSH Password: '${RESET})" SSH_PASS
                    echo ""
                fi
                
                log "INFO" "Connection details updated"
                ;;
            2)
                if [ -z "$SSH_HOST" ] || [ -z "$SSH_USER" ]; then
                    log "ERROR" "Please set connection details first"
                else
                    test_connection "$SSH_HOST" "$SSH_USER"
                    detect_remote_os "$SSH_HOST" "$SSH_USER"
                fi
                read -p "Press ENTER to continue..."
                ;;
            3)
                deploy_nullsec_windows
                read -p "Press ENTER to continue..."
                ;;
            4)
                echo ""
                read -p "$(echo -e ${CYAN}'Local file path: '${RESET})" local_path
                read -p "$(echo -e ${CYAN}'Remote path: '${RESET})" remote_path
                transfer_file "$local_path" "$remote_path" "$SSH_HOST" "$SSH_USER"
                read -p "Press ENTER to continue..."
                ;;
            5)
                echo ""
                read -p "$(echo -e ${CYAN}'Local directory: '${RESET})" local_dir
                read -p "$(echo -e ${CYAN}'Remote directory: '${RESET})" remote_dir
                transfer_directory "$local_dir" "$remote_dir" "$SSH_HOST" "$SSH_USER"
                read -p "Press ENTER to continue..."
                ;;
            6)
                echo ""
                read -p "$(echo -e ${CYAN}'Command to execute: '${RESET})" cmd
                remote_exec "$SSH_HOST" "$SSH_USER" "$cmd"
                read -p "Press ENTER to continue..."
                ;;
            7)
                if [ -z "$SSH_HOST" ] || [ -z "$SSH_USER" ]; then
                    log "ERROR" "Please set connection details first"
                else
                    log "INFO" "Opening SSH session..."
                    if [ -n "$SSH_KEY" ]; then
                        ssh -i "$SSH_KEY" -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}"
                    elif [ -n "$SSH_PASS" ]; then
                        sshpass -p "$SSH_PASS" ssh -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}"
                    else
                        ssh -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}"
                    fi
                fi
                ;;
            q|Q)
                echo -e "\n${GREEN}[+] Goodbye!${RESET}\n"
                exit 0
                ;;
            *)
                log "ERROR" "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Quick deploy mode for command line
quick_deploy() {
    local host="$1"
    local user="$2"
    local pass="$3"
    
    SSH_HOST="$host"
    SSH_USER="$user"
    SSH_PASS="$pass"
    
    deploy_nullsec_windows
}

# Help message
show_help() {
    echo "NULLSEC SSH Transfer Utility v2.0"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -i, --interactive       Run in interactive mode (default)"
    echo "  -d, --deploy HOST USER  Quick deploy NULLSEC Windows to host"
    echo "  -p, --port PORT         SSH port (default: 22)"
    echo "  -k, --key KEYFILE       SSH private key file"
    echo "  --password PASS         SSH password (not recommended)"
    echo ""
    echo "Examples:"
    echo "  $0 -i                                    # Interactive mode"
    echo "  $0 -d 192.168.1.100 admin                # Deploy with interactive password"
    echo "  $0 -d 192.168.1.100 admin -k ~/.ssh/id_rsa  # Deploy with SSH key"
    echo ""
}

# Main
main() {
    check_dependencies
    
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        -d|--deploy)
            if [ $# -lt 3 ]; then
                log "ERROR" "Deploy requires host and user"
                show_help
                exit 1
            fi
            SSH_HOST="$2"
            SSH_USER="$3"
            shift 3
            
            while [ $# -gt 0 ]; do
                case "$1" in
                    -p|--port) SSH_PORT="$2"; shift 2 ;;
                    -k|--key) SSH_KEY="$2"; shift 2 ;;
                    --password) SSH_PASS="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done
            
            if [ -z "$SSH_KEY" ] && [ -z "$SSH_PASS" ]; then
                read -sp "SSH Password: " SSH_PASS
                echo ""
            fi
            
            deploy_nullsec_windows
            ;;
        *)
            interactive_menu
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
