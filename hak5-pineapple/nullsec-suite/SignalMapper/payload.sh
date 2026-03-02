#!/bin/bash
# Title: Signal Mapper
# Author: bad-antics
# Description: WiFi signal strength survey and coverage mapping
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/signalmap"
mkdir -p "$LOOT_DIR"

PROMPT "SIGNAL MAPPER

Survey wireless signal strength
across all detected networks.

Generates:
- Signal strength rankings
- Channel utilization chart
- Interference analysis
- Weakest/strongest AP report
- Coverage quality scores
- Best channel recommendation

Press OK to configure."

[ ! -d "/sys/class/net/wlan0" ] && { ERROR_DIALOG "wlan0 not found!"; exit 1; }

SAMPLES=$(NUMBER_PICKER "Sample count:" 5)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SAMPLES=5 ;; esac

SAMPLE_DURATION=$(NUMBER_PICKER "Seconds per sample:" 10)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SAMPLE_DURATION=10 ;; esac

TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT="$LOOT_DIR/signalmap_${TIMESTAMP}.txt"

resp=$(CONFIRMATION_DIALOG "START SURVEY?

Samples: $SAMPLES x ${SAMPLE_DURATION}s
Total time: ~$((SAMPLES * (SAMPLE_DURATION + 2))) sec
Mode: Passive scan

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Starting signal survey..."
SPINNER_START "Surveying signals..."

declare -A AP_POWER_SUM
declare -A AP_POWER_COUNT
declare -A AP_POWER_MIN
declare -A AP_POWER_MAX
declare -A AP_INFO
declare -A CHANNEL_COUNT

for ((s=1; s<=SAMPLES; s++)); do
    LOG "Sample $s/$SAMPLES"
    SNAP="/tmp/sigmap_snap"
    rm -f "${SNAP}"*.csv 2>/dev/null

    timeout $SAMPLE_DURATION airodump-ng wlan0 --write-interval 5 -w "$SNAP" --output-format csv 2>/dev/null

    [ ! -f "${SNAP}-01.csv" ] && continue

    while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons iv lan_ip id_len essid rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        essid=$(echo "$essid" | sed 's/^ *//;s/ *$//')
        channel=$(echo "$channel" | tr -d ' ')
        power=$(echo "$power" | tr -d ' ')
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
        [ -z "$power" ] || [ "$power" = "-1" ] && continue

        power_int=${power//-/}
        power_int=$((0 - power_int))

        AP_POWER_SUM[$bssid]=$(( ${AP_POWER_SUM[$bssid]:-0} + power_int ))
        AP_POWER_COUNT[$bssid]=$(( ${AP_POWER_COUNT[$bssid]:-0} + 1 ))

        # Track min/max
        if [ -z "${AP_POWER_MIN[$bssid]}" ] || [ "$power_int" -gt "${AP_POWER_MIN[$bssid]}" ]; then
            AP_POWER_MIN[$bssid]=$power_int
        fi
        if [ -z "${AP_POWER_MAX[$bssid]}" ] || [ "$power_int" -lt "${AP_POWER_MAX[$bssid]}" ]; then
            AP_POWER_MAX[$bssid]=$power_int
        fi

        [ -z "$essid" ] && essid="<hidden>"
        AP_INFO[$bssid]="$essid|$channel|$privacy"

        # Channel utilization
        CHANNEL_COUNT[$channel]=$(( ${CHANNEL_COUNT[$channel]:-0} + 1 ))
    done < "${SNAP}-01.csv"

    sleep 2
done

SPINNER_STOP

AP_TOTAL=${#AP_POWER_COUNT[@]}

echo "================================================================" > "$REPORT"
echo "         NULLSEC SIGNAL MAPPER REPORT                          " >> "$REPORT"
echo "================================================================" >> "$REPORT"
echo "Time: $(date)" >> "$REPORT"
echo "Samples: $SAMPLES x ${SAMPLE_DURATION}s" >> "$REPORT"
echo "Networks detected: $AP_TOTAL" >> "$REPORT"
echo "" >> "$REPORT"

# Signal rankings (strongest to weakest)
echo "--- SIGNAL STRENGTH RANKING ---" >> "$REPORT"
echo "(Strongest first, dBm)" >> "$REPORT"
echo "" >> "$REPORT"

SORTED=""
for bssid in "${!AP_POWER_SUM[@]}"; do
    avg=$(( AP_POWER_SUM[$bssid] / AP_POWER_COUNT[$bssid] ))
    SORTED="${SORTED}${avg} ${bssid}\n"
done

echo -e "$SORTED" | sort -rn | while read -r avg bssid; do
    [ -z "$bssid" ] && continue
    IFS='|' read -r essid ch priv <<< "${AP_INFO[$bssid]}"
    min=${AP_POWER_MIN[$bssid]}
    max=${AP_POWER_MAX[$bssid]}

    # Quality score
    if [ "$avg" -ge -50 ]; then quality="EXCELLENT"
    elif [ "$avg" -ge -60 ]; then quality="GOOD"
    elif [ "$avg" -ge -70 ]; then quality="FAIR"
    elif [ "$avg" -ge -80 ]; then quality="WEAK"
    else quality="VERY WEAK"
    fi

    # Signal bar visualization
    bar_len=$(( (avg + 100) / 5 ))
    [ $bar_len -lt 0 ] && bar_len=0
    [ $bar_len -gt 10 ] && bar_len=10
    bar=$(printf '%*s' "$bar_len" | tr ' ' '#')
    bar_empty=$(printf '%*s' $((10 - bar_len)) | tr ' ' '-')

    printf "  %-20s [%s%s] %4ddBm (%s)\n" "$essid" "$bar" "$bar_empty" "$avg" "$quality" >> "$REPORT"
    printf "    BSSID: %s | Ch:%s | %s | Range: %d to %d dBm\n" "$bssid" "$ch" "$priv" "$min" "$max" >> "$REPORT"
done

echo "" >> "$REPORT"

# Channel utilization
echo "--- CHANNEL UTILIZATION ---" >> "$REPORT"
echo "" >> "$REPORT"

# Find max for scaling
MAX_CH_COUNT=1
for ch in "${!CHANNEL_COUNT[@]}"; do
    [ "${CHANNEL_COUNT[$ch]}" -gt "$MAX_CH_COUNT" ] && MAX_CH_COUNT=${CHANNEL_COUNT[$ch]}
done

for ch in $(for k in "${!CHANNEL_COUNT[@]}"; do echo "$k ${CHANNEL_COUNT[$k]}"; done | sort -n -k1); do
    ch_num=$(echo "$ch" | awk '{print $1}')
    ch_count=$(echo "$ch" | awk '{print $2}')
    [ -z "$ch_num" ] && continue
    bar_len=$(( ch_count * 20 / MAX_CH_COUNT ))
    [ $bar_len -lt 1 ] && bar_len=1
    bar=$(printf '%*s' "$bar_len" | tr ' ' '=')
    printf "  Ch %3s: %-20s (%d APs)\n" "$ch_num" "$bar" "$ch_count" >> "$REPORT"
done

echo "" >> "$REPORT"

# Channel recommendation
BEST_CH=""
BEST_CH_SCORE=999
for ch in 1 6 11; do
    score=${CHANNEL_COUNT[$ch]:-0}
    if [ "$score" -lt "$BEST_CH_SCORE" ]; then
        BEST_CH=$ch
        BEST_CH_SCORE=$score
    fi
done

echo "--- RECOMMENDATION ---" >> "$REPORT"
echo "  Least congested 2.4GHz channel: $BEST_CH ($BEST_CH_SCORE APs)" >> "$REPORT"
echo "" >> "$REPORT"
echo "================================================================" >> "$REPORT"

PROMPT "SIGNAL SURVEY COMPLETE

Networks mapped: $AP_TOTAL
Best 2.4GHz channel: $BEST_CH

Report saved:
$REPORT"
