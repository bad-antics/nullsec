#!/bin/bash
# Title: Honeypot
# Author: NullSec
# Description: Decoy AP that logs all connection attempts
# Category: nullsec/defense

LOOT_DIR="/mmc/nullsec/honeypot"
mkdir -p "$LOOT_DIR"

PROMPT "HONEYPOT AP

Deploy a decoy access point
with weak credentials to
detect and log attackers.

Monitors:
- Connection attempts
- Authentication tries
- Client behavior

Press OK to configure."

SSID=$(TEXT_PICKER "Honeypot SSID:" "Free_WiFi_Secure")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SSID="Free_WiFi_Secure" ;; esac

HP_PASS=$(TEXT_PICKER "Weak password:" "password123")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) HP_PASS="password123" ;; esac

DURATION=$(NUMBER_PICKER "Duration (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac
DURATION_SEC=$((DURATION * 60))

resp=$(CONFIRMATION_DIALOG "DEPLOY HONEYPOT?

SSID: $SSID
Password: $HP_PASS
Duration: ${DURATION} min

All activity will be logged.

Press OK to deploy.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

HP_IF="wlan1"
airmon-ng stop wlan1mon 2>/dev/null
sleep 1

LOG_FILE="$LOOT_DIR/honeypot_$(date +%Y%m%d_%H%M).log"
ALERT_FILE="$LOOT_DIR/alerts_$(date +%Y%m%d_%H%M).txt"

cat > /tmp/hp_hostapd.conf << EOF
interface=$HP_IF
driver=nl80211
ssid=$SSID
channel=6
hw_mode=g
auth_algs=1
wpa=2
wpa_passphrase=$HP_PASS
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
logger_stdout=-1
logger_stdout_level=2
EOF

ifconfig "$HP_IF" up
hostapd /tmp/hp_hostapd.conf > /tmp/hp_log.txt 2>&1 &
HP_PID=$!
sleep 2

ifconfig "$HP_IF" 192.168.99.1 netmask 255.255.255.0 2>/dev/null

# Capture traffic
tcpdump -i "$HP_IF" -w "$LOOT_DIR/hp_capture_$(date +%Y%m%d_%H%M).pcap" 2>/dev/null &
TCP_PID=$!

LOG "Honeypot deployed: $SSID"

# Monitor for the duration
END=$(($(date +%s) + DURATION_SEC))
while [ $(date +%s) -lt $END ]; do
    # Check for new associations
    if [ -f /tmp/hp_log.txt ]; then
        grep -i "associated\|authenticated\|deauth" /tmp/hp_log.txt 2>/dev/null | tail -5 >> "$ALERT_FILE"
        > /tmp/hp_log.txt
    fi
    CLIENTS=$(iw dev "$HP_IF" station dump 2>/dev/null | grep -c "Station")
    [ "$CLIENTS" -gt 0 ] && echo "$(date) Active clients: $CLIENTS" >> "$LOG_FILE"
    sleep 10
done

kill $HP_PID $TCP_PID 2>/dev/null
killall hostapd tcpdump 2>/dev/null
airmon-ng start wlan1 2>/dev/null

ALERT_COUNT=$(wc -l < "$ALERT_FILE" 2>/dev/null || echo 0)

PROMPT "HONEYPOT STOPPED

SSID: $SSID
Duration: ${DURATION} min
Alerts: $ALERT_COUNT
Log: $LOG_FILE

Press OK to exit."
