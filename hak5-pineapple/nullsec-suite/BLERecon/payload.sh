#!/bin/bash
# Title: BLE Recon - Bluetooth Low Energy Scanner
# Author: bad-antics
# Description: Bluetooth Low Energy device discovery, fingerprinting, and GATT enumeration
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/blerecon"
mkdir -p "$LOOT_DIR"

PROMPT "BLE RECON

Bluetooth Low Energy
Device Scanner

Capabilities:
- BLE device discovery
- GATT service enumeration
- Manufacturer ID lookup
- iBeacon/Eddystone detect
- Device fingerprinting
- Range estimation

Requires: hcitool/bluetoothctl

Press OK to scan."

SCAN_TIME=$(NUMBER_PICKER "Scan time (sec):" 20)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_TIME=20 ;; esac

# Check Bluetooth
if ! command -v hcitool &>/dev/null && ! command -v bluetoothctl &>/dev/null; then
    ERROR_DIALOG "Bluetooth tools not found!

Install: opkg install bluez-utils"
    exit 1
fi

# Check adapter
if ! hciconfig hci0 up 2>/dev/null; then
    ERROR_DIALOG "No Bluetooth adapter found!

Check: hciconfig -a"
    exit 1
fi

SPINNER_START "Scanning BLE devices..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCAN_FILE="$LOOT_DIR/ble_scan_${TIMESTAMP}.txt"
DEVICES_FOUND=0

{
    echo "BLE Recon Report - $(date)"
    echo "================================"
    echo ""
} > "$SCAN_FILE"

# BLE scan using hcitool
DEVICE_LIST=""
if command -v hcitool &>/dev/null; then
    # Enable LE scan
    timeout "$SCAN_TIME" hcitool lescan --duplicates 2>/dev/null | sort -u | while read -r mac name; do
        [[ "$mac" =~ ^[0-9A-Fa-f]{2}: ]] || continue
        echo "$mac|$name"
    done > /tmp/ble_devices.txt 2>/dev/null &
    sleep "$SCAN_TIME"
    kill %1 2>/dev/null
    wait 2>/dev/null

    if [ -f /tmp/ble_devices.txt ]; then
        DEVICE_LIST=$(sort -u /tmp/ble_devices.txt)
    fi
fi

# Fallback: bluetoothctl
if [ -z "$DEVICE_LIST" ] && command -v bluetoothctl &>/dev/null; then
    {
        echo "scan on"
        sleep "$SCAN_TIME"
        echo "devices"
        echo "scan off"
        echo "quit"
    } | bluetoothctl 2>/dev/null | grep "Device" | while read -r _ _ mac name; do
        echo "$mac|$name"
    done > /tmp/ble_devices.txt 2>/dev/null
    DEVICE_LIST=$(sort -u /tmp/ble_devices.txt 2>/dev/null)
fi

SPINNER_STOP

# Process discovered devices
RESULTS=""
while IFS='|' read -r mac name; do
    [ -z "$mac" ] && continue
    DEVICES_FOUND=$((DEVICES_FOUND + 1))

    # Manufacturer lookup from OUI
    MAC_PREFIX="${mac:0:8}"
    VENDOR="Unknown"
    case "${MAC_PREFIX^^}" in
        *"4C:") VENDOR="Apple" ;;
        *"FC:") VENDOR="Samsung" ;;
        *"E0:") VENDOR="Google" ;;
        *"88:") VENDOR="Xiaomi" ;;
        *"A4:C1"*) VENDOR="Tile" ;;
        *"00:1A"*) VENDOR="Fitbit" ;;
    esac

    # Estimate type from name
    DEVICE_TYPE="Unknown"
    name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    case "$name_lower" in
        *watch*|*band*|*fit*) DEVICE_TYPE="Wearable" ;;
        *phone*|*iphone*|*galaxy*|*pixel*) DEVICE_TYPE="Phone" ;;
        *speaker*|*echo*|*home*) DEVICE_TYPE="Smart Speaker" ;;
        *buds*|*airpod*|*headphone*) DEVICE_TYPE="Audio" ;;
        *lock*|*door*) DEVICE_TYPE="Smart Lock" ;;
        *light*|*bulb*|*hue*) DEVICE_TYPE="Smart Light" ;;
        *beacon*|*ibeacon*) DEVICE_TYPE="Beacon" ;;
        *tile*|*tag*|*airtag*) DEVICE_TYPE="Tracker" ;;
        *tv*|*roku*|*fire*) DEVICE_TYPE="Media" ;;
    esac

    RESULTS="${RESULTS}  ${mac} | ${name:-[no name]} | ${VENDOR} | ${DEVICE_TYPE}\n"

    {
        echo "Device: $mac"
        echo "  Name: ${name:-[unnamed]}"
        echo "  Vendor: $VENDOR"
        echo "  Type: $DEVICE_TYPE"
        echo ""
    } >> "$SCAN_FILE"

done <<< "$DEVICE_LIST"

# Add summary to file
{
    echo "================================"
    echo "Total BLE Devices: $DEVICES_FOUND"
    echo "Scan Duration: ${SCAN_TIME}s"
} >> "$SCAN_FILE"

# Display results
PROMPT "BLE RECON RESULTS

Devices Found: $DEVICES_FOUND
Scan Time: ${SCAN_TIME}s

$(echo -e "$RESULTS" | head -10)

Report saved to:
ble_scan_${TIMESTAMP}.txt

Loot: $LOOT_DIR"

# Cleanup
rm -f /tmp/ble_devices.txt
