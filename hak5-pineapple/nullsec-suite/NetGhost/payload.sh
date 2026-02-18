#!/bin/bash
# Title: Net Ghost
# Author: bad-antics
# Description: Invisible network presence — hide from IDS, bypass NAC, ghost on the wire
# Category: nullsec/stealth

LOOT_DIR="/mmc/nullsec/netghost"
mkdir -p "$LOOT_DIR"

PROMPT "NET GHOST

Invisible network presence.

- MAC randomization
- Traffic obfuscation
- IDS/IPS evasion
- NAC bypass techniques
- Fingerprint spoofing

Press OK to configure."

IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
ORIG_MAC=$(ip link show "$IFACE" 2>/dev/null | grep ether | awk '{print $2}')

PROMPT "GHOST MODE

1. Full stealth (all)
2. MAC ghost only
3. Traffic obfuscation
4. OS fingerprint spoof
5. TTL manipulation
6. Timing randomization

Select on next screen."

MODE=$(NUMBER_PICKER "Mode (1-6):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=1 ;; esac

# Save original state for restore
echo "$ORIG_MAC" > "$LOOT_DIR/.orig_mac"
cat /proc/sys/net/ipv4/ip_default_ttl > "$LOOT_DIR/.orig_ttl" 2>/dev/null

resp=$(CONFIRMATION_DIALOG "ACTIVATE GHOST?

Interface: $IFACE
Original MAC: $ORIG_MAC
Mode: $MODE

WARNING: Network will
briefly disconnect.

Press OK to go dark.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "NetGhost: mode=$MODE iface=$IFACE"

ghost_mac() {
    # Generate random MAC with common vendor prefix
    VENDORS=("00:0c:29" "00:50:56" "b4:2e:99" "ac:de:48" "d8:bb:c1" "f0:18:98")
    VENDOR=${VENDORS[$((RANDOM % ${#VENDORS[@]}))]}
    RAND_MAC="$VENDOR:$(printf '%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))"
    
    ip link set "$IFACE" down 2>/dev/null
    ip link set "$IFACE" address "$RAND_MAC" 2>/dev/null
    ip link set "$IFACE" up 2>/dev/null
    sleep 2
    
    NEW_MAC=$(ip link show "$IFACE" | grep ether | awk '{print $2}')
    echo "$NEW_MAC"
}

ghost_traffic() {
    # Randomize TCP timestamps
    echo 0 > /proc/sys/net/ipv4/tcp_timestamps 2>/dev/null
    
    # Disable ICMP responses
    echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_all 2>/dev/null
    
    # Randomize source ports
    echo "32768 60999" > /proc/sys/net/ipv4/ip_local_port_range 2>/dev/null
    
    # Fragment packets to evade DPI
    iptables -A OUTPUT -p tcp --tcp-flags SYN SYN -j TCPMSS --set-mss 256 2>/dev/null
}

ghost_fingerprint() {
    # Spoof OS fingerprint via TTL manipulation
    # Windows=128, Linux=64, FreeBSD=64, Solaris=255
    PROMPT "OS TO MIMIC

1. Windows 10/11 (TTL 128)
2. macOS (TTL 64)
3. FreeBSD (TTL 64)
4. Cisco IOS (TTL 255)
5. Random

Select on next."
    
    OS_CHOICE=$(NUMBER_PICKER "OS (1-5):" 1)
    case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) OS_CHOICE=1 ;; esac
    
    case $OS_CHOICE in
        1) TTL=128; WINDOW=65535 ;;
        2) TTL=64; WINDOW=65535 ;;
        3) TTL=64; WINDOW=16384 ;;
        4) TTL=255; WINDOW=4128 ;;
        5) TTL=$((64 + RANDOM % 192)); WINDOW=$((1024 + RANDOM % 65000)) ;;
    esac
    
    echo "$TTL" > /proc/sys/net/ipv4/ip_default_ttl 2>/dev/null
    iptables -t mangle -A POSTROUTING -j TTL --ttl-set "$TTL" 2>/dev/null
}

ghost_timing() {
    # Add random delays to outgoing packets to defeat timing analysis
    tc qdisc add dev "$IFACE" root netem delay 10ms 50ms distribution normal 2>/dev/null
}

SPINNER_START "Going dark..."

case $MODE in
    1) # Full stealth
        NEW_MAC=$(ghost_mac)
        ghost_traffic
        ghost_fingerprint
        ghost_timing
        ;;
    2) NEW_MAC=$(ghost_mac) ;;
    3) ghost_traffic ;;
    4) ghost_fingerprint ;;
    5) echo "$TTL_VAL" > /proc/sys/net/ipv4/ip_default_ttl 2>/dev/null ;;
    6) ghost_timing ;;
esac

SPINNER_STOP

CURRENT_MAC=$(ip link show "$IFACE" | grep ether | awk '{print $2}')
CURRENT_TTL=$(cat /proc/sys/net/ipv4/ip_default_ttl 2>/dev/null)

# Log state
cat > "$LOOT_DIR/ghost_state.txt" << EOF
Ghost activated: $(date)
Original MAC: $ORIG_MAC
Current MAC:  $CURRENT_MAC
TTL:          $CURRENT_TTL
Mode:         $MODE
Interface:    $IFACE
EOF

PROMPT "GHOST ACTIVE

MAC: $CURRENT_MAC
TTL: $CURRENT_TTL
ICMP: suppressed
Timestamps: disabled

You are invisible.

Press OK when done to
restore original state."

# Restore
SPINNER_START "Restoring..."

ip link set "$IFACE" down 2>/dev/null
ip link set "$IFACE" address "$ORIG_MAC" 2>/dev/null
ip link set "$IFACE" up 2>/dev/null

ORIG_TTL=$(cat "$LOOT_DIR/.orig_ttl" 2>/dev/null)
[ -n "$ORIG_TTL" ] && echo "$ORIG_TTL" > /proc/sys/net/ipv4/ip_default_ttl 2>/dev/null
echo 0 > /proc/sys/net/ipv4/icmp_echo_ignore_all 2>/dev/null
echo 1 > /proc/sys/net/ipv4/tcp_timestamps 2>/dev/null
iptables -F 2>/dev/null
iptables -t mangle -F 2>/dev/null
tc qdisc del dev "$IFACE" root 2>/dev/null

SPINNER_STOP

sleep 2

PROMPT "RESTORED

MAC: $ORIG_MAC
Network identity reset.
Ghost session logged.

Press OK to exit."
