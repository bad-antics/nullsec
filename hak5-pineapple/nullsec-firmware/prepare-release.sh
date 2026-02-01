#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Firmware Release Preparation Script
# Prepares a clean release package for public distribution
#
# This script:
# - Removes all personal information
# - Packages firmware and updater
# - Creates release archives
# - Generates checksums
#═══════════════════════════════════════════════════════════════════════════════

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$SCRIPT_DIR/release"
DATE_TAG=$(date +%Y%m%d)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
    echo -e "${RED}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║         NULLSEC FIRMWARE - RELEASE PREPARATION                ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log() {
    echo -e "${GREEN}[*]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Clean previous release
clean_release() {
    log "Cleaning previous release..."
    rm -rf "$RELEASE_DIR"
    mkdir -p "$RELEASE_DIR"
}

# Scrub personal information
scrub_files() {
    log "Scrubbing personal information from files..."
    
    local target_dir=$1
    
    # Patterns to scrub
    local patterns=(
        # WiFi passwords and SSIDs
        's/PINEAPPLE_PASS="[^"]*"/PINEAPPLE_PASS="YOUR_PASSWORD"/g'
        's/HOME_CONN="[^"]*"/HOME_CONN="YOUR_HOME_WIFI"/g'
        's/password="[^"]*"/password="YOUR_PASSWORD"/g'
        's/SSID="[^"]*"/SSID="YOUR_SSID"/g'
        's/psk=[^ ]*/psk=YOUR_PSK/g'
        's/key_mgmt=[^ ]*/key_mgmt=wpa-psk/g'
        
        # Home directories
        's|/home/[a-zA-Z0-9_-]*/|/home/user/|g'
        's|~[a-zA-Z0-9_-]*/|~/|g'
        
        # SSH credentials
        's/root@[0-9.]*:[0-9]*/root@DEVICE_IP/g'
        's/sshpass -p "[^"]*"/sshpass -p "YOUR_PASSWORD"/g'
        's/sshpass -p '\''[^'\'']*'\''/sshpass -p '\''YOUR_PASSWORD'\''/g'
        
        # Webhooks and API keys
        's|https://discord.com/api/webhooks/[^"'\'' ]*|https://discord.com/api/webhooks/YOUR_WEBHOOK|g'
        's|https://api.telegram.org/bot[^"'\'' ]*|https://api.telegram.org/botYOUR_TOKEN|g'
        's/DISCORD_WEBHOOK="[^"]*"/DISCORD_WEBHOOK=""/g'
        's/TELEGRAM_BOT_TOKEN="[^"]*"/TELEGRAM_BOT_TOKEN=""/g'
        's/TELEGRAM_CHAT_ID="[^"]*"/TELEGRAM_CHAT_ID=""/g'
        
        # IP addresses (replace private IPs)
        's/192\.168\.[0-9]*\.[0-9]*/192.168.X.X/g'
        's/10\.[0-9]*\.[0-9]*\.[0-9]*/10.X.X.X/g'
        
        # Email addresses
        's/[a-zA-Z0-9._%+-]*@[a-zA-Z0-9.-]*\.[a-zA-Z]*/user@example.com/g'
        
        # MAC addresses in configs (not in code examples)
        # s/([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/XX:XX:XX:XX:XX:XX/g
    )
    
    # Apply to shell scripts and configs
    find "$target_dir" -type f \( -name "*.sh" -o -name "*.conf" -o -name "*.py" -o -name "*.json" \) | while read -r file; do
        for pattern in "${patterns[@]}"; do
            sed -i "$pattern" "$file" 2>/dev/null
        done
    done
    
    # Remove sensitive files
    find "$target_dir" -type f \( \
        -name "id_rsa*" -o \
        -name "*.pem" -o \
        -name "*.key" -o \
        -name ".env" -o \
        -name "secrets*" -o \
        -name "*password*" -o \
        -name "*credential*" \
    \) -delete 2>/dev/null
    
    # Remove git history
    find "$target_dir" -type d -name ".git" -exec rm -rf {} + 2>/dev/null
    rm -f "$target_dir/.gitignore" 2>/dev/null
    
    # Remove temp files
    find "$target_dir" -type f \( -name "*.swp" -o -name "*.tmp" -o -name "*~" -o -name "*.log" \) -delete 2>/dev/null
    
    log "Personal information scrubbed"
}

# Copy and prepare firmware package
prepare_firmware() {
    log "Preparing firmware package..."
    
    local fw_dir="$RELEASE_DIR/nullsec-pager-firmware-v${VERSION}"
    mkdir -p "$fw_dir"
    
    # Copy firmware files
    cp -r "$SCRIPT_DIR/payloads" "$fw_dir/"
    cp -r "$SCRIPT_DIR/themes" "$fw_dir/" 2>/dev/null || mkdir -p "$fw_dir/themes"
    cp -r "$SCRIPT_DIR/docs" "$fw_dir/"
    
    # Copy installer and tools
    cp "$SCRIPT_DIR/build-firmware.sh" "$fw_dir/"
    
    # Copy documentation
    cp "$SCRIPT_DIR/README.md" "$fw_dir/"
    cp "$SCRIPT_DIR/LICENSE" "$fw_dir/"
    cp "$SCRIPT_DIR/CONTRIBUTING.md" "$fw_dir/"
    
    # Create VERSION file
    cat > "$fw_dir/VERSION" << EOF
NullSec Pager Firmware
Version: ${VERSION}
Release Date: $(date +%Y-%m-%d)

Compatible Devices:
- Hak5 WiFi Pineapple Pager

Credits:
- Built for Hak5 devices (https://hak5.org)
- NullSec Team
EOF

    # Scrub the firmware directory
    scrub_files "$fw_dir"
    
    # Make scripts executable
    find "$fw_dir" -name "*.sh" -exec chmod +x {} \;
    
    # Build the firmware package
    cd "$fw_dir"
    bash build-firmware.sh
    
    # Move the built package to release
    mv dist/*.tar.gz "$RELEASE_DIR/" 2>/dev/null
    mv dist/*.sha256 "$RELEASE_DIR/" 2>/dev/null
    
    log "Firmware package prepared"
}

# Prepare desktop updater
prepare_updater() {
    log "Preparing desktop updater..."
    
    local updater_dir="$RELEASE_DIR/nullsec-updater"
    mkdir -p "$updater_dir"
    
    # Copy updater files
    cp "$SCRIPT_DIR/updater/nullsec-updater.py" "$updater_dir/"
    cp "$SCRIPT_DIR/updater/nullsec-updater.desktop" "$updater_dir/"
    
    # Create requirements file
    cat > "$updater_dir/requirements.txt" << EOF
PyQt5>=5.15.0
EOF

    # Create launcher scripts
    cat > "$updater_dir/run-linux.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
python3 nullsec-updater.py "$@"
EOF
    chmod +x "$updater_dir/run-linux.sh"
    
    cat > "$updater_dir/run-windows.bat" << 'EOF'
@echo off
cd /d "%~dp0"
python nullsec-updater.py %*
pause
EOF

    # Create README for updater
    cat > "$updater_dir/README.md" << EOF
# NullSec Firmware Updater

Desktop application for installing NullSec firmware on Hak5 WiFi Pineapple Pager.

## Requirements

- Python 3.8+
- PyQt5 or tkinter
- sshpass

## Installation

### Linux
\`\`\`bash
pip install PyQt5
sudo apt install sshpass
./run-linux.sh
\`\`\`

### Windows
\`\`\`
pip install PyQt5
run-windows.bat
\`\`\`

### macOS
\`\`\`bash
pip install PyQt5
brew install hudochenkov/sshpass/sshpass
./run-linux.sh
\`\`\`

## Usage

1. Connect to your Pineapple Pager's WiFi network
2. Launch the updater
3. Enter device password
4. Select firmware package
5. Click "Install"

## Credits

Built for Hak5 WiFi Pineapple - https://hak5.org
EOF

    # Scrub updater files
    scrub_files "$updater_dir"
    
    # Create archive
    cd "$RELEASE_DIR"
    tar -czvf "nullsec-updater-v${VERSION}.tar.gz" nullsec-updater
    sha256sum "nullsec-updater-v${VERSION}.tar.gz" > "nullsec-updater-v${VERSION}.sha256"
    
    log "Updater package prepared"
}

# Create release notes
create_release_notes() {
    log "Creating release notes..."
    
    cat > "$RELEASE_DIR/RELEASE_NOTES.md" << EOF
# NullSec Firmware v${VERSION} Release Notes

**Release Date:** $(date +%Y-%m-%d)

## What's New

### Features
- Custom NullSec theme with red/black aesthetic
- Comprehensive payload suite for security testing
- Desktop firmware updater application
- Quick commands (nullscan, nullstatus)

### Payloads Included

**Attack Payloads:**
- nullsec-autopwn - Full automated attack chain
- nullsec-karma - Evil twin with captive portal
- nullsec-deauth - Mass deauthentication
- nullsec-pmkid - PMKID hash capture
- cred-harvest - Multi-protocol credential capture
- usb-arsenal - BadUSB payload generator

**Reconnaissance:**
- wifi-audit - Comprehensive WiFi security audit
- network-mapper - Network topology discovery
- nullsec-probes - Probe request harvesting

**Utilities:**
- nullsec-sync - Loot backup and exfiltration

### Theme
- Custom NullSec color scheme
- Red LED indicator
- Custom boot animation
- NullSec sound effects

## Installation

See USER_GUIDE.md for detailed installation instructions.

## Compatibility

- Hak5 WiFi Pineapple Pager

## Credits

Built for Hak5 WiFi Pineapple devices - https://hak5.org

WiFi Pineapple® is a registered trademark of Hak5 LLC.

---

**For authorized security testing only.**
EOF

    log "Release notes created"
}

# Generate checksums
generate_checksums() {
    log "Generating checksums..."
    
    cd "$RELEASE_DIR"
    
    # Create combined checksum file
    sha256sum *.tar.gz > "SHA256SUMS.txt" 2>/dev/null
    
    log "Checksums generated"
}

# Create GitHub release structure
create_github_release() {
    log "Creating GitHub release structure..."
    
    local gh_dir="$RELEASE_DIR/github-release"
    mkdir -p "$gh_dir"
    
    # Copy release files
    cp "$RELEASE_DIR"/*.tar.gz "$gh_dir/"
    cp "$RELEASE_DIR"/*.sha256 "$gh_dir/" 2>/dev/null
    cp "$RELEASE_DIR/SHA256SUMS.txt" "$gh_dir/"
    cp "$RELEASE_DIR/RELEASE_NOTES.md" "$gh_dir/"
    
    log "GitHub release files prepared at: $gh_dir"
}

# Main
main() {
    banner
    
    echo "NullSec Firmware Release Preparation"
    echo "Version: $VERSION"
    echo ""
    
    read -p "Proceed with release preparation? (y/N) " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Cancelled."
        exit 0
    fi
    
    echo ""
    
    clean_release
    prepare_firmware
    prepare_updater
    create_release_notes
    generate_checksums
    create_github_release
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}               RELEASE PREPARATION COMPLETE!                   ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Release files are in: $RELEASE_DIR"
    echo ""
    echo "Files created:"
    ls -la "$RELEASE_DIR"/*.tar.gz 2>/dev/null
    echo ""
    echo "GitHub release files: $RELEASE_DIR/github-release/"
    echo ""
    echo -e "${CYAN}Credits: Built for Hak5 WiFi Pineapple - https://hak5.org${NC}"
}

main "$@"
