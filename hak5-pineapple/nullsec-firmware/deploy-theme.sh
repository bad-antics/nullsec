#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Theme Deployment Script
# Deploys complete NullSec theme to WiFi Pineapple Pager
#
# Author: bad-antics // NullSec
# Credits: Built for Hak5 WiFi Pineapple Pager
#═══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_DIR="$SCRIPT_DIR/themes/nullsec"
PAGER_IP="${PAGER_IP:-172.16.52.1}"
PAGER_USER="${PAGER_USER:-root}"
PAGER_PASS="${PAGER_PASS:-}"
REMOTE_THEME_PATH="/mmc/root/themes/nullsec"
BASE_THEME_PATH="/rom/lib/pager/themes/wargames"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
    echo -e "${RED}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║         NULLSEC THEME DEPLOYMENT                              ║
    ║         For WiFi Pineapple Pager                              ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log() { echo -e "${GREEN}[*]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

# Check if we can reach the Pager
check_connection() {
    log "Checking connection to Pager..."
    
    if ! ping -c 1 -W 2 "$PAGER_IP" &>/dev/null; then
        warn "Cannot ping $PAGER_IP"
        warn "Make sure you're connected to the Pager's WiFi AP"
        return 1
    fi
    
    log "Pager is reachable"
    return 0
}

# Get password if not set
get_password() {
    if [ -z "$PAGER_PASS" ]; then
        read -sp "Enter Pager root password: " PAGER_PASS
        echo
    fi
}

# Run command on Pager
pager_cmd() {
    sshpass -p "$PAGER_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        "$PAGER_USER@$PAGER_IP" "$1" 2>/dev/null
}

# Copy file to Pager
pager_copy() {
    local src="$1"
    local dst="$2"
    sshpass -p "$PAGER_PASS" scp -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        -r "$src" "$PAGER_USER@$PAGER_IP:$dst" 2>/dev/null
}

# Step 1: Generate theme assets if needed
generate_assets() {
    log "Generating custom theme assets..."
    
    if [ -f "$THEME_DIR/generate-theme-assets.py" ]; then
        cd "$THEME_DIR"
        python3 generate-theme-assets.py
        cd "$SCRIPT_DIR"
    else
        warn "Asset generator not found, using existing assets"
    fi
}

# Step 2: Copy base theme components from device
copy_base_components() {
    log "Copying base theme components from device..."
    
    # Create local components directory
    mkdir -p "$THEME_DIR/components"
    
    # Copy the entire components folder from wargames theme
    pager_cmd "tar -czf /tmp/base_components.tar.gz -C $BASE_THEME_PATH components" || {
        warn "Failed to create component archive on device"
        return 1
    }
    
    # Download and extract
    sshpass -p "$PAGER_PASS" scp -o StrictHostKeyChecking=no \
        "$PAGER_USER@$PAGER_IP:/tmp/base_components.tar.gz" "/tmp/base_components.tar.gz" || {
        warn "Failed to download components"
        return 1
    }
    
    # Extract to theme directory (preserving our custom files)
    tar -xzf /tmp/base_components.tar.gz -C "$THEME_DIR" --skip-old-files
    
    # Clean up
    rm -f /tmp/base_components.tar.gz
    pager_cmd "rm -f /tmp/base_components.tar.gz"
    
    log "Base components copied"
}

# Step 3: Copy base assets we haven't replaced
copy_base_assets() {
    log "Copying base theme assets from device..."
    
    # Get the base assets
    pager_cmd "tar -czf /tmp/base_assets.tar.gz -C $BASE_THEME_PATH assets" || {
        warn "Failed to create asset archive on device"
        return 1
    }
    
    sshpass -p "$PAGER_PASS" scp -o StrictHostKeyChecking=no \
        "$PAGER_USER@$PAGER_IP:/tmp/base_assets.tar.gz" "/tmp/base_assets.tar.gz" || {
        warn "Failed to download assets"
        return 1
    }
    
    # Extract to theme directory (skip files we've already created)
    tar -xzf /tmp/base_assets.tar.gz -C "$THEME_DIR" --skip-old-files
    
    rm -f /tmp/base_assets.tar.gz
    pager_cmd "rm -f /tmp/base_assets.tar.gz"
    
    log "Base assets copied"
}

# Step 4: Deploy theme to device
deploy_theme() {
    log "Deploying NullSec theme to device..."
    
    # Create theme directory on device
    pager_cmd "mkdir -p $REMOTE_THEME_PATH"
    
    # Create archive of our theme
    cd "$SCRIPT_DIR/themes"
    tar -czf /tmp/nullsec_theme.tar.gz nullsec
    cd "$SCRIPT_DIR"
    
    # Copy to device
    sshpass -p "$PAGER_PASS" scp -o StrictHostKeyChecking=no \
        "/tmp/nullsec_theme.tar.gz" "$PAGER_USER@$PAGER_IP:/tmp/" || {
        error "Failed to upload theme"
    }
    
    # Extract on device
    pager_cmd "cd /mmc/root/themes && rm -rf nullsec && tar -xzf /tmp/nullsec_theme.tar.gz && rm -f /tmp/nullsec_theme.tar.gz"
    
    rm -f /tmp/nullsec_theme.tar.gz
    
    log "Theme deployed to device"
}

# Step 5: Apply theme configuration
apply_theme() {
    log "Applying NullSec theme configuration..."
    
    pager_cmd "uci set system.@pager[0].theme_name='nullsec'"
    pager_cmd "uci set system.@pager[0].theme_path='$REMOTE_THEME_PATH'"
    pager_cmd "uci commit system"
    
    log "Theme configuration applied"
}

# Step 6: Verify theme
verify_theme() {
    log "Verifying theme installation..."
    
    # Check theme.json exists
    if pager_cmd "[ -f $REMOTE_THEME_PATH/theme.json ]"; then
        log "theme.json: OK"
    else
        error "theme.json missing!"
    fi
    
    # Check dashboard
    if pager_cmd "[ -f $REMOTE_THEME_PATH/components/dashboards/nullsec_dashboard.json ]"; then
        log "nullsec_dashboard.json: OK"
    else
        error "Dashboard missing!"
    fi
    
    # Check boot animation
    if pager_cmd "[ -d $REMOTE_THEME_PATH/assets/boot_animation ]"; then
        local count=$(pager_cmd "ls $REMOTE_THEME_PATH/assets/boot_animation/*.png 2>/dev/null | wc -l")
        log "Boot animation frames: $count"
    else
        warn "Boot animation directory missing"
    fi
    
    # Check spinner
    if pager_cmd "[ -d $REMOTE_THEME_PATH/assets/spinner ]"; then
        log "Spinner assets: OK"
    else
        warn "Spinner directory missing"
    fi
    
    log "Theme verification complete"
}

# Restart Pager UI
restart_pager() {
    log "Restarting Pager UI..."
    pager_cmd "service pineapplepager restart" || warn "Could not restart service"
    info "Theme will be fully applied after restart"
}

# Full installation
full_install() {
    banner
    
    check_connection || error "Cannot reach Pager"
    get_password
    
    # Test SSH connection
    if ! pager_cmd "echo OK" | grep -q "OK"; then
        error "Cannot SSH to Pager. Check password."
    fi
    
    echo ""
    log "Starting NullSec theme installation..."
    echo ""
    
    generate_assets
    copy_base_components
    copy_base_assets
    deploy_theme
    apply_theme
    verify_theme
    
    echo ""
    read -p "Restart Pager UI now? (y/N) " restart
    if [ "$restart" = "y" ] || [ "$restart" = "Y" ]; then
        restart_pager
    fi
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           NULLSEC THEME INSTALLATION COMPLETE!                ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Theme installed to: $REMOTE_THEME_PATH"
    echo ""
    echo "To manually restart, SSH to device and run:"
    echo "  service pineapplepager restart"
    echo ""
    echo -e "${CYAN}Credits: Built for Hak5 WiFi Pineapple - https://hak5.org${NC}"
}

# Show usage
usage() {
    echo "NullSec Theme Deployment"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install     Full theme installation (default)"
    echo "  generate    Generate theme assets only"
    echo "  deploy      Deploy theme to device only"
    echo "  apply       Apply theme via UCI config"
    echo "  verify      Verify theme installation"
    echo "  restart     Restart Pager UI"
    echo ""
    echo "Environment variables:"
    echo "  PAGER_IP    Device IP (default: 172.16.52.1)"
    echo "  PAGER_PASS  Root password"
    echo ""
}

# Main
case "${1:-install}" in
    install|full)
        full_install
        ;;
    generate)
        generate_assets
        ;;
    deploy)
        check_connection || error "Cannot reach Pager"
        get_password
        deploy_theme
        ;;
    apply)
        check_connection || error "Cannot reach Pager"
        get_password
        apply_theme
        ;;
    verify)
        check_connection || error "Cannot reach Pager"
        get_password
        verify_theme
        ;;
    restart)
        check_connection || error "Cannot reach Pager"
        get_password
        restart_pager
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac
