#!/bin/bash
# NullSec Screensaver Fleet Deployer
# Deploys NullSec matrix screensaver to all cluster nodes
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

deploy_linux() {
    local host=$1 user=$2 name=$3 use_sudo=$4
    echo -e "${YELLOW}[DEPLOY]${NC} $name ($host) — Linux"
    
    # Copy files
    scp -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        "$SCRIPT_DIR/nullsec-screensaver.py" "$user@$host:/tmp/" 2>/dev/null || { echo -e "${RED}[FAIL]${NC} SCP failed to $name"; return 1; }
    
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$user@$host" bash << REMOTE
mkdir -p ~/bin ~/.config/autostart
cp /tmp/nullsec-screensaver.py ~/bin/
chmod +x ~/bin/nullsec-screensaver.py

# Try xss-lock first
if which xss-lock > /dev/null 2>&1; then
    cat > ~/bin/nullsec-screensaver << 'W'
#!/bin/bash
exec python3 ~/bin/nullsec-screensaver.py
W
    chmod +x ~/bin/nullsec-screensaver
    cat > ~/.config/autostart/nullsec-screensaver.desktop << 'D'
[Desktop Entry]
Type=Application
Name=NullSec Screensaver
Exec=sh -c "xset s 600 600; xset s noblank; xset -dpms; xss-lock -l -- \$HOME/bin/nullsec-screensaver &"
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
D
    pkill -f "xss-lock.*nullsec" 2>/dev/null; sleep 1
    DISPLAY=:0 XAUTHORITY=~/.Xauthority xset s 600 600 2>/dev/null
    DISPLAY=:0 XAUTHORITY=~/.Xauthority xset s noblank 2>/dev/null
    DISPLAY=:0 XAUTHORITY=~/.Xauthority xset -dpms 2>/dev/null
    DISPLAY=:0 XAUTHORITY=~/.Xauthority nohup xss-lock -l -- ~/bin/nullsec-screensaver > /dev/null 2>&1 &
else
    # Fallback: Python idle watcher
    cat > ~/bin/nullsec-idle-watch.py << 'P'
#!/usr/bin/env python3
import subprocess, time, os, signal, sys, ctypes, ctypes.util
IDLE_TIMEOUT = 600; SCREENSAVER = os.path.expanduser("~/bin/nullsec-screensaver.py"); ss_proc = None
def get_idle_ms():
    try:
        xlib = ctypes.cdll.LoadLibrary(ctypes.util.find_library("X11"))
        xss = ctypes.cdll.LoadLibrary(ctypes.util.find_library("Xss"))
        display = xlib.XOpenDisplay(None)
        if not display: return 0
        class I(ctypes.Structure):
            _fields_ = [('window',ctypes.c_ulong),('state',ctypes.c_int),('kind',ctypes.c_int),('til',ctypes.c_ulong),('idle',ctypes.c_ulong),('mask',ctypes.c_ulong)]
        xss.XScreenSaverAllocInfo.restype = ctypes.POINTER(I)
        info = xss.XScreenSaverAllocInfo()
        xss.XScreenSaverQueryInfo(display, xlib.XDefaultRootWindow(display), info)
        idle = info.contents.idle; xlib.XCloseDisplay(display); return idle
    except: return 0
def cleanup(*a):
    if ss_proc and ss_proc.poll() is None: ss_proc.terminate()
    sys.exit(0)
signal.signal(signal.SIGTERM, cleanup); signal.signal(signal.SIGINT, cleanup)
while True:
    idle_s = get_idle_ms() / 1000.0
    if idle_s >= IDLE_TIMEOUT and (ss_proc is None or ss_proc.poll() is not None):
        ss_proc = subprocess.Popen([sys.executable, SCREENSAVER], env={**os.environ, 'DISPLAY': ':0'})
    if idle_s < 5 and ss_proc and ss_proc.poll() is None:
        ss_proc.terminate()
        try: ss_proc.wait(timeout=3)
        except: ss_proc.kill()
        ss_proc = None
    time.sleep(2)
P
    chmod +x ~/bin/nullsec-idle-watch.py
    cat > ~/.config/autostart/nullsec-screensaver.desktop << 'D'
[Desktop Entry]
Type=Application
Name=NullSec Screensaver
Exec=python3 /home/antics/bin/nullsec-idle-watch.py
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
D
    pkill -f nullsec-idle-watch 2>/dev/null; sleep 1
    DISPLAY=:0 XAUTHORITY=~/.Xauthority nohup python3 ~/bin/nullsec-idle-watch.py > /dev/null 2>&1 &
fi
sleep 1
(pgrep -af "xss-lock.*nullsec" || pgrep -af nullsec-idle) && echo "RUNNING" || echo "FAILED"
REMOTE
}

deploy_windows() {
    local host=$1 user=$2 name=$3
    echo -e "${YELLOW}[DEPLOY]${NC} $name ($host) — Windows"
    
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes "$user@$host" "mkdir C:\\Users\\$user\\NullSec 2>nul & echo ok" 2>/dev/null || { echo -e "${RED}[FAIL]${NC} SSH failed to $name"; return 1; }
    
    scp -o StrictHostKeyChecking=no -o BatchMode=yes \
        "$SCRIPT_DIR/NullSec-Screensaver.ps1" "$SCRIPT_DIR/NullSec-IdleWatch.ps1" "$SCRIPT_DIR/NullSec-Screensaver-Start.vbs" \
        "$user@$host:C:/Users/$user/NullSec/" 2>/dev/null || { echo -e "${RED}[FAIL]${NC} SCP failed"; return 1; }
    
    ssh -o StrictHostKeyChecking=no -o BatchMode=yes "$user@$host" \
        "schtasks /create /tn NullSecScreensaver /tr \"powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\\Users\\$user\\NullSec\\NullSec-IdleWatch.ps1\" /sc onlogon /ru $user /f" 2>/dev/null
    
    ssh -o StrictHostKeyChecking=no -o BatchMode=yes "$user@$host" \
        "powershell -ExecutionPolicy Bypass -Command \"Start-Process powershell -ArgumentList '-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\\Users\\$user\\NullSec\\NullSec-IdleWatch.ps1' -WindowStyle Hidden\"" 2>/dev/null
    
    echo -e "${GREEN}[OK]${NC} $name deployed"
}

echo "╔══════════════════════════════════════╗"
echo "║  NullSec Screensaver Fleet Deploy    ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Linux nodes
deploy_linux "192.168.40.209" "root" "r420" "yes"
deploy_linux "192.168.40.129" "antics" "nullsec" "no"
deploy_linux "192.168.40.214" "antics" "parrot" "no"
deploy_linux "192.168.40.43" "antics" "nullkia" "no"

# Windows nodes  
deploy_windows "192.168.40.22" "antics" "doomsday"

echo ""
echo "═══════════════════════════════════════"
echo "For machines requiring password SSH:"
echo "  thinkcentre (.55): Run from that machine:"
echo "    powershell -ExecutionPolicy Bypass -File \\\\server\\NullSec-IdleWatch.ps1"
echo "  fairy (.163): Run from that machine:"
echo "    schtasks /create /tn NullSecScreensaver /tr ... /sc onlogon /f"
echo "  DESKTOP-F3K7OP9 (.65): Deploy via WinRM"
echo "═══════════════════════════════════════"
