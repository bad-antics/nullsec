#!/bin/bash
#
# N01D Desktop Menu - Installation Script
# Installs all desktop entries to the applications menu
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="$HOME/.local/share/applications"
MENU_DIR="$HOME/.local/share/desktop-directories"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}"
cat << 'EOF'
 ███╗   ██╗ ██████╗  ██╗██████╗ 
 ████╗  ██║██╔═████╗███║██╔══██╗
 ██╔██╗ ██║██║██╔██║╚██║██║  ██║
 ██║╚██╗██║████╔╝██║ ██║██║  ██║
 ██║ ╚████║╚██████╔╝ ██║██████╔╝
 ╚═╝  ╚═══╝ ╚═════╝  ╚═╝╚═════╝ 
  Desktop Menu Installer
EOF
echo -e "${NC}"

# Create directories
mkdir -p "$DESKTOP_DIR"
mkdir -p "$MENU_DIR"

echo -e "${YELLOW}Installing desktop entries...${NC}"

# Desktop files to install
DESKTOP_FILES=(
    "$SCRIPT_DIR/n01d-desktop-menu.desktop"
    "$SCRIPT_DIR/nullsec-launcher.desktop"
    "$SCRIPT_DIR/nullsec-ai.desktop"
    "$SCRIPT_DIR/nullsec-screensaver.desktop"
    "$SCRIPT_DIR/nullsec-desktop/nullsec-desktop.desktop"
    "$SCRIPT_DIR/github-bot-panel/github-bot-panel.desktop"
    "$SCRIPT_DIR/n01d-media/n01d-media.desktop"
)

# Install each desktop file
for desktop_file in "${DESKTOP_FILES[@]}"; do
    if [[ -f "$desktop_file" ]]; then
        filename=$(basename "$desktop_file")
        cp "$desktop_file" "$DESKTOP_DIR/$filename"
        chmod +x "$DESKTOP_DIR/$filename"
        echo -e "  ${GREEN}✓${NC} Installed: $filename"
    else
        echo -e "  ${YELLOW}⚠${NC} Skipped (not found): $desktop_file"
    fi
done

# Create N01D menu category
echo -e "\n${YELLOW}Creating N01D menu category...${NC}"

cat > "$MENU_DIR/N01D.directory" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Directory
Name=N01D Suite
Comment=NullSec Security & Media Tools
Icon=applications-other
EOF

echo -e "  ${GREEN}✓${NC} Created N01D.directory"

# Create custom menu file for N01D apps
MENU_FILE="$HOME/.config/menus/applications-merged/n01d-menu.menu"
mkdir -p "$(dirname "$MENU_FILE")"

cat > "$MENU_FILE" << 'EOF'
<!DOCTYPE Menu PUBLIC "-//freedesktop//org-DTD Menu 1.0//EN"
  "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
<Menu>
  <Name>Applications</Name>
  <Menu>
    <Name>N01D Suite</Name>
    <Directory>N01D.directory</Directory>
    <Include>
      <Filename>n01d-desktop-menu.desktop</Filename>
      <Filename>nullsec-launcher.desktop</Filename>
      <Filename>nullsec-desktop.desktop</Filename>
      <Filename>github-bot-panel.desktop</Filename>
      <Filename>n01d-media.desktop</Filename>
      <Filename>nullsec-ai.desktop</Filename>
      <Filename>nullsec-screensaver.desktop</Filename>
    </Include>
  </Menu>
</Menu>
EOF

echo -e "  ${GREEN}✓${NC} Created N01D menu category"

# Update desktop database
echo -e "\n${YELLOW}Updating desktop database...${NC}"
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Desktop database updated"
fi

echo -e "\n${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "\nYou can now find your apps in:"
echo -e "  • System applications menu under '${CYAN}N01D Suite${NC}'"
echo -e "  • Run '${CYAN}python3 $SCRIPT_DIR/n01d-desktop-menu.py${NC}' for the launcher"
echo -e "\nTo uninstall, run:"
echo -e "  ${YELLOW}$SCRIPT_DIR/uninstall-desktop-menu.sh${NC}"
