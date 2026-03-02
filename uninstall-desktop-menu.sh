#!/bin/bash
#
# N01D Desktop Menu - Uninstallation Script
# Removes all desktop entries
#

DESKTOP_DIR="$HOME/.local/share/applications"
MENU_DIR="$HOME/.local/share/desktop-directories"
MENU_FILE="$HOME/.config/menus/applications-merged/n01d-menu.menu"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Uninstalling N01D Desktop Menu...${NC}\n"

# Desktop files to remove
FILES_TO_REMOVE=(
    "$DESKTOP_DIR/n01d-desktop-menu.desktop"
    "$DESKTOP_DIR/nullsec-launcher.desktop"
    "$DESKTOP_DIR/nullsec-ai.desktop"
    "$DESKTOP_DIR/nullsec-screensaver.desktop"
    "$DESKTOP_DIR/nullsec-desktop.desktop"
    "$DESKTOP_DIR/github-bot-panel.desktop"
    "$DESKTOP_DIR/n01d-media.desktop"
    "$MENU_DIR/N01D.directory"
    "$MENU_FILE"
)

for file in "${FILES_TO_REMOVE[@]}"; do
    if [[ -f "$file" ]]; then
        rm "$file"
        echo -e "  ${RED}✗${NC} Removed: $(basename "$file")"
    fi
done

# Update desktop database
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

echo -e "\n${GREEN}Uninstallation complete!${NC}"
