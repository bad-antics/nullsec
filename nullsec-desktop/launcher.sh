#!/bin/bash
# NULLSEC Desktop Launcher
# Launch the Armitage-style attack framework GUI
# Requires root privileges for full functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
RESET='\033[0m'

# Check if running as root (may have been called from main nullsec script)
if [[ $EUID -ne 0 ]] && [[ -z "$NULLSEC_ROOT" ]]; then
    clear
    echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
    echo -e "${RED}█${RESET}     ${WHITE}NULLSEC Desktop - Root Access Required${RESET}"
    echo -e "${RED}█${RESET}              ${CYAN}[ bad-antics development ]${RESET}"
    echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
    echo ""
    echo -e "${CYAN}[*]${RESET} Requesting root privileges..."
    echo ""
    
    # For GUI apps, use pkexec or sudo with display forwarding
    if command -v pkexec &> /dev/null; then
        exec pkexec env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" HOME="$HOME" "$0" "$@"
    else
        exec sudo -E "$0" "$@"
    fi
    exit $?
fi

clear
echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
echo -e "${RED}█${RESET}        ${WHITE}NULLSEC DESKTOP - Attack Framework GUI${RESET}"
echo -e "${RED}█${RESET}              ${CYAN}[ bad-antics development ]${RESET}"
echo -e "${RED}█${RESET}              ${GREEN}[  Running as ROOT  ]${RESET}"
echo -e "${RED}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
echo ""

# Check dependencies
echo -e "${CYAN}[*]${RESET} Checking dependencies..."

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}[!]${RESET} Python 3 is required. Install with: apt install python3"
    exit 1
fi

# Check GTK
python3 -c "import gi; gi.require_version('Gtk', '3.0')" 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}[!]${RESET} PyGObject (GTK3) is required."
    echo -e "${CYAN}[*]${RESET} Installing: apt install python3-gi python3-gi-cairo gir1.2-gtk-3.0"
    apt install -y python3-gi python3-gi-cairo gir1.2-gtk-3.0
fi

echo -e "${GREEN}[+]${RESET} Dependencies OK"
echo -e "${GREEN}[+]${RESET} Running with root privileges"
echo ""
echo -e "${CYAN}[*]${RESET} Launching NULLSEC Desktop..."
echo ""

# Launch the application
python3 "$SCRIPT_DIR/nullsec_desktop.py" "$@"
