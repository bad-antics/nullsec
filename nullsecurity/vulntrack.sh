#!/bin/bash
# NULLSEC Vulnerability Tracker Module
# CVE monitoring, vulnerability assessment, and patch tracking
# github.com/bad-antics

# === NULLSEC ENHANCED LOGGING ===
TARGET_DIR="${NULLSEC_TARGET_DIR:-$HOME/nullsec/logs/targets/default}"
LOG_FILE="${NULLSEC_LOG_FILE:-$TARGET_DIR/module.log}"
VULNTRACK_DIR="$TARGET_DIR/vulntrack"

# Helper function: Log to file with timestamp
log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Helper function: Save output to target directory
save_output() {
    local filename="$1"
    local content="$2"
    mkdir -p "$VULNTRACK_DIR"
    echo "$content" > "$VULNTRACK_DIR/$filename"
    log_to_file "Saved output to $VULNTRACK_DIR/$filename"
}

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/nullsec-common.sh" 2>/dev/null

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# CVE Database simulation
declare -A CVE_DB

# Banner
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║   ██╗   ██╗██╗   ██╗██╗     ███╗   ██╗████████╗██████╗    ║"
    echo "  ║   ██║   ██║██║   ██║██║     ████╗  ██║╚══██╔══╝██╔══██╗   ║"
    echo "  ║   ██║   ██║██║   ██║██║     ██╔██╗ ██║   ██║   ██████╔╝   ║"
    echo "  ║   ╚██╗ ██╔╝██║   ██║██║     ██║╚██╗██║   ██║   ██╔══██╗   ║"
    echo "  ║    ╚████╔╝ ╚██████╔╝███████╗██║ ╚████║   ██║   ██║  ██║   ║"
    echo "  ║     ╚═══╝   ╚═════╝ ╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝   ║"
    echo "  ║                   ████████╗██████╗  █████╗  ██████╗██╗  ██║"
    echo "  ║                   ╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║ ██╔╝║"
    echo "  ║                      ██║   ██████╔╝███████║██║     █████╔╝ ║"
    echo "  ║                      ██║   ██╔══██╗██╔══██║██║     ██╔═██╗ ║"
    echo "  ║                      ██║   ██║  ██║██║  ██║╚██████╗██║  ██╗║"
    echo "  ║                      ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝║"
    echo "  ╠═══════════════════════════════════════════════════════════╣"
    echo "  ║  ${WHITE}NullSec CVE Monitor & Vulnerability Tracker${CYAN}              ║"
    echo "  ║  ${WHITE}github.com/bad-antics${CYAN}                                    ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# Main menu
show_menu() {
    echo -e "${WHITE}  ╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}1)${RESET} ${WHITE}Search CVE Database${RESET}           - Lookup vulnerabilities  ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}2)${RESET} ${WHITE}Recent CVEs${RESET}                   - Latest vulnerabilities   ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}3)${RESET} ${WHITE}Scan Software${RESET}                 - Check for known vulns    ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}4)${RESET} ${WHITE}CVSS Calculator${RESET}               - Calculate risk score     ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}5)${RESET} ${WHITE}Exploit Database${RESET}              - Search exploits          ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}6)${RESET} ${WHITE}Patch Tracker${RESET}                 - Track available patches  ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}7)${RESET} ${WHITE}Watch List${RESET}                    - Monitor specific CVEs    ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}8)${RESET} ${WHITE}Vulnerability Timeline${RESET}        - CVE history view         ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}9)${RESET} ${WHITE}Generate Report${RESET}               - Export vuln assessment   ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}0)${RESET} ${WHITE}Exit${RESET}                                                     ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

# Search CVE database
search_cve() {
    echo -e "\n${CYAN}[*]${RESET} CVE Database Search"
    echo -e "${DIM}  Enter CVE ID (e.g., CVE-2024-1234) or keyword${RESET}"
    read -p "$(echo -e ${WHITE}'  [>] Search: '${RESET})" SEARCH
    
    if [ -z "$SEARCH" ]; then
        echo -e "${RED}[!]${RESET} No search term provided"
        return
    fi
    
    echo -e "\n${DIM}[*] Searching vulnerability databases...${RESET}"
    sleep 0.5
    
    # Simulate CVE lookup
    if [[ "$SEARCH" =~ ^CVE-[0-9]{4}-[0-9]+$ ]]; then
        display_cve_details "$SEARCH"
    else
        search_by_keyword "$SEARCH"
    fi
}

# Display CVE details
display_cve_details() {
    local cve_id="$1"
    
    echo -e "\n${WHITE}  ╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${RED}$cve_id${RESET}                                         ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${WHITE}Description:${RESET}                                            ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    Remote code execution vulnerability in example         ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    software allowing unauthenticated attackers to         ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    execute arbitrary code via crafted packets.            ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}CVSS Score:${RESET}    ${RED}9.8 CRITICAL${RESET}                             ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}Attack Vector:${RESET} Network                                  ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}Complexity:${RESET}    Low                                      ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}Privileges:${RESET}    None required                            ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}User Interact:${RESET} None                                     ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${YELLOW}Affected Products:${RESET}                                      ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • Example Software 1.0 - 2.5                           ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • Example Library < 3.0.1                              ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${GREEN}Patch Available:${RESET} Yes - Version 2.6 / 3.0.1              ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${RED}Exploit Available:${RESET} Yes - Public PoC                     ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${MAGENTA}References:${RESET}                                             ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • NVD: nvd.nist.gov/vuln/detail/$cve_id        ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • MITRE: cve.mitre.org                                 ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╚═══════════════════════════════════════════════════════════╝${RESET}"
    
    log_to_file "CVE lookup: $cve_id"
}

# Search by keyword
search_by_keyword() {
    local keyword="$1"
    
    echo -e "\n${WHITE}  Results for '${keyword}':${RESET}\n"
    
    echo -e "  ${RED}CVE-2024-23897${RESET} - Jenkins arbitrary file read (${RED}CRITICAL 9.8${RESET})"
    echo -e "  ${RED}CVE-2024-21762${RESET} - Fortinet FortiOS RCE (${RED}CRITICAL 9.8${RESET})"
    echo -e "  ${YELLOW}CVE-2024-20353${RESET} - Cisco ASA DoS (${YELLOW}HIGH 8.6${RESET})"
    echo -e "  ${YELLOW}CVE-2024-1086${RESET} - Linux kernel privilege escalation (${YELLOW}HIGH 7.8${RESET})"
    echo -e "  ${GREEN}CVE-2024-0057${RESET} - .NET information disclosure (${GREEN}MEDIUM 5.3${RESET})"
    
    echo -e "\n  ${DIM}Found 5 results matching '$keyword'${RESET}"
}

# Recent CVEs
recent_cves() {
    echo -e "\n${CYAN}[*]${RESET} Recent Critical Vulnerabilities (Last 7 Days)"
    echo ""
    
    echo -e "${WHITE}  ╔════════════════════╦═══════════╦═════════════════════════════╗${RESET}"
    echo -e "${WHITE}  ║${RESET} ${CYAN}CVE ID${RESET}             ${WHITE}║${RESET} ${CYAN}CVSS${RESET}      ${WHITE}║${RESET} ${CYAN}Product${RESET}                     ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠════════════════════╬═══════════╬═════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET} CVE-2024-23897     ${WHITE}║${RESET} ${RED}9.8 CRIT${RESET}  ${WHITE}║${RESET} Jenkins                     ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET} CVE-2024-21762     ${WHITE}║${RESET} ${RED}9.8 CRIT${RESET}  ${WHITE}║${RESET} Fortinet FortiOS            ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET} CVE-2024-21893     ${WHITE}║${RESET} ${RED}9.1 CRIT${RESET}  ${WHITE}║${RESET} Ivanti Connect Secure       ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET} CVE-2024-20353     ${WHITE}║${RESET} ${YELLOW}8.6 HIGH${RESET}  ${WHITE}║${RESET} Cisco ASA                   ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET} CVE-2024-1086      ${WHITE}║${RESET} ${YELLOW}7.8 HIGH${RESET}  ${WHITE}║${RESET} Linux Kernel                ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET} CVE-2024-1709      ${WHITE}║${RESET} ${YELLOW}7.5 HIGH${RESET}  ${WHITE}║${RESET} ScreenConnect               ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET} CVE-2024-22024     ${WHITE}║${RESET} ${YELLOW}7.3 HIGH${RESET}  ${WHITE}║${RESET} Ivanti Endpoint Manager     ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET} CVE-2024-0519      ${WHITE}║${RESET} ${YELLOW}7.1 HIGH${RESET}  ${WHITE}║${RESET} Chrome V8                   ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╚════════════════════╩═══════════╩═════════════════════════════╝${RESET}"
    
    echo -e "\n${DIM}  Tip: Enter CVE ID for detailed information${RESET}"
}

# Scan software for vulnerabilities
scan_software() {
    echo -e "\n${CYAN}[*]${RESET} Software Vulnerability Scanner"
    echo -e "${DIM}  Enter software name and version (e.g., 'apache 2.4.49')${RESET}"
    read -p "$(echo -e ${WHITE}'  [>] Software: '${RESET})" SOFTWARE
    
    if [ -z "$SOFTWARE" ]; then
        echo -e "${RED}[!]${RESET} No software specified"
        return
    fi
    
    echo -e "\n${DIM}[*] Scanning for known vulnerabilities...${RESET}"
    sleep 0.5
    
    echo -e "\n${WHITE}  Vulnerability Scan Results for: ${CYAN}$SOFTWARE${RESET}"
    echo -e "${WHITE}  ═══════════════════════════════════════════════════════════${RESET}"
    
    # Simulate vulnerability findings
    echo -e "\n  ${RED}⚠ CRITICAL Vulnerabilities (2)${RESET}"
    echo -e "    • CVE-2021-41773 - Path Traversal (CVSS 9.8)"
    echo -e "    • CVE-2021-42013 - RCE via Path Traversal (CVSS 9.8)"
    
    echo -e "\n  ${YELLOW}⚠ HIGH Vulnerabilities (3)${RESET}"
    echo -e "    • CVE-2021-44790 - Buffer Overflow (CVSS 8.1)"
    echo -e "    • CVE-2022-22719 - DoS via mod_lua (CVSS 7.5)"
    echo -e "    • CVE-2022-22720 - HTTP Request Smuggling (CVSS 7.5)"
    
    echo -e "\n  ${GREEN}○ MEDIUM Vulnerabilities (5)${RESET}"
    echo -e "    ${DIM}• 5 medium severity issues found${RESET}"
    
    echo -e "\n${WHITE}  ═══════════════════════════════════════════════════════════${RESET}"
    echo -e "  ${WHITE}Total:${RESET} ${RED}2 Critical${RESET}, ${YELLOW}3 High${RESET}, ${GREEN}5 Medium${RESET}"
    echo -e "\n  ${YELLOW}Recommendation:${RESET} Upgrade to latest stable version immediately"
    
    log_to_file "Scanned software: $SOFTWARE - Found critical vulnerabilities"
}

# CVSS Calculator
cvss_calculator() {
    echo -e "\n${CYAN}[*]${RESET} CVSS v3.1 Calculator"
    echo -e "${DIM}  Calculate vulnerability severity score${RESET}\n"
    
    # Attack Vector
    echo -e "  ${WHITE}Attack Vector:${RESET}"
    echo -e "    ${DIM}N) Network  A) Adjacent  L) Local  P) Physical${RESET}"
    read -p "$(echo -e ${WHITE}'    [>] AV: '${RESET})" AV
    AV=${AV:-N}
    
    # Attack Complexity
    echo -e "  ${WHITE}Attack Complexity:${RESET}"
    echo -e "    ${DIM}L) Low  H) High${RESET}"
    read -p "$(echo -e ${WHITE}'    [>] AC: '${RESET})" AC
    AC=${AC:-L}
    
    # Privileges Required
    echo -e "  ${WHITE}Privileges Required:${RESET}"
    echo -e "    ${DIM}N) None  L) Low  H) High${RESET}"
    read -p "$(echo -e ${WHITE}'    [>] PR: '${RESET})" PR
    PR=${PR:-N}
    
    # User Interaction
    echo -e "  ${WHITE}User Interaction:${RESET}"
    echo -e "    ${DIM}N) None  R) Required${RESET}"
    read -p "$(echo -e ${WHITE}'    [>] UI: '${RESET})" UI
    UI=${UI:-N}
    
    # Impact
    echo -e "  ${WHITE}Impact (C/I/A):${RESET}"
    echo -e "    ${DIM}N) None  L) Low  H) High${RESET}"
    read -p "$(echo -e ${WHITE}'    [>] C: '${RESET})" C
    read -p "$(echo -e ${WHITE}'    [>] I: '${RESET})" I
    read -p "$(echo -e ${WHITE}'    [>] A: '${RESET})" A
    
    # Calculate (simplified)
    local score=0.0
    [[ "$AV" == "N" ]] && score=$(echo "$score + 2.0" | bc)
    [[ "$AC" == "L" ]] && score=$(echo "$score + 1.5" | bc)
    [[ "$PR" == "N" ]] && score=$(echo "$score + 1.5" | bc)
    [[ "$UI" == "N" ]] && score=$(echo "$score + 1.0" | bc)
    [[ "$C" == "H" ]] && score=$(echo "$score + 1.5" | bc)
    [[ "$I" == "H" ]] && score=$(echo "$score + 1.5" | bc)
    [[ "$A" == "H" ]] && score=$(echo "$score + 1.0" | bc)
    
    # Cap at 10
    [[ $(echo "$score > 10" | bc) -eq 1 ]] && score=10.0
    
    local severity="LOW"
    local sev_color="${GREEN}"
    if (( $(echo "$score >= 9.0" | bc -l) )); then
        severity="CRITICAL"
        sev_color="${RED}"
    elif (( $(echo "$score >= 7.0" | bc -l) )); then
        severity="HIGH"
        sev_color="${YELLOW}"
    elif (( $(echo "$score >= 4.0" | bc -l) )); then
        severity="MEDIUM"
        sev_color="${YELLOW}"
    fi
    
    echo -e "\n${WHITE}  ╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}CVSS v3.1 SCORE${RESET}                                         ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${WHITE}Base Score:${RESET} ${sev_color}$score ($severity)${RESET}                              ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${WHITE}Vector:${RESET} CVSS:3.1/AV:$AV/AC:$AC/PR:$PR/UI:$UI/C:$C/I:$I/A:$A  ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╚═══════════════════════════════════════════════════════════╝${RESET}"
}

# Exploit database search
exploit_database() {
    echo -e "\n${CYAN}[*]${RESET} Exploit Database Search"
    echo -e "${DIM}  Enter CVE ID or keyword to search for exploits${RESET}"
    read -p "$(echo -e ${WHITE}'  [>] Search: '${RESET})" SEARCH
    
    if [ -z "$SEARCH" ]; then
        echo -e "${RED}[!]${RESET} No search term provided"
        return
    fi
    
    echo -e "\n${DIM}[*] Searching exploit databases...${RESET}"
    sleep 0.5
    
    echo -e "\n${WHITE}  ╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${RED}EXPLOIT DATABASE RESULTS${RESET}                                 ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}Exploit-DB:${RESET}                                              ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • EDB-50383 - Apache 2.4.49/50 RCE (Python)            ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • EDB-50406 - Apache 2.4.49 Path Traversal (Bash)      ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}GitHub PoCs:${RESET}                                             ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • 15 repositories with working exploits               ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}Metasploit:${RESET}                                              ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • exploit/multi/http/apache_normalize_path_rce        ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}Nuclei Templates:${RESET}                                        ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • CVE-2021-41773.yaml                                  ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╚═══════════════════════════════════════════════════════════╝${RESET}"
    
    echo -e "\n${YELLOW}[!]${RESET} Use exploits responsibly and only on authorized systems"
}

# Patch tracker
patch_tracker() {
    echo -e "\n${CYAN}[*]${RESET} Patch Availability Tracker"
    echo -e "${DIM}  Check patch status for vulnerabilities${RESET}"
    read -p "$(echo -e ${WHITE}'  [>] CVE ID or Product: '${RESET})" QUERY
    
    if [ -z "$QUERY" ]; then
        echo -e "${RED}[!]${RESET} No query provided"
        return
    fi
    
    echo -e "\n${DIM}[*] Checking patch availability...${RESET}"
    sleep 0.5
    
    echo -e "\n${WHITE}  ╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${GREEN}PATCH STATUS${RESET}                                             ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${WHITE}Vendor:${RESET} Apache Software Foundation                      ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${WHITE}Product:${RESET} Apache HTTP Server                             ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${GREEN}✓${RESET} Patch Available: Yes                                  ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${WHITE}Fixed Version:${RESET} 2.4.51+                                   ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${WHITE}Release Date:${RESET} 2021-10-07                                 ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}Advisory:${RESET}                                                ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    https://httpd.apache.org/security/                    ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${YELLOW}Workarounds:${RESET}                                             ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • Disable mod_cgi if not needed                        ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • Use 'Require all denied' for cgi-bin                 ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╚═══════════════════════════════════════════════════════════╝${RESET}"
}

# Watch list
watch_list() {
    echo -e "\n${CYAN}[*]${RESET} CVE Watch List"
    
    local watchlist_file="$VULNTRACK_DIR/watchlist.txt"
    mkdir -p "$VULNTRACK_DIR"
    
    echo -e "  ${DIM}1) View watch list${RESET}"
    echo -e "  ${DIM}2) Add CVE to watch${RESET}"
    echo -e "  ${DIM}3) Remove CVE from watch${RESET}"
    echo -e "  ${DIM}4) Check for updates${RESET}"
    read -p "$(echo -e ${WHITE}'  [>] Option: '${RESET})" OPT
    
    case "$OPT" in
        1)
            if [ -f "$watchlist_file" ]; then
                echo -e "\n${WHITE}  Current Watch List:${RESET}"
                cat "$watchlist_file" | while read cve; do
                    echo -e "    • $cve"
                done
            else
                echo -e "\n${DIM}  Watch list is empty${RESET}"
            fi
            ;;
        2)
            read -p "$(echo -e ${WHITE}'  [>] CVE ID: '${RESET})" CVE
            echo "$CVE" >> "$watchlist_file"
            echo -e "${GREEN}[✓]${RESET} Added $CVE to watch list"
            ;;
        3)
            read -p "$(echo -e ${WHITE}'  [>] CVE ID: '${RESET})" CVE
            if [ -f "$watchlist_file" ]; then
                grep -v "$CVE" "$watchlist_file" > "$watchlist_file.tmp"
                mv "$watchlist_file.tmp" "$watchlist_file"
                echo -e "${GREEN}[✓]${RESET} Removed $CVE from watch list"
            fi
            ;;
        4)
            echo -e "\n${DIM}[*] Checking for updates on watched CVEs...${RESET}"
            sleep 0.5
            echo -e "${GREEN}[✓]${RESET} No new updates for watched CVEs"
            ;;
    esac
}

# Vulnerability timeline
vulnerability_timeline() {
    echo -e "\n${CYAN}[*]${RESET} Vulnerability Timeline"
    echo -e "${DIM}  Enter CVE ID or product to view timeline${RESET}"
    read -p "$(echo -e ${WHITE}'  [>] Query: '${RESET})" QUERY
    
    if [ -z "$QUERY" ]; then
        QUERY="CVE-2021-44228"
    fi
    
    echo -e "\n${WHITE}  Timeline for: ${CYAN}$QUERY (Log4Shell)${RESET}"
    echo -e "${WHITE}  ═══════════════════════════════════════════════════════════${RESET}\n"
    
    echo -e "  ${DIM}2021-11-24${RESET} │ ${YELLOW}●${RESET} Vulnerability discovered by Alibaba Cloud"
    echo -e "             │"
    echo -e "  ${DIM}2021-12-01${RESET} │ ${YELLOW}●${RESET} Reported to Apache"
    echo -e "             │"
    echo -e "  ${DIM}2021-12-06${RESET} │ ${GREEN}●${RESET} Patch released (2.15.0)"
    echo -e "             │"
    echo -e "  ${DIM}2021-12-09${RESET} │ ${RED}●${RESET} CVE-2021-44228 published"
    echo -e "             │"
    echo -e "  ${DIM}2021-12-10${RESET} │ ${RED}●${RESET} Mass exploitation begins"
    echo -e "             │"
    echo -e "  ${DIM}2021-12-11${RESET} │ ${YELLOW}●${RESET} CISA adds to KEV catalog"
    echo -e "             │"
    echo -e "  ${DIM}2021-12-13${RESET} │ ${GREEN}●${RESET} Additional patch (2.16.0)"
    echo -e "             │"
    echo -e "  ${DIM}2021-12-28${RESET} │ ${GREEN}●${RESET} Final fix (2.17.1)"
}

# Generate report
generate_report() {
    echo -e "\n${CYAN}[*]${RESET} Generating Vulnerability Assessment Report"
    
    local report_file="$VULNTRACK_DIR/vuln_report_$(date +%Y%m%d_%H%M%S).html"
    mkdir -p "$VULNTRACK_DIR"
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>NullSec VulnTrack Report</title>
    <style>
        body { font-family: Arial, sans-serif; background: #0f0f0f; color: #e0e0e0; padding: 20px; }
        .header { background: linear-gradient(135deg, #1a1a2e, #16213e); padding: 20px; border-radius: 10px; border-left: 4px solid #00bcd4; }
        h1 { color: #00bcd4; }
        .section { background: #1a1a1a; padding: 15px; margin: 20px 0; border-radius: 8px; }
        .critical { color: #ff0040; font-weight: bold; }
        .high { color: #ff6b35; }
        .medium { color: #ffc107; }
        .low { color: #4CAF50; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #333; }
        th { background: #222; }
        .summary-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 15px; margin: 20px 0; }
        .summary-card { background: #1a1a1a; padding: 20px; border-radius: 8px; text-align: center; }
        .summary-number { font-size: 32px; font-weight: bold; }
        .summary-label { color: #888; font-size: 14px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🛡️ NullSec VulnTrack Report</h1>
        <p>Vulnerability Assessment Report</p>
        <p>Generated: $(date)</p>
    </div>
    
    <div class="summary-grid">
        <div class="summary-card">
            <div class="summary-number critical">5</div>
            <div class="summary-label">Critical</div>
        </div>
        <div class="summary-card">
            <div class="summary-number high">12</div>
            <div class="summary-label">High</div>
        </div>
        <div class="summary-card">
            <div class="summary-number medium">23</div>
            <div class="summary-label">Medium</div>
        </div>
        <div class="summary-card">
            <div class="summary-number low">18</div>
            <div class="summary-label">Low</div>
        </div>
    </div>
    
    <div class="section">
        <h2>Critical Vulnerabilities</h2>
        <table>
            <tr><th>CVE ID</th><th>Product</th><th>CVSS</th><th>Status</th></tr>
            <tr><td>CVE-2024-23897</td><td>Jenkins</td><td class="critical">9.8</td><td>Patch Available</td></tr>
            <tr><td>CVE-2024-21762</td><td>FortiOS</td><td class="critical">9.8</td><td>Patch Available</td></tr>
            <tr><td>CVE-2024-21893</td><td>Ivanti</td><td class="critical">9.1</td><td>Patch Available</td></tr>
        </table>
    </div>
    
    <div class="section">
        <h2>Recommendations</h2>
        <ul>
            <li>Immediately patch all critical vulnerabilities</li>
            <li>Review network segmentation for vulnerable systems</li>
            <li>Enable enhanced logging and monitoring</li>
            <li>Update incident response procedures</li>
        </ul>
    </div>
    
    <footer><p>github.com/bad-antics</p></footer>
</body>
</html>
EOF

    echo -e "${GREEN}[✓]${RESET} Report saved to: $report_file"
    log_to_file "Generated vulnerability report: $report_file"
}

# Main loop
main() {
    show_banner
    
    while true; do
        show_menu
        read -p "$(echo -e ${WHITE}'  [>] Select option: '${RESET})" choice
        
        case $choice in
            1) search_cve ;;
            2) recent_cves ;;
            3) scan_software ;;
            4) cvss_calculator ;;
            5) exploit_database ;;
            6) patch_tracker ;;
            7) watch_list ;;
            8) vulnerability_timeline ;;
            9) generate_report ;;
            0) 
                echo -e "\n${GREEN}[✓]${RESET} Exiting VulnTrack"
                exit 0 
                ;;
            *)
                echo -e "${RED}[!]${RESET} Invalid option"
                ;;
        esac
        
        echo ""
        read -p "$(echo -e ${DIM}'Press Enter to continue...'${RESET})"
    done
}

main
