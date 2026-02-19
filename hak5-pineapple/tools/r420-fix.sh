#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# R420 Recovery Script — Run from physical console (keyboard+monitor on R420)
# Fixes: sshd (broken — accepts TCP but never sends banner), 1600x900@60Hz
#
# Diagnosis (from remote testing):
#   - 192.168.40.209 + .210 both respond to ping (same MAC 90:B1:1C:36:A2:2D)
#   - Port 22 accepts TCP but sshd NEVER sends SSH-2.0 banner → RST
#   - Tested from 4 hosts (nullsec, nullkia, doomsday, parrot) — all fail
#   - IPMI/iDRAC not reachable (UDP 623 unresponsive, no web on 443/80)
#   - No other services running (all ports closed except broken 22)
#   - Likely cause: TCP wrappers, disk full, corrupted host keys, or config error
#
# Usage: Login at R420 physical console, then:
#   curl -sL https://raw.githubusercontent.com/bad-antics/nullsec/feature/nullsec-mesh-cluster/tools/r420-fix.sh | bash
#   OR: copy this file to USB and run: bash /mnt/usb/r420-fix.sh
# ═══════════════════════════════════════════════════════════════════════════════

set -e
echo "╔══════════════════════════════════════════════╗"
echo "║  NullSec R420 Recovery Script v2             ║"
echo "╚══════════════════════════════════════════════╝"

# ── Step 1: Diagnose sshd ──
echo ""
echo "[1/6] Diagnosing sshd..."
echo "--- Disk usage ---"
df -h / /var /tmp 2>/dev/null
echo ""
echo "--- sshd status ---"
systemctl status sshd --no-pager 2>/dev/null || service ssh status 2>/dev/null || echo "sshd status unknown"
echo ""
echo "--- TCP wrappers ---"
cat /etc/hosts.deny 2>/dev/null || echo "No hosts.deny"
echo ""
echo "--- fail2ban ---"
systemctl is-active fail2ban 2>/dev/null && echo "fail2ban is ACTIVE" || echo "fail2ban not running"
fail2ban-client status sshd 2>/dev/null || true
echo ""
echo "--- sshd journal (last 20 lines) ---"
journalctl -u sshd -n 20 --no-pager 2>/dev/null || journalctl -u ssh -n 20 --no-pager 2>/dev/null || true

# ── Step 2: Fix TCP wrappers / fail2ban ──
echo ""
echo "[2/6] Fixing access blocks..."
# Clear TCP wrappers blocks
if [ -f /etc/hosts.deny ]; then
    cp /etc/hosts.deny /etc/hosts.deny.bak.$(date +%s)
    # Comment out any ALL or sshd deny lines
    sed -i 's/^[^#].*ALL.*$/# &/' /etc/hosts.deny
    sed -i 's/^[^#].*sshd.*$/# &/' /etc/hosts.deny
    echo "  hosts.deny: blocked entries commented out"
fi
# Ensure hosts.allow permits SSH
grep -q "sshd: ALL" /etc/hosts.allow 2>/dev/null || echo "sshd: ALL" >> /etc/hosts.allow 2>/dev/null
echo "  hosts.allow: sshd: ALL ensured"

# Unban all IPs from fail2ban
if systemctl is-active fail2ban &>/dev/null; then
    fail2ban-client set sshd unbanall 2>/dev/null || true
    echo "  fail2ban: unbanned all"
fi

# Clear any iptables SSH blocks
iptables -L INPUT -n --line-numbers 2>/dev/null | grep -i "dpt:22.*DROP\|dpt:22.*REJECT" | awk '{print $1}' | sort -rn | while read line; do
    iptables -D INPUT $line 2>/dev/null
    echo "  iptables: removed SSH block rule $line"
done

# ── Step 3: Fix disk space if needed ──
echo ""
echo "[3/6] Checking disk space..."
USAGE=$(df / --output=pcent | tail -1 | tr -d ' %')
if [ "$USAGE" -gt 90 ] 2>/dev/null; then
    echo "  !! Disk >90% full — cleaning..."
    journalctl --vacuum-size=50M 2>/dev/null
    apt-get clean 2>/dev/null
    rm -f /var/log/*.gz /var/log/*.1 /var/log/*.old 2>/dev/null
    docker system prune -af 2>/dev/null || true
    echo "  Cleaned. New usage: $(df / --output=pcent | tail -1)"
else
    echo "  Disk usage: ${USAGE}% — OK"
fi

# ── Step 4: Fix sshd config ──
echo ""
echo "[4/6] Fixing sshd configuration..."
SSHD_CONF="/etc/ssh/sshd_config"
cp "$SSHD_CONF" "${SSHD_CONF}.bak.$(date +%s)"

# Disable DNS lookups (common cause of connection resets)
sed -i 's/^#*UseDNS.*/UseDNS no/' "$SSHD_CONF"
grep -q "^UseDNS" "$SSHD_CONF" || echo "UseDNS no" >> "$SSHD_CONF"

# Ensure root login is allowed
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONF"
grep -q "^PermitRootLogin" "$SSHD_CONF" || echo "PermitRootLogin yes" >> "$SSHD_CONF"

# Ensure pubkey auth is enabled
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONF"
grep -q "^PubkeyAuthentication" "$SSHD_CONF" || echo "PubkeyAuthentication yes" >> "$SSHD_CONF"

# Increase MaxStartups
sed -i 's/^#*MaxStartups.*/MaxStartups 10:30:60/' "$SSHD_CONF"
grep -q "^MaxStartups" "$SSHD_CONF" || echo "MaxStartups 10:30:60" >> "$SSHD_CONF"

# Set standard port
sed -i 's/^#*Port .*/Port 22/' "$SSHD_CONF"

# Disable any broken subsystems/pam if they cause hangs
sed -i 's/^#*GSSAPIAuthentication.*/GSSAPIAuthentication no/' "$SSHD_CONF"

# Regenerate host keys if corrupted or missing
for ktype in rsa ecdsa ed25519; do
    keyfile="/etc/ssh/ssh_host_${ktype}_key"
    if [ ! -f "$keyfile" ] || [ ! -s "$keyfile" ]; then
        echo "  Regenerating $ktype host key..."
        rm -f "$keyfile" "${keyfile}.pub"
        ssh-keygen -t $ktype -f "$keyfile" -N "" -q
    fi
done

# Test config before restarting
if sshd -t 2>&1; then
    echo "  sshd config OK"
else
    echo "  !! sshd config ERROR — attempting minimal config..."
    cat > /etc/ssh/sshd_config.d/99-emergency.conf << 'EOF'
Port 22
PermitRootLogin yes
PubkeyAuthentication yes
UseDNS no
MaxStartups 10:30:60
EOF
    sshd -t && echo "  Emergency config OK" || echo "  !! STILL BROKEN — check sshd -t output"
fi

# Restart sshd
systemctl restart sshd 2>/dev/null || service ssh restart 2>/dev/null
echo "  sshd restarted"

# Quick test
sleep 1
ss -tlnp | grep :22 && echo "  ✅ sshd listening on port 22" || echo "  ❌ sshd NOT listening!"

# ── Step 5: Fix screen resolution to 1600x900@60Hz ──
echo ""
echo "[5/6] Setting screen resolution to 1600x900@60Hz..."

# Method 1: Console framebuffer (immediate, no X needed)
if [ -c /dev/fb0 ]; then
    echo "  Framebuffer detected"
    # Try fbset if available
    if command -v fbset &>/dev/null; then
        fbset -xres 1600 -yres 900 -depth 32 2>/dev/null && echo "  Set via fbset" || true
    fi
fi

# Method 2: xrandr (if X is running)
if command -v xrandr &>/dev/null && [ -n "$DISPLAY" ]; then
    OUTPUT=$(xrandr | grep ' connected' | head -1 | cut -d' ' -f1)
    if xrandr | grep -q "1600x900"; then
        xrandr --output "$OUTPUT" --mode 1600x900 --rate 60 2>/dev/null
        echo "  Set via xrandr (existing mode)"
    else
        # Create custom mode (Matrox G200eR needs this)
        xrandr --newmode "1600x900_60.00" 118.25 1600 1696 1856 2112 900 903 908 934 -hsync +vsync 2>/dev/null
        xrandr --addmode "$OUTPUT" "1600x900_60.00" 2>/dev/null
        xrandr --output "$OUTPUT" --mode "1600x900_60.00" 2>/dev/null
        echo "  Created and set custom 1600x900@60 mode"
    fi
fi

# Method 3: GRUB framebuffer (persistent, applies after reboot)
echo "  Setting GRUB framebuffer to 1600x900..."
if [ -f /etc/default/grub ]; then
    cp /etc/default/grub /etc/default/grub.bak.$(date +%s)
    
    sed -i 's/^#*GRUB_GFXMODE=.*/GRUB_GFXMODE=1600x900x32/' /etc/default/grub
    grep -q "^GRUB_GFXMODE" /etc/default/grub || echo 'GRUB_GFXMODE=1600x900x32' >> /etc/default/grub

    sed -i 's/^#*GRUB_GFXPAYLOAD_LINUX=.*/GRUB_GFXPAYLOAD_LINUX=keep/' /etc/default/grub
    grep -q "^GRUB_GFXPAYLOAD_LINUX" /etc/default/grub || echo 'GRUB_GFXPAYLOAD_LINUX=keep' >> /etc/default/grub

    # Matrox G200eR in Dell servers needs nomodeset + video= kernel params
    CURRENT=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub | cut -d'"' -f2)
    if ! echo "$CURRENT" | grep -q "nomodeset"; then
        sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"nomodeset /" /etc/default/grub
    fi
    if ! echo "$CURRENT" | grep -q "video="; then
        sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 video=1600x900@60\"/" /etc/default/grub
    fi

    update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null
    echo "  GRUB updated (takes effect after reboot)"
fi

# Method 4: Xorg conf for persistent X resolution
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/10-resolution.conf << 'XCONF'
Section "Monitor"
    Identifier  "Monitor0"
    Modeline    "1600x900_60.00"  118.25  1600 1696 1856 2112  900 903 908 934 -hsync +vsync
    Option      "PreferredMode" "1600x900_60.00"
EndSection

Section "Screen"
    Identifier  "Screen0"
    Monitor     "Monitor0"
    DefaultDepth 24
    SubSection "Display"
        Depth   24
        Modes   "1600x900"
    EndSubSection
EndSection
XCONF
echo "  Xorg config written to /etc/X11/xorg.conf.d/10-resolution.conf"

# ── Step 6: Verify & ensure authorized_keys ──
echo ""
echo "[6/6] Verification & SSH keys..."

# Make sure the controller's public key is in authorized_keys
mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
# Add common NullSec cluster key format
echo "  Check /root/.ssh/authorized_keys has your ed25519 public key"
echo "  Current keys:"
cat /root/.ssh/authorized_keys 2>/dev/null | head -5

echo ""
echo "--- Final Status ---"
echo "  sshd: $(systemctl is-active sshd 2>/dev/null || service ssh status 2>/dev/null | head -1)"
echo "  Port 22: $(ss -tlnp | grep :22 | head -1)"
echo "  Disk: $(df -h / --output=avail | tail -1) free"
echo "  Resolution: $(xrandr 2>/dev/null | grep '*' | head -1 || cat /sys/class/graphics/fb0/virtual_size 2>/dev/null || echo 'reboot needed')"
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ R420 Recovery Complete                                    ║"
echo "║                                                               ║"
echo "║  Test SSH from controller:                                    ║"
echo "║    ssh root@192.168.40.209 hostname                          ║"
echo "║                                                               ║"
echo "║  If SSH works → reboot for resolution: sudo reboot           ║"
echo "║  If SSH still fails → check: sshd -t && journalctl -u sshd  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
