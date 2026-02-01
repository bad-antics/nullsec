#!/bin/bash
# NULLSEC Framework Quick Reference
# bad-antics development

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
MAGENTA='\033[1;35m'
DIM='\033[2m'
RESET='\033[0m'

clear
echo -e "${RED}"
cat << 'BANNER'
    ███▓   ██▓██▓   ██▓██▓     ██▓     ███████▓███████▓ ██████▓
    ████▓  ██████   ██████     ███     ██▓━━━━▓██▓━━━━▓██▓━━━━▓
    ██▓██▓ ██████   ██████     ███     ███████▓█████▓  ███     
    ███▓██▓██████   ██████     ███     ▓━━━━█████▓━━▓  ███     
    ███ ▓█████▓██████▓▓███████▓███████▓███████████████▓▓██████▓
    ▓━▓  ▓━━━▓ ▓━━━━━▓ ▓━━━━━━▓▓━━━━━━▓▓━━━━━━▓▓━━━━━━▓ ▓━━━━━▓
BANNER
echo -e "${RESET}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}                    QUICK REFERENCE GUIDE${RESET}"
echo -e "${CYAN}                      [ bad-antics development ]${RESET}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${CYAN}▓${WHITE}  LAUNCHING FRAMEWORK                                                ${CYAN}▓${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${DIM}  Main Launcher:${RESET}         ${GREEN}./nullsec${RESET}  ${DIM}or${RESET}  ${GREEN}python3 nullsec-launcher.py${RESET}"
echo -e "${DIM}  Framework Console:${RESET}     ${YELLOW}Press [F] in main menu${RESET}"
echo -e "${DIM}  MSF Integration:${RESET}       ${YELLOW}Press [M] in main menu${RESET}"
echo -e "${DIM}  Direct MSF Launch:${RESET}     ${GREEN}./nullsecurity/msf-launch.sh${RESET}"
echo -e "${DIM}  Quick Module Launcher:${RESET} ${GREEN}./nullsecurity/simulate.sh${RESET}"
echo ""

echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${CYAN}▓${WHITE}  MAIN MENU SHORTCUTS                                                ${CYAN}▓${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${YELLOW}  [N]${RESET} Next Page          ${YELLOW}[P]${RESET} Previous Page      ${YELLOW}[A]${RESET} Run ALL Modules"
echo -e "${YELLOW}  [R]${RESET} Random Module      ${YELLOW}[C]${RESET} Category Filter    ${YELLOW}[S]${RESET} Search Modules"
echo -e "${YELLOW}  [E]${RESET} External Terminal  ${YELLOW}[M]${RESET} MSF Integration    ${YELLOW}[F]${RESET} Framework Console"
echo -e "${YELLOW}  [X]${RESET} Credits            ${GREEN}[Q]${RESET} Quit               ${DIM}[1-62]${RESET} Run Module by ID"
echo ""

echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${CYAN}▓${WHITE}  FRAMEWORK CONSOLE COMMANDS                                         ${CYAN}▓${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${GREEN}  use <id>${RESET}              Select module by ID number"
echo -e "${GREEN}  show modules${RESET}          List all available attack modules"
echo -e "${GREEN}  show options${RESET}          Display current module configuration"
echo -e "${GREEN}  set <option> <value>${RESET}  Configure module parameters"
echo -e "${GREEN}  run${RESET} / ${GREEN}exploit${RESET}         Execute the selected module"
echo -e "${GREEN}  back${RESET}                  Deselect current module"
echo -e "${GREEN}  search <term>${RESET}         Search for specific modules"
echo -e "${GREEN}  info${RESET}                  Show detailed module information"
echo -e "${GREEN}  msfconsole${RESET}            Launch Metasploit Framework"
echo -e "${GREEN}  clear${RESET}                 Clear the screen"
echo -e "${GREEN}  help${RESET}                  Display help information"
echo -e "${GREEN}  exit${RESET}                  Exit framework console"
echo ""

echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${CYAN}▓${WHITE}  MSF INTEGRATION MENU                                               ${CYAN}▓${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${RED}  [1]${RESET} Launch Metasploit Console (msfconsole)"
echo -e "${RED}  [2]${RESET} MSFVenom Payload Generator"
echo -e "${RED}  [3]${RESET} MSF Database Management"
echo -e "${RED}  [4]${RESET} Search MSF Exploits"
echo -e "${RED}  [5]${RESET} Search MSF Auxiliary Modules"
echo -e "${RED}  [6]${RESET} Generate Reverse Shell"
echo -e "${RED}  [7]${RESET} Generate Bind Shell"
echo -e "${RED}  [8]${RESET} Generate Web Payload (PHP/JSP/ASP)"
echo -e "${RED}  [9]${RESET} Multi Handler Setup"
echo -e "${RED}  [10]${RESET} Resource Script Generator"
echo ""

echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${CYAN}▓${WHITE}  MODULE CATEGORIES (62 TOTAL)                                       ${CYAN}▓${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${DIM}  Network (5):${RESET}       Intrusion, Port Scanner, MITM, DNS Poison, VLAN Hop"
echo -e "${DIM}  Wireless (5):${RESET}      WiFi Deauth, Bluetooth, RFID Clone, RF Jammer, Zigbee"
echo -e "${DIM}  Web (6):${RESET}           SQLi, XSS, WebShell, Dir Brute, API Exploit, Session Hijack"
echo -e "${DIM}  Malware (7):${RESET}       Ransomware, RAT, Rootkit, Keylogger, Worm, Fileless, Cryptominer"
echo -e "${DIM}  Social (5):${RESET}        Phishing, Vishing, Smishing, Watering Hole, Pretexting"
echo -e "${DIM}  Advanced (6):${RESET}      APT, Zero-Day, Supply Chain, Firmware, AI Poison, Satellite"
echo -e "${DIM}  Credentials (5):${RESET}   Password Crack, Cred Stuff, Kerberoast, Pass-the-Hash, Golden Ticket"
echo -e "${DIM}  Infrastructure (5):${RESET} C2 Server, Proxy Chain, VPN Tunnel, Tor Service, Fast Flux"
echo -e "${DIM}  Physical (5):${RESET}      Bypass, BadUSB, Camera Hijack, Alarm Bypass, ATM Jackpot"
echo -e "${DIM}  OPSEC (5):${RESET}         Dark Web Ops, Crypto Launder, Identity Forge, Evidence Destroy, Stego"
echo -e "${DIM}  DDoS (4):${RESET}          DDoS Attack, Slowloris, DNS Amplification, Memcached"
echo -e "${DIM}  ICS/SCADA (4):${RESET}     SCADA Exploit, PLC Attack, Power Grid, Water System"
echo ""

echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${CYAN}▓${WHITE}  QUICK EXAMPLES                                                     ${CYAN}▓${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${YELLOW}Example 1: Run port scanner${RESET}"
echo -e "${DIM}  ./nullsec → Select [2] → Enter target IP → Choose TEST MODE${RESET}"
echo ""
echo -e "${YELLOW}Example 2: Generate MSF payload${RESET}"
echo -e "${DIM}  ./nullsec → Press [M] → Select [6] → Enter LHOST/LPORT${RESET}"
echo ""
echo -e "${YELLOW}Example 3: Framework console${RESET}"
echo -e "${DIM}  ./nullsec → Press [F] → use 35 → show options → run${RESET}"
echo ""
echo -e "${YELLOW}Example 4: Direct module execution${RESET}"
echo -e "${DIM}  cd nullsecurity && ./wifi-deauth.sh${RESET}"
echo ""

echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${CYAN}▓${WHITE}  COMMON MSF COMMANDS                                                ${CYAN}▓${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${GREEN}  msfconsole${RESET}                    Launch Metasploit"
echo -e "${GREEN}  msfvenom -l payloads${RESET}         List available payloads"
echo -e "${GREEN}  msfdb init${RESET}                   Initialize MSF database"
echo -e "${GREEN}  workspace nullsec${RESET}            Switch to NULLSEC workspace"
echo -e "${GREEN}  use exploit/multi/handler${RESET}    Set up multi handler"
echo -e "${GREEN}  search <keyword>${RESET}             Search for modules"
echo -e "${GREEN}  db_nmap <target>${RESET}             Run nmap and store in database"
echo ""

echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${CYAN}▓${WHITE}  TEST MODE vs LIVE MODE                                             ${CYAN}▓${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${YELLOW}  TEST MODE${RESET} (Default - Safe)"
echo -e "${DIM}    • Visual simulation only${RESET}"
echo -e "${DIM}    • No actual exploitation${RESET}"
echo -e "${DIM}    • Uses live user inputs${RESET}"
echo -e "${DIM}    • Perfect for demos/training${RESET}"
echo ""
echo -e "${RED}  LIVE MODE${RESET} (Requires Authorization)"
echo -e "${DIM}    • Executes live attacks${RESET}"
echo -e "${DIM}    • Runs actual security tools${RESET}"
echo -e "${DIM}    • Requires installed dependencies${RESET}"
echo -e "${DIM}    • For authorized testing only${RESET}"
echo ""

echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${CYAN}▓${WHITE}  USEFUL FILES                                                       ${CYAN}▓${RESET}"
echo -e "${CYAN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${RESET}"
echo -e "${DIM}  README.md${RESET}                    Quick start guide"
echo -e "${DIM}  FRAMEWORK.md${RESET}                 Complete documentation"
echo -e "${DIM}  nullsecurity/*.sh${RESET}            62 attack modules"
echo -e "${DIM}  nullsecurity/msf-launch.sh${RESET}   MSF integration launcher"
echo -e "${DIM}  nullsecurity/msf-integration.rc${RESET} MSF resource script"
echo -e "${DIM}  logs/${RESET}                        Operation logs directory"
echo ""

echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}                         bad-antics development${RESET}"
echo -e "${CYAN}                     github.com/bad-antics/nullsec${RESET}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
