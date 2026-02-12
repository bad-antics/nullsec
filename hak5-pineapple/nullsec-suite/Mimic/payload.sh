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
