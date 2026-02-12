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
