#!/bin/bash
#
# NullSec Linux Boot Theme & Updater Setup v1.1
# Creates custom Plymouth theme and rebrands update notifications
# Repository: https://github.com/bad-antics/nullsec
#

set -e

RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}"
cat << "EOF"
====
|          NullSec Linux Boot Theme & Updater Configuration            |
====
EOF
echo -e "${NC}"

# ============================================================================
# STEP 1: Install Plymouth (Boot Splash)
# ============================================================================
echo -e "${GREEN}[+] Step 1: Installing Plymouth boot splash system...${NC}"

sudo apt-get update -qq
sudo apt-get install -y plymouth plymouth-themes plymouth-label

echo -e "${GREEN}  ✓ Plymouth installed${NC}"

# ============================================================================
# STEP 2: Create NullSec Plymouth Theme
# ============================================================================
echo -e "${GREEN}[+] Step 2: Creating NullSec Plymouth theme...${NC}"

THEME_DIR="/usr/share/plymouth/themes/nullsec"
sudo mkdir -p "$THEME_DIR"

# Create theme configuration
sudo tee "$THEME_DIR/nullsec.plymouth" > /dev/null << 'PLYMOUTHCONF'
[Plymouth Theme]
Name=NullSec Linux
Description=NullSec Linux Boot Splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/nullsec
ScriptFile=/usr/share/plymouth/themes/nullsec/nullsec.script
PLYMOUTHCONF

# Create Plymouth script
sudo tee "$THEME_DIR/nullsec.script" > /dev/null << 'PLYMOUTHSCRIPT'
# NullSec Linux Plymouth Script

# Background
Window.SetBackgroundTopColor(0.0, 0.0, 0.0);
Window.SetBackgroundBottomColor(0.05, 0.05, 0.05);

# Logo
logo.image = Image.Text("NULLSEC LINUX", 1, 0, 0, 1, "Sans Bold 48");
logo.sprite = Sprite(logo.image);
logo.sprite.SetPosition(Window.GetWidth() / 2 - logo.image.GetWidth() / 2, 
                        Window.GetHeight() / 3);

# Version text
version.image = Image.Text("Version 1.0 - Offensive Security Platform", 0.5, 0.5, 0.5, 1, "Sans 16");
version.sprite = Sprite(version.image);
version.sprite.SetPosition(Window.GetWidth() / 2 - version.image.GetWidth() / 2,
                           Window.GetHeight() / 3 + 80);

# Loading text
loading.image = Image.Text("Loading...", 1, 0, 0, 1, "Sans 18");
loading.sprite = Sprite(loading.image);
loading.sprite.SetPosition(Window.GetWidth() / 2 - loading.image.GetWidth() / 2,
                           Window.GetHeight() / 2 + 100);

# Progress bar setup
progress_box.image = Image("progress_box.png");
progress_box.sprite = Sprite(progress_box.image);
progress_box.sprite.SetPosition(Window.GetWidth() / 2 - progress_box.image.GetWidth() / 2,
                                Window.GetHeight() / 2 + 150);

progress_bar.original_image = Image("progress_bar.png");
progress_bar.sprite = Sprite();
progress_bar.sprite.SetPosition(Window.GetWidth() / 2 - progress_box.image.GetWidth() / 2,
                                Window.GetHeight() / 2 + 150);

# Spinning animation
spin = 0;

fun refresh_callback() {
    spin = (spin + 1) % 360;
    
    # Animate loading text
    loading.sprite.SetOpacity(Math.Sin(spin * 3.14159 / 180) * 0.5 + 0.5);
}

Plymouth.SetRefreshFunction(refresh_callback);

# Progress bar update
fun progress_callback(duration, progress) {
    if (progress_bar.image.GetWidth() != Math.Int(progress_bar.original_image.GetWidth() * progress)) {
        progress_bar.image = progress_bar.original_image.Scale(
            progress_bar.original_image.GetWidth() * progress,
            progress_bar.original_image.GetHeight()
        );
        progress_bar.sprite.SetImage(progress_bar.image);
    }
}

Plymouth.SetBootProgressFunction(progress_callback);

# Message display
message_sprite = Sprite();
message_sprite.SetPosition(10, 10, 10000);

fun message_callback(text) {
    my_image = Image.Text(text, 1, 1, 1);
    message_sprite.SetImage(my_image);
}

Plymouth.SetMessageFunction(message_callback);

# Quit callback
fun quit_callback() {
    logo.sprite.SetOpacity(0);
    version.sprite.SetOpacity(0);
    loading.sprite.SetOpacity(0);
    progress_box.sprite.SetOpacity(0);
    progress_bar.sprite.SetOpacity(0);
}

Plymouth.SetQuitFunction(quit_callback);
PLYMOUTHSCRIPT

# Create simple progress bar images
sudo convert -size 400x20 xc:gray30 "$THEME_DIR/progress_box.png" 2>/dev/null || \
sudo convert -size 400x20 canvas:gray30 "$THEME_DIR/progress_box.png" 2>/dev/null || {
    # Fallback: create simple file if ImageMagick not available
    echo "ImageMagick not found, using text-only boot screen"
}

sudo convert -size 400x20 xc:red "$THEME_DIR/progress_bar.png" 2>/dev/null || \
sudo convert -size 400x20 canvas:red "$THEME_DIR/progress_bar.png" 2>/dev/null || {
    echo "ImageMagick not found, using text-only boot screen"
}

echo -e "${GREEN}  ✓ NullSec Plymouth theme created${NC}"

# ============================================================================
# STEP 3: Activate Plymouth Theme
# ============================================================================
echo -e "${GREEN}[+] Step 3: Activating NullSec boot theme...${NC}"

sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
    "$THEME_DIR/nullsec.plymouth" 100

sudo update-alternatives --set default.plymouth "$THEME_DIR/nullsec.plymouth"

# Update initramfs
echo -e "${CYAN}[*] Updating initramfs (this may take a minute)...${NC}"
sudo update-initramfs -u

echo -e "${GREEN}  ✓ Boot theme activated${NC}"

# ============================================================================
# STEP 4: Update GRUB for Quiet Boot
# ============================================================================
echo -e "${GREEN}[+] Step 4: Configuring GRUB for splash screen...${NC}"

sudo cp /etc/default/grub /etc/default/grub.bak.plymouth

# Update GRUB_CMDLINE_LINUX_DEFAULT
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub

sudo update-grub

echo -e "${GREEN}  ✓ GRUB configured${NC}"

# ============================================================================
# STEP 5: Rebrand Parrot Update Notifier
# ============================================================================
echo -e "${GREEN}[+] Step 5: Rebranding system updater...${NC}"

# Find and update parrot-upgrade-notifier
if [ -f /usr/bin/parrot-upgrade-notifier ]; then
    sudo cp /usr/bin/parrot-upgrade-notifier /usr/bin/parrot-upgrade-notifier.bak
    
    sudo sed -i 's/Parrot/NullSec Linux/g' /usr/bin/parrot-upgrade-notifier
    sudo sed -i 's/parrot/nullsec/g' /usr/bin/parrot-upgrade-notifier
    
    echo -e "${GREEN}  ✓ Updated upgrade notifier${NC}"
fi

# Update apt-check messages
if [ -f /usr/lib/update-notifier/apt-check ]; then
    sudo cp /usr/lib/update-notifier/apt-check /usr/lib/update-notifier/apt-check.bak
    
    sudo sed -i 's/Parrot/NullSec Linux/g' /usr/lib/update-notifier/apt-check 2>/dev/null || true
fi

# Update update-manager if present
if [ -f /usr/bin/update-manager ]; then
    sudo cp /usr/bin/update-manager /usr/bin/update-manager.bak
    
    sudo sed -i 's/Parrot/NullSec Linux/g' /usr/bin/update-manager
    sudo sed -i 's/parrot/nullsec/g' /usr/bin/update-manager
    
    echo -e "${GREEN}  ✓ Updated update-manager${NC}"
fi

# Create custom update notification script
sudo tee /usr/local/bin/nullsec-update-check > /dev/null << 'UPDATECHECK'
#!/bin/bash
# NullSec Linux Update Checker

UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable)

if [ "$UPDATES" -gt 0 ]; then
    notify-send "NullSec Linux Updates" \
                "$UPDATES updates available for your system" \
                --icon=system-software-update \
                --urgency=normal
fi
UPDATECHECK

sudo chmod +x /usr/local/bin/nullsec-update-check

echo -e "${GREEN}  ✓ Created NullSec update checker${NC}"

# ============================================================================
# STEP 6: Update Desktop Notifications
# ============================================================================
echo -e "${GREEN}[+] Step 6: Configuring startup notifications...${NC}"

# Create autostart entry for update notifications
mkdir -p ~/.config/autostart

cat > ~/.config/autostart/nullsec-updates.desktop << 'AUTOSTART'
[Desktop Entry]
Type=Application
Name=NullSec Update Notifier
Comment=Check for NullSec Linux updates
Exec=/usr/local/bin/nullsec-update-check
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
AUTOSTART

echo -e "${GREEN}  ✓ Update notifier configured${NC}"

# ============================================================================
# STEP 7: Create Startup Logo Display
# ============================================================================
echo -e "${GREEN}[+] Step 7: Creating startup logo display...${NC}"

sudo tee /usr/local/bin/nullsec-startup-logo > /dev/null << 'STARTUPLOGO'
#!/bin/bash
# Display NullSec Linux logo on terminal login

cat << "LOGO"

     ███==   ██==██==   ██==██==     ██==     ███████==███████== ██████==
     ████==  ██|██|   ██|██|     ██|     ██====██====██====
     ██==██== ██|██|   ██|██|     ██|     ███████==█████==  ██|
     ██|==██==██|██|   ██|██|     ██|     ==██|██====  ██|
     ██| ==████|==██████====███████==███████==███████|███████====██████==
     ====  ==== ==== ================ ====

               L I N U X   v1.0  -  O F F E N S I V E   S E C
               
     [+] NULLSEC Framework: /home/antics/nullsec
     [+] Run 'nullsec-fetch' for system info
     [+] Run 'nullsec-info' for framework details

LOGO
STARTUPLOGO

sudo chmod +x /usr/local/bin/nullsec-startup-logo

# Add to bash profile if not already there
if ! grep -q "nullsec-startup-logo" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# NullSec Linux startup logo" >> ~/.bashrc
    echo "/usr/local/bin/nullsec-startup-logo" >> ~/.bashrc
fi

echo -e "${GREEN}  ✓ Startup logo configured${NC}"

# ============================================================================
# STEP 8: Update Notification Daemon
# ============================================================================
echo -e "${GREEN}[+] Step 8: Configuring notification system...${NC}"

# Update notification-daemon branding if exists
if [ -d /usr/share/notification-daemon ]; then
    sudo find /usr/share/notification-daemon -type f -name "*.xml" -exec \
        sudo sed -i 's/Parrot/NullSec Linux/g' {} \; 2>/dev/null || true
fi

# Update any .desktop files mentioning Parrot in system directories
sudo find /usr/share/applications -type f -name "*.desktop" -exec \
    sudo sed -i 's/Parrot Security/NullSec Linux/g' {} \; 2>/dev/null || true

echo -e "${GREEN}  ✓ Notification system updated${NC}"

# ============================================================================
# COMPLETION
# ============================================================================
echo ""
echo -e "${GREEN}====${NC}"
echo -e "${GREEN}|           BOOT THEME & UPDATER SETUP COMPLETED!                       |${NC}"
echo -e "${GREEN}====${NC}"
echo ""
echo -e "${CYAN}Changes Made:${NC}"
echo -e "  ✓ Custom Plymouth boot splash (NullSec Linux theme)"
echo -e "  ✓ GRUB configured for quiet boot with splash"
echo -e "  ✓ Update notifier rebranded to NullSec Linux"
echo -e "  ✓ Startup logo displays on terminal login"
echo -e "  ✓ Update notifications show 'NullSec Linux'"
echo -e "  ✓ Desktop notifications rebranded"
echo ""
echo -e "${CYAN}New Features:${NC}"
echo -e "  • Boot splash: NullSec Linux logo during startup"
echo -e "  • Update check: ${RED}nullsec-update-check${NC}"
echo -e "  • Startup logo: Displays on new terminal sessions"
echo -e "  • Auto-update notifications with NullSec branding"
echo ""
echo -e "${YELLOW}[!] Reboot required to see boot splash:${NC}"
echo -e "     ${RED}sudo reboot${NC}"
echo ""
echo -e "${CYAN}Test Boot Splash (Optional):${NC}"
echo -e "     ${RED}sudo plymouthd --debug; sudo plymouth --show-splash${NC}"
echo -e "     ${DIM}(Press Ctrl+C to exit test, then: sudo plymouth --quit)${NC}"
echo ""
echo -e "${GREEN}[+] Your system now displays NullSec Linux branding everywhere!${NC}"
echo ""
