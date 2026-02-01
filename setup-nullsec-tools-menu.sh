#!/bin/bash

#############################################################################
#               NULLSEC LINUX - TOOLS MENU SETUP v1.1                      #
#               Repository: https://github.com/bad-antics/nullsec         #
#############################################################################
# Creates "NullSec Tools" menu with all modules grouped by exploit type
# Each module gets its own quick-launch entry
#############################################################################

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
====
|            NULLSEC LINUX - TOOLS MENU INSTALLER                       |
====
EOF
echo -e "${NC}"

echo -e "${GREEN}[+] Setting up NullSec Tools menu system...${NC}"

# Step 1: Remove old Pentesting directory if exists
echo -e "${YELLOW}[*] Removing old Pentesting directory...${NC}"
sudo rm -f /usr/share/desktop-directories/NullSec-Pentesting.directory 2>/dev/null || true

# Step 2: Create main NullSec Tools directory
echo -e "${YELLOW}[*] Creating NullSec Tools category...${NC}"
sudo tee /usr/share/desktop-directories/NullSec-Tools.directory > /dev/null << 'EOF'
[Desktop Entry]
Name=⚡ NullSec Tools
Name[en]=⚡ NullSec Tools
Comment=NullSec Penetration Testing Modules (188 Tools)
Type=Directory
Icon=/usr/share/icons/hicolor/256x256/apps/nullsec.png
EOF

# Step 3: Create category subdirectories
echo -e "${YELLOW}[*] Creating exploit type categories...${NC}"

# Network Category
sudo tee /usr/share/desktop-directories/NullSec-Network.directory > /dev/null << 'EOF'
[Desktop Entry]
Name=🌐 Network Exploitation
Type=Directory
Icon=/usr/share/icons/hicolor/256x256/apps/nullsec.png
EOF

# Web Category
sudo tee /usr/share/desktop-directories/NullSec-Web.directory > /dev/null << 'EOF'
[Desktop Entry]
Name=🌍 Web Exploitation
Type=Directory
Icon=/usr/share/icons/hicolor/256x256/apps/nullsec.png
EOF

# Wireless Category
sudo tee /usr/share/desktop-directories/NullSec-Wireless.directory > /dev/null << 'EOF'
[Desktop Entry]
Name=📡 Wireless Attacks
Type=Directory
Icon=/usr/share/icons/hicolor/256x256/apps/nullsec.png
EOF

# Exploitation Category
sudo tee /usr/share/desktop-directories/NullSec-Exploitation.directory > /dev/null << 'EOF'
[Desktop Entry]
Name=💣 Exploitation
Type=Directory
Icon=/usr/share/icons/hicolor/256x256/apps/nullsec.png
EOF

# Password Category
sudo tee /usr/share/desktop-directories/NullSec-Password.directory > /dev/null << 'EOF'
[Desktop Entry]
Name=🔑 Password Attacks
Type=Directory
Icon=/usr/share/icons/hicolor/256x256/apps/nullsec.png
EOF

# Cloud Category
sudo tee /usr/share/desktop-directories/NullSec-Cloud.directory > /dev/null << 'EOF'
[Desktop Entry]
Name=☁️ Cloud & Container
Type=Directory
Icon=/usr/share/icons/hicolor/256x256/apps/nullsec.png
EOF

# Active Directory Category
sudo tee /usr/share/desktop-directories/NullSec-ActiveDirectory.directory > /dev/null << 'EOF'
[Desktop Entry]
Name=🏢 Active Directory
Type=Directory
Icon=/usr/share/icons/hicolor/256x256/apps/nullsec.png
EOF

# IoT Category
sudo tee /usr/share/desktop-directories/NullSec-IoT.directory > /dev/null << 'EOF'
[Desktop Entry]
Name=📱 IoT & ICS/SCADA
Type=Directory
Icon=/usr/share/icons/hicolor/256x256/apps/nullsec.png
EOF

echo -e "${GREEN}[✓] Created 8 category directories${NC}"

# Step 4: Generate desktop entries for all modules
echo -e "${YELLOW}[*] Generating desktop entries for 188 modules...${NC}"
cd /home/antics/nullsec
sudo -u antics python3 create-module-menu-entries.py

# Step 5: Update menu configuration
echo -e "${YELLOW}[*] Updating menu configuration...${NC}"

# Backup
sudo cp /etc/xdg/menus/mate-applications.menu /etc/xdg/menus/mate-applications.menu.bak-tools 2>/dev/null || true

# Remove old Pentesting menu if exists
sudo sed -i '/<\!-- Pentesting (NullSec Linux) -->/,/<\!-- End Pentesting -->/d' /etc/xdg/menus/mate-applications.menu 2>/dev/null || true

# Create comprehensive menu structure
cat > /tmp/nullsec-tools-menu.xml << 'MENUEOF'

  <!-- NullSec Tools (All Modules) -->
  <Menu>
    <Name>NullSec Tools</Name>
    <Directory>NullSec-Tools.directory</Directory>
    
    <!-- Network Exploitation -->
    <Menu>
      <Name>Network</Name>
      <Directory>NullSec-Network.directory</Directory>
      <Include>
        <Category>Network</Category>
      </Include>
    </Menu>
    
    <!-- Web Exploitation -->
    <Menu>
      <Name>Web</Name>
      <Directory>NullSec-Web.directory</Directory>
      <Include>
        <Category>Web</Category>
      </Include>
    </Menu>
    
    <!-- Wireless Attacks -->
    <Menu>
      <Name>Wireless</Name>
      <Directory>NullSec-Wireless.directory</Directory>
      <Include>
        <Category>Wireless</Category>
      </Include>
    </Menu>
    
    <!-- Exploitation -->
    <Menu>
      <Name>Exploitation</Name>
      <Directory>NullSec-Exploitation.directory</Directory>
      <Include>
        <Category>Exploitation</Category>
      </Include>
    </Menu>
    
    <!-- Password Attacks -->
    <Menu>
      <Name>Password</Name>
      <Directory>NullSec-Password.directory</Directory>
      <Include>
        <Category>Password</Category>
      </Include>
    </Menu>
    
    <!-- Cloud & Container -->
    <Menu>
      <Name>Cloud</Name>
      <Directory>NullSec-Cloud.directory</Directory>
      <Include>
        <Category>Cloud</Category>
      </Include>
    </Menu>
    
    <!-- Active Directory -->
    <Menu>
      <Name>ActiveDirectory</Name>
      <Directory>NullSec-ActiveDirectory.directory</Directory>
      <Include>
        <Category>ActiveDirectory</Category>
      </Include>
    </Menu>
    
    <!-- IoT & ICS/SCADA -->
    <Menu>
      <Name>IoT</Name>
      <Directory>NullSec-IoT.directory</Directory>
      <Include>
        <Category>IoT</Category>
      </Include>
    </Menu>
    
    <!-- Main Tools (Framework Launchers) -->
    <Include>
      <Or>
        <Filename>nullsec-launcher.desktop</Filename>
        <Filename>nullsec-desktop.desktop</Filename>
        <Category>NullSecTools</Category>
      </Or>
    </Include>
    
  </Menu> <!-- End NullSec Tools -->
MENUEOF

# Insert after Games section
sudo sed -i '/<\/Menu> <!-- End Games -->/r /tmp/nullsec-tools-menu.xml' /etc/xdg/menus/mate-applications.menu

echo -e "${GREEN}[✓] Updated menu configuration${NC}"

# Step 6: Update main launcher desktop files
echo -e "${YELLOW}[*] Updating main launcher categories...${NC}"

for file in ~/.local/share/applications/nullsec-launcher.desktop \
            ~/.local/share/applications/nullsec-desktop.desktop \
            ~/nullsec/nullsec-launcher.desktop \
            ~/nullsec/nullsec-desktop/nullsec-desktop.desktop; do
    if [ -f "$file" ]; then
        sed -i 's/Categories=Pentesting;Security;System;/Categories=NullSecTools;Security;System;/' "$file" 2>/dev/null || true
        sed -i 's/Categories=Security;System;/Categories=NullSecTools;Security;System;/' "$file" 2>/dev/null || true
    fi
done

echo -e "${GREEN}[✓] Updated launcher categories${NC}"

# Step 7: Refresh menu
echo -e "${YELLOW}[*] Refreshing menu cache...${NC}"
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
update-desktop-database ~/.local/share/applications/nullsec-modules/ 2>/dev/null || true
xdg-desktop-menu forceupdate 2>/dev/null || true

# Step 8: Restart panel
echo -e "${YELLOW}[*] Restarting MATE panel...${NC}"
killall mate-panel 2>/dev/null && sleep 2 && mate-panel &
disown

echo -e "${GREEN}"
cat << "EOF"
====
|                    ✅ INSTALLATION COMPLETE                           |
====

🎯 NULLSEC TOOLS MENU CREATED!

Menu Structure:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Applications → Games
Applications → ⚡ NullSec Tools  ← NEW!
    │
    ├─ 🌐 Network Exploitation
    │   └─ (Network attack modules with quick launch)
    │
    ├─ 🌍 Web Exploitation
    │   └─ (Web attack modules with quick launch)
    │
    ├─ 📡 Wireless Attacks
    │   └─ (WiFi/Bluetooth modules with quick launch)
    │
    ├─ 💣 Exploitation
    │   └─ (Exploit modules with quick launch)
    │
    ├─ 🔑 Password Attacks
    │   └─ (Credential attack modules with quick launch)
    │
    ├─ ☁️ Cloud & Container
    │   └─ (Cloud/Docker/K8s modules with quick launch)
    │
    ├─ 🏢 Active Directory
    │   └─ (AD attack modules with quick launch)
    │
    ├─ 📱 IoT & ICS/SCADA
    │   └─ (IoT/SCADA modules with quick launch)
    │
    ├─ ⚡ NullSec Framework Launcher
    │   └─ (Main interactive framework)
    │
    └─ ⚡ NullSec Desktop GUI
        └─ (Desktop GUI application)

📊 Statistics:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  • Total Modules: 188
  • Categories: 8 exploit types
  • Desktop Entries: ~190+ created
  • Quick Launch: Click any module to execute

🚀 Access:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. Click Applications Menu
  2. Navigate to "⚡ NullSec Tools"
  3. Browse by category (Network, Web, etc.)
  4. Click any module for instant execution

📋 Files Created:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  • /usr/share/desktop-directories/NullSec-*.directory (9 files)
  • ~/.local/share/applications/nullsec-modules/*.desktop (188 files)
  • /etc/xdg/menus/mate-applications.menu (updated)

NOTE: If menu doesn't appear immediately, log out and back in.

EOF
echo -e "${NC}"

exit 0
