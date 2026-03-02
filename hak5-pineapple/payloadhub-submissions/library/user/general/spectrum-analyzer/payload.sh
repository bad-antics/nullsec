#!/bin/bash
# Title:         Spectrum Analyzer
# Description:   Visual WiFi channel utilization and interference analysis
# Author:        bad-antics
# Version:       1.0
# Category:      General
# Target:        WiFi Pineapple Pager
#
# LED State Descriptions
# SETUP     - Initializing scanner
# SPECIAL   - Scanning spectrum
# SUCCESS   - Analysis complete
# CLEANUP   - Restoring interfaces
#
# Firmware:  Tested on firmware 1.0.4+

# ============================================================================
# CONFIGURATION
# ============================================================================
INTERFACE="wlan0"
LOOT_DIR="/root/loot/spectrum"
SCAN_DURATION=20

# ============================================================================
# CLEANUP TRAP
# ============================================================================
cleanup() {
    airmon-ng stop "${INTERFACE}mon" 2>/dev/null
    airmon-ng stop "$INTERFACE" 2>/dev/null
    rm -rf "/tmp/spectrum_$$"
    LED CLEANUP
}
trap cleanup EXIT

# ============================================================================
# HELPER: GENERATE BAR CHART
# ============================================================================
bar_chart() {
    local value="$1"
    local max="$2"
    local width=20
    local filled=0

    if [ "$max" -gt 0 ] 2>/dev/null; then
        filled=$((value * width / max))
    fi
    [ "$filled" -gt "$width" ] && filled=$width

    local bar=""
    for i in $(seq 1 $filled); do
        bar="${bar}█"
    done
    for i in $(seq $((filled + 1)) $width); do
        bar="${bar}░"
    done
    echo "$bar"
}

# ============================================================================
# PAYLOAD START
# ============================================================================
LED SETUP

PROMPT "SPECTRUM ANALYZER v1.0

Visual WiFi channel
utilization analysis.

Shows:
- AP count per channel
- Channel congestion map
- Band utilization
- Best channel suggestion
- Interference hotspots

Press OK to scan."

DURATION=$(NUMBER_PICKER "Scan time (sec):" $SCAN_DURATION)
case $? in
    $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED)
        exit 0
        ;;
esac
[ -z "$DURATION" ] && DURATION=$SCAN_DURATION

# ============================================================================
# SCAN
# ============================================================================
SPINNER_START "Preparing scanner..."

airmon-ng check kill 2>/dev/null
sleep 1
airmon-ng start "$INTERFACE" >/dev/null 2>&1
MON_IF="${INTERFACE}mon"
[ ! -d "/sys/class/net/$MON_IF" ] && MON_IF="$INTERFACE"

SPINNER_STOP

TEMP_DIR="/tmp/spectrum_$$"
mkdir -p "$TEMP_DIR"

LED SPECIAL
SPINNER_START "Scanning spectrum (${DURATION}s)..."

timeout "$DURATION" airodump-ng "$MON_IF" -w "$TEMP_DIR/scan" --output-format csv 2>/dev/null &
SCAN_PID=$!
sleep "$DURATION"
kill $SCAN_PID 2>/dev/null
wait $SCAN_PID 2>/dev/null

SPINNER_STOP

# ============================================================================
# ANALYZE
# ============================================================================
SPINNER_START "Analyzing spectrum..."

mkdir -p "$LOOT_DIR"
LOOT_FILE="$LOOT_DIR/spectrum_$(date +%Y%m%d_%H%M%S).txt"

# Initialize channel counters
declare -A CH_COUNT
declare -A CH_SIGNAL
for ch in 1 2 3 4 5 6 7 8 9 10 11 12 13 36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 149 153 157 161 165; do
    CH_COUNT[$ch]=0
    CH_SIGNAL[$ch]=0
done

TOTAL_APS=0
TOTAL_24=0
TOTAL_5=0
STRONGEST_SIG=-100
STRONGEST_SSID=""
OPEN_COUNT=0

if [ -f "$TEMP_DIR/scan-01.csv" ]; then
    while IFS=',' read -r BSSID F2 F3 CHANNEL F5 SPEED PRIVACY CIPHER AUTH POWER F11 F12 F13 ESSID REST; do
        BSSID=$(echo "$BSSID" | tr -d ' ')
        CH=$(echo "$CHANNEL" | tr -d ' ')
        PWR=$(echo "$POWER" | tr -d ' ')
        ENC=$(echo "$PRIVACY" | tr -d ' ')
        ESSID=$(echo "$ESSID" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [ -n "$BSSID" ] && echo "$BSSID" | grep -qE "^[0-9A-Fa-f]{2}:" && [ -n "$CH" ]; then
            TOTAL_APS=$((TOTAL_APS + 1))

            # Count per channel
            if [ -n "${CH_COUNT[$CH]+x}" ]; then
                CH_COUNT[$CH]=$((CH_COUNT[$CH] + 1))
            else
                CH_COUNT[$CH]=1
            fi

            # Track signal strength
            if [ -n "$PWR" ] && [ "$PWR" != "-1" ] 2>/dev/null; then
                if [ -n "${CH_SIGNAL[$CH]+x}" ]; then
                    # Keep strongest signal per channel
                    if [ "$PWR" -gt "${CH_SIGNAL[$CH]}" ] 2>/dev/null; then
                        CH_SIGNAL[$CH]=$PWR
                    fi
                fi

                if [ "$PWR" -gt "$STRONGEST_SIG" ] 2>/dev/null; then
                    STRONGEST_SIG=$PWR
                    STRONGEST_SSID=$ESSID
                fi
            fi

            # Band counting
            if [ "$CH" -le 14 ] 2>/dev/null; then
                TOTAL_24=$((TOTAL_24 + 1))
            else
                TOTAL_5=$((TOTAL_5 + 1))
            fi

            # Open network count
            if [ "$ENC" = "OPN" ] || [ -z "$ENC" ]; then
                OPEN_COUNT=$((OPEN_COUNT + 1))
            fi
        fi
    done < "$TEMP_DIR/scan-01.csv"
fi

# Find max count for scaling
MAX_COUNT=1
for ch in "${!CH_COUNT[@]}"; do
    [ "${CH_COUNT[$ch]}" -gt "$MAX_COUNT" ] && MAX_COUNT=${CH_COUNT[$ch]}
done

SPINNER_STOP

# ============================================================================
# GENERATE REPORT
# ============================================================================
{
    echo "════════════════════════════════════════"
    echo "  SPECTRUM ANALYZER REPORT"
    echo "════════════════════════════════════════"
    echo "Date:     $(date)"
    echo "Duration: ${DURATION}s"
    echo "Total APs: $TOTAL_APS"
    echo ""

    # 2.4 GHz band
    echo "═══ 2.4 GHz Band ($TOTAL_24 APs) ═══"
    echo ""
    for ch in 1 2 3 4 5 6 7 8 9 10 11; do
        count=${CH_COUNT[$ch]:-0}
        bar=$(bar_chart "$count" "$MAX_COUNT")
        printf "  Ch %2d  %s (%d)\n" "$ch" "$bar" "$count"
    done
    echo ""

    # 5 GHz band
    echo "═══ 5 GHz Band ($TOTAL_5 APs) ═══"
    echo ""
    for ch in 36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 149 153 157 161 165; do
        count=${CH_COUNT[$ch]:-0}
        if [ "$count" -gt 0 ]; then
            bar=$(bar_chart "$count" "$MAX_COUNT")
            printf "  Ch %3d %s (%d)\n" "$ch" "$bar" "$count"
        fi
    done
    echo ""

    # Best channel recommendations
    echo "═══ Recommendations ═══"
    echo ""

    # Find least congested 2.4 GHz channel (1, 6, or 11)
    BEST_24_CH=1
    BEST_24_COUNT=${CH_COUNT[1]:-0}
    for ch in 6 11; do
        if [ "${CH_COUNT[$ch]:-0}" -lt "$BEST_24_COUNT" ]; then
            BEST_24_CH=$ch
            BEST_24_COUNT=${CH_COUNT[$ch]:-0}
        fi
    done

    # Find least congested 5 GHz channel
    BEST_5_CH=36
    BEST_5_COUNT=999
    for ch in 36 40 44 48 149 153 157 161; do
        count=${CH_COUNT[$ch]:-0}
        if [ "$count" -lt "$BEST_5_COUNT" ]; then
            BEST_5_CH=$ch
            BEST_5_COUNT=$count
        fi
    done

    echo "  Best 2.4 GHz: Channel $BEST_24_CH ($BEST_24_COUNT APs)"
    echo "  Best 5 GHz:   Channel $BEST_5_CH ($BEST_5_COUNT APs)"
    echo ""

    # Congestion rating
    if [ "$TOTAL_APS" -gt 50 ]; then
        CONGESTION="EXTREMELY HIGH"
    elif [ "$TOTAL_APS" -gt 30 ]; then
        CONGESTION="HIGH"
    elif [ "$TOTAL_APS" -gt 15 ]; then
        CONGESTION="MODERATE"
    elif [ "$TOTAL_APS" -gt 5 ]; then
        CONGESTION="LOW"
    else
        CONGESTION="MINIMAL"
    fi

    echo "═══ Summary ═══"
    echo ""
    echo "  Total APs:       $TOTAL_APS"
    echo "  2.4 GHz:         $TOTAL_24"
    echo "  5 GHz:           $TOTAL_5"
    echo "  Open networks:   $OPEN_COUNT"
    echo "  Congestion:      $CONGESTION"
    echo "  Strongest:       ${STRONGEST_SSID:-N/A} (${STRONGEST_SIG}dBm)"
    echo ""
    echo "════════════════════════════════════════"
} > "$LOOT_FILE"

# ============================================================================
# DISPLAY ON PAGER
# ============================================================================
LED SUCCESS

# Show 2.4 GHz chart on screen
CHART_24=""
for ch in 1 6 11; do
    count=${CH_COUNT[$ch]:-0}
    bar=$(bar_chart "$count" "$MAX_COUNT")
    CHART_24="${CHART_24}Ch${ch}: ${bar} (${count})\n"
done

LOG "═══ 2.4 GHz ═══"
for ch in 1 2 3 4 5 6 7 8 9 10 11; do
    count=${CH_COUNT[$ch]:-0}
    bar=$(bar_chart "$count" "$MAX_COUNT")
    LOG "Ch $ch $bar ($count)"
done

LOG ""
LOG "═══ 5 GHz ═══"
for ch in 36 40 44 48 149 153 157 161 165; do
    count=${CH_COUNT[$ch]:-0}
    [ "$count" -gt 0 ] && LOG "Ch $ch $(bar_chart "$count" "$MAX_COUNT") ($count)"
done

PROMPT "SPECTRUM ANALYSIS

Total APs: $TOTAL_APS
2.4GHz: $TOTAL_24  5GHz: $TOTAL_5
Congestion: $CONGESTION

Best channels:
  2.4 GHz: Ch $BEST_24_CH
  5 GHz:   Ch $BEST_5_CH

Strongest:
  ${STRONGEST_SSID:-N/A}
  ${STRONGEST_SIG}dBm

Full report: $LOOT_FILE

Press OK to exit."

LOG "Spectrum Analyzer complete. APs: $TOTAL_APS"
