#!/bin/bash
# NullSec Firmware Uninstaller

echo "=== NullSec Firmware Uninstaller ==="
echo ""
read -p "This will remove all NullSec components. Continue? (y/N) " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

echo "[*] Removing payloads..."
rm -rf /root/payloads/nullsec

echo "[*] Removing theme..."
rm -rf /mmc/root/themes/nullsec

echo "[*] Removing quick commands..."
rm -f /usr/bin/nullscan /usr/bin/nullstatus /usr/bin/nulloot

echo "[*] Restoring default theme..."
uci set system.@pager[0].theme='wargames' 2>/dev/null
uci set system.@pager[0].theme_path='/root/themes/wargames' 2>/dev/null
uci commit system 2>/dev/null

echo ""
echo "[+] NullSec firmware removed. Reboot to complete."
