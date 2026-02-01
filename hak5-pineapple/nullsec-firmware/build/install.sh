#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Firmware Installer for WiFi Pineapple Pager
# 
# This installer is designed for Hak5 WiFi Pineapple Pager devices
# Credits: Built for Hak5 devices - https://hak5.org
#═══════════════════════════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="/mmc/nullsec"
PAYLOAD_DIR="/root/payloads/nullsec"
THEME_DIR="/mmc/root/themes/nullsec"

echo -e "${RED}"
cat << 'BANNER'
    ╔═══════════════════════════════════════════════════════════╗
    ║         NULLSEC FIRMWARE INSTALLER v1.0                   ║
    ║                                                           ║
    ║         Built for Hak5 WiFi Pineapple Pager              ║
    ╚═══════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}[*]${NC} Detecting device..."

# Check if we're on a Pineapple Pager
if [ ! -f /pineapple/pineapple ]; then
    echo -e "${RED}[!]${NC} This doesn't appear to be a WiFi Pineapple Pager"
    echo "    This installer is designed for Hak5 Pineapple Pager devices"
    exit 1
fi

echo -e "${GREEN}[*]${NC} WiFi Pineapple Pager detected!"
echo ""

# Check for SD card
if [ ! -d /mmc ]; then
    echo -e "${RED}[!]${NC} SD card not found at /mmc"
    echo "    Please insert an SD card and try again"
    exit 1
fi

echo -e "${GREEN}[*]${NC} Installing NullSec firmware components..."

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$PAYLOAD_DIR"
mkdir -p "$THEME_DIR"
mkdir -p /mmc/nullsec/{handshakes,pmkid,creds,probes,backups,logs}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install payloads
if [ -d "$SCRIPT_DIR/payloads" ]; then
    echo -e "${GREEN}[*]${NC} Installing payloads..."
    cp -r "$SCRIPT_DIR/payloads"/* "$PAYLOAD_DIR/"
    chmod +x "$PAYLOAD_DIR"/**/*.sh 2>/dev/null || true
fi

# Install theme
if [ -d "$SCRIPT_DIR/themes/nullsec" ]; then
    echo -e "${GREEN}[*]${NC} Installing NullSec theme..."
    cp -r "$SCRIPT_DIR/themes/nullsec"/* "$THEME_DIR/"
fi

# Install tools
if [ -d "$SCRIPT_DIR/tools" ]; then
    echo -e "${GREEN}[*]${NC} Installing tools..."
    cp -r "$SCRIPT_DIR/tools"/* /usr/bin/ 2>/dev/null || true
    chmod +x /usr/bin/nullsec-* 2>/dev/null || true
fi

# Set up quick commands
echo -e "${GREEN}[*]${NC} Setting up quick commands..."

cat > /usr/bin/nullscan << 'NULLSCAN'
#!/bin/sh
echo "=== NullSec Quick Scan ==="
iw dev wlan1mon scan 2>/dev/null | grep -E "SSID|signal|BSS" | head -30
NULLSCAN
chmod +x /usr/bin/nullscan

cat > /usr/bin/nullstatus << 'NULLSTATUS'
#!/bin/sh
echo "=== NullSec Pager Status ==="
echo "Hostname: $(cat /etc/hostname)"
echo "Uptime: $(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"
echo "Memory: $(free | awk '/Mem:/ {printf "%.1f%%", $3/$2 * 100}')"
echo "Storage: $(df -h /mmc | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
echo "Battery: $(cat /sys/class/power_supply/*/capacity 2>/dev/null || echo "N/A")%"
NULLSTATUS
chmod +x /usr/bin/nullstatus

# Configure system
echo -e "${GREEN}[*]${NC} Configuring system..."

# Set hostname
echo "nullsec-pager" > /etc/hostname

# Set custom banner
cat > /etc/banner << 'BANNER'

    ╔═══════════════════════════════════════════════════════════════╗
    ║     ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗║
    ║     ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝║
    ║     ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║     ║
    ║     ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║     ║
    ║     ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗║
    ║     ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝║
    ╠═══════════════════════════════════════════════════════════════╣
    ║           WiFi Pineapple Pager - NullSec Edition              ║
    ║                  Built for Hak5 Hardware                      ║
    ╚═══════════════════════════════════════════════════════════════╝

BANNER

# Set theme
uci set system.@pager[0].theme='nullsec' 2>/dev/null
uci set system.@pager[0].theme_name='nullsec' 2>/dev/null
uci set system.@pager[0].theme_path='/root/themes/nullsec' 2>/dev/null
uci set system.@pager[0].led_color='red' 2>/dev/null
uci commit system 2>/dev/null

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           NULLSEC FIRMWARE INSTALLATION COMPLETE!             ║${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  • Payloads installed to: /root/payloads/nullsec/             ║${NC}"
echo -e "${GREEN}║  • Theme installed to: /mmc/root/themes/nullsec/              ║${NC}"
echo -e "${GREEN}║  • Loot directory: /mmc/nullsec/                              ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║  Quick Commands: nullscan, nullstatus                         ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║  Please reboot to apply theme changes.                        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Credits: Built for Hak5 WiFi Pineapple - https://hak5.org${NC}"
