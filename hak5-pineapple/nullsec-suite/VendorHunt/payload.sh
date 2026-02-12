#!/bin/bash
# Title: Vendor Hunt
# Author: bad-antics
# Description: Find devices by manufacturer
# Category: nullsec/recon

# OUI database (manufacturer:prefix pairs)
declare -A OUI_MAP
# Apple
for p in 00:0A:95 00:1C:B3 00:03:93 00:17:F2 AC:DE:48 3C:06:30 00:23:12 FC:FC:48 00:26:BB 70:56:81 40:33:1A A4:D1:8C 00:1E:C2 64:20:0C 78:CA:39 00:0D:93; do
    OUI_MAP["$p"]="Apple"
done
# Samsung
for p in 00:26:5E 00:1A:8A 00:12:47 00:15:99 00:1D:F6 00:21:D2 00:24:91 00:26:37 5C:0A:5B 84:25:DB E4:7C:F9 78:D6:F0; do
    OUI_MAP["$p"]="Samsung"
done
# Amazon
for p in 00:17:FA 40:B4:CD 44:65:0D 68:54:FD 74:C2:46 A0:02:DC FC:A6:67 18:74:2E B0:FC:36 68:37:E9 50:DC:E7 00:FC:8B; do
    OUI_MAP["$p"]="Amazon"
done
# Google
for p in 00:1A:11 3C:5A:B4 54:60:09 94:EB:2C F4:F5:D8 20:DF:B9 30:FD:38 18:B4:30 64:16:66; do
    OUI_MAP["$p"]="Google"
done
# Cisco
for p in 00:0C:76 00:40:96 00:50:0F 00:17:94 00:21:1C 00:24:C3 00:18:74 00:22:55 18:33:9D F4:CF:E2; do
    OUI_MAP["$p"]="Cisco"
done
# Raspberry Pi
for p in B8:27:EB DC:A6:32 E4:5F:01 28:CD:C1 D8:3A:DD; do
    OUI_MAP["$p"]="Raspberry_Pi"
done
# Microsoft
for p in 00:0D:3A 00:12:5A 00:15:5D 00:50:F2 28:18:78 60:45:BD; do
    OUI_MAP["$p"]="Microsoft"
done

PROMPT "VENDOR HUNT

Find devices by their
manufacturer (Apple,
Samsung, Cisco, etc).

Press OK to configure."

PROMPT "TARGET VENDOR:

1. Apple
2. Samsung
3. Amazon
4. Google/Nest
5. Cisco
6. Raspberry Pi
7. All vendors
8. Custom OUI prefix

Select on next screen."

VENDOR_CHOICE=$(NUMBER_PICKER "Vendor (1-8):" 7)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) VENDOR_CHOICE=7 ;; esac

VENDOR_FILTER=""
CUSTOM_OUI=""
case $VENDOR_CHOICE in
    1) VENDOR_FILTER="Apple" ;;
    2) VENDOR_FILTER="Samsung" ;;
    3) VENDOR_FILTER="Amazon" ;;
    4) VENDOR_FILTER="Google" ;;
    5) VENDOR_FILTER="Cisco" ;;
    6) VENDOR_FILTER="Raspberry_Pi" ;;
    7) VENDOR_FILTER="" ;;
    8) CUSTOM_OUI=$(TEXT_PICKER "OUI prefix (XX:XX:XX):" "B8:27:EB")
       VENDOR_FILTER="CUSTOM" ;;
esac

# Use existing monitor interface
MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

DURATION=$(NUMBER_PICKER "Scan duration (sec):" 20)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=20 ;; esac

resp=$(CONFIRMATION_DIALOG "START VENDOR HUNT?

Vendor: ${VENDOR_FILTER:-All}
Interface: $MON_IF
Duration: ${DURATION}s

Press OK to scan.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Hunting ${VENDOR_FILTER:-all} devices..."

TEMP_DIR="/tmp/vendorhunt_$$"
mkdir -p "$TEMP_DIR"
rm -f /tmp/vendorhunt_*
timeout "$DURATION" airodump-ng "$MON_IF" -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
sleep "$DURATION"
killall airodump-ng 2>/dev/null

SPINNER_STOP

LOOT_DIR="/mmc/nullsec/vendor_hunt"
mkdir -p "$LOOT_DIR"
LOOT_FILE="$LOOT_DIR/${VENDOR_FILTER:-all}_$(date +%Y%m%d_%H%M%S).txt"

echo "Vendor Hunt: ${VENDOR_FILTER:-All Vendors}" > "$LOOT_FILE"
echo "Date: $(date)" >> "$LOOT_FILE"
echo "---" >> "$LOOT_FILE"

FOUND=0

if [ -f "$TEMP_DIR/scan-01.csv" ]; then
    # Extract all MACs from the scan
    grep -oE "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" "$TEMP_DIR/scan-01.csv" 2>/dev/null | sort -u | while read MAC; do
        OUI=$(echo "$MAC" | cut -d':' -f1-3 | tr '[:lower:]' '[:upper:]')

        MATCHED_VENDOR=""
        if [ "$VENDOR_FILTER" = "CUSTOM" ]; then
            CUSTOM_UPPER=$(echo "$CUSTOM_OUI" | tr '[:lower:]' '[:upper:]')
            [ "$OUI" = "$CUSTOM_UPPER" ] && MATCHED_VENDOR="Custom($CUSTOM_OUI)"
        elif [ -n "${OUI_MAP[$OUI]+x}" ]; then
            MATCHED_VENDOR="${OUI_MAP[$OUI]}"
            if [ -n "$VENDOR_FILTER" ] && [ "$MATCHED_VENDOR" != "$VENDOR_FILTER" ]; then
                continue
            fi
        else
            [ -n "$VENDOR_FILTER" ] && [ "$VENDOR_FILTER" != "" ] && continue
            MATCHED_VENDOR="Unknown"
        fi

        [ -z "$MATCHED_VENDOR" ] && continue
        echo "$MATCHED_VENDOR: $MAC" >> "$LOOT_FILE"
        FOUND=$((FOUND + 1))
    done
fi

# Count from file since the while loop was in a subshell
FOUND=$(grep -c ": " "$LOOT_FILE" 2>/dev/null || echo 0)
FOUND=$((FOUND - 1))  # subtract header line
[ "$FOUND" -lt 0 ] && FOUND=0

rm -rf "$TEMP_DIR"

PROMPT "VENDOR HUNT COMPLETE

Found: $FOUND devices
Filter: ${VENDOR_FILTER:-All}
Results: $LOOT_FILE

Press OK to exit."
