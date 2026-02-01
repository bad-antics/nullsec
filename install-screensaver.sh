#!/bin/bash
#
# NullSec Linux - Screensaver Installer v1.1
# Configures the custom NullSec screensaver for the system
# Repository: https://github.com/bad-antics/nullsec
#

RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
RESET='\033[0m'

echo -e "${RED}"
cat << 'BANNER'
 ███▄    █  █    ██  ██▓     ██▓      ██████ ▓█████  ▄████▄
 ██ ▀█   █  ██  ▓██▒▓██▒    ▓██▒    ▒██    ▒ ▓█   ▀ ▒██▀ ▀█
▓██  ▀█ ██▒▓██  ▒██░▒██░    ▒██░    ░ ▓██▄   ▒███   ▒▓█    ▄
▓██▒  ▐▌██▒▓▓█  ░██░▒██░    ▒██░      ▒   ██▒▒▓█  ▄ ▒▓▓▄ ▄██▒
▒██░   ▓██░▒▒█████▓ ░██████▒░██████▒▒██████▒▒░▒████▒▒ ▓███▀ ░
BANNER
echo -e "${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}         NullSec Linux - Custom Screensaver Installer${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo ""

# Check if screensaver file exists
if [ ! -f "$HOME/nullsec/nullsec-screensaver.py" ]; then
    echo -e "${RED}[!] Error: nullsec-screensaver.py not found!${RESET}"
    exit 1
fi

echo -e "${GREEN}[+] Installing NullSec screensaver...${RESET}"

# Make executable
chmod +x "$HOME/nullsec/nullsec-screensaver.py"

# Create desktop entry for screensaver
cat > ~/.local/share/applications/nullsec-screensaver.desktop << 'DESKTOP'
[Desktop Entry]
Name=NullSec Screensaver
Comment=Custom Matrix-style screensaver for NullSec Linux
Exec=/home/antics/nullsec/nullsec-screensaver.py
Icon=preferences-desktop-screensaver
Terminal=false
Type=Application
Categories=Screensaver;
X-NullSec-Package=screensaver
DESKTOP

echo -e "${GREEN}[+] Desktop entry created${RESET}"

# Configure MATE screensaver (if using MATE)
if command -v mate-screensaver-preferences &> /dev/null; then
    echo -e "${GREEN}[+] Configuring MATE screensaver...${RESET}"
    
    # Set screensaver to activate after 10 minutes
    dconf write /org/mate/screensaver/idle-activation-enabled true
    dconf write /org/mate/screensaver/lock-enabled false
    dconf write /org/mate/screensaver/mode "'blank-only'"
    
    echo -e "${GREEN}[+] MATE screensaver configured (blank mode)${RESET}"
fi

# Create systemd service for idle detection
mkdir -p ~/.config/systemd/user/

cat > ~/.config/systemd/user/nullsec-screensaver.service << 'SERVICE'
[Unit]
Description=NullSec Linux Custom Screensaver
After=graphical.target

[Service]
Type=simple
ExecStart=/home/antics/nullsec/nullsec-screensaver.py
Restart=no

[Install]
WantedBy=default.target
SERVICE

echo -e "${GREEN}[+] Systemd service created${RESET}"

# Create idle watcher script
cat > ~/.config/nullsec-idle-watcher.sh << 'WATCHER'
#!/bin/bash
# NullSec Linux - Idle Watcher
# Launches screensaver after 10 minutes of inactivity

IDLE_TIME=600000  # 10 minutes in milliseconds
SCREENSAVER="/home/antics/nullsec/nullsec-screensaver.py"

while true; do
    # Get idle time in milliseconds
    IDLE=$(xprintidle 2>/dev/null || echo 0)
    
    if [ "$IDLE" -gt "$IDLE_TIME" ]; then
        # Check if screensaver is already running
        if ! pgrep -f "nullsec-screensaver.py" > /dev/null; then
            python3 "$SCREENSAVER" &
        fi
    fi
    
    sleep 30
done
WATCHER

chmod +x ~/.config/nullsec-idle-watcher.sh

echo -e "${GREEN}[+] Idle watcher script created${RESET}"

# Create autostart entry
mkdir -p ~/.config/autostart/
cat > ~/.config/autostart/nullsec-screensaver-watcher.desktop << 'AUTOSTART'
[Desktop Entry]
Type=Application
Name=NullSec Screensaver Watcher
Comment=Monitors idle time and launches NullSec screensaver
Exec=/home/antics/.config/nullsec-idle-watcher.sh
Terminal=false
Hidden=false
X-MATE-Autostart-enabled=true
X-NullSec-Package=screensaver
AUTOSTART

echo -e "${GREEN}[+] Autostart entry created${RESET}"

# Install xprintidle if not present
if ! command -v xprintidle &> /dev/null; then
    echo -e "${CYAN}[*] Installing xprintidle for idle detection...${RESET}"
    sudo apt-get update -qq && sudo apt-get install -y xprintidle -qq
    echo -e "${GREEN}[+] xprintidle installed${RESET}"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}✅ NullSec Screensaver Installation Complete!${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo ""
echo "Usage:"
echo "  • Automatic: Will launch after 10 minutes of inactivity"
echo "  • Manual: Run 'python3 ~/nullsec/nullsec-screensaver.py'"
echo "  • Test now: python3 ~/nullsec/nullsec-screensaver.py"
echo ""
echo "Features:"
echo "  ✓ Matrix-style falling characters"
echo "  ✓ NullSec Linux ASCII logo"
echo "  ✓ Animated hex streams"
echo "  ✓ Binary particle effects"
echo "  ✓ Scanning line effect"
echo "  ✓ System status messages"
echo "  ✓ Live clock display"
echo ""
echo "Press any key or move mouse to exit screensaver"
echo ""
echo -e "${CYAN}Starting idle watcher in background...${RESET}"

# Start the watcher in background
nohup ~/.config/nullsec-idle-watcher.sh > /dev/null 2>&1 &

echo -e "${GREEN}[+] Idle watcher started (PID: $!)${RESET}"
echo ""
echo "To test immediately, run:"
echo "  python3 ~/nullsec/nullsec-screensaver.py"
echo ""
