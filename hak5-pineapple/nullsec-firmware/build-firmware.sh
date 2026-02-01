#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Firmware Builder for WiFi Pineapple Pager
# Packages all NullSec enhancements into a distributable firmware package
#
# Credits: Built for Hak5 WiFi Pineapple devices - https://hak5.org
#═══════════════════════════════════════════════════════════════════════════════

VERSION="1.0.0"
BUILD_DATE=$(date +%Y%m%d)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
DIST_DIR="$SCRIPT_DIR/dist"
PACKAGE_NAME="nullsec-pager-firmware-v${VERSION}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
    echo -e "${RED}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                                                                    ║
    ║     ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗   ║
    ║     ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝   ║
    ║     ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║        ║
    ║     ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║        ║
    ║     ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗   ║
    ║     ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝   ║
    ║                                                                    ║
    ║              FIRMWARE BUILDER FOR PINEAPPLE PAGER                  ║
    ║                    Built for Hak5 Devices                          ║
    ╚═══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${CYAN}Version: ${VERSION} | Build Date: ${BUILD_DATE}${NC}"
    echo ""
}

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check dependencies
check_deps() {
    log_info "Checking dependencies..."
    local deps=(tar gzip sha256sum find)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            log_error "Missing dependency: $dep"
            exit 1
        fi
    done
    log_info "All dependencies satisfied"
}

# Clean previous builds
clean_build() {
    log_info "Cleaning previous builds..."
    rm -rf "$BUILD_DIR" "$DIST_DIR"
    mkdir -p "$BUILD_DIR" "$DIST_DIR"
}

# Scrub personal information from files
scrub_personal_info() {
    log_info "Scrubbing personal information..."
    
    local scrub_patterns=(
        # WiFi credentials
        's/PINEAPPLE_PASS="[^"]*"/PINEAPPLE_PASS="YOUR_PASSWORD"/g'
        's/HOME_CONN="[^"]*"/HOME_CONN="YOUR_HOME_WIFI"/g'
        's/password "[^"]*"/password "YOUR_PASSWORD"/g'
        's/psk=[^ ]*/psk=YOUR_PSK/g'
        
        # SSH keys and credentials
        's|/home/[a-zA-Z0-9_-]*/|/home/USER/|g'
        's/root@[0-9.]*:[0-9]*/root@DEVICE_IP/g'
        
        # Personal SSIDs (common patterns)
        's/SSID="[^"]*"/SSID="YOUR_SSID"/g'
        
        # Discord/Telegram webhooks
        's|https://discord.com/api/webhooks/[^"]*|https://discord.com/api/webhooks/YOUR_WEBHOOK|g'
        's|https://api.telegram.org/bot[^"]*|https://api.telegram.org/botYOUR_BOT_TOKEN|g'
        
        # IP addresses (private ranges kept generic)
        's/192\.168\.[0-9]*\.[0-9]*/192.168.X.X/g'
        's/10\.[0-9]*\.[0-9]*\.[0-9]*/10.X.X.X/g'
    )
    
    # Apply scrubbing to all shell scripts and config files
    find "$BUILD_DIR" -type f \( -name "*.sh" -o -name "*.conf" -o -name "*.json" \) | while read -r file; do
        for pattern in "${scrub_patterns[@]}"; do
            sed -i "$pattern" "$file" 2>/dev/null
        done
    done
    
    # Remove any .git directories
    find "$BUILD_DIR" -type d -name ".git" -exec rm -rf {} + 2>/dev/null
    
    # Remove any SSH keys
    find "$BUILD_DIR" -type f -name "id_rsa*" -delete 2>/dev/null
    find "$BUILD_DIR" -type f -name "*.pem" -delete 2>/dev/null
    
    log_info "Personal information scrubbed"
}

# Copy payloads
copy_payloads() {
    log_info "Copying payloads..."
    
    local payload_src="$SCRIPT_DIR/../payloads/nullsec"
    local payload_dst="$BUILD_DIR/payloads"
    
    mkdir -p "$payload_dst"
    
    if [ -d "$payload_src" ]; then
        cp -r "$payload_src"/* "$payload_dst/"
        log_info "Copied payloads from $payload_src"
    else
        log_warn "Payload source not found, creating defaults..."
        mkdir -p "$payload_dst"/{attacks,recon,utils,community}
    fi
}

# Copy themes
copy_themes() {
    log_info "Copying themes..."
    
    local theme_src="$SCRIPT_DIR/../themes/nullsec"
    local theme_dst="$BUILD_DIR/themes/nullsec"
    
    mkdir -p "$theme_dst"
    
    if [ -d "$theme_src" ]; then
        cp -r "$theme_src"/* "$theme_dst/"
    fi
    
    # Also copy the theme installer
    if [ -f "$SCRIPT_DIR/../themes/install-nullsec-theme.sh" ]; then
        cp "$SCRIPT_DIR/../themes/install-nullsec-theme.sh" "$BUILD_DIR/themes/"
    fi
    
    log_info "Themes copied"
}

# Create installer script
create_installer() {
    log_info "Creating installer script..."
    
    cat > "$BUILD_DIR/install.sh" << 'INSTALLER'
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
INSTALLER

    chmod +x "$BUILD_DIR/install.sh"
    log_info "Installer created"
}

# Create uninstaller
create_uninstaller() {
    log_info "Creating uninstaller..."
    
    cat > "$BUILD_DIR/uninstall.sh" << 'UNINSTALLER'
#!/bin/bash
# NullSec Firmware Uninstaller

echo "=== NullSec Firmware Uninstaller ==="
echo ""
read -p "This will remove all NullSec components. Continue? (y/N) " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

echo "[*] Removing payloads..."
rm -rf /root/payloads/nullsec

echo "[*] Removing theme..."
rm -rf /mmc/root/themes/nullsec

echo "[*] Removing quick commands..."
rm -f /usr/bin/nullscan /usr/bin/nullstatus /usr/bin/nulloot

echo "[*] Restoring default theme..."
uci set system.@pager[0].theme='wargames' 2>/dev/null
uci set system.@pager[0].theme_path='/root/themes/wargames' 2>/dev/null
uci commit system 2>/dev/null

echo ""
echo "[+] NullSec firmware removed. Reboot to complete."
UNINSTALLER

    chmod +x "$BUILD_DIR/uninstall.sh"
}

# Create config template
create_config() {
    log_info "Creating configuration template..."
    
    mkdir -p "$BUILD_DIR/config"
    
    cat > "$BUILD_DIR/config/nullsec.conf" << 'CONFIG'
# NullSec Firmware Configuration
# Edit these values before installation

# Discord webhook for loot exfiltration (optional)
DISCORD_WEBHOOK=""

# Telegram bot token and chat ID (optional)
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# SSH server for loot backup (optional)
BACKUP_SSH_HOST=""
BACKUP_SSH_USER=""
BACKUP_SSH_PATH="/backup/pager"

# Default attack settings
DEFAULT_DEAUTH_COUNT=50
DEFAULT_HANDSHAKE_TIMEOUT=120
KARMA_PORTAL_ENABLED=true

# Theme settings
THEME_NAME="nullsec"
LED_COLOR="red"
CONFIG

    log_info "Configuration template created"
}

# Create version info
create_version_info() {
    log_info "Creating version info..."
    
    cat > "$BUILD_DIR/VERSION" << EOF
NullSec Pager Firmware
Version: ${VERSION}
Build Date: ${BUILD_DATE}
Build Host: $(hostname)

Compatible Devices:
- Hak5 WiFi Pineapple Pager

Credits:
- Built for Hak5 devices (https://hak5.org)
- NullSec Team

Checksum: [GENERATED_AT_PACKAGE]
EOF
}

# Package everything
create_package() {
    log_info "Creating distribution package..."
    
    # Create the tarball
    cd "$BUILD_DIR"
    tar -czvf "$DIST_DIR/${PACKAGE_NAME}.tar.gz" .
    
    # Create checksum
    cd "$DIST_DIR"
    sha256sum "${PACKAGE_NAME}.tar.gz" > "${PACKAGE_NAME}.sha256"
    
    # Update VERSION with checksum
    local checksum=$(cat "${PACKAGE_NAME}.sha256" | awk '{print $1}')
    sed -i "s/\[GENERATED_AT_PACKAGE\]/${checksum}/" "$BUILD_DIR/VERSION"
    
    # Recreate with updated VERSION
    cd "$BUILD_DIR"
    tar -czvf "$DIST_DIR/${PACKAGE_NAME}.tar.gz" .
    
    cd "$DIST_DIR"
    sha256sum "${PACKAGE_NAME}.tar.gz" > "${PACKAGE_NAME}.sha256"
    
    log_info "Package created: $DIST_DIR/${PACKAGE_NAME}.tar.gz"
}

# Main build process
main() {
    banner
    
    check_deps
    clean_build
    copy_payloads
    copy_themes
    create_installer
    create_uninstaller
    create_config
    create_version_info
    scrub_personal_info
    create_package
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    BUILD COMPLETE!                            ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Output files:"
    echo "  $DIST_DIR/${PACKAGE_NAME}.tar.gz"
    echo "  $DIST_DIR/${PACKAGE_NAME}.sha256"
    echo ""
    echo -e "${CYAN}Credits: Built for Hak5 WiFi Pineapple - https://hak5.org${NC}"
}

main "$@"
