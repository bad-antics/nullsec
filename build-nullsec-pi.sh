#!/bin/bash
#===============================================================================
#  NULLSEC LINUX - RASPBERRY PI 4 IMAGE BUILDER
#===============================================================================
#  Creates a custom NullSec Linux image for Raspberry Pi 4
#  Based on Raspberry Pi OS Lite (arm64) with full pentesting toolkit
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/tmp/nullsec-pi-build"
MOUNT_DIR="/tmp/nullsec-pi-mount"
OUTPUT_DIR="$SCRIPT_DIR/pi-images"
NULLSEC_TOOLS="$SCRIPT_DIR/nullsecurity"

# Raspberry Pi OS Lite 64-bit image URL (Bookworm)
RPI_IMAGE_URL="https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2024-11-19/2024-11-19-raspios-bookworm-arm64-lite.img.xz"
RPI_IMAGE_NAME="raspios-bookworm-arm64-lite.img"
NULLSEC_IMAGE="nullsec-pi4-$(date +%Y%m%d).img"

banner() {
    echo -e "${RED}"
    cat << 'EOF'
    ╔══════════════════════════════════════════════════════════════════╗
    ║  ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗     ║
    ║  ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝     ║
    ║  ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║          ║
    ║  ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║          ║
    ║  ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗     ║
    ║  ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝     ║
    ║                                                                   ║
    ║           RASPBERRY PI 4 - PENTESTING PLATFORM                   ║
    ╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[*]${NC} $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (sudo)"
    fi
}

check_dependencies() {
    log "Checking dependencies..."
    local deps=(wget xz parted losetup mkfs.ext4 rsync qemu-arm-static chroot)
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Missing dependencies: ${missing[*]}"
        log "Installing dependencies..."
        apt-get update
        apt-get install -y wget xz-utils parted dosfstools e2fsprogs rsync qemu-user-static binfmt-support
    fi
    
    # Enable ARM emulation
    if [[ -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]]; then
        log "ARM64 emulation already enabled"
    else
        log "Enabling ARM64 emulation..."
        update-binfmts --enable qemu-aarch64 2>/dev/null || true
    fi
}

setup_directories() {
    log "Setting up build directories..."
    mkdir -p "$BUILD_DIR" "$MOUNT_DIR" "$OUTPUT_DIR"
    mkdir -p "$MOUNT_DIR/boot" "$MOUNT_DIR/root"
}

download_base_image() {
    log "Downloading Raspberry Pi OS base image..."
    
    if [[ -f "$BUILD_DIR/$RPI_IMAGE_NAME" ]]; then
        info "Base image already exists, skipping download"
        return
    fi
    
    cd "$BUILD_DIR"
    
    if [[ -f "${RPI_IMAGE_NAME}.xz" ]]; then
        info "Compressed image exists, decompressing..."
    else
        wget -c "$RPI_IMAGE_URL" -O "${RPI_IMAGE_NAME}.xz"
    fi
    
    log "Decompressing image..."
    xz -dk "${RPI_IMAGE_NAME}.xz" 2>/dev/null || true
    
    log "Base image ready: $BUILD_DIR/$RPI_IMAGE_NAME"
}

prepare_image() {
    log "Preparing NullSec image..."
    
    cp "$BUILD_DIR/$RPI_IMAGE_NAME" "$BUILD_DIR/$NULLSEC_IMAGE"
    
    # Expand image to 8GB for tools
    log "Expanding image to 8GB..."
    truncate -s 8G "$BUILD_DIR/$NULLSEC_IMAGE"
    
    # Setup loop device
    LOOP_DEV=$(losetup -fP --show "$BUILD_DIR/$NULLSEC_IMAGE")
    log "Loop device: $LOOP_DEV"
    
    # Resize partition
    log "Resizing root partition..."
    parted -s "$LOOP_DEV" resizepart 2 100%
    
    # Check and resize filesystem
    e2fsck -f "${LOOP_DEV}p2" || true
    resize2fs "${LOOP_DEV}p2"
    
    # Mount partitions
    log "Mounting partitions..."
    mount "${LOOP_DEV}p2" "$MOUNT_DIR/root"
    mount "${LOOP_DEV}p1" "$MOUNT_DIR/boot"
    
    log "Image mounted and ready for customization"
}

install_nullsec_branding() {
    log "Installing NullSec branding..."
    
    local ROOT="$MOUNT_DIR/root"
    
    # OS Release
    cat > "$ROOT/etc/os-release" << 'EOF'
PRETTY_NAME="NullSec Linux Pi 1.0 (void)"
NAME="NullSec Linux Pi"
VERSION_ID="1.0"
VERSION="1.0 (void)"
VERSION_CODENAME=void
ID=nullsec
ID_LIKE=debian
HOME_URL="https://github.com/bad-antics"
SUPPORT_URL="https://github.com/bad-antics/nullsec"
BUG_REPORT_URL="https://github.com/bad-antics/nullsec/issues"
EOF

    # Issue banner
    cat > "$ROOT/etc/issue" << 'EOF'

[0;31m    ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗[0m
[0;31m    ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝[0m
[0;31m    ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║     [0m
[0;31m    ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║     [0m
[0;31m    ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗[0m
[0;31m    ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝[0m

[1;33m              NULLSEC LINUX Pi - PENETRATION TESTING[0m
[0;36m                   Raspberry Pi 4 Edition[0m

EOF

    # MOTD
    cat > "$ROOT/etc/motd" << 'EOF'

 ╔═══════════════════════════════════════════════════════════════╗
 ║              NULLSEC LINUX Pi - ARMED & READY                ║
 ╠═══════════════════════════════════════════════════════════════╣
 ║  Type 'nullsec-menu' for the security toolkit                ║
 ║  Type 'nullsec-help' for quick reference                     ║
 ║  Type 'nullsec-ai' for AI-powered security assistant         ║
 ╚═══════════════════════════════════════════════════════════════╝

EOF

    log "Branding installed"
}

install_pentesting_tools() {
    log "Installing pentesting tools (this takes a while)..."
    
    local ROOT="$MOUNT_DIR/root"
    
    # Copy qemu for chroot
    cp /usr/bin/qemu-aarch64-static "$ROOT/usr/bin/" 2>/dev/null || \
    cp /usr/bin/qemu-arm-static "$ROOT/usr/bin/" 2>/dev/null || true
    
    # Prepare chroot script
    cat > "$ROOT/tmp/install-tools.sh" << 'CHROOT_SCRIPT'
#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

echo "[+] Updating package lists..."
apt-get update

echo "[+] Installing core pentesting tools..."
apt-get install -y --no-install-recommends \
    git curl wget vim nano htop tmux screen \
    net-tools wireless-tools iw aircrack-ng \
    nmap masscan netcat-openbsd socat \
    tcpdump wireshark-common tshark \
    hydra john hashcat \
    sqlmap nikto dirb gobuster \
    metasploit-framework 2>/dev/null || true \
    exploitdb searchsploit 2>/dev/null || true \
    python3 python3-pip python3-venv \
    ruby perl golang \
    build-essential libssl-dev libffi-dev \
    bluetooth bluez bluez-tools btscanner \
    hostapd dnsmasq iptables \
    macchanger proxychains4 tor \
    binwalk foremost steghide \
    ffuf feroxbuster \
    seclists wordlists 2>/dev/null || true

echo "[+] Installing Python security tools..."
pip3 install --break-system-packages \
    requests beautifulsoup4 lxml \
    scapy impacket \
    pwntools 2>/dev/null || true \
    paramiko fabric \
    shodan censys \
    crackmapexec 2>/dev/null || true

echo "[+] Installing additional tools from git..."
cd /opt

# Responder
git clone https://github.com/lgandx/Responder.git 2>/dev/null || true

# Evil-WinRM
git clone https://github.com/Hackplayers/evil-winrm.git 2>/dev/null || true

# LinPEAS/WinPEAS
git clone https://github.com/carlospolop/PEASS-ng.git 2>/dev/null || true

# Chisel
wget -q https://github.com/jpillora/chisel/releases/latest/download/chisel_linux_arm64.gz -O /tmp/chisel.gz 2>/dev/null || true
gunzip -f /tmp/chisel.gz 2>/dev/null && mv /tmp/chisel /usr/local/bin/ && chmod +x /usr/local/bin/chisel || true

echo "[+] Configuring services..."
systemctl disable bluetooth 2>/dev/null || true
systemctl enable ssh

echo "[+] Tool installation complete!"
CHROOT_SCRIPT

    chmod +x "$ROOT/tmp/install-tools.sh"
    
    # Mount required filesystems for chroot
    mount --bind /dev "$ROOT/dev"
    mount --bind /dev/pts "$ROOT/dev/pts"
    mount --bind /proc "$ROOT/proc"
    mount --bind /sys "$ROOT/sys"
    
    # Run installation in chroot
    log "Running tool installation in chroot..."
    chroot "$ROOT" /tmp/install-tools.sh || warn "Some tools may have failed to install"
    
    # Cleanup chroot mounts
    umount "$ROOT/sys" 2>/dev/null || true
    umount "$ROOT/proc" 2>/dev/null || true
    umount "$ROOT/dev/pts" 2>/dev/null || true
    umount "$ROOT/dev" 2>/dev/null || true
    
    rm -f "$ROOT/tmp/install-tools.sh"
    rm -f "$ROOT/usr/bin/qemu-"*"-static"
}

install_nullsec_modules() {
    log "Installing NullSec security modules..."
    
    local ROOT="$MOUNT_DIR/root"
    
    # Create NullSec directory structure
    mkdir -p "$ROOT/opt/nullsec"
    mkdir -p "$ROOT/opt/nullsec/modules"
    mkdir -p "$ROOT/opt/nullsec/logs"
    mkdir -p "$ROOT/opt/nullsec/resources"
    mkdir -p "$ROOT/usr/local/bin"
    
    # Copy all security modules
    if [[ -d "$NULLSEC_TOOLS" ]]; then
        log "Copying $(ls "$NULLSEC_TOOLS"/*.sh 2>/dev/null | wc -l) security modules..."
        cp -r "$NULLSEC_TOOLS"/* "$ROOT/opt/nullsec/modules/" 2>/dev/null || true
        chmod +x "$ROOT/opt/nullsec/modules/"*.sh 2>/dev/null || true
    fi
    
    # Copy main scripts
    cp "$SCRIPT_DIR/module-framework.py" "$ROOT/opt/nullsec/" 2>/dev/null || true
    cp "$SCRIPT_DIR/nullsec-ai.py" "$ROOT/opt/nullsec/" 2>/dev/null || true
    cp "$SCRIPT_DIR/nullsec-ai-v2.py" "$ROOT/opt/nullsec/" 2>/dev/null || true
    cp "$SCRIPT_DIR/netmgr.py" "$ROOT/opt/nullsec/" 2>/dev/null || true
    cp "$SCRIPT_DIR/flipper.sh" "$ROOT/opt/nullsec/" 2>/dev/null || true
    cp "$SCRIPT_DIR/pager.sh" "$ROOT/opt/nullsec/" 2>/dev/null || true
    
    # Copy resources
    cp -r "$SCRIPT_DIR/resources" "$ROOT/opt/nullsec/" 2>/dev/null || true
    cp -r "$SCRIPT_DIR/utils" "$ROOT/opt/nullsec/" 2>/dev/null || true
    
    # Create launcher scripts
    cat > "$ROOT/usr/local/bin/nullsec-menu" << 'EOF'
#!/bin/bash
cd /opt/nullsec
python3 module-framework.py
EOF
    chmod +x "$ROOT/usr/local/bin/nullsec-menu"
    
    cat > "$ROOT/usr/local/bin/nullsec-ai" << 'EOF'
#!/bin/bash
cd /opt/nullsec
python3 nullsec-ai-v2.py "$@"
EOF
    chmod +x "$ROOT/usr/local/bin/nullsec-ai"
    
    cat > "$ROOT/usr/local/bin/nullsec-help" << 'EOF'
#!/bin/bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              NULLSEC LINUX Pi - QUICK REFERENCE              ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  COMMANDS:                                                    ║"
echo "║    nullsec-menu    - Launch module framework                 ║"
echo "║    nullsec-ai      - AI security assistant                   ║"
echo "║    nullsec-help    - This help message                       ║"
echo "║                                                               ║"
echo "║  MODULES: /opt/nullsec/modules/                              ║"
echo "║    wifi-attack.sh      - Wireless attacks                    ║"
echo "║    bluetooth-attack.sh - Bluetooth attacks                   ║"
echo "║    network-scanner.sh  - Network enumeration                 ║"
echo "║    mitm-attack.sh      - Man-in-the-middle                   ║"
echo "║    password-crack.sh   - Password cracking                   ║"
echo "║    ...and 180+ more modules                                  ║"
echo "║                                                               ║"
echo "║  TOOLS:                                                       ║"
echo "║    nmap, masscan, aircrack-ng, hashcat, hydra                ║"
echo "║    sqlmap, nikto, gobuster, responder, impacket              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
EOF
    chmod +x "$ROOT/usr/local/bin/nullsec-help"
    
    log "NullSec modules installed"
}

configure_wifi_and_bluetooth() {
    log "Configuring WiFi and Bluetooth for pentesting..."
    
    local ROOT="$MOUNT_DIR/root"
    
    # WiFi configuration for monitor mode
    cat > "$ROOT/etc/modprobe.d/wifi-inject.conf" << 'EOF'
# Enable monitor mode and injection
options cfg80211 ieee80211_regdom=US
options brcmfmac feature_disable=0x82000
EOF

    # Bluetooth HCI configuration
    cat > "$ROOT/etc/bluetooth/main.conf" << 'EOF'
[General]
DiscoverableTimeout = 0
AlwaysPairable = true
Class = 0x000100
FastConnectable = true

[Policy]
AutoEnable=true
EOF

    # Network manager to not interfere
    mkdir -p "$ROOT/etc/NetworkManager/conf.d"
    cat > "$ROOT/etc/NetworkManager/conf.d/unmanaged.conf" << 'EOF'
[keyfile]
unmanaged-devices=interface-name:wlan*mon;interface-name:eth*
EOF

    log "WiFi/Bluetooth configured for pentesting"
}

configure_boot() {
    log "Configuring boot settings..."
    
    local BOOT="$MOUNT_DIR/boot"
    
    # Enable SSH on boot
    touch "$BOOT/ssh"
    
    # Enable USB OTG gadget mode (for BadUSB attacks)
    if ! grep -q "dtoverlay=dwc2" "$BOOT/config.txt"; then
        echo "" >> "$BOOT/config.txt"
        echo "# NullSec USB Gadget Mode" >> "$BOOT/config.txt"
        echo "dtoverlay=dwc2" >> "$BOOT/config.txt"
    fi
    
    # Add modules-load for USB gadget
    if ! grep -q "modules-load=dwc2" "$BOOT/cmdline.txt"; then
        sed -i 's/rootwait/rootwait modules-load=dwc2,g_ether/' "$BOOT/cmdline.txt"
    fi
    
    # Enable hardware watchdog
    if ! grep -q "dtparam=watchdog=on" "$BOOT/config.txt"; then
        echo "dtparam=watchdog=on" >> "$BOOT/config.txt"
    fi
    
    # GPU memory (minimal for headless)
    if ! grep -q "gpu_mem=" "$BOOT/config.txt"; then
        echo "gpu_mem=16" >> "$BOOT/config.txt"
    fi
    
    # Enable UART for serial console
    if ! grep -q "enable_uart=1" "$BOOT/config.txt"; then
        echo "enable_uart=1" >> "$BOOT/config.txt"
    fi
    
    log "Boot configuration complete"
}

configure_user() {
    log "Configuring default user..."
    
    local ROOT="$MOUNT_DIR/root"
    local BOOT="$MOUNT_DIR/boot"
    
    # Create userconf for first boot (user: nullsec, password: nullsec)
    # Password hash for 'nullsec'
    PASS_HASH=$(echo 'nullsec' | openssl passwd -6 -stdin)
    echo "nullsec:${PASS_HASH}" > "$BOOT/userconf.txt"
    
    # Add bashrc customization
    cat >> "$ROOT/etc/skel/.bashrc" << 'EOF'

# NullSec customization
export PS1='\[\033[0;31m\]┌──[\[\033[1;33m\]\u@nullsec-pi\[\033[0;31m\]]-[\[\033[0;36m\]\w\[\033[0;31m\]]\n└──╼ \[\033[0m\]$ '

alias ll='ls -la'
alias ns='cd /opt/nullsec && python3 module-framework.py'
alias modules='ls -la /opt/nullsec/modules/'

# Display help on login
if [ -n "$PS1" ]; then
    nullsec-help 2>/dev/null || true
fi
EOF

    log "User configuration complete"
    info "Default credentials: nullsec / nullsec"
}

finalize_image() {
    log "Finalizing image..."
    
    # Sync filesystems
    sync
    
    # Unmount partitions
    log "Unmounting partitions..."
    umount "$MOUNT_DIR/boot" 2>/dev/null || true
    umount "$MOUNT_DIR/root" 2>/dev/null || true
    
    # Detach loop device
    losetup -d "$LOOP_DEV" 2>/dev/null || true
    
    # Move to output directory
    mv "$BUILD_DIR/$NULLSEC_IMAGE" "$OUTPUT_DIR/"
    
    # Compress image
    log "Compressing image..."
    cd "$OUTPUT_DIR"
    xz -9 -k "$NULLSEC_IMAGE" || gzip -k "$NULLSEC_IMAGE" || true
    
    log "Image created: $OUTPUT_DIR/$NULLSEC_IMAGE"
    
    # Calculate checksum
    sha256sum "$OUTPUT_DIR/$NULLSEC_IMAGE" > "$OUTPUT_DIR/${NULLSEC_IMAGE}.sha256"
}

cleanup() {
    log "Cleaning up..."
    umount "$MOUNT_DIR/boot" 2>/dev/null || true
    umount "$MOUNT_DIR/root" 2>/dev/null || true
    umount "$MOUNT_DIR/root/dev/pts" 2>/dev/null || true
    umount "$MOUNT_DIR/root/dev" 2>/dev/null || true
    umount "$MOUNT_DIR/root/proc" 2>/dev/null || true
    umount "$MOUNT_DIR/root/sys" 2>/dev/null || true
    losetup -D 2>/dev/null || true
}

flash_to_device() {
    local DEVICE="$1"
    local IMAGE="$OUTPUT_DIR/$NULLSEC_IMAGE"
    
    if [[ ! -b "$DEVICE" ]]; then
        error "Device $DEVICE not found"
    fi
    
    if [[ ! -f "$IMAGE" ]]; then
        error "Image not found: $IMAGE"
    fi
    
    warn "This will ERASE all data on $DEVICE"
    read -p "Are you sure? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        error "Aborted"
    fi
    
    log "Flashing to $DEVICE..."
    dd if="$IMAGE" of="$DEVICE" bs=4M status=progress conv=fsync
    sync
    
    log "Flash complete! You can now boot your Pi with NullSec Linux"
}

show_usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  build          Build the NullSec Pi image"
    echo "  flash DEVICE   Flash image to device (e.g., /dev/sdb)"
    echo "  list           List connected USB devices"
    echo ""
    echo "Examples:"
    echo "  sudo $0 build"
    echo "  sudo $0 flash /dev/sdb"
}

list_devices() {
    log "Connected storage devices:"
    echo ""
    lsblk -o NAME,SIZE,TYPE,MODEL,TRAN | grep -E "disk|NAME"
    echo ""
    info "SD cards typically appear as /dev/sdb, /dev/sdc, etc."
    info "Look for devices with TRAN=usb"
}

# Trap for cleanup
trap cleanup EXIT

# Main
banner

case "${1:-build}" in
    build)
        check_root
        check_dependencies
        setup_directories
        download_base_image
        prepare_image
        install_nullsec_branding
        install_pentesting_tools
        install_nullsec_modules
        configure_wifi_and_bluetooth
        configure_boot
        configure_user
        finalize_image
        
        echo ""
        log "╔═══════════════════════════════════════════════════════════════╗"
        log "║              BUILD COMPLETE!                                  ║"
        log "╠═══════════════════════════════════════════════════════════════╣"
        log "║  Image: $OUTPUT_DIR/$NULLSEC_IMAGE"
        log "║                                                               ║"
        log "║  Flash with: sudo $0 flash /dev/sdX                          ║"
        log "║  Or use: sudo dd if=IMAGE of=/dev/sdX bs=4M status=progress  ║"
        log "║                                                               ║"
        log "║  Default login: nullsec / nullsec                            ║"
        log "║  SSH enabled by default                                       ║"
        log "╚═══════════════════════════════════════════════════════════════╝"
        ;;
    flash)
        check_root
        if [[ -z "$2" ]]; then
            error "Please specify device: $0 flash /dev/sdX"
        fi
        flash_to_device "$2"
        ;;
    list)
        list_devices
        ;;
    *)
        show_usage
        ;;
esac
