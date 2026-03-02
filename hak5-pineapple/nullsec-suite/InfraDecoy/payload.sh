#!/bin/bash
# Title: Infra Decoy
# Author: bad-antics
# Description: Deploy fake network infrastructure as honeypot lures
# Category: nullsec/defense

LOOT_DIR="/mmc/nullsec/decoy"
mkdir -p "$LOOT_DIR"

PROMPT "INFRA DECOY

Deploy fake network services
as honeypot lures to detect
attackers on your network.

Deploys:
- Fake SSH server (logs creds)
- Fake HTTP admin panel
- Fake SMB share
- Fake FTP server
- Fake Telnet banner
- Connection logging & alerts

Press OK to configure."

IFACE=$(TEXT_PICKER "Interface:" "br-lan")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) IFACE="br-lan" ;; esac

MY_IP=$(ip -4 addr show "$IFACE" | grep -oE 'inet [0-9.]+' | awk '{print $2}')
[ -z "$MY_IP" ] && { ERROR_DIALOG "No IP on $IFACE!"; exit 1; }

DURATION=$(NUMBER_PICKER "Duration (minutes):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/decoy_${TIMESTAMP}.txt"
ALERT_LOG="$LOOT_DIR/alerts_${TIMESTAMP}.txt"

resp=$(CONFIRMATION_DIALOG "DEPLOY DECOYS?

IP: $MY_IP
Duration: ${DURATION} min

Fake services will listen on
non-standard ports to avoid
disrupting real services.

SSH:  2222
HTTP: 8888
FTP:  2121
Telnet: 2323

Press OK to deploy.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Deploying decoy infrastructure..."
SPINNER_START "Setting up honeypots..."

echo "================================================================" > "$REPORT"
echo "         NULLSEC INFRA DECOY REPORT                            " >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "Time: $(date)" >> "$REPORT"
echo "IP: $MY_IP | Duration: ${DURATION} min" >> "$REPORT"
echo "" >> "$REPORT"

touch "$ALERT_LOG"
DURATION_SEC=$((DURATION * 60))

# Helper: log an alert
log_alert() {
    local service="$1" remote="$2" detail="$3"
    local ts=$(date +%H:%M:%S)
    echo "[$ts] ALERT: $service connection from $remote — $detail" >> "$ALERT_LOG"
}

# --- Decoy 1: Fake SSH (banner grab trap) ---
FAKE_SSH_LOG="/tmp/decoy_ssh.log"
(
    while true; do
        echo -e "SSH-2.0-OpenSSH_8.9p1 Ubuntu-3ubuntu0.1\r\n" | \
            nc -l -p 2222 -w 5 2>/dev/null | while read -r line; do
                REMOTE=$(echo "$line" | head -1)
                log_alert "SSH:2222" "unknown" "data: $line"
            done
        sleep 1
    done
) &
SSH_PID=$!
echo "  [+] Fake SSH on :2222" >> "$REPORT"

# --- Decoy 2: Fake HTTP admin panel ---
FAKE_HTTP_DIR="/tmp/decoy_http"
mkdir -p "$FAKE_HTTP_DIR"
cat > "$FAKE_HTTP_DIR/index.html" << 'HTMLEOF'
<html><head><title>Router Admin</title></head>
<body style="font-family:Arial;margin:40px">
<h2>Network Administration Portal</h2>
<form method="POST" action="/login">
<table>
<tr><td>Username:</td><td><input name="username" type="text"></td></tr>
<tr><td>Password:</td><td><input name="password" type="password"></td></tr>
<tr><td></td><td><input type="submit" value="Login"></td></tr>
</table>
</form>
<p style="color:#999">Firmware v4.2.1 | &copy; 2024 NetGear Inc.</p>
</body></html>
HTMLEOF

(
    while true; do
        RESP="HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n$(cat "$FAKE_HTTP_DIR/index.html")"
        REQUEST=$(echo -e "$RESP" | nc -l -p 8888 -w 10 2>/dev/null)
        if [ -n "$REQUEST" ]; then
            log_alert "HTTP:8888" "unknown" "request received"
            # Check for POST data (credential submission)
            echo "$REQUEST" | grep -iE "(username|password)" >> "$LOOT_DIR/http_creds_${TIMESTAMP}.txt" 2>/dev/null
        fi
        sleep 1
    done
) &
HTTP_PID=$!
echo "  [+] Fake HTTP admin on :8888" >> "$REPORT"

# --- Decoy 3: Fake FTP ---
(
    while true; do
        (
            echo "220 ProFTPD 1.3.5e Server (Corporate FTP)"
            read -r line
            echo "331 Password required for $(echo "$line" | awk '{print $2}')"
            read -r line
            PASS=$(echo "$line" | awk '{print $2}')
            log_alert "FTP:2121" "unknown" "login attempt: $line"
            echo "530 Login incorrect."
            echo "221 Goodbye."
        ) | nc -l -p 2121 -w 10 2>/dev/null
        sleep 1
    done
) &
FTP_PID=$!
echo "  [+] Fake FTP on :2121" >> "$REPORT"

# --- Decoy 4: Fake Telnet ---
(
    while true; do
        (
            echo ""
            echo "==================================="
            echo "  Cisco IOS Router - RESTRICTED"
            echo "==================================="
            echo ""
            echo -n "Username: "
            read -r user
            echo -n "Password: "
            read -r pass
            log_alert "TELNET:2323" "unknown" "login: $user / $pass"
            echo ""
            echo "% Login invalid"
            echo ""
        ) | nc -l -p 2323 -w 15 2>/dev/null
        sleep 1
    done
) &
TELNET_PID=$!
echo "  [+] Fake Telnet on :2323" >> "$REPORT"

echo "" >> "$REPORT"
echo "  All decoys deployed. Monitoring..." >> "$REPORT"
echo "" >> "$REPORT"

SPINNER_STOP

PROMPT "DECOYS DEPLOYED

Services active on $MY_IP:
  SSH:    :2222
  HTTP:   :8888
  FTP:    :2121
  Telnet: :2323

Monitoring for ${DURATION} min...
Any interaction = attacker alert

Press OK to monitor (background)"

# Monitor phase
sleep $DURATION_SEC

# Shutdown all decoys
kill $SSH_PID $HTTP_PID $FTP_PID $TELNET_PID 2>/dev/null

# Count alerts
ALERT_COUNT=$(wc -l < "$ALERT_LOG" 2>/dev/null || echo 0)

echo "--- ALERT SUMMARY ---" >> "$REPORT"
echo "  Total alerts: $ALERT_COUNT" >> "$REPORT"
[ "$ALERT_COUNT" -gt 0 ] && cat "$ALERT_LOG" >> "$REPORT"
echo "" >> "$REPORT"
echo "End: $(date)" >> "$REPORT"
echo "================================================================" >> "$REPORT"

# Cleanup
rm -rf "$FAKE_HTTP_DIR" 2>/dev/null

PROMPT "DECOY MONITORING COMPLETE

Duration: ${DURATION} min
Total alerts: $ALERT_COUNT

$([ $ALERT_COUNT -gt 0 ] && echo 'ATTACKER ACTIVITY DETECTED!' || echo 'No suspicious activity.')

Report: $REPORT
Alerts: $ALERT_LOG"
