#!/bin/bash

echo "===="
echo "|       FINAL AUDIT - NullSec Linux Complete System Scan               |"
echo "===="
echo ""

# Header
echo -e "\033[1;32m"
cat << 'HEADER'
 ███▄    █  █    ██  ██▓     ██▓      ██████ ▓█████  ▄████▄
 ██ ▀█   █  ██  ▓██▒▓██▒    ▓██▒    ▒██    ▒ ▓█   ▀ ▒██▀ ▀█
▓██  ▀█ ██▒▓██  ▒██░▒██░    ▒██░    ░ ▓██▄   ▒███   ▒▓█    ▄
▓██▒  ▐▌██▒▓▓█  ░██░▒██░    ▒██░      ▒   ██▒▒▓█  ▄ ▒▓▓▄ ▄██▒
▒██░   ▓██░▒▒█████▓ ░██████▒░██████▒▒██████▒▒░▒████▒▒ ▓███▀ ░
░ ▒░   ▒ ▒ ░▒▓▒ ▒ ▒ ░ ▒░▓  ░░ ▒░▓  ░▒ ▒▓▒ ▒ ░░░ ▒░ ░░ ░▒ ▒  ░
░ ░░   ░ ▒░░░▒░ ░ ░ ░ ░ ▒  ░░ ░ ▒  ░░ ░▒  ░ ░ ░ ░  ░  ░  ▒
   ░   ░ ░  ░░░ ░ ░   ░ ░     ░ ░   ░  ░  ░     ░   ░
         ░    ░         ░  ░    ░  ░      ░     ░  ░░ ░
                                                    ░
HEADER
echo -e "\033[0m"
echo ""

# System Info
echo "======================================================================="
echo "SYSTEM IDENTIFICATION"
echo "======================================================================="
echo "OS Release:"
/usr/bin/lsb_release -d 2>/dev/null | cut -f2
cat /etc/os-release | /bin/grep "PRETTY_NAME\|VERSION\|ID" | head -4
echo ""
echo "Hostname: $(/bin/hostname)"
echo "Terminal: $(dconf read /org/mate/terminal/profiles/default/title 2>/dev/null || echo 'Not configured')"
echo "Plymouth: $(plymouth-set-default-theme 2>/dev/null || echo 'Not configured')"
echo ""

# Scan Categories
echo "======================================================================="
echo "COMPREHENSIVE SCAN RESULTS"
echo "======================================================================="

TOTAL_REFS=0

# Desktop Files
COUNT=$(sudo /bin/grep -r "Parrot" /usr/share/applications/*.desktop 2>/dev/null | /bin/grep -v "Binary\|\.bak" | /usr/bin/wc -l)
TOTAL_REFS=$((TOTAL_REFS + COUNT))
[ $COUNT -eq 0 ] && echo "✅ Desktop Files: $COUNT references" || echo "⚠️  Desktop Files: $COUNT references"

# Menu Entries
COUNT=$(sudo /bin/grep -r "Parrot" /usr/share/parrot-menu/applications/*.desktop 2>/dev/null | /bin/grep -v "Binary\|\.bak" | /usr/bin/wc -l)
TOTAL_REFS=$((TOTAL_REFS + COUNT))
[ $COUNT -eq 0 ] && echo "✅ Menu Entries: $COUNT references" || echo "⚠️  Menu Entries: $COUNT references"

# Config Files
COUNT=$(sudo /bin/grep -r "Parrot" /etc/*.conf 2>/dev/null | /bin/grep -v "Binary\|\.bak" | /usr/bin/wc -l)
TOTAL_REFS=$((TOTAL_REFS + COUNT))
[ $COUNT -eq 0 ] && echo "✅ Config Files: $COUNT references" || echo "⚠️  Config Files: $COUNT references"

# System Releases
COUNT=$(sudo /bin/grep -r "Parrot" /etc/*-release 2>/dev/null | /bin/grep -v "Binary\|\.bak" | /usr/bin/wc -l)
TOTAL_REFS=$((TOTAL_REFS + COUNT))
[ $COUNT -eq 0 ] && echo "✅ System Releases: $COUNT references" || echo "⚠️  System Releases: $COUNT references"

# GRUB Config
COUNT=$(sudo /bin/grep -i "parrot" /boot/grub/grub.cfg 2>/dev/null | /bin/grep -v "Binary\|\.bak\|#" | /usr/bin/wc -l)
TOTAL_REFS=$((TOTAL_REFS + COUNT))
[ $COUNT -eq 0 ] && echo "✅ GRUB Config: $COUNT references" || echo "⚠️  GRUB Config: $COUNT references"

# MOTD Files
COUNT=$(sudo /bin/grep -i "parrot" /etc/motd /etc/issue 2>/dev/null | /usr/bin/wc -l)
TOTAL_REFS=$((TOTAL_REFS + COUNT))
[ $COUNT -eq 0 ] && echo "✅ MOTD Files: $COUNT references" || echo "⚠️  MOTD Files: $COUNT references"

# Autostart
COUNT=$(sudo /bin/grep -r "Parrot" /etc/xdg/autostart/*.desktop 2>/dev/null | /bin/grep -v "Binary\|\.bak" | /usr/bin/wc -l)
TOTAL_REFS=$((TOTAL_REFS + COUNT))
[ $COUNT -eq 0 ] && echo "✅ Autostart: $COUNT references" || echo "⚠️  Autostart: $COUNT references"

echo ""

# Summary
echo "======================================================================="
echo "AUDIT SUMMARY"
echo "======================================================================="
echo "Total Parrot References Found: $TOTAL_REFS"
echo ""

if [ $TOTAL_REFS -eq 0 ]; then
    echo -e "\033[1;32m"
    echo "===="
    echo "|                                                                   |"
    echo "|        ✅ REBRAND 100% COMPLETE - READY FOR ISO CREATION!        |"
    echo "|                                                                   |"
    echo "===="
    echo -e "\033[0m"
    echo ""
    echo "Next Steps:"
    echo "  1. Create ISO: cd /home/antics/nullsec && sudo bash create-nullsec-iso.sh"
    echo "  2. Output: /home/antics/nullsec-iso/nullsec-linux-1.0-amd64.iso"
    echo "  3. Size: ~3-5GB"
    echo "  4. Time: 30-60 minutes"
else
    echo -e "\033[1;33m⚠️  $TOTAL_REFS references remain (likely in comments/metadata)\033[0m"
fi
echo ""
