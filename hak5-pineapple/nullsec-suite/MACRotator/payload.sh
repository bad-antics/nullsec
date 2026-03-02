#!/bin/bash
# Title: MAC Rotator
# Author: bad-antics
# Description: Automated MAC address rotation for stealth wireless operations
# Category: nullsec/stealth

LOOT_DIR="/mmc/nullsec/macrotator"
mkdir -p "$LOOT_DIR"

PROMPT "MAC ROTATOR

Automated MAC address rotation
for stealth wireless operations.

Features:
- Timed MAC rotation intervals
- OUI-realistic MAC generation
- Vendor-specific spoofing
- Activity logging per MAC
- Rotation on trigger events
- MAC history tracking

Press OK to configure."

# Select interface
IFACE=$(TEXT_PICKER "Interface:" "wlan1")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) IFACE="wlan1" ;; esac

# Verify interface
[ ! -d "/sys/class/net/$IFACE" ] && { ERROR_DIALOG "Interface $IFACE not found!"; exit 1; }

ORIGINAL_MAC=$(cat "/sys/class/net/$IFACE/address" 2>/dev/null)
[ -z "$ORIGINAL_MAC" ] && { ERROR_DIALOG "Cannot read MAC from $IFACE!"; exit 1; }

# Rotation interval
INTERVAL=$(NUMBER_PICKER "Rotation interval (sec):" 300)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) INTERVAL=300 ;; esac

# Number of rotations (0 = infinite)
ROTATIONS=$(NUMBER_PICKER "Number of rotations (0=inf):" 10)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) ROTATIONS=10 ;; esac

# MAC generation method
resp=$(CONFIRMATION_DIALOG "USE VENDOR-SPECIFIC OUIs?

YES = Generate MACs matching
real vendor prefixes (stealthier)

NO = Fully random MACs

Press OK for vendor-specific.")
if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    MAC_MODE="vendor"
else
    MAC_MODE="random"
fi

# Common wireless OUI prefixes
OUIS=(
    "00:0C:29" # VMware
    "00:50:56" # VMware
    "3C:5A:B4" # Google
    "AC:BC:32" # Apple
    "F8:E0:79" # Motorola
    "DC:A6:32" # Raspberry Pi
    "B8:27:EB" # Raspberry Pi
    "00:1A:2B" # Ayecom
    "00:26:AB" # Seiko Epson
    "48:D7:05" # Intel
    "A4:34:D9" # Intel
    "00:15:5D" # Microsoft Hyper-V
    "5C:CF:7F" # Espressif
    "CC:50:E3" # Amazon
    "FC:65:DE" # Samsung
    "00:1E:C2" # Apple
)

gen_mac() {
    if [ "$MAC_MODE" = "vendor" ]; then
        OUI=${OUIS[$((RANDOM % ${#OUIS[@]}))]}
        TAIL=$(printf '%02X:%02X:%02X' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))
        echo "${OUI}:${TAIL}"
    else
        printf '%02X:%02X:%02X:%02X:%02X:%02X' \
            $((RANDOM % 256 & 0xFE | 0x02)) \
            $((RANDOM % 256)) $((RANDOM % 256)) \
            $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256))
    fi
}

set_mac() {
    local new_mac="$1"
    ip link set "$IFACE" down 2>/dev/null
    ip link set "$IFACE" address "$new_mac" 2>/dev/null
    ip link set "$IFACE" up 2>/dev/null
    sleep 1
    CURRENT=$(cat "/sys/class/net/$IFACE/address" 2>/dev/null)
    [ "$(echo "$CURRENT" | tr 'A-Z' 'a-z')" = "$(echo "$new_mac" | tr 'A-Z' 'a-z')" ]
}

TIMESTAMP=$(date +%Y%m%d_%H%M)
LOG_FILE="$LOOT_DIR/rotation_${TIMESTAMP}.log"

resp=$(CONFIRMATION_DIALOG "START MAC ROTATION?

Interface: $IFACE
Original MAC: $ORIGINAL_MAC
Mode: $MAC_MODE OUI
Interval: ${INTERVAL}s
Rotations: ${ROTATIONS:-infinite}

MAC will rotate every ${INTERVAL}s.
Original MAC restored on exit.

Press OK to start.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "MAC rotation active..."

echo "MAC ROTATION LOG — $(date)" > "$LOG_FILE"
echo "Interface: $IFACE | Original: $ORIGINAL_MAC" >> "$LOG_FILE"
echo "Mode: $MAC_MODE | Interval: ${INTERVAL}s" >> "$LOG_FILE"
echo "======================================" >> "$LOG_FILE"

TOTAL=0
SUCCESS=0
FAIL=0
COUNT=0

# Trap to restore original MAC
cleanup() {
    set_mac "$ORIGINAL_MAC"
    echo "" >> "$LOG_FILE"
    echo "--- RESTORED: $ORIGINAL_MAC ---" >> "$LOG_FILE"
    echo "Total rotations: $TOTAL | Success: $SUCCESS | Fail: $FAIL" >> "$LOG_FILE"
}
trap cleanup EXIT

while true; do
    [ "$ROTATIONS" -gt 0 ] 2>/dev/null && [ $COUNT -ge $ROTATIONS ] && break

    NEW_MAC=$(gen_mac)
    TOTAL=$((TOTAL + 1))
    COUNT=$((COUNT + 1))

    LOG "Rotation $COUNT — Setting $NEW_MAC..."

    if set_mac "$NEW_MAC"; then
        SUCCESS=$((SUCCESS + 1))
        STATUS="OK"
        LOG "MAC set: $NEW_MAC"
    else
        FAIL=$((FAIL + 1))
        STATUS="FAIL"
        LOG "Failed to set: $NEW_MAC"
    fi

    echo "[$(date '+%H:%M:%S')] #$COUNT $NEW_MAC — $STATUS" >> "$LOG_FILE"

    # Wait for next rotation
    sleep "$INTERVAL"
done

SPINNER_STOP

# Restore original
set_mac "$ORIGINAL_MAC"

PROMPT "MAC ROTATION COMPLETE

Interface: $IFACE
Rotations: $TOTAL
Successful: $SUCCESS
Failed: $FAIL

Original MAC restored:
$ORIGINAL_MAC

Log: $LOG_FILE"
