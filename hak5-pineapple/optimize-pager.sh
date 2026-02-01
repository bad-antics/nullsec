#!/bin/bash
# NullSec Pager Optimization Script
# Cleans up storage and optimizes boot performance

PAGER_IP="${1:-172.16.52.1}"
PAGER_PASS="${2:-toor??}"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║       NullSec Pineapple Pager Optimization Tool           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# SSH command helper
run_ssh() {
    sshpass -p "$PAGER_PASS" ssh -o StrictHostKeyChecking=no root@$PAGER_IP "$1"
}

# Check connection
echo "[*] Checking connection to Pager at $PAGER_IP..."
if ! run_ssh "echo 'Connected'" 2>/dev/null; then
    echo "[!] Cannot connect to Pager. Check USB connection."
    exit 1
fi
echo "[+] Connected!"
echo ""

# Storage report
echo "═══════════════════════════════════════════════════════════════"
echo "                    STORAGE ANALYSIS                           "
echo "═══════════════════════════════════════════════════════════════"
run_ssh "df -h /mmc"
echo ""

# Show loot sizes
echo "[*] Loot folder analysis:"
run_ssh "du -sh /mmc/root/loot/*"
echo ""

# Find large files
echo "[*] Files over 10MB:"
run_ssh "find /mmc -type f -size +10M -exec ls -lh {} \; 2>/dev/null"
echo ""

# Ask for cleanup
read -p "[?] Delete pcap files over 50MB? (y/N): " CLEANUP_PCAP
if [[ "$CLEANUP_PCAP" == "y" || "$CLEANUP_PCAP" == "Y" ]]; then
    echo "[*] Deleting large pcap files..."
    run_ssh "find /mmc/root/loot/pcap -type f -size +50M -delete"
    echo "[+] Large pcap files deleted!"
fi

# Ask about themes
read -p "[?] Remove unused themes (keep only nullsec)? (y/N): " CLEANUP_THEMES
if [[ "$CLEANUP_THEMES" == "y" || "$CLEANUP_THEMES" == "Y" ]]; then
    echo "[*] Removing unused themes..."
    run_ssh "cd /mmc/root/themes && rm -rf StarWars cambridge chromatic_trout dedsec finalfantasy mayhem-red old-skool-green quake-n-page radar wargames 2>/dev/null"
    echo "[+] Themes removed!"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "                    SERVICE OPTIMIZATION                        "
echo "═══════════════════════════════════════════════════════════════"

# Ask about services
read -p "[?] Disable Bluetooth service? (y/N): " DISABLE_BT
if [[ "$DISABLE_BT" == "y" || "$DISABLE_BT" == "Y" ]]; then
    run_ssh "/etc/init.d/bluetoothd disable 2>/dev/null"
    run_ssh "/etc/init.d/bluetoothd stop 2>/dev/null"
    echo "[+] Bluetooth disabled"
fi

read -p "[?] Disable AutoSSH service? (y/N): " DISABLE_AUTOSSH
if [[ "$DISABLE_AUTOSSH" == "y" || "$DISABLE_AUTOSSH" == "Y" ]]; then
    run_ssh "/etc/init.d/autossh disable 2>/dev/null"
    run_ssh "/etc/init.d/autossh stop 2>/dev/null"
    echo "[+] AutoSSH disabled"
fi

read -p "[?] Disable OpenVPN service? (y/N): " DISABLE_VPN
if [[ "$DISABLE_VPN" == "y" || "$DISABLE_VPN" == "Y" ]]; then
    run_ssh "/etc/init.d/openvpn disable 2>/dev/null"
    run_ssh "/etc/init.d/openvpn stop 2>/dev/null"
    echo "[+] OpenVPN disabled"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "                    MEMORY OPTIMIZATION                         "
echo "═══════════════════════════════════════════════════════════════"

# Clear tmp files
echo "[*] Clearing temporary files..."
run_ssh "rm -rf /tmp/*.log /tmp/*.tmp 2>/dev/null"

# Sync and drop caches
echo "[*] Syncing filesystem and dropping caches..."
run_ssh "sync && echo 3 > /proc/sys/vm/drop_caches"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "                    FINAL STORAGE REPORT                        "
echo "═══════════════════════════════════════════════════════════════"
run_ssh "df -h /mmc"
echo ""

echo "[*] Memory status:"
run_ssh "free -m"
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║                 Optimization Complete!                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "[*] Recommendations for faster boot:"
echo "    1. Reboot the Pager to apply service changes"
echo "    2. Boot animation is theme-based (nullsec theme active)"
echo "    3. Initial Hak5 splash is firmware-level (cannot change)"
echo ""
