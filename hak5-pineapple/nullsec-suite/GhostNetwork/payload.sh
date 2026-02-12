#!/bin/bash
# Title: Ghost Network
# Author: NullSec
# Description: Create hidden covert network for stealth ops
# Category: nullsec/stealth

LOOT_DIR="/mmc/nullsec/ghost"
mkdir -p "$LOOT_DIR"

PROMPT "GHOST NETWORK

Create an invisible hidden
WiFi network for covert
operations.

Network will not appear
in normal WiFi scans.

Press OK to configure."

GHOST_CH=$(NUMBER_PICKER "Channel (1-11):" 6)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) GHOST_CH=6 ;; esac

DURATION=$(NUMBER_PICKER "Duration (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac
DURATION_SEC=$((DURATION * 60))

resp=$(CONFIRMATION_DIALOG "DEPLOY GHOST NETWORK?

Channel: $GHOST_CH
Duration: ${DURATION} min
SSID: (hidden)

Clients need SSID to connect.

Press OK to deploy.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

GHOST_IF="wlan1"
# Stop monitor mode to use AP mode
airmon-ng stop wlan1mon 2>/dev/null
sleep 1

LOG_FILE="$LOOT_DIR/ghost_$(date +%Y%m%d_%H%M).log"

cat > /tmp/ghost_hostapd.conf << EOF
interface=$GHOST_IF
driver=nl80211
ssid=nullsec_ghost
channel=$GHOST_CH
hw_mode=g
ieee80211n=1
ignore_broadcast_ssid=2
beacon_int=1000
auth_algs=1
wpa=2
wpa_passphrase=nullsec_ghost_key
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

ifconfig "$GHOST_IF" up 2>/dev/null
hostapd /tmp/ghost_hostapd.conf -B 2>/dev/null
sleep 2
ifconfig "$GHOST_IF" 10.66.66.1 netmask 255.255.255.0

LOG "Ghost network active on CH:$GHOST_CH"

# Run for duration
sleep "$DURATION_SEC"

killall hostapd 2>/dev/null
airmon-ng start wlan1 2>/dev/null

PROMPT "GHOST NETWORK STOPPED

Channel: $GHOST_CH
Duration: ${DURATION} min
Log: $LOG_FILE

Press OK to exit."
