#!/bin/bash
#===============================================================================
#  NULLSEC PAGER SETUP - Complete Device Customization
#===============================================================================

# NullSec Branding
HOSTNAME="nullsec-pager"
BANNER='
 ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗
 ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝
 ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║     
 ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║     
 ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗
 ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝
              PAGER EDITION - Offensive WiFi Platform
'

echo "$BANNER"
echo "[+] NullSec Pager Setup Starting..."

# Set hostname
echo "[+] Setting hostname to $HOSTNAME"
echo "$HOSTNAME" > /etc/hostname
uci set system.@system[0].hostname="$HOSTNAME"
uci commit system

# Create NullSec directory structure
echo "[+] Creating NullSec directories..."
mkdir -p /root/nullsec/{loot,logs,configs,scripts}
mkdir -p /mmc/nullsec/{captures,handshakes,creds,exfil}

# Set custom banner
echo "[+] Setting login banner..."
cat > /etc/banner << 'EOF'

 ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗
 ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝
 ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║     
 ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║     
 ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗
 ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝
                    PAGER - WiFi Assault Platform
 ───────────────────────────────────────────────────────────
  Payloads: /root/payloads/nullsec/
  Loot:     /mmc/nullsec/
  Logs:     /root/nullsec/logs/
 ───────────────────────────────────────────────────────────
EOF

# Custom profile
echo "[+] Setting up shell profile..."
cat > /etc/profile.d/nullsec.sh << 'EOF'
# NullSec Pager Profile
export PS1='\[\033[0;31m\]nullsec\[\033[0m\]@\[\033[0;32m\]pager\[\033[0m\]:\w# '
export LOOT_DIR="/mmc/nullsec"
export PATH="$PATH:/root/payloads/nullsec"

alias ll='ls -la'
alias loot='cd /mmc/nullsec && ls -la'
alias payloads='cd /root/payloads/nullsec && ls -la'
alias logs='tail -f /root/nullsec/logs/*.log 2>/dev/null'
alias scan='cd /root/payloads/nullsec && ./nullsec-launcher.sh'

# Auto-log sessions
script -q -a /root/nullsec/logs/session_$(date +%Y%m%d).log
EOF

# Create quick-access scripts
echo "[+] Creating quick-access commands..."

# Quick scan command
cat > /usr/bin/nullscan << 'EOF'
#!/bin/sh
cd /root/payloads/nullsec && ./nullsec-launcher.sh
EOF
chmod +x /usr/bin/nullscan

# Quick loot view
cat > /usr/bin/nulloot << 'EOF'
#!/bin/sh
echo "=== NULLSEC LOOT ==="
echo ""
echo "Handshakes:"
ls -la /mmc/nullsec/handshakes/ 2>/dev/null | tail -10
echo ""
echo "Credentials:"
cat /mmc/nullsec/creds/*.txt 2>/dev/null | tail -20
echo ""
echo "Exfil data:"
du -sh /mmc/nullsec/exfil/* 2>/dev/null
EOF
chmod +x /usr/bin/nulloot

# Status command
cat > /usr/bin/nullstatus << 'EOF'
#!/bin/sh
echo "╔═══════════════════════════════════════╗"
echo "║       NULLSEC PAGER STATUS            ║"
echo "╚═══════════════════════════════════════╝"
echo ""
echo "Hostname: $(cat /etc/hostname)"
echo "Uptime:   $(uptime | cut -d',' -f1)"
echo "Memory:   $(free | grep Mem | awk '{printf "%.0f%%", $3/$2*100}')"
echo "Storage:  $(df -h /mmc | tail -1 | awk '{print $5 " used"}')"
echo ""
echo "Network Interfaces:"
ip -br addr | grep -v "^lo"
echo ""
echo "WiFi Status:"
iwinfo wlan0mgmt info 2>/dev/null | head -5
echo ""
echo "Active Processes:"
ps | grep -E "airmon|airodump|aireplay|tcpdump|hostapd" | grep -v grep
EOF
chmod +x /usr/bin/nullstatus

echo "[+] NullSec Pager setup complete!"
echo ""
echo "Quick commands:"
echo "  nullscan   - Launch NullSec payload menu"
echo "  nulloot    - View captured loot"
echo "  nullstatus - Show system status"
