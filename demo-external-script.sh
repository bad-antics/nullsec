#!/bin/bash
#
# Demo External Script for NULLSEC Command Console v1.1
# This demonstrates how any external script can be executed from within NULLSEC
# Repository: https://github.com/bad-antics/nullsec
#

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
RESET='\033[0m'

clear

echo -e "${CYAN}"
cat << "EOF"
▓━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━▓
█                                                                       █
█        🔥  NULLSEC EXTERNAL SCRIPT DEMO  🔥                           █
█                                                                       █
█        This script demonstrates external execution                   █
█        capabilities from the NULLSEC command console                 █
█                                                                       █
▓━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━▓
EOF
echo -e "${RESET}\n"

echo -e "${WHITE}[*] Script Information:${RESET}"
echo -e "    Name: demo-external-script.sh"
echo -e "    Path: $(readlink -f "$0")"
echo -e "    User: $(whoami)"
echo -e "    Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

echo -e "${YELLOW}[*] System Information:${RESET}"
echo -e "    OS: $(uname -s)"
echo -e "    Kernel: $(uname -r)"
echo -e "    Arch: $(uname -m)"
echo -e "    Hostname: $(hostname)"
echo ""

echo -e "${CYAN}[*] Available Security Tools:${RESET}"
tools=("nmap" "wireshark" "aircrack-ng" "hashcat" "hydra" "metasploit" "sqlmap")
for tool in "${tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo -e "    ${GREEN}✓${RESET} $tool"
    else
        echo -e "    ${RED}✗${RESET} $tool (not installed)"
    fi
done
echo ""

echo -e "${WHITE}[*] Performing Sample Tasks:${RESET}"
echo ""

# Task 1: Network Interface Info
echo -e "  ${CYAN}[1/3]${RESET} Checking network interfaces..."
sleep 0.5
interfaces=$(ip -br link | wc -l)
echo -e "        Found ${GREEN}$interfaces${RESET} network interfaces"

# Task 2: Check for wireless
echo -e "  ${CYAN}[2/3]${RESET} Checking for wireless adapters..."
sleep 0.5
if iwconfig 2>/dev/null | grep -q "IEEE 802.11"; then
    echo -e "        ${GREEN}✓${RESET} Wireless adapter detected"
else
    echo -e "        ${YELLOW}⚠${RESET} No wireless adapter found"
fi

# Task 3: Sample nmap scan (safe)
echo -e "  ${CYAN}[3/3]${RESET} Testing nmap availability..."
sleep 0.5
if command -v nmap &> /dev/null; then
    echo -e "        ${GREEN}✓${RESET} nmap is ready ($(nmap --version | head -n1))"
else
    echo -e "        ${RED}✗${RESET} nmap not available"
fi

echo ""
echo -e "${GREEN}[✓] Demo script completed successfully!${RESET}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}This script was executed from the NULLSEC Command Console${RESET}"
echo -e "${WHITE}You can run ANY script this way:${RESET}"
echo -e "  ${CYAN}nullsec@exec >${RESET} run /path/to/your-script.sh"
echo -e "  ${CYAN}nullsec@exec >${RESET} run /path/to/exploit.py"
echo -e "  ${CYAN}nullsec@exec >${RESET} run ./custom-tool.rb"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
