#!/bin/bash
#╔═══════════════════════════════════════════════════════════════════════════════╗
#║                                                                               ║
#║     ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗              ║
#║     ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝              ║
#║     ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║                   ║
#║     ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║                   ║
#║     ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗              ║
#║     ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝              ║
#║                                                                               ║
#║                  NullSec Mesh Network Setup v1.0                              ║
#║            NullSec Gateway Configuration Script                               ║
#║                    Developed by: bad-antics                                   ║
#║                                                                               ║
#╚═══════════════════════════════════════════════════════════════════════════════╝
#
#  Sets up the full mesh network on the NullSec Gateway:
#    - batman-adv mesh networking
#    - Firewall rules (UFW + iptables) for mesh traffic
#    - IP forwarding and NAT for mesh nodes
#    - Flipper Zero serial bridge (SubGHz relay)
#    - Pineapple Pager integration
#    - Mesh node discovery and management
#
#  Architecture:
#    [Internet] <--WiFi--> [NullSec GW] <--mesh0/bat0--> [Pineapple Pager]
#                               |
#                          [Flipper Zero]  <-- /dev/ttyACM0 SubGHz bridge
#                               |
#                         [Remote nodes via SubGHz]
#
#  Usage: sudo ./nullsec-mesh-setup.sh [command]
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# Network Config
MESH_ID="nullsec-mesh"
MESH_FREQ=2437                          # Channel 6 (2.4GHz for range)
MESH_CHANNEL=6
WIFI_IFACE="${NULLSEC_WIFI:-wlan0}"      # Main WiFi (internet)
MESH_IFACE="mesh0"                      # Virtual mesh interface
BAT_IFACE="bat0"                        # batman-adv virtual interface
BAT_IP="10.10.10.1/24"                  # This node's mesh IP
BAT_NETWORK="10.10.10.0/24"             # Mesh network CIDR
BAT_GW_MODE="server"                    # This machine is the gateway

# Pineapple Config
PINEAPPLE_USB_IFACE="usb0"              # Pineapple USB interface (auto-detected)
PINEAPPLE_IP="172.16.52.1"
PINEAPPLE_NET="172.16.52.0/24"
PINEAPPLE_LOCAL_IP="172.16.52.42"

# Flipper Zero Config
FLIPPER_DEV="/dev/ttyACM0"
FLIPPER_BAUD=115200
FLIPPER_SUBGHZ_FREQ=433920000           # 433.92 MHz default
FLIPPER_LOG="/var/log/nullsec/flipper-bridge.log"

# WireGuard VPN
WG_IFACE="${NULLSEC_WG:-wg0}"

# Logging
LOG_DIR="/var/log/nullsec"
LOG_FILE="${LOG_DIR}/mesh-setup.log"
MESH_STATE_DIR="/var/lib/nullsec/mesh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

log()     { echo -e "${GREEN}[+]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null; }
warn()    { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null; }
err()     { echo -e "${RED}[-]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null; }
info()    { echo -e "${BLUE}[i]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null; }
debug()   { echo -e "${GRAY}[d] $1${NC}" >> "$LOG_FILE" 2>/dev/null; }
header()  {
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${WHITE}  $1${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        err "This script must be run as root (sudo)"
        exit 1
    fi
}

banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔══════════════════════════════════════════════════════════════╗
    ║                                                              ║
    ║   ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗║
    ║   ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝║
    ║   ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║     ║
    ║   ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║     ║
    ║   ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗║
    ║   ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝║
    ║                                                              ║
    ║              NullSec Mesh Network Setup v1.0                 ║
    ║                  Developed by: bad-antics                    ║
    ╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 1: PREREQUISITES & DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════════

install_dependencies() {
    header "PHASE 1: Installing Dependencies"

    local packages_needed=()
    local pkg_mgr=""

    # Detect package manager
    if command -v apt-get &>/dev/null; then
        pkg_mgr="apt"
    elif command -v xbps-install &>/dev/null; then
        pkg_mgr="xbps"
    elif command -v pacman &>/dev/null; then
        pkg_mgr="pacman"
    elif command -v dnf &>/dev/null; then
        pkg_mgr="dnf"
    else
        warn "Unknown package manager. Install dependencies manually."
        return 1
    fi

    # Check for batctl
    if ! command -v batctl &>/dev/null; then
        packages_needed+=("batctl")
        log "batctl not found - will install"
    else
        log "batctl already installed: $(batctl -v 2>/dev/null)"
    fi

    # Check for iw
    if ! command -v iw &>/dev/null; then
        packages_needed+=("iw")
    fi

    # Check for screen (for Flipper serial)
    if ! command -v screen &>/dev/null; then
        packages_needed+=("screen")
    fi

    # Check for bridge-utils
    if ! command -v brctl &>/dev/null; then
        packages_needed+=("bridge-utils")
    fi

    # Check for iperf3 (mesh testing)
    if ! command -v iperf3 &>/dev/null; then
        packages_needed+=("iperf3")
    fi

    if [[ ${#packages_needed[@]} -gt 0 ]]; then
        log "Installing: ${packages_needed[*]}"
        case "$pkg_mgr" in
            apt)
                apt-get update -qq
                # batman-adv-tools provides batctl on Debian/Ubuntu
                local apt_pkgs=()
                for p in "${packages_needed[@]}"; do
                    [[ "$p" == "batctl" ]] && apt_pkgs+=("batctl" "batman-adv") || apt_pkgs+=("$p")
                done
                apt-get install -y -qq "${apt_pkgs[@]}" 2>/dev/null || true
                ;;
            xbps)
                local xbps_pkgs=()
                for p in "${packages_needed[@]}"; do
                    [[ "$p" == "batctl" ]] && xbps_pkgs+=("batman-adv" "batctl") || xbps_pkgs+=("$p")
                done
                xbps-install -y "${xbps_pkgs[@]}" 2>/dev/null || true
                ;;
            pacman)
                pacman -Sy --noconfirm "${packages_needed[@]}" 2>/dev/null || true
                ;;
            dnf)
                dnf install -y "${packages_needed[@]}" 2>/dev/null || true
                ;;
        esac
    fi

    # Load batman-adv kernel module
    if ! lsmod | grep -q batman_adv; then
        log "Loading batman-adv kernel module..."
        modprobe batman-adv 2>/dev/null || {
            err "Failed to load batman-adv module"
            info "Try: sudo modprobe batman_adv"
            info "If not available, install linux-headers and batman-adv-dkms"
            return 1
        }
        log "batman-adv module loaded: $(modinfo -F version batman-adv 2>/dev/null)"
    else
        log "batman-adv already loaded: $(cat /sys/module/batman_adv/version 2>/dev/null)"
    fi

    # Make it persistent
    if ! grep -q "batman-adv" /etc/modules-load.d/*.conf 2>/dev/null; then
        echo "batman-adv" > /etc/modules-load.d/batman-adv.conf
        log "batman-adv added to auto-load on boot"
    fi

    # Create directories
    mkdir -p "$LOG_DIR" "$MESH_STATE_DIR"
    chmod 750 "$LOG_DIR" "$MESH_STATE_DIR"

    log "Dependencies ready ✓"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 2: FIREWALL CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

setup_firewall() {
    header "PHASE 2: Firewall Configuration"

    # ─── Enable IP Forwarding ───
    log "Enabling IP forwarding..."
    sysctl -w net.ipv4.ip_forward=1 > /dev/null
    sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null

    # ─── Mesh-optimized kernel tuning ───
    sysctl -w net.ipv4.tcp_slow_start_after_idle=0 > /dev/null 2>&1
    sysctl -w net.ipv4.tcp_mtu_probing=1 > /dev/null 2>&1
    sysctl -w net.ipv4.neigh.default.gc_thresh1=1024 > /dev/null 2>&1
    sysctl -w net.ipv4.neigh.default.gc_thresh2=4096 > /dev/null 2>&1
    sysctl -w net.ipv4.neigh.default.gc_thresh3=8192 > /dev/null 2>&1
    sysctl -w net.ipv4.tcp_keepalive_time=60 > /dev/null 2>&1
    sysctl -w net.ipv4.tcp_keepalive_intvl=10 > /dev/null 2>&1
    sysctl -w net.ipv4.tcp_keepalive_probes=6 > /dev/null 2>&1
    log "Mesh kernel tuning applied (neighbor tables, keepalive, MTU probing)"

    # Make persistent
    if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
        cat >> /etc/sysctl.conf << 'SYSCTL'

# NullSec Mesh - IP Forwarding
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv4.conf.all.proxy_arp=1
SYSCTL
        log "IP forwarding persisted in /etc/sysctl.conf"
    fi

    # ─── UFW Rules ───
    if command -v ufw &>/dev/null; then
        log "Configuring UFW firewall rules..."

        # Allow mesh network traffic
        ufw allow in on bat0 comment "NullSec mesh bat0 in" 2>/dev/null || true
        ufw allow out on bat0 comment "NullSec mesh bat0 out" 2>/dev/null || true

        # Allow mesh management port
        ufw allow 4305/tcp comment "NullSec mesh management" 2>/dev/null || true
        ufw allow 4305/udp comment "NullSec mesh management" 2>/dev/null || true

        # Allow batman-adv protocol (ETH_P_BATMAN 0x4305 / 0x0842)
        # These work at layer 2 so UFW won't block them, but add for clarity

        # Allow Pineapple network
        ufw allow from "$PINEAPPLE_NET" comment "Pineapple network" 2>/dev/null || true
        ufw allow from "$BAT_NETWORK" comment "NullSec mesh network" 2>/dev/null || true

        # Allow Flipper serial port access (not a network rule, but for ufw logs)
        # Allow mDNS for mesh discovery
        ufw allow 5353/udp comment "mDNS mesh discovery" 2>/dev/null || true

        # Allow mesh ICMP (ping for mesh health)
        # UFW allows outgoing ICMP by default; ensure incoming is allowed from mesh
        ufw allow proto icmp from "$BAT_NETWORK" comment "Mesh ICMP" 2>/dev/null || true

        # Enable forwarding in UFW
        if grep -q "DEFAULT_FORWARD_POLICY=\"DROP\"" /etc/default/ufw 2>/dev/null; then
            sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
            log "UFW forward policy set to ACCEPT"
        fi

        # Reload UFW
        ufw --force enable > /dev/null 2>&1
        ufw reload 2>/dev/null || true
        log "UFW rules applied ✓"
    fi

    # ─── iptables NAT & Forwarding Rules ───
    log "Configuring iptables NAT and forwarding..."

    # Flush existing NullSec rules (idempotent)
    iptables -t nat -D POSTROUTING -s "$BAT_NETWORK" -o "$WIFI_IFACE" -j MASQUERADE 2>/dev/null || true
    iptables -t nat -D POSTROUTING -s "$BAT_NETWORK" -o "$WG_IFACE" -j MASQUERADE 2>/dev/null || true
    iptables -t nat -D POSTROUTING -s "$PINEAPPLE_NET" -o "$WIFI_IFACE" -j MASQUERADE 2>/dev/null || true
    iptables -D FORWARD -i bat0 -o "$WIFI_IFACE" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "$WIFI_IFACE" -o bat0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i bat0 -o "$WG_IFACE" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "$WG_IFACE" -o bat0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true

    # NAT: Mesh nodes → Internet via WiFi
    iptables -t nat -A POSTROUTING -s "$BAT_NETWORK" -o "$WIFI_IFACE" -j MASQUERADE
    log "NAT: ${BAT_NETWORK} → ${WIFI_IFACE} (WiFi internet)"

    # NAT: Mesh nodes → Internet via WireGuard (if active)
    if ip link show "$WG_IFACE" &>/dev/null; then
        iptables -t nat -A POSTROUTING -s "$BAT_NETWORK" -o "$WG_IFACE" -j MASQUERADE
        log "NAT: ${BAT_NETWORK} → ${WG_IFACE} (WireGuard VPN)"
    fi

    # NAT: Pineapple → Internet via WiFi
    iptables -t nat -A POSTROUTING -s "$PINEAPPLE_NET" -o "$WIFI_IFACE" -j MASQUERADE
    log "NAT: ${PINEAPPLE_NET} → ${WIFI_IFACE} (Pineapple internet)"

    # FORWARD: Allow mesh ↔ internet
    iptables -A FORWARD -i bat0 -o "$WIFI_IFACE" -j ACCEPT
    iptables -A FORWARD -i "$WIFI_IFACE" -o bat0 -m state --state RELATED,ESTABLISHED -j ACCEPT

    # FORWARD: Allow mesh ↔ VPN
    if ip link show "$WG_IFACE" &>/dev/null; then
        iptables -A FORWARD -i bat0 -o "$WG_IFACE" -j ACCEPT
        iptables -A FORWARD -i "$WG_IFACE" -o bat0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    fi

    # FORWARD: Allow Pineapple ↔ Mesh
    iptables -A FORWARD -s "$PINEAPPLE_NET" -d "$BAT_NETWORK" -j ACCEPT
    iptables -A FORWARD -s "$BAT_NETWORK" -d "$PINEAPPLE_NET" -j ACCEPT

    # Allow batman-adv ethertype on mesh interface
    iptables -A INPUT -i mesh0 -p 0x4305 -j ACCEPT 2>/dev/null || true
    iptables -A INPUT -i mesh0 -p 0x0842 -j ACCEPT 2>/dev/null || true

    log "iptables rules applied ✓"

    # ─── Save iptables rules ───
    if command -v iptables-save &>/dev/null; then
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/nullsec-mesh.rules
        log "iptables rules saved to /etc/iptables/nullsec-mesh.rules"
    fi

    # ─── Create restore script ───
    cat > /etc/network/if-pre-up.d/nullsec-mesh-fw 2>/dev/null << 'FWRESTORE' || true
#!/bin/sh
# Restore NullSec mesh firewall rules on boot
if [ -f /etc/iptables/nullsec-mesh.rules ]; then
    iptables-restore < /etc/iptables/nullsec-mesh.rules
fi
FWRESTORE
    chmod +x /etc/network/if-pre-up.d/nullsec-mesh-fw 2>/dev/null || true

    log "Firewall configuration complete ✓"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 3: MESH NETWORK (batman-adv)
# ═══════════════════════════════════════════════════════════════════════════════

setup_mesh_network() {
    header "PHASE 3: Mesh Network (batman-adv)"

    # Check that batman-adv is loaded
    if ! lsmod | grep -q batman_adv; then
        modprobe batman-adv || { err "batman-adv kernel module not available"; return 1; }
    fi

    local mesh_transport=""   # Will be set to: "mesh_point", "ibss", or "veth"

    # ─── Tear down existing mesh/bat interfaces ───
    if ip link show "$MESH_IFACE" &>/dev/null; then
        warn "Removing existing mesh interface..."
        ip link set "$MESH_IFACE" down 2>/dev/null || true
        iw dev "$MESH_IFACE" del 2>/dev/null || true
        ip link del "$MESH_IFACE" 2>/dev/null || true
        sleep 1
    fi
    if ip link show "${MESH_IFACE}-peer" &>/dev/null; then
        ip link del "${MESH_IFACE}-peer" 2>/dev/null || true
    fi
    if ip link show "$BAT_IFACE" &>/dev/null; then
        ip link set "$BAT_IFACE" down 2>/dev/null || true
        batctl meshif "$BAT_IFACE" interface del -M 2>/dev/null || true
    fi

    # ─── Get WiFi PHY info ───
    local phy_name phy_num
    phy_num=$(iw dev "$WIFI_IFACE" info 2>/dev/null | grep wiphy | awk '{print $2}')
    phy_name="phy${phy_num}"
    log "WiFi PHY: ${phy_name}"

    # ─── Check valid interface combinations ───
    local combo_info
    combo_info=$(iw phy "$phy_name" info 2>/dev/null | grep -A10 "valid interface combinations")
    local has_mesh_combo=false
    if echo "$combo_info" | grep -q "mesh point"; then
        # Check if mesh can coexist with managed (need both in same combo line)
        if echo "$combo_info" | grep -E "managed.*mesh|mesh.*managed" &>/dev/null; then
            has_mesh_combo=true
        fi
    fi

    local has_ibss_combo=false
    if iw phy "$phy_name" info 2>/dev/null | grep -q "IBSS"; then
        has_ibss_combo=true
    fi

    # ─── Strategy 1: Try 802.11s Mesh Point (concurrent with managed) ───
    if $has_mesh_combo; then
        log "WiFi supports concurrent managed+mesh ─ using 802.11s mesh point"
        iw dev "$WIFI_IFACE" interface add "$MESH_IFACE" type mesh 2>/dev/null && {
            ip link set "$MESH_IFACE" up
            sleep 1
            iw dev "$MESH_IFACE" set channel "$MESH_CHANNEL" 2>/dev/null || true
            iw dev "$MESH_IFACE" mesh join "$MESH_ID" 2>/dev/null || \
                iw dev "$MESH_IFACE" mesh join "$MESH_ID" freq "$MESH_FREQ" 2>/dev/null || true
            mesh_transport="mesh_point"
            log "Mesh interface ${MESH_IFACE} up (802.11s mesh point, ch${MESH_CHANNEL})"
        } || warn "802.11s mesh point creation failed, trying alternatives..."
    fi

    # ─── Strategy 2: Use veth pair with batman-adv (software mesh) ───
    # This ALWAYS works regardless of WiFi driver limitations.
    # batman-adv runs over a veth pair, and we route/bridge to the LAN.
    # Other mesh nodes on the same LAN or VPN can reach us via IP.
    if [[ -z "$mesh_transport" ]]; then
        log "WiFi cannot do concurrent managed+mesh ─ using software mesh (veth + batman-adv)"
        info "This creates a virtual ethernet pair for batman-adv transport"
        info "Mesh nodes communicate via LAN/VPN overlay ─ no WiFi mode change needed"

        # Create veth pair: mesh0 ↔ mesh0-peer
        ip link add "$MESH_IFACE" type veth peer name "${MESH_IFACE}-peer" || {
            err "Failed to create veth pair"
            return 1
        }

        # Bring both ends up
        ip link set "$MESH_IFACE" up
        ip link set "${MESH_IFACE}-peer" up

        # Set MTU high enough for batman-adv overhead
        ip link set "$MESH_IFACE" mtu 1560 2>/dev/null || true
        ip link set "${MESH_IFACE}-peer" mtu 1560 2>/dev/null || true

        mesh_transport="veth"
        log "Software mesh transport created (veth pair) ✓"

        # ─── Set up GRE tunnels for remote mesh nodes ───
        # This allows batman-adv to communicate with nodes over the existing network
        info "Setting up GRE tunnel endpoint for remote mesh peers..."

        # Create a script other nodes can use to join this mesh
        mkdir -p /usr/local/share/nullsec
        cat > /usr/local/share/nullsec/mesh-peer-join.sh << 'PEERJOIN'
#!/bin/bash
# NullSec Mesh Peer Join - run on remote machines to join the mesh
# Usage: sudo ./mesh-peer-join.sh <gateway_ip>
GATEWAY_IP="${1:-10.10.10.1}"
MY_MESH_IP="${2:-auto}"

modprobe batman-adv 2>/dev/null
modprobe ip_gre 2>/dev/null

# Create GRE tunnel to gateway
ip tunnel add mesh-gre mode gre remote "$GATEWAY_IP" local "$(ip route get "$GATEWAY_IP" | awk '{for(i=1;i<=NF;i++)if($i=="src")print $(i+1)}')" ttl 255 2>/dev/null
ip link set mesh-gre up
ip link set mesh-gre mtu 1400

# Add to batman-adv
batctl meshif bat0 interface add -M mesh-gre 2>/dev/null || batctl if add mesh-gre 2>/dev/null
ip link set bat0 up

# Auto-assign IP if not specified
if [[ "$MY_MESH_IP" == "auto" ]]; then
    HASH=$(hostname | md5sum | cut -c1-2)
    OCTET=$((16#$HASH % 253 + 2))
    MY_MESH_IP="10.10.10.${OCTET}/24"
fi
ip addr add "$MY_MESH_IP" dev bat0

echo "[+] Joined NullSec mesh at $MY_MESH_IP via GRE to $GATEWAY_IP"
PEERJOIN
        chmod +x /usr/local/share/nullsec/mesh-peer-join.sh
    fi

    # ─── batman-adv Configuration ───
    log "Configuring batman-adv on ${MESH_IFACE} (transport: ${mesh_transport})..."

    # Add mesh interface to batman
    batctl meshif "$BAT_IFACE" interface add -M "$MESH_IFACE" 2>/dev/null || \
    batctl if add "$MESH_IFACE" 2>/dev/null || {
        err "Failed to add ${MESH_IFACE} to batman-adv"
        return 1
    }

    # Bring up bat0
    ip link set "$BAT_IFACE" up

    # Assign IP to bat0
    ip addr flush dev "$BAT_IFACE" 2>/dev/null
    ip addr add "$BAT_IP" dev "$BAT_IFACE"

    # Set batman-adv parameters
    # Gateway mode: server (this machine shares internet to mesh)
    # Announce real bandwidth (default 10/2 MBit is way too low)
    batctl meshif "$BAT_IFACE" gw_mode server 1000mbit/1000mbit 2>/dev/null || \
    batctl gw_mode server 1000mbit/1000mbit 2>/dev/null || true

    # Originator interval (ms) - how often we announce ourselves
    # 500ms = faster convergence for small mesh (default 1000ms)
    batctl meshif "$BAT_IFACE" orig_interval 500 2>/dev/null || \
    batctl orig_interval 500 2>/dev/null || true

    # Enable distributed ARP table
    batctl meshif "$BAT_IFACE" distributed_arp_table 1 2>/dev/null || \
    batctl dat 1 2>/dev/null || true

    # Enable bridge loop avoidance
    batctl meshif "$BAT_IFACE" bridge_loop_avoidance 1 2>/dev/null || \
    batctl bla 1 2>/dev/null || true

    # Multicast mode
    batctl meshif "$BAT_IFACE" multicast_mode 1 2>/dev/null || \
    batctl mm 1 2>/dev/null || true

    # Set hop penalty (lower = prefer this gateway)
    batctl meshif "$BAT_IFACE" hop_penalty 15 2>/dev/null || \
    batctl hop_penalty 15 2>/dev/null || true

    # Enable network coding (XOR-based, improves multi-hop throughput)
    batctl meshif "$BAT_IFACE" network_coding 1 2>/dev/null || \
    batctl nc 1 2>/dev/null || true

    # ─── Interface Performance Tuning ───
    # Increase transmit queue to prevent drops under load
    ip link set "$BAT_IFACE" txqueuelen 5000 2>/dev/null || true

    # Smart queuing discipline (CAKE > fq_codel > default)
    tc qdisc replace dev "$BAT_IFACE" root cake bandwidth 1gbit 2>/dev/null || \
        tc qdisc replace dev "$BAT_IFACE" root fq_codel 2>/dev/null || true

    # Tune transport interface
    if [[ -n "$mesh_transport" ]]; then
        local transport_if="$MESH_IFACE"
        ip link set "$transport_if" txqueuelen 5000 2>/dev/null || true
    fi

    log "batman-adv configured ✓"
    log "  Mesh ID:      ${MESH_ID}"
    log "  Transport:    ${mesh_transport}"
    log "  Interface:    ${BAT_IFACE} → ${BAT_IP}"
    log "  Gateway:      ${BAT_GW_MODE}"

    # ─── Set up mesh HTTP server for serving setup scripts to joining nodes ───
    if [[ "$mesh_transport" == "veth" ]]; then
        info "Starting HTTP server on bat0 for mesh peer bootstrapping..."
        local serve_dir="/usr/local/share/nullsec"
        # Serve mesh-peer-join.sh on port 8080 for BadUSB payloads to download
        if command -v python3 &>/dev/null; then
            # Kill any existing server
            pkill -f "python3 -m http.server 8080" 2>/dev/null || true
            cd "$serve_dir" && python3 -m http.server 8080 --bind 10.10.10.1 &>/dev/null &
            disown
            log "Mesh bootstrap HTTP server on http://10.10.10.1:8080/ ✓"
        fi
    fi

    # ─── Add static route for mesh ↔ Pineapple ───
    ip route add "$PINEAPPLE_NET" via "$PINEAPPLE_LOCAL_IP" 2>/dev/null || true

    # ─── Save mesh transport type for status checks ───
    mkdir -p "$MESH_STATE_DIR"
    echo "$mesh_transport" > "${MESH_STATE_DIR}/transport"

    log "Mesh network ready ✓"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 4: PINEAPPLE INTEGRATION
# ═══════════════════════════════════════════════════════════════════════════════

setup_pineapple() {
    header "PHASE 4: Pineapple Pager Integration"

    # Auto-detect Pineapple USB interface
    local usb_if=""

    # Look for Hak5 OUI 00:13:37
    usb_if=$(ip link 2>/dev/null | grep -B1 "00:13:37" | head -1 | awk -F: '{print $2}' | tr -d ' ' || true)

    # Fallback: look for USB ethernet interfaces
    if [[ -z "$usb_if" ]]; then
        for pattern in usb0 usb1; do
            if [[ -e "/sys/class/net/$pattern" ]]; then
                usb_if="$pattern"
                break
            fi
        done
    fi

    # Fallback: any interface on 172.16.52.x
    if [[ -z "$usb_if" ]]; then
        usb_if=$(ip -o addr 2>/dev/null | grep "172.16.52" | awk '{print $2}' || true)
    fi

    if [[ -z "$usb_if" ]]; then
        warn "No Pineapple USB interface detected"
        info "Plug in Pineapple via USB and re-run: sudo $0 pineapple"
        info "Mesh network will still work without Pineapple"
        return 0
    fi

    PINEAPPLE_USB_IFACE="$usb_if"
    log "Found Pineapple on interface: ${PINEAPPLE_USB_IFACE}"

    # Configure USB interface
    ip addr flush dev "$PINEAPPLE_USB_IFACE" 2>/dev/null
    ip addr add "${PINEAPPLE_LOCAL_IP}/24" dev "$PINEAPPLE_USB_IFACE" 2>/dev/null
    ip link set "$PINEAPPLE_USB_IFACE" up

    # Route Pineapple traffic
    ip route add "$PINEAPPLE_NET" dev "$PINEAPPLE_USB_IFACE" 2>/dev/null || true

    # Ensure default route stays on WiFi
    local wifi_gw
    wifi_gw=$(ip route | grep "default.*${WIFI_IFACE}" | awk '{print $3}' | head -1 || true)
    if [[ -n "$wifi_gw" ]]; then
        # Delete any Pineapple default route hijack
        ip route del default via 172.16.52.1 2>/dev/null || true
        ip route del default dev "$PINEAPPLE_USB_IFACE" 2>/dev/null || true
        # Restore WiFi default
        ip route replace default via "$wifi_gw" dev "$WIFI_IFACE" 2>/dev/null || true
    fi

    # Add Pineapple to batman-adv mesh bridge (optional - connects Pineapple to mesh)
    if ip link show "$BAT_IFACE" &>/dev/null; then
        # Add route: mesh nodes can reach Pineapple via this machine
        ip route add "$PINEAPPLE_NET" dev "$PINEAPPLE_USB_IFACE" table main 2>/dev/null || true

        # NAT for Pineapple ↔ mesh
        iptables -t nat -D POSTROUTING -s "$PINEAPPLE_NET" -o "$BAT_IFACE" -j MASQUERADE 2>/dev/null || true
        iptables -t nat -A POSTROUTING -s "$PINEAPPLE_NET" -o "$BAT_IFACE" -j MASQUERADE
        iptables -A FORWARD -i "$PINEAPPLE_USB_IFACE" -o "$BAT_IFACE" -j ACCEPT 2>/dev/null || true
        iptables -A FORWARD -i "$BAT_IFACE" -o "$PINEAPPLE_USB_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true

        log "Pineapple bridged to mesh network ✓"
    fi

    # Test connectivity
    if ping -c1 -W2 "$PINEAPPLE_IP" &>/dev/null; then
        log "Pineapple reachable at ${PINEAPPLE_IP} ✓"

        # Check SSH
        if nc -zw2 "$PINEAPPLE_IP" 22 &>/dev/null; then
            log "Pineapple SSH port open ✓"
        fi

        # Check web UI
        if nc -zw2 "$PINEAPPLE_IP" 1471 &>/dev/null; then
            log "Pineapple Web UI port open ✓"
        fi
    else
        warn "Cannot ping Pineapple at ${PINEAPPLE_IP}"
        info "Check USB cable and Pineapple power"
    fi

    # Verify internet still works
    if ping -c1 -W2 8.8.8.8 &>/dev/null; then
        log "Internet connectivity preserved ✓"
    else
        warn "Internet may be disrupted - checking routes..."
        if [[ -n "$wifi_gw" ]]; then
            ip route replace default via "$wifi_gw" dev "$WIFI_IFACE"
            log "Re-applied default route via ${wifi_gw}"
        fi
    fi

    log "Pineapple integration complete ✓"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 5: FLIPPER ZERO SERIAL BRIDGE
# ═══════════════════════════════════════════════════════════════════════════════

setup_flipper() {
    header "PHASE 5: Flipper Zero SubGHz Bridge"

    # Check if Flipper is connected
    if [[ ! -c "$FLIPPER_DEV" ]]; then
        warn "Flipper Zero not found at ${FLIPPER_DEV}"
        info "Connect Flipper via USB and re-run: sudo $0 flipper"
        return 0
    fi

    log "Flipper Zero detected at ${FLIPPER_DEV}"

    # Configure serial port
    stty -F "$FLIPPER_DEV" "$FLIPPER_BAUD" raw -echo -echoe -echok 2>/dev/null || {
        warn "Could not configure serial port"
        info "Flipper may be in a different mode"
    }

    # Set permissions
    chmod 666 "$FLIPPER_DEV" 2>/dev/null || true

    # Create udev rule for persistent Flipper access
    if [[ ! -f /etc/udev/rules.d/42-nullsec-flipper.rules ]]; then
        cat > /etc/udev/rules.d/42-nullsec-flipper.rules << 'UDEV'
# NullSec - Flipper Zero persistent access
# STMicroelectronics Virtual COM Port (Flipper Zero)
SUBSYSTEM=="tty", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="5740", \
    MODE="0666", GROUP="dialout", SYMLINK+="flipper"
UDEV
        udevadm control --reload-rules 2>/dev/null || true
        udevadm trigger 2>/dev/null || true
        log "Udev rule created: /dev/flipper → Flipper Zero"
    fi

    # Create the Flipper SubGHz bridge service script
    cat > /usr/local/bin/nullsec-flipper-bridge << 'FLIPPERBRIDGE'
#!/bin/bash
# NullSec Flipper Zero SubGHz ↔ Mesh Bridge
# Relays mesh control messages over SubGHz radio via Flipper Zero CLI

FLIPPER_DEV="${1:-/dev/ttyACM0}"
FLIPPER_BAUD=115200
LOG="/var/log/nullsec/flipper-bridge.log"
MESH_FIFO="/tmp/nullsec-mesh-bridge.fifo"
SUBGHZ_FREQ="${NULLSEC_SUBGHZ_FREQ:-433920000}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }

cleanup() {
    log "Stopping Flipper bridge"
    rm -f "$MESH_FIFO"
    # Return Flipper to idle
    echo -e "\r\n" > "$FLIPPER_DEV" 2>/dev/null
    exit 0
}

trap cleanup EXIT INT TERM

log "Starting Flipper SubGHz bridge on ${FLIPPER_DEV}"

# Create FIFO for mesh → Flipper communication
[[ -p "$MESH_FIFO" ]] || mkfifo "$MESH_FIFO"

# Configure serial
stty -F "$FLIPPER_DEV" "$FLIPPER_BAUD" raw -echo -echoe -echok 2>/dev/null

# Wait for Flipper CLI prompt
sleep 1
echo -e "\r\n" > "$FLIPPER_DEV"
sleep 0.5

# Function: Send CLI command to Flipper
flipper_cmd() {
    echo -e "$1\r\n" > "$FLIPPER_DEV"
    sleep 0.3
}

# Function: Transmit mesh beacon via SubGHz
tx_mesh_beacon() {
    local payload="$1"
    # Encode payload as SubGHz raw data
    log "TX SubGHz beacon: $payload"
    flipper_cmd "subghz tx_raw ${SUBGHZ_FREQ} 0 ${payload}"
}

# Function: Listen for incoming SubGHz and relay to mesh
rx_mesh_relay() {
    log "Starting SubGHz RX on ${SUBGHZ_FREQ} Hz"
    flipper_cmd "subghz rx ${SUBGHZ_FREQ}"

    # Read Flipper output and relay to mesh
    while IFS= read -r -t 1 line < "$FLIPPER_DEV" 2>/dev/null; do
        if [[ "$line" == *"RAW"* ]] || [[ "$line" == *"nullsec"* ]]; then
            log "RX SubGHz: $line"
            echo "$line" > "$MESH_FIFO" 2>/dev/null
        fi
    done
}

# Main loop: alternate between TX beacons and RX
BEACON_INTERVAL=30
LAST_BEACON=0

while true; do
    NOW=$(date +%s)

    # Send periodic mesh beacon
    if (( NOW - LAST_BEACON >= BEACON_INTERVAL )); then
        HOSTNAME=$(hostname)
        MESH_IP=$(ip addr show bat0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        tx_mesh_beacon "NULLSEC|BEACON|${HOSTNAME}|${MESH_IP}|$(date +%s)"
        LAST_BEACON=$NOW
    fi

    # Check for outbound messages from mesh
    if [[ -p "$MESH_FIFO" ]]; then
        while IFS= read -r -t 1 msg < "$MESH_FIFO" 2>/dev/null; do
            tx_mesh_beacon "$msg"
        done
    fi

    # Brief RX window
    rx_mesh_relay

    sleep 1
done
FLIPPERBRIDGE

    chmod +x /usr/local/bin/nullsec-flipper-bridge

    # Create systemd service for the bridge
    cat > /etc/systemd/system/nullsec-flipper-bridge.service << 'SYSTEMD'
[Unit]
Description=NullSec Flipper Zero SubGHz Mesh Bridge
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/nullsec-flipper-bridge /dev/ttyACM0
Restart=on-failure
RestartSec=10
User=root
Environment=NULLSEC_SUBGHZ_FREQ=433920000

[Install]
WantedBy=multi-user.target
SYSTEMD

    systemctl daemon-reload 2>/dev/null || true

    log "Flipper bridge service created ✓"
    log "  Start:   sudo systemctl start nullsec-flipper-bridge"
    log "  Enable:  sudo systemctl enable nullsec-flipper-bridge"
    log "  Status:  sudo systemctl status nullsec-flipper-bridge"
    log "  Logs:    tail -f ${FLIPPER_LOG}"

    log "Flipper Zero setup complete ✓"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 6: MESH MONITORING & MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

setup_monitoring() {
    header "PHASE 6: Mesh Monitoring"

    # Create mesh status script
    cat > /usr/local/bin/nullsec-mesh-status << 'MESHSTATUS'
#!/bin/bash
# NullSec Mesh Network Status Dashboard

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'
NC='\033[0m'; BOLD='\033[1m'

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              NullSec Mesh Network Status                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# batman-adv status
echo -e "${WHITE}═══ batman-adv ═══${NC}"
if ip link show bat0 &>/dev/null; then
    echo -e "  Status:     ${GREEN}ACTIVE${NC}"
    echo -e "  Version:    $(cat /sys/module/batman_adv/version 2>/dev/null || echo 'unknown')"
    echo -e "  Interface:  bat0 ($(ip addr show bat0 2>/dev/null | grep 'inet ' | awk '{print $2}'))"
    echo -e "  GW Mode:    $(batctl meshif bat0 gw_mode 2>/dev/null || batctl gw_mode 2>/dev/null || echo 'unknown')"
else
    echo -e "  Status:     ${RED}INACTIVE${NC}"
fi

# Mesh neighbors
echo ""
echo -e "${WHITE}═══ Mesh Neighbors ═══${NC}"
if command -v batctl &>/dev/null; then
    NEIGHBORS=$(batctl meshif bat0 neighbors 2>/dev/null || batctl n 2>/dev/null)
    if [[ -n "$NEIGHBORS" ]]; then
        echo "$NEIGHBORS" | while IFS= read -r line; do
            echo -e "  ${CYAN}${line}${NC}"
        done
    else
        echo -e "  ${YELLOW}No neighbors discovered yet${NC}"
    fi
fi

# Originator table (mesh routing)
echo ""
echo -e "${WHITE}═══ Mesh Routes (Originators) ═══${NC}"
if command -v batctl &>/dev/null; then
    ORIGINATORS=$(batctl meshif bat0 originators 2>/dev/null || batctl o 2>/dev/null)
    if [[ -n "$ORIGINATORS" ]]; then
        echo "$ORIGINATORS" | head -10 | while IFS= read -r line; do
            echo -e "  ${line}"
        done
    else
        echo -e "  ${YELLOW}No originators yet (mesh is forming)${NC}"
    fi
fi

# Pineapple status
echo ""
echo -e "${WHITE}═══ Pineapple Pager ═══${NC}"
PINE_IF=$(ip link 2>/dev/null | grep -B1 "00:13:37" | head -1 | awk -F: '{print $2}' | tr -d ' ')
[[ -z "$PINE_IF" ]] && PINE_IF=$(ip -o addr 2>/dev/null | grep "172.16.52" | awk '{print $2}')
if [[ -n "$PINE_IF" ]]; then
    echo -e "  Interface:  ${GREEN}${PINE_IF}${NC}"
    if ping -c1 -W1 172.16.52.1 &>/dev/null; then
        echo -e "  Status:     ${GREEN}CONNECTED${NC}"
        echo -e "  IP:         172.16.52.1"
        echo -e "  SSH:        $(nc -zw1 172.16.52.1 22 &>/dev/null && echo -e "${GREEN}OPEN${NC}" || echo -e "${RED}CLOSED${NC}")"
        echo -e "  Web UI:     $(nc -zw1 172.16.52.1 1471 &>/dev/null && echo -e "${GREEN}OPEN${NC}" || echo -e "${RED}CLOSED${NC}")"
    else
        echo -e "  Status:     ${RED}UNREACHABLE${NC}"
    fi
else
    echo -e "  Status:     ${YELLOW}NOT CONNECTED${NC}"
fi

# Flipper Zero status
echo ""
echo -e "${WHITE}═══ Flipper Zero ═══${NC}"
if [[ -c /dev/ttyACM0 ]]; then
    echo -e "  Device:     ${GREEN}/dev/ttyACM0${NC}"
    FLIP_USB=$(lsusb 2>/dev/null | grep "0483:5740")
    [[ -n "$FLIP_USB" ]] && echo -e "  USB:        ${FLIP_USB}"
    if systemctl is-active nullsec-flipper-bridge &>/dev/null; then
        echo -e "  Bridge:     ${GREEN}RUNNING${NC}"
    else
        echo -e "  Bridge:     ${YELLOW}STOPPED${NC} (start: sudo systemctl start nullsec-flipper-bridge)"
    fi
else
    echo -e "  Status:     ${YELLOW}NOT CONNECTED${NC}"
fi

# Network overview
echo ""
echo -e "${WHITE}═══ Network Overview ═══${NC}"
echo -e "  Internet:   $(ping -c1 -W1 8.8.8.8 &>/dev/null && echo -e "${GREEN}OK${NC}" || echo -e "${RED}DOWN${NC}")"
echo -e "  VPN:        $(ip link show "$WG_IFACE" &>/dev/null && echo -e "${GREEN}ACTIVE${NC}" || echo -e "${YELLOW}INACTIVE${NC}")"
echo -e "  WiFi:       $(iw dev "$WIFI_IFACE" link 2>/dev/null | grep SSID | awk '{print $2}')"
echo -e "  Mesh IP:    $(ip addr show bat0 2>/dev/null | grep 'inet ' | awk '{print $2}' || echo 'N/A')"
echo ""

# Firewall status
echo -e "${WHITE}═══ Firewall ═══${NC}"
echo -e "  UFW:        $(ufw status 2>/dev/null | head -1)"
echo -e "  Forwarding: $(sysctl -n net.ipv4.ip_forward 2>/dev/null && echo 'enabled' || echo 'disabled')"
echo -e "  NAT rules:  $(iptables -t nat -L POSTROUTING 2>/dev/null | grep -c MASQUERADE) active"
echo ""
MESHSTATUS

    chmod +x /usr/local/bin/nullsec-mesh-status

    # Create mesh node discovery helper
    cat > /usr/local/bin/nullsec-mesh-discover << 'DISCOVER'
#!/bin/bash
# NullSec Mesh Node Discovery
# Scans the mesh network for active nodes

BAT_NETWORK="10.10.10.0/24"

echo "Scanning mesh network ${BAT_NETWORK} for nodes..."
echo ""

# ARP scan on bat0
if command -v arp-scan &>/dev/null; then
    arp-scan --interface=bat0 "$BAT_NETWORK" 2>/dev/null
elif command -v nmap &>/dev/null; then
    nmap -sn "$BAT_NETWORK" 2>/dev/null | grep -E "Nmap scan|Host is up|MAC"
else
    # Fallback: ping sweep
    BASE="10.10.10"
    for i in $(seq 1 254); do
        (ping -c1 -W1 "${BASE}.${i}" &>/dev/null && echo "  ALIVE: ${BASE}.${i}") &
    done
    wait
fi

echo ""
echo "batman-adv translation table:"
batctl meshif bat0 transglobal 2>/dev/null || batctl tg 2>/dev/null || echo "  (no entries)"
DISCOVER

    chmod +x /usr/local/bin/nullsec-mesh-discover

    log "Monitoring tools installed ✓"
    log "  Status:    nullsec-mesh-status"
    log "  Discover:  nullsec-mesh-discover"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 7: BOOT PERSISTENCE
# ═══════════════════════════════════════════════════════════════════════════════

setup_persistence() {
    header "PHASE 7: Boot Persistence"

    # Create systemd service for mesh network
    cat > /etc/systemd/system/nullsec-mesh.service << MESHSERVICE
[Unit]
Description=NullSec Mesh Network (batman-adv)
After=network-online.target
Wants=network-online.target
Before=nullsec-flipper-bridge.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/nullsec-mesh-up
ExecStop=/usr/local/bin/nullsec-mesh-down

[Install]
WantedBy=multi-user.target
MESHSERVICE

    # Create mesh up script
    cat > /usr/local/bin/nullsec-mesh-up << MESHUP
#!/bin/bash
# NullSec Mesh Network - Bring Up
LOG="/var/log/nullsec/mesh-setup.log"
log() { echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" >> "\$LOG"; }

log "Starting NullSec mesh network..."

# Load batman-adv
modprobe batman-adv

# Create mesh interface
if ! ip link show ${MESH_IFACE} &>/dev/null; then
    iw dev ${WIFI_IFACE} interface add ${MESH_IFACE} type mesh 2>/dev/null || \\
    iw phy \$(iw dev ${WIFI_IFACE} info | grep wiphy | awk '{print "phy"\$2}') interface add ${MESH_IFACE} type mesh 2>/dev/null
fi

ip link set ${MESH_IFACE} up
sleep 1
iw dev ${MESH_IFACE} mesh join ${MESH_ID} 2>/dev/null

# Setup batman
batctl meshif ${BAT_IFACE} interface add -M ${MESH_IFACE} 2>/dev/null || batctl if add ${MESH_IFACE} 2>/dev/null
ip link set ${BAT_IFACE} up
ip addr flush dev ${BAT_IFACE} 2>/dev/null
ip addr add ${BAT_IP} dev ${BAT_IFACE}

# Gateway mode
batctl meshif ${BAT_IFACE} gw_mode server 2>/dev/null || batctl gw_mode server 2>/dev/null

# IP forwarding
sysctl -w net.ipv4.ip_forward=1 > /dev/null

# NAT
iptables -t nat -A POSTROUTING -s ${BAT_NETWORK} -o ${WIFI_IFACE} -j MASQUERADE 2>/dev/null
iptables -A FORWARD -i ${BAT_IFACE} -o ${WIFI_IFACE} -j ACCEPT 2>/dev/null
iptables -A FORWARD -i ${WIFI_IFACE} -o ${BAT_IFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null

# NAT via VPN if active
if ip link show ${WG_IFACE} &>/dev/null; then
    iptables -t nat -A POSTROUTING -s ${BAT_NETWORK} -o ${WG_IFACE} -j MASQUERADE 2>/dev/null
fi

log "Mesh network started successfully"
MESHUP

    chmod +x /usr/local/bin/nullsec-mesh-up

    # Create mesh down script
    cat > /usr/local/bin/nullsec-mesh-down << MESHDOWN
#!/bin/bash
# NullSec Mesh Network - Tear Down
LOG="/var/log/nullsec/mesh-setup.log"
log() { echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" >> "\$LOG"; }

log "Stopping NullSec mesh network..."

# Remove NAT rules
iptables -t nat -D POSTROUTING -s ${BAT_NETWORK} -o ${WIFI_IFACE} -j MASQUERADE 2>/dev/null
iptables -D FORWARD -i ${BAT_IFACE} -o ${WIFI_IFACE} -j ACCEPT 2>/dev/null
iptables -D FORWARD -i ${WIFI_IFACE} -o ${BAT_IFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null

# Tear down bat0
ip link set ${BAT_IFACE} down 2>/dev/null

# Remove mesh interface from batman
batctl meshif ${BAT_IFACE} interface del -M ${MESH_IFACE} 2>/dev/null || batctl if del ${MESH_IFACE} 2>/dev/null

# Tear down mesh interface
ip link set ${MESH_IFACE} down 2>/dev/null
iw dev ${MESH_IFACE} del 2>/dev/null

log "Mesh network stopped"
MESHDOWN

    chmod +x /usr/local/bin/nullsec-mesh-down

    # Enable on boot
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable nullsec-mesh.service 2>/dev/null || true

    log "Boot persistence configured ✓"
    log "  Service:  nullsec-mesh.service"
    log "  Enable:   sudo systemctl enable nullsec-mesh"
    log "  Start:    sudo systemctl start nullsec-mesh"
    log "  Stop:     sudo systemctl stop nullsec-mesh"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SHOW STATUS / SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

show_status() {
    header "MESH NETWORK STATUS"

    echo -e "  ${WHITE}Mesh Interface:${NC}  ${MESH_IFACE}"
    if ip link show "$MESH_IFACE" &>/dev/null; then
        echo -e "  ${WHITE}Mesh Status:${NC}     ${GREEN}UP${NC}"
        echo -e "  ${WHITE}Mesh ID:${NC}         ${MESH_ID}"
    else
        echo -e "  ${WHITE}Mesh Status:${NC}     ${RED}DOWN${NC}"
    fi

    echo ""
    echo -e "  ${WHITE}bat0 Interface:${NC}  ${BAT_IFACE}"
    if ip link show "$BAT_IFACE" &>/dev/null; then
        echo -e "  ${WHITE}bat0 Status:${NC}     ${GREEN}UP${NC}"
        echo -e "  ${WHITE}bat0 IP:${NC}         $(ip addr show $BAT_IFACE 2>/dev/null | grep 'inet ' | awk '{print $2}')"
        echo -e "  ${WHITE}GW Mode:${NC}         $(batctl meshif $BAT_IFACE gw_mode 2>/dev/null || batctl gw_mode 2>/dev/null || echo 'N/A')"
    else
        echo -e "  ${WHITE}bat0 Status:${NC}     ${RED}DOWN${NC}"
    fi

    echo ""
    echo -e "  ${WHITE}Neighbors:${NC}"
    batctl meshif "$BAT_IFACE" neighbors 2>/dev/null || batctl n 2>/dev/null || echo "    (none)"

    echo ""
    echo -e "  ${WHITE}Pineapple:${NC}       $(ping -c1 -W1 $PINEAPPLE_IP &>/dev/null && echo -e "${GREEN}CONNECTED${NC}" || echo -e "${YELLOW}NOT CONNECTED${NC}")"
    echo -e "  ${WHITE}Flipper:${NC}         $([[ -c $FLIPPER_DEV ]] && echo -e "${GREEN}CONNECTED${NC}" || echo -e "${YELLOW}NOT CONNECTED${NC}")"
    echo -e "  ${WHITE}Internet:${NC}        $(ping -c1 -W1 8.8.8.8 &>/dev/null && echo -e "${GREEN}OK${NC}" || echo -e "${RED}DOWN${NC}")"
    echo -e "  ${WHITE}VPN:${NC}             $(ip link show $WG_IFACE &>/dev/null && echo -e "${GREEN}ACTIVE${NC}" || echo -e "${YELLOW}INACTIVE${NC}")"
    echo -e "  ${WHITE}IP Forward:${NC}      $(sysctl -n net.ipv4.ip_forward 2>/dev/null)"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# TEARDOWN
# ═══════════════════════════════════════════════════════════════════════════════

teardown() {
    header "TEARDOWN: Removing Mesh Network"

    warn "This will remove ALL mesh networking components"
    echo -n "Are you sure? [y/N] "
    read -r confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { info "Aborted"; return; }

    # Stop services
    systemctl stop nullsec-flipper-bridge 2>/dev/null || true
    systemctl stop nullsec-mesh 2>/dev/null || true
    systemctl disable nullsec-flipper-bridge 2>/dev/null || true
    systemctl disable nullsec-mesh 2>/dev/null || true

    # Remove mesh interface
    ip link set "$BAT_IFACE" down 2>/dev/null || true
    batctl meshif "$BAT_IFACE" interface del -M "$MESH_IFACE" 2>/dev/null || true
    ip link set "$MESH_IFACE" down 2>/dev/null || true
    iw dev "$MESH_IFACE" del 2>/dev/null || true

    # Remove iptables rules
    iptables -t nat -D POSTROUTING -s "$BAT_NETWORK" -o "$WIFI_IFACE" -j MASQUERADE 2>/dev/null || true
    iptables -t nat -D POSTROUTING -s "$BAT_NETWORK" -o "$WG_IFACE" -j MASQUERADE 2>/dev/null || true
    iptables -t nat -D POSTROUTING -s "$PINEAPPLE_NET" -o "$WIFI_IFACE" -j MASQUERADE 2>/dev/null || true
    iptables -D FORWARD -i bat0 -o "$WIFI_IFACE" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "$WIFI_IFACE" -o bat0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true

    # Remove UFW rules
    ufw delete allow in on bat0 2>/dev/null || true
    ufw delete allow out on bat0 2>/dev/null || true
    ufw delete allow 4305/tcp 2>/dev/null || true
    ufw delete allow 4305/udp 2>/dev/null || true
    ufw delete allow from "$BAT_NETWORK" 2>/dev/null || true

    # Remove systemd services
    rm -f /etc/systemd/system/nullsec-mesh.service
    rm -f /etc/systemd/system/nullsec-flipper-bridge.service
    systemctl daemon-reload 2>/dev/null || true

    # Remove scripts
    rm -f /usr/local/bin/nullsec-mesh-up
    rm -f /usr/local/bin/nullsec-mesh-down
    rm -f /usr/local/bin/nullsec-mesh-status
    rm -f /usr/local/bin/nullsec-mesh-discover
    rm -f /usr/local/bin/nullsec-flipper-bridge

    # Remove udev rule
    rm -f /etc/udev/rules.d/42-nullsec-flipper.rules

    log "Teardown complete. Mesh network removed."
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

show_help() {
    banner
    echo -e "${WHITE}USAGE:${NC}"
    echo "  sudo $0 [command]"
    echo ""
    echo -e "${WHITE}COMMANDS:${NC}"
    echo -e "  ${CYAN}setup${NC}       Full mesh network setup (all phases)"
    echo -e "  ${CYAN}firewall${NC}    Configure firewall only (Phase 2)"
    echo -e "  ${CYAN}mesh${NC}        Setup batman-adv mesh only (Phase 3)"
    echo -e "  ${CYAN}pineapple${NC}   Setup Pineapple integration (Phase 4)"
    echo -e "  ${CYAN}flipper${NC}     Setup Flipper Zero bridge (Phase 5)"
    echo -e "  ${CYAN}optimize${NC}    Tune mesh for max performance (run after setup)"
    echo -e "  ${CYAN}status${NC}      Show mesh network status"
    echo -e "  ${CYAN}monitor${NC}     Real-time mesh monitoring (installs tools)"
    echo -e "  ${CYAN}teardown${NC}    Remove all mesh components"
    echo -e "  ${CYAN}help${NC}        Show this help"
    echo ""
    echo -e "${WHITE}QUICK START:${NC}"
    echo "  sudo $0 setup    # Full setup (recommended)"
    echo ""
    echo -e "${WHITE}ARCHITECTURE:${NC}"
    echo "  [Internet] ←WiFi→ [This Machine] ←mesh0/bat0→ [Mesh Nodes]"
    echo "                          │                          "
    echo "                    [Flipper Zero]  ← SubGHz bridge  "
    echo "                          │                          "
    echo "                   [Remote Nodes]                    "
    echo "                          │                          "
    echo "                  [Pineapple Pager] ← USB            "
    echo ""
    echo -e "${WHITE}MESH NETWORK:${NC}"
    echo "  Network:    ${BAT_NETWORK}"
    echo "  This node:  ${BAT_IP}"
    echo "  Mesh ID:    ${MESH_ID}"
    echo "  Channel:    ${MESH_CHANNEL} (${MESH_FREQ} MHz)"
    echo ""
    echo -e "${GRAY}NullSec Mesh Setup v1.0 - Developed by bad-antics${NC}"
    echo ""
}

main() {
    # Setup logging
    mkdir -p "$LOG_DIR" 2>/dev/null || true

    case "${1:-help}" in
        setup|install|full)
            check_root
            banner
            log "═══ NullSec Mesh Setup started at $(date) ═══"
            install_dependencies
            setup_firewall
            setup_mesh_network
            setup_pineapple || warn "Pineapple phase skipped (not connected)"
            setup_flipper || warn "Flipper phase skipped (not connected)"
            setup_monitoring
            setup_persistence

            header "SETUP COMPLETE ✓"
            echo -e "  ${GREEN}All phases completed successfully!${NC}"
            echo ""
            show_status
            echo -e "  ${WHITE}Commands:${NC}"
            echo -e "    ${CYAN}nullsec-mesh-status${NC}      View full status dashboard"
            echo -e "    ${CYAN}nullsec-mesh-discover${NC}    Discover mesh nodes"
            echo -e "    ${CYAN}sudo systemctl start nullsec-flipper-bridge${NC}"
            echo -e "                             Start Flipper SubGHz bridge"
            echo ""
            echo -e "  ${WHITE}Pineapple:${NC}"
            echo -e "    ${CYAN}ssh root@${PINEAPPLE_IP}${NC}"
            echo -e "    ${CYAN}http://${PINEAPPLE_IP}:1471${NC}"
            echo ""
            log "═══ Setup completed at $(date) ═══"
            ;;
        firewall|fw)
            check_root
            banner
            setup_firewall
            ;;
        mesh|batman)
            check_root
            banner
            install_dependencies
            setup_mesh_network
            ;;
        pineapple|pine)
            check_root
            banner
            setup_pineapple
            ;;
        flipper|flip)
            check_root
            banner
            setup_flipper
            ;;
        optimize|tune|perf)
            check_root
            banner
            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            if [[ -x "${SCRIPT_DIR}/nullsec-mesh-optimize.sh" ]]; then
                exec "${SCRIPT_DIR}/nullsec-mesh-optimize.sh" "${2:-}"
            else
                err "nullsec-mesh-optimize.sh not found in ${SCRIPT_DIR}"
                info "Download it or run: ./nullsec-mesh-setup.sh setup"
                exit 1
            fi
            ;;
        status|stat)
            banner
            show_status
            ;;
        monitor|mon)
            check_root
            banner
            setup_monitoring
            nullsec-mesh-status 2>/dev/null || show_status
            ;;
        teardown|remove|uninstall)
            check_root
            banner
            teardown
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            err "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
