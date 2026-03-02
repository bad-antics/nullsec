#!/bin/bash
# Title:         Pager Diagnostics
# Description:   Comprehensive system health and diagnostics for your WiFi Pineapple Pager
# Author:        bad-antics
# Version:       1.0
# Category:      General
# Target:        WiFi Pineapple Pager
#
# LED State Descriptions
# SETUP     - Starting diagnostics
# SPECIAL   - Running checks
# SUCCESS   - All checks passed
# FAIL      - Issues detected
#
# Firmware:  Tested on firmware 1.0.4+

# ============================================================================
# CONFIGURATION
# ============================================================================
LOOT_DIR="/root/loot/diagnostics"

# ============================================================================
# PAYLOAD START
# ============================================================================
LED SETUP

PROMPT "PAGER DIAGNOSTICS v1.0

Comprehensive system
health check for your
WiFi Pineapple Pager.

Checks:
- Storage & memory
- WiFi interfaces
- Network connectivity
- Battery & temperature
- Installed packages
- Payload inventory
- System uptime & load

Press OK to start."

# ============================================================================
# RUN DIAGNOSTICS
# ============================================================================
LED SPECIAL
mkdir -p "$LOOT_DIR"
REPORT="$LOOT_DIR/diag_$(date +%Y%m%d_%H%M%S).txt"

SPINNER_START "Running diagnostics..."

{
    echo "════════════════════════════════════════"
    echo "  PAGER DIAGNOSTICS REPORT"
    echo "════════════════════════════════════════"
    echo "Date:     $(date)"
    echo "Hostname: $(hostname)"
    echo "Uptime:   $(uptime -p 2>/dev/null || uptime | awk '{print $3,$4}')"
    echo ""

    # ── SYSTEM INFO ──
    echo "─── System Information ───"
    echo "Kernel:    $(uname -r)"
    echo "Arch:      $(uname -m)"
    echo "Firmware:  $(cat /etc/pineapple/firmware_version 2>/dev/null || echo 'unknown')"
    echo "Build:     $(cat /etc/pineapple/build 2>/dev/null || echo 'unknown')"
    echo ""

    # ── CPU & LOAD ──
    echo "─── CPU & Load ───"
    echo "Load avg:  $(cat /proc/loadavg)"
    echo "CPU info:  $(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | sed 's/^[ \t]*//' || echo 'N/A')"
    CORES=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
    echo "Cores:     $CORES"
    echo ""

    # ── MEMORY ──
    echo "─── Memory ───"
    TOTAL_MEM=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
    USED_MEM=$(free -m 2>/dev/null | awk '/^Mem:/{print $3}')
    FREE_MEM=$(free -m 2>/dev/null | awk '/^Mem:/{print $4}')
    if [ -n "$TOTAL_MEM" ]; then
        MEM_PCT=$((USED_MEM * 100 / TOTAL_MEM))
        echo "Total:     ${TOTAL_MEM}MB"
        echo "Used:      ${USED_MEM}MB (${MEM_PCT}%)"
        echo "Free:      ${FREE_MEM}MB"
        if [ "$MEM_PCT" -gt 90 ]; then
            echo "⚠ WARNING: Memory usage is critically high!"
        elif [ "$MEM_PCT" -gt 75 ]; then
            echo "⚠ NOTICE: Memory usage is elevated"
        else
            echo "✓ Memory usage is healthy"
        fi
    else
        echo "Unable to read memory info"
    fi
    echo ""

    # ── STORAGE ──
    echo "─── Storage ───"
    echo "Filesystem          Size  Used  Avail  Use%"
    df -h 2>/dev/null | grep -E "^/dev|^tmpfs|^overlay" | while read -r line; do
        echo "  $line"
    done

    # Check /mmc (SD card)
    MMC_AVAIL=$(df -m /mmc 2>/dev/null | tail -1 | awk '{print $4}')
    if [ -n "$MMC_AVAIL" ]; then
        if [ "$MMC_AVAIL" -lt 100 ]; then
            echo "⚠ WARNING: SD card has less than 100MB free!"
        else
            echo "✓ SD card: ${MMC_AVAIL}MB available"
        fi
    fi

    ROOT_AVAIL=$(df -m / 2>/dev/null | tail -1 | awk '{print $4}')
    if [ -n "$ROOT_AVAIL" ] && [ "$ROOT_AVAIL" -lt 10 ]; then
        echo "⚠ CRITICAL: Root filesystem nearly full!"
    fi
    echo ""

    # ── WIFI INTERFACES ──
    echo "─── WiFi Interfaces ───"
    for iface in $(ls /sys/class/net/ 2>/dev/null); do
        if [ -d "/sys/class/net/$iface/wireless" ] || echo "$iface" | grep -qE "wlan|mon|phy"; then
            MAC=$(cat /sys/class/net/$iface/address 2>/dev/null || echo "N/A")
            STATE=$(cat /sys/class/net/$iface/operstate 2>/dev/null || echo "unknown")
            echo "  $iface: MAC=$MAC State=$STATE"
            iwconfig "$iface" 2>/dev/null | grep -E "Mode:|Frequency:|Signal" | sed 's/^/    /'
        fi
    done

    # Check for monitor mode capable interfaces
    MON_CAPABLE=$(airmon-ng 2>/dev/null | grep -c "phy")
    echo "Monitor-capable interfaces: $MON_CAPABLE"
    echo ""

    # ── NETWORK ──
    echo "─── Network Connectivity ───"
    GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
    echo "Default gateway: ${GATEWAY:-none}"

    if [ -n "$GATEWAY" ]; then
        if ping -c 1 -W 2 "$GATEWAY" >/dev/null 2>&1; then
            echo "✓ Gateway reachable"
        else
            echo "⚠ Gateway unreachable"
        fi
    fi

    # DNS check
    if nslookup example.com >/dev/null 2>&1 || host example.com >/dev/null 2>&1; then
        echo "✓ DNS resolution working"
    else
        echo "⚠ DNS resolution failed"
    fi

    # Internet check
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        echo "✓ Internet connectivity OK"
    else
        echo "⚠ No internet connectivity"
    fi

    # IP addresses
    echo "IP addresses:"
    ip -4 addr show 2>/dev/null | grep "inet " | awk '{print "  " $NF ": " $2}'
    echo ""

    # ── TEMPERATURE ──
    echo "─── Temperature ───"
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        if [ -f "$zone" ]; then
            TEMP=$(cat "$zone")
            TEMP_C=$((TEMP / 1000))
            ZONE_NAME=$(basename "$(dirname "$zone")")
            echo "  $ZONE_NAME: ${TEMP_C}°C"
            if [ "$TEMP_C" -gt 80 ]; then
                echo "  ⚠ CRITICAL: Temperature is very high!"
            elif [ "$TEMP_C" -gt 65 ]; then
                echo "  ⚠ NOTICE: Temperature is elevated"
            else
                echo "  ✓ Temperature normal"
            fi
        fi
    done
    echo ""

    # ── PACKAGES ──
    echo "─── Key Packages ───"
    for pkg in aircrack-ng tcpdump nmap python3 curl wget hostapd dnsmasq; do
        if command -v "$pkg" >/dev/null 2>&1; then
            VER=$($pkg --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+[\.0-9]*' | head -1)
            echo "  ✓ $pkg ${VER:+(v$VER)}"
        else
            echo "  ✗ $pkg (not installed)"
        fi
    done
    echo ""

    # ── PAYLOAD INVENTORY ──
    echo "─── Payload Inventory ───"
    for dir in /root/payloads/user /mmc/root/payloads/user /root/payloads/alerts /root/payloads/recon; do
        if [ -d "$dir" ]; then
            COUNT=$(find "$dir" -name "payload.sh" 2>/dev/null | wc -l)
            echo "  $dir: $COUNT payloads"
        fi
    done

    # Loot size
    LOOT_SIZE=$(du -sh /root/loot 2>/dev/null | awk '{print $1}')
    echo "  Loot directory: ${LOOT_SIZE:-0}"
    echo ""

    # ── PROCESSES ──
    echo "─── Top Processes (by memory) ───"
    ps aux 2>/dev/null | sort -k4 -rn | head -5 | awk '{printf "  %-6s %-5s %-5s %s\n", $1, $3"%", $4"%", $11}'
    echo ""

    # ── SUMMARY ──
    echo "════════════════════════════════════════"
    echo "  DIAGNOSTICS COMPLETE"
    echo "════════════════════════════════════════"
} > "$REPORT"

SPINNER_STOP

# ============================================================================
# DISPLAY SUMMARY
# ============================================================================
# Count issues
WARNINGS=$(grep -c "⚠" "$REPORT" 2>/dev/null || echo 0)
CHECKS_OK=$(grep -c "✓" "$REPORT" 2>/dev/null || echo 0)
MISSING=$(grep -c "✗" "$REPORT" 2>/dev/null || echo 0)

MEM_INFO="RAM: ${USED_MEM:-?}/${TOTAL_MEM:-?}MB"
STORAGE_INFO="SD: ${MMC_AVAIL:-?}MB free"

if [ "$WARNINGS" -gt 0 ]; then
    LED FAIL
    PROMPT "ISSUES DETECTED

$WARNINGS warnings found
$CHECKS_OK checks passed
$MISSING packages missing

$MEM_INFO
$STORAGE_INFO

Full report saved to:
$REPORT

Press OK to view LOG."
else
    LED SUCCESS
    PROMPT "ALL SYSTEMS GO

$CHECKS_OK checks passed
$MISSING packages missing
No warnings!

$MEM_INFO
$STORAGE_INFO

Full report saved to:
$REPORT

Press OK to exit."
fi

# Show key info in LOG
LOG "════ DIAGNOSTICS ════"
LOG "Kernel: $(uname -r)"
LOG "$MEM_INFO"
LOG "$STORAGE_INFO"
LOG "Interfaces: $(ls /sys/class/net/ | tr '\n' ' ')"
LOG "Warnings: $WARNINGS"
LOG "Report: $REPORT"

LOG "Pager Diagnostics complete."
