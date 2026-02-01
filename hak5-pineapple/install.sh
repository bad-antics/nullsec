#!/bin/sh
#
# NullSec Pineapple Suite - Installation Script
# https://github.com/bad-antics/nullsec-pineapple-suite
#
# Automated installer for WiFi Pineapple Pager
# Installs payloads, dependencies, and configures the device
#

VERSION="2.0"
REPO_URL="https://github.com/bad-antics/nullsec-pineapple-suite"

# Colors (if terminal supports)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_banner() {
    echo ""
    echo "███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗"
    echo "████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝"
    echo "██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║     "
    echo "██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║     "
    echo "██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗"
    echo "╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝"
    echo "         PINEAPPLE SUITE INSTALLER v${VERSION}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

log_info() {
    echo "[*] $1"
}

log_success() {
    echo "[+] $1"
}

log_error() {
    echo "[!] $1"
}

log_warn() {
    echo "[~] $1"
}

# Check if running on Pineapple
check_device() {
    log_info "Checking device..."
    
    if [ -f /etc/openwrt_release ]; then
        DEVICE=$(grep "DISTRIB_ID" /etc/openwrt_release | cut -d"'" -f2)
        if echo "$DEVICE" | grep -qi "pineapple"; then
            log_success "Detected: $DEVICE"
            return 0
        fi
    fi
    
    log_warn "This doesn't appear to be a WiFi Pineapple"
    echo -n "Continue anyway? [y/N]: "
    read CONTINUE
    [ "$CONTINUE" = "y" ] || [ "$CONTINUE" = "Y" ] && return 0
    return 1
}

# Create directory structure
setup_directories() {
    log_info "Setting up directories..."
    
    mkdir -p /root/payloads/user/nullsec
    mkdir -p /mmc/nullsec/loot
    mkdir -p /mmc/nullsec/logs
    mkdir -p /mmc/packages
    mkdir -p /root/nullsec/logs
    
    log_success "Directories created"
}

# Download packages from OpenWrt repos
download_packages() {
    log_info "Downloading dependency packages..."
    
    PKG_URL="https://downloads.openwrt.org/releases/24.10.1/packages/mipsel_24kc/packages"
    BASE_URL="https://downloads.openwrt.org/releases/24.10.1/packages/mipsel_24kc/base"
    
    cd /mmc/packages
    
    # Core packages
    PACKAGES="
        aircrack-ng_1.7-r1_mipsel_24kc.ipk
        airmon-ng_1.7-r1_mipsel_24kc.ipk
        hcxdumptool_6.3.4-r1_mipsel_24kc.ipk
        php8_8.3.29-r1_mipsel_24kc.ipk
        php8-cli_8.3.29-r1_mipsel_24kc.ipk
        libpython3-3.11_3.11.14-r1_mipsel_24kc.ipk
        python3-base_3.11.14-r1_mipsel_24kc.ipk
        python3-light_3.11.14-r1_mipsel_24kc.ipk
        zoneinfo-core_2025c-r1_mipsel_24kc.ipk
        procps-ng_4.0.4-r1_mipsel_24kc.ipk
    "
    
    BASE_PACKAGES="
        wireless-tools_29-r6_mipsel_24kc.ipk
        ethtool_6.11-r1_mipsel_24kc.ipk
        libxml2-16_2.14.5-r2_mipsel_24kc.ipk
        libnl-core200_3.10.0-r1_mipsel_24kc.ipk
        libnl-genl200_3.10.0-r1_mipsel_24kc.ipk
        libpcre2_10.42-r1_mipsel_24kc.ipk
    "
    
    DOWNLOAD_COUNT=0
    TOTAL_PACKAGES=$(echo "$PACKAGES $BASE_PACKAGES" | wc -w)
    
    for pkg in $PACKAGES; do
        if [ ! -f "$pkg" ]; then
            wget -q "$PKG_URL/$pkg" 2>/dev/null && DOWNLOAD_COUNT=$((DOWNLOAD_COUNT + 1))
        fi
    done
    
    for pkg in $BASE_PACKAGES; do
        if [ ! -f "$pkg" ]; then
            wget -q "$BASE_URL/$pkg" 2>/dev/null && DOWNLOAD_COUNT=$((DOWNLOAD_COUNT + 1))
        fi
    done
    
    log_success "Downloaded $DOWNLOAD_COUNT packages"
}

# Install packages
install_packages() {
    log_info "Installing packages..."
    
    cd /mmc/packages
    
    # Install in dependency order
    INSTALL_ORDER="
        libpcre2*.ipk
        libnl-core200*.ipk
        libnl-genl200*.ipk
        libxml2*.ipk
        wireless-tools*.ipk
        ethtool*.ipk
        procps-ng*.ipk
        aircrack-ng*.ipk
        airmon-ng*.ipk
        hcxdumptool*.ipk
        zoneinfo-core*.ipk
        php8_*.ipk
        php8-cli*.ipk
        libpython3*.ipk
        python3-base*.ipk
        python3-light*.ipk
    "
    
    for pattern in $INSTALL_ORDER; do
        for pkg in $pattern; do
            [ -f "$pkg" ] && opkg install "./$pkg" 2>/dev/null | tail -1
        done
    done
    
    # Create php symlink if needed
    [ -f /usr/bin/php8-cli ] && [ ! -f /usr/bin/php ] && ln -sf /usr/bin/php8-cli /usr/bin/php
    
    log_success "Packages installed"
}

# Install payloads
install_payloads() {
    log_info "Installing payloads..."
    
    SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
    PAYLOAD_DIR="$SCRIPT_DIR/nullsec-suite"
    
    if [ ! -d "$PAYLOAD_DIR" ]; then
        log_error "Payload directory not found: $PAYLOAD_DIR"
        log_info "Make sure nullsec-suite/ folder is in the same directory as install.sh"
        return 1
    fi
    
    # Copy payloads
    cp -r "$PAYLOAD_DIR"/* /root/payloads/user/nullsec/
    
    # Set permissions
    chmod +x /root/payloads/user/nullsec/*/payload.sh 2>/dev/null
    
    PAYLOAD_COUNT=$(ls -d /root/payloads/user/nullsec/*/ 2>/dev/null | wc -l)
    log_success "Installed $PAYLOAD_COUNT payloads"
}

# Configure system
configure_system() {
    log_info "Configuring system..."
    
    # Create profile script for banner
    cat > /etc/profile.d/nullsec.sh << 'PROFEOF'
#!/bin/sh
# NullSec Pineapple Banner
echo ""
echo " ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗"
echo " ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝"
echo " ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║     "
echo " ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║     "
echo " ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗"
echo " ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝"
echo "                    PAGER - WiFi Assault Platform"
echo " ───────────────────────────────────────────────────────────"
echo "  Payloads: /root/payloads/nullsec/"
echo "  Loot:     /mmc/nullsec/"
echo "  Logs:     /root/nullsec/logs/"
echo " ───────────────────────────────────────────────────────────"

# Aliases
alias payloads='cd /root/payloads/user/nullsec && ls -la'
alias loot='cd /mmc/nullsec && ls -la'
alias monitor='airmon-ng start wlan0'
alias scan='airodump-ng wlan0mon'
PROFEOF
    chmod +x /etc/profile.d/nullsec.sh
    
    log_success "System configured"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  INSTALLATION VERIFICATION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Check tools
    echo "=== Tools ==="
    for tool in iwconfig airodump-ng aireplay-ng airmon-ng aircrack-ng hcxdumptool python3 php; do
        if which $tool >/dev/null 2>&1; then
            echo "  ✓ $tool"
        else
            echo "  ✗ $tool (missing)"
        fi
    done
    
    echo ""
    echo "=== Payloads ==="
    PAYLOAD_COUNT=$(ls -d /root/payloads/user/nullsec/*/ 2>/dev/null | wc -l)
    
    # Verify syntax
    VALID_COUNT=0
    for payload in /root/payloads/user/nullsec/*/payload.sh; do
        [ -f "$payload" ] && sh -n "$payload" 2>/dev/null && VALID_COUNT=$((VALID_COUNT + 1))
    done
    
    echo "  Total: $PAYLOAD_COUNT"
    echo "  Valid: $VALID_COUNT"
    
    echo ""
    echo "=== Directories ==="
    [ -d /mmc/nullsec ] && echo "  ✓ /mmc/nullsec" || echo "  ✗ /mmc/nullsec"
    [ -d /root/payloads/user/nullsec ] && echo "  ✓ /root/payloads/user/nullsec" || echo "  ✗ /root/payloads/user/nullsec"
    
    echo ""
}

# Main menu
show_menu() {
    echo ""
    echo "Installation Options:"
    echo "━━━━━━━━━━━━━━━━━━━━━"
    echo "1) Full installation (recommended)"
    echo "2) Install payloads only"
    echo "3) Install dependencies only"
    echo "4) Download packages only (for offline install)"
    echo "5) Verify installation"
    echo "6) Uninstall"
    echo "0) Exit"
    echo ""
    echo -n "Choice [1]: "
    read CHOICE
    CHOICE=${CHOICE:-1}
}

# Full installation
full_install() {
    print_banner
    check_device || return 1
    
    echo ""
    log_info "Starting full installation..."
    echo ""
    
    setup_directories
    
    # Check if we have internet
    if ping -c 1 downloads.openwrt.org >/dev/null 2>&1; then
        download_packages
    else
        log_warn "No internet - using local packages if available"
    fi
    
    install_packages
    install_payloads
    configure_system
    verify_installation
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  INSTALLATION COMPLETE!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Reboot your Pineapple or run: source /etc/profile.d/nullsec.sh"
    echo ""
    echo "Payloads: /root/payloads/user/nullsec/"
    echo "Loot:     /mmc/nullsec/"
    echo ""
    echo "GitHub:   $REPO_URL"
    echo ""
}

# Uninstall
uninstall() {
    log_warn "This will remove all NullSec payloads and configurations"
    echo -n "Are you sure? [y/N]: "
    read CONFIRM
    [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ] || return 1
    
    log_info "Removing NullSec suite..."
    rm -rf /root/payloads/user/nullsec
    rm -f /etc/profile.d/nullsec.sh
    
    echo -n "Remove loot and logs? [y/N]: "
    read REMOVE_LOOT
    [ "$REMOVE_LOOT" = "y" ] || [ "$REMOVE_LOOT" = "Y" ] && rm -rf /mmc/nullsec
    
    log_success "Uninstall complete"
}

# Main
main() {
    # Check if running as root
    [ "$(id -u)" != "0" ] && { log_error "Must run as root!"; exit 1; }
    
    # Parse command line args
    case "$1" in
        --full|-f)
            full_install
            exit 0
            ;;
        --payloads|-p)
            setup_directories
            install_payloads
            exit 0
            ;;
        --deps|-d)
            setup_directories
            download_packages
            install_packages
            exit 0
            ;;
        --verify|-v)
            verify_installation
            exit 0
            ;;
        --uninstall|-u)
            uninstall
            exit 0
            ;;
        --help|-h)
            echo "NullSec Pineapple Suite Installer"
            echo ""
            echo "Usage: $0 [OPTION]"
            echo ""
            echo "Options:"
            echo "  --full, -f      Full installation (default)"
            echo "  --payloads, -p  Install payloads only"
            echo "  --deps, -d      Install dependencies only"
            echo "  --verify, -v    Verify installation"
            echo "  --uninstall, -u Remove NullSec suite"
            echo "  --help, -h      Show this help"
            echo ""
            exit 0
            ;;
    esac
    
    # Interactive mode
    print_banner
    
    while true; do
        show_menu
        
        case "$CHOICE" in
            1) full_install ;;
            2) setup_directories; install_payloads; verify_installation ;;
            3) setup_directories; download_packages; install_packages; verify_installation ;;
            4) setup_directories; download_packages ;;
            5) verify_installation ;;
            6) uninstall ;;
            0) echo "Goodbye!"; exit 0 ;;
            *) log_error "Invalid choice" ;;
        esac
    done
}

main "$@"
