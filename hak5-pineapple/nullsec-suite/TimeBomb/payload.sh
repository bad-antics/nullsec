#!/bin/bash
# Title: TimeBomb - Scheduled Payload Execution
# Author: bad-antics
# Description: Schedule delayed payload execution
# Category: nullsec/util

TIMEBOMB_DIR="/mmc/nullsec/timebomb"
mkdir -p "$TIMEBOMB_DIR"

PROMPT "TIMEBOMB - SCHEDULER

Schedule payloads to run
after a delay.

Actions:
1. Schedule new payload
2. List scheduled
3. Clear all scheduled

Press OK to continue."

ACTION=$(NUMBER_PICKER "Action (1-3):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

SCHEDULE_FILE="$TIMEBOMB_DIR/scheduled.txt"

case $ACTION in
    2)
        # List scheduled
        if [ -f "$SCHEDULE_FILE" ] && [ -s "$SCHEDULE_FILE" ]; then
            JOBS=$(cat "$SCHEDULE_FILE")
            PROMPT "SCHEDULED PAYLOADS:

$JOBS

Press OK to exit."
        else
            PROMPT "No payloads scheduled.

Press OK to exit."
        fi
        exit 0
        ;;
    3)
        resp=$(CONFIRMATION_DIALOG "CLEAR ALL TIMEBOMBS?

Remove all scheduled
payload executions?")
        [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ] && {
            > "$SCHEDULE_FILE"
            [ -f "$TIMEBOMB_DIR/watcher.pid" ] && kill $(cat "$TIMEBOMB_DIR/watcher.pid") 2>/dev/null
            PROMPT "All timebombs cleared."
        }
        exit 0
        ;;
esac

# Schedule new payload
PROMPT "AVAILABLE PAYLOADS:

$(ls /root/payloads/user/nullsec/ 2>/dev/null | head -15)

Enter payload name next."

PAYLOAD_NAME=$(TEXT_PICKER "Payload name:" "DeauthStorm")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

PAYLOAD_PATH="/root/payloads/user/nullsec/$PAYLOAD_NAME/payload.sh"
[ ! -f "$PAYLOAD_PATH" ] && { ERROR_DIALOG "Payload not found: $PAYLOAD_NAME"; exit 1; }

DELAY_MIN=$(NUMBER_PICKER "Delay (minutes):" 5)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

resp=$(CONFIRMATION_DIALOG "SCHEDULE TIMEBOMB?

Payload: $PAYLOAD_NAME
Delay: ${DELAY_MIN} minutes

Press OK to schedule.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

DELAY_SEC=$((DELAY_MIN * 60))
EXEC_TIME=$(($(date +%s) + DELAY_SEC))
JOB_ID="TB_$(date +%s)"

echo "$JOB_ID | $PAYLOAD_NAME | in ${DELAY_MIN}m | pending" >> "$SCHEDULE_FILE"

LOG "TimeBomb set: $PAYLOAD_NAME in ${DELAY_MIN}m"

# Start background watcher
(
    sleep "$DELAY_SEC"
    bash "$PAYLOAD_PATH" >> "$TIMEBOMB_DIR/exec_log.txt" 2>&1
    sed -i "s/$JOB_ID.*pending/$JOB_ID | $PAYLOAD_NAME | executed/" "$SCHEDULE_FILE"
) &
echo $! > "$TIMEBOMB_DIR/watcher_${JOB_ID}.pid"

PROMPT "TIMEBOMB SET!

Payload: $PAYLOAD_NAME
Fires in: ${DELAY_MIN} minutes
Job ID: $JOB_ID

Press OK to exit."
