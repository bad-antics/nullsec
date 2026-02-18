#!/bin/bash
# Title: Signal Hound
# Author: bad-antics
# Description: RF signal intelligence — detect and analyze wireless signals across spectrum
# Category: nullsec/sigint

LOOT_DIR="/mmc/nullsec/signal-hound"
mkdir -p "$LOOT_DIR"

PROMPT "SIGNAL HOUND

RF Signal Intelligence.

Detects and analyzes:
- WiFi (2.4/5GHz)
- Bluetooth devices
- Zigbee/Z-Wave IoT
- Hidden cameras (RF)
- Rogue transmitters
- Signal strength mapping

Press OK to begin."

PROMPT "SCAN MODE

1. Full spectrum sweep
2. WiFi deep analysis
3. Bluetooth discovery
4. IoT device hunt
5. RF anomaly detection
6. Signal strength map

Select on next screen."

MODE=$(NUMBER_PICKER "Mode (1-6):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=1 ;; esac

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$LOOT_DIR/sigint_${TIMESTAMP}.txt"

SPINNER_START "Scanning spectrum..."

case $MODE in
    1)
        echo "=== FULL SPECTRUM SWEEP ===" > "$REPORT"
        echo "Timestamp: $(date)" >> "$REPORT"
        echo "" >> "$REPORT"
        
        echo "--- WiFi Networks ---" >> "$REPORT"
        iwlist wlan0 scan 2>/dev/null | grep -E "ESSID|Signal|Encryption|Channel" >> "$REPORT"
        WIFI_COUNT=$(iwlist wlan0 scan 2>/dev/null | grep -c "ESSID")
        
        echo "" >> "$REPORT"
        echo "--- Bluetooth Devices ---" >> "$REPORT"
        if command -v hcitool &>/dev/null; then
            timeout 15 hcitool scan 2>/dev/null >> "$REPORT"
            timeout 15 hcitool lescan --duplicates 2>/dev/null | head -30 >> "$REPORT"
            BT_COUNT=$(timeout 10 hcitool scan 2>/dev/null | grep -c ":")
        else
            echo "No Bluetooth adapter" >> "$REPORT"
            BT_COUNT=0
        fi
        
        echo "" >> "$REPORT"
        echo "--- Channel Utilization ---" >> "$REPORT"
        for ch in 1 6 11 36 40 44 48; do
            iwconfig wlan0 channel $ch 2>/dev/null
            NOISE=$(iwconfig wlan0 2>/dev/null | grep -oP "Noise level[=:]\K[^ ]+")
            echo "Channel $ch: noise=$NOISE" >> "$REPORT"
        done
        ;;
    2)
        echo "=== WIFI DEEP ANALYSIS ===" > "$REPORT"
        timeout 30 airodump-ng wlan0 --write-interval 5 -w /tmp/sighound --output-format csv 2>/dev/null
        
        if [ -f /tmp/sighound-01.csv ]; then
            echo "--- Access Points ---" >> "$REPORT"
            grep "WPA\|WEP\|OPN" /tmp/sighound*.csv 2>/dev/null | while IFS=, read -r bssid ft lt ch sp priv ciph auth pwr bea iv lip idl essid key; do
                essid=$(echo "$essid" | tr -d " ")
                pwr=$(echo "$pwr" | tr -d " ")
                priv=$(echo "$priv" | tr -d " ")
                ch=$(echo "$ch" | tr -d " ")
                echo "  $essid | Ch:$ch | $priv | $pwr dBm" >> "$REPORT"
            done
            
            echo "" >> "$REPORT"
            echo "--- Clients ---" >> "$REPORT"
            grep -E "^([0-9A-Fa-f]{2}:){5}" /tmp/sighound*.csv 2>/dev/null | grep -v BSSID >> "$REPORT"
            WIFI_COUNT=$(grep -c "WPA\|WEP\|OPN" /tmp/sighound*.csv 2>/dev/null)
        fi
        rm -f /tmp/sighound* 2>/dev/null
        ;;
    3)
        echo "=== BLUETOOTH DISCOVERY ===" > "$REPORT"
        if command -v hcitool &>/dev/null; then
            hciconfig hci0 up 2>/dev/null
            echo "--- Classic Bluetooth ---" >> "$REPORT"
            timeout 20 hcitool scan 2>/dev/null >> "$REPORT"
            echo "--- BLE Devices ---" >> "$REPORT"
            timeout 20 hcitool lescan 2>/dev/null | sort -u | head -50 >> "$REPORT"
            BT_COUNT=$(grep -c ":" "$REPORT")
        else
            echo "Bluetooth not available" >> "$REPORT"
            BT_COUNT=0
        fi
        ;;
    4)
        echo "=== IoT DEVICE HUNT ===" > "$REPORT"
        SUBNET=$(ip -4 addr show | grep -oP "(\d+\.){3}0/\d+" | head -1)
        nmap -sn "$SUBNET" -oG - 2>/dev/null | grep "Up" | while read -r line; do
            IP=$(echo "$line" | grep -oP "(\d+\.){3}\d+")
            MAC=$(nmap -sn "$IP" 2>/dev/null | grep -oP "([0-9A-F]{2}:){5}[0-9A-F]{2}" | head -1)
            VENDOR=$(nmap -sn "$IP" 2>/dev/null | grep -oP "(?<=\().*?(?=\))" | tail -1)
            echo "  $IP | $MAC | $VENDOR" >> "$REPORT"
        done
        
        echo "" >> "$REPORT"
        echo "--- IoT Ports ---" >> "$REPORT"
        nmap "$SUBNET" -p 80,443,8080,8443,1883,5683,5684,8883,554,49152 --open -T4 2>/dev/null | \
            grep -E "open|Nmap scan" >> "$REPORT"
        ;;
    5)
        echo "=== RF ANOMALY DETECTION ===" > "$REPORT"
        echo "Monitoring for unusual transmissions..." >> "$REPORT"
        for i in $(seq 1 5); do
            echo "--- Sweep $i ---" >> "$REPORT"
            iwlist wlan0 scan 2>/dev/null | grep -E "ESSID|Signal" >> "$REPORT"
            sleep 10
        done
        echo "--- Hidden Networks ---" >> "$REPORT"
        iwlist wlan0 scan 2>/dev/null | grep -B2 ESSID: >> "$REPORT"
        HIDDEN=$(iwlist wlan0 scan 2>/dev/null | grep -c ESSID:)
        echo "Hidden networks found: $HIDDEN" >> "$REPORT"
        ;;
    6)
        echo "=== SIGNAL STRENGTH MAP ===" > "$REPORT"
        echo "Measuring signal levels..." >> "$REPORT"
        for i in $(seq 1 10); do
            iwlist wlan0 scan 2>/dev/null | grep -E "ESSID|Signal" | paste - - | \
                awk -F: "{printf \"Sample $i: %s %s\n\", \$2, \$4}" >> "$REPORT"
            sleep 5
        done
        ;;
esac

SPINNER_STOP

TOTAL_SIGNALS=$(grep -c ":" "$REPORT" 2>/dev/null)

PROMPT "SIGNAL HOUND COMPLETE

Signals detected: $TOTAL_SIGNALS
WiFi: ${WIFI_COUNT:-n/a}
Bluetooth: ${BT_COUNT:-n/a}

Report saved to:
signal-hound/

Press OK to exit."
