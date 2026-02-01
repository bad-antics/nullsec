#!/bin/sh
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Theme Installer
# Installs the NullSec theme to WiFi Pineapple Pager
#═══════════════════════════════════════════════════════════════════════════════

THEME_DIR="/mmc/root/themes/nullsec"
THEME_SRC="$(dirname "$0")"

echo "═══════════════════════════════════════════════════════════"
echo "           NULLSEC THEME INSTALLER                         "
echo "═══════════════════════════════════════════════════════════"

# Create theme directory
echo "[*] Creating theme directory..."
mkdir -p "$THEME_DIR/components/boot"
mkdir -p "$THEME_DIR/components/dashboards"
mkdir -p "$THEME_DIR/components/apps"
mkdir -p "$THEME_DIR/sounds"

# Copy theme files
echo "[*] Installing theme files..."
cp "$THEME_SRC/theme.json" "$THEME_DIR/"
cp "$THEME_SRC/components/boot/nullsec_boot.json" "$THEME_DIR/components/boot/"
cp "$THEME_SRC/components/dashboards/nullsec_dashboard.json" "$THEME_DIR/components/dashboards/"
cp "$THEME_SRC/components/apps/nullsec_apps.json" "$THEME_DIR/components/apps/"

# Create placeholder sound files if they don't exist
echo "[*] Setting up sounds..."
touch "$THEME_DIR/sounds/startup.wav"
touch "$THEME_DIR/sounds/alert.wav"
touch "$THEME_DIR/sounds/success.wav"
touch "$THEME_DIR/sounds/error.wav"

# Set permissions
echo "[*] Setting permissions..."
chmod -R 755 "$THEME_DIR"

# Apply theme via UCI
echo "[*] Applying theme configuration..."
uci set system.@pager[0].theme_name='nullsec'
uci set system.@pager[0].theme_path='/mmc/root/themes/nullsec'
uci commit system

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "           INSTALLATION COMPLETE!                          "
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Theme installed to: $THEME_DIR"
echo ""
echo "To activate, restart the pager or run:"
echo "  reboot"
echo ""
echo "Credits: Built for Hak5 WiFi Pineapple"
