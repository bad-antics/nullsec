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
#║               NullSec Distributed Compute Cluster v1.0                        ║
#║                      Developed by: bad-antics                                 ║
#║                                                                               ║
#╚═══════════════════════════════════════════════════════════════════════════════╝
#
#  Combines all machines on the network into a distributed compute cluster.
#  Supports Linux (x86_64, ARM64) and Windows (via SSH/OpenSSH).
#
#  Features:
#    - Node auto-discovery and registration
#    - SSH-based job distribution (GNU Parallel)
#    - Distributed compilation (distcc)
#    - GPU compute offloading (CUDA)
#    - Real-time resource monitoring across all nodes
#    - Easy add/remove nodes
#    - Works across mixed OS (Linux, Windows, ARM)
#
#  Architecture:
#    ┌─────────────────────────────────────────────────────────┐
#    │  NullSec Gateway (controller)                          │
#    │  gateway @ 192.168.1.1                                 │
#    ├─────────────────────────────────────────────────────────┤
#    │                                                         │
#    │  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐  │
#    │  │  node-1      │  │   node-2     │  │  node-3      │  │
#    │  │  Windows PC  │  │   RPi / ARM  │  │  Laptop      │  │
#    │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
#    │         │                 │                  │          │
#    │    ─────┴─────────────────┴──────────────────┴─────     │
#    │              192.168.1.0/24  (your LAN)                 │
#    └─────────────────────────────────────────────────────────┘
#
#  Usage: ./nullsec-cluster.sh [command]
#

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

CLUSTER_NAME="nullsec-compute"
CLUSTER_DIR="$HOME/.nullsec/cluster"
NODES_FILE="${CLUSTER_DIR}/nodes.conf"
STATE_DIR="${CLUSTER_DIR}/state"
LOG_DIR="${CLUSTER_DIR}/logs"
LOG_FILE="${LOG_DIR}/cluster.log"
JOBS_DIR="${CLUSTER_DIR}/jobs"
SHARED_DIR="${CLUSTER_DIR}/shared"
SSH_KEY="${HOME}/.ssh/id_ed25519"
SSH_OPTS="-o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"
SUBNET="192.168.1.0/24"
PARALLEL_PROFILE="${CLUSTER_DIR}/parallel-profile"
DISTCC_HOSTS_FILE="${CLUSTER_DIR}/distcc-hosts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

log()    { echo -e "${GREEN}[+]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null; }
warn()   { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null; }
err()    { echo -e "${RED}[-]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null; }
info()   { echo -e "${BLUE}[i]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null; }
debug()  { echo -e "${GRAY}[d] $1${NC}" >> "$LOG_FILE" 2>/dev/null; }
header() {
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${WHITE}  $1${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
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
    ║          NullSec Distributed Compute Cluster v1.0            ║
    ║                  Developed by: bad-antics                    ║
    ╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

init_dirs() {
    mkdir -p "$CLUSTER_DIR" "$STATE_DIR" "$LOG_DIR" "$JOBS_DIR" "$SHARED_DIR"
}

# ═══════════════════════════════════════════════════════════════════════════════
# NODE REGISTRY
# Format: hostname|ip|user|port|os|arch|cores|ram_mb|gpu|role|tags
# ═══════════════════════════════════════════════════════════════════════════════

init_nodes_file() {
    if [[ ! -f "$NODES_FILE" ]]; then
        cat > "$NODES_FILE" << 'HEADER'
# NullSec Compute Cluster - Node Registry
# Format: hostname|ip|user|port|os|arch|cores|ram_mb|gpu|role|tags
# Role: controller, worker, gpu-worker, arm-worker
# Tags: comma-separated (e.g., linux,x86,cuda,docker)
HEADER
    fi
}

add_node_entry() {
    local hostname="$1" ip="$2" user="$3" port="${4:-22}" os="$5" arch="$6"
    local cores="$7" ram_mb="$8" gpu="${9:-none}" role="${10:-worker}" tags="${11:-}"

    # Remove existing entry for this IP
    if [[ -f "$NODES_FILE" ]]; then
        sed -i "/^${hostname}|/d" "$NODES_FILE" 2>/dev/null
        sed -i "/|${ip}|/d" "$NODES_FILE" 2>/dev/null
    fi

    echo "${hostname}|${ip}|${user}|${port}|${os}|${arch}|${cores}|${ram_mb}|${gpu}|${role}|${tags}" >> "$NODES_FILE"
}

get_nodes() {
    # Returns active node lines (skipping comments and blanks)
    grep -v "^#" "$NODES_FILE" 2>/dev/null | grep -v "^$" || true
}

get_node_field() {
    local line="$1" field="$2"
    echo "$line" | cut -d'|' -f"$field"
}

# Field indices
F_HOSTNAME=1 F_IP=2 F_USER=3 F_PORT=4 F_OS=5 F_ARCH=6
F_CORES=7 F_RAM=8 F_GPU=9 F_ROLE=10 F_TAGS=11

# ═══════════════════════════════════════════════════════════════════════════════
# NODE PROBING - Detect OS, hardware, capabilities
# ═══════════════════════════════════════════════════════════════════════════════

probe_linux_node() {
    local ip="$1" user="$2" port="${3:-22}"
    ssh $SSH_OPTS -p "$port" "${user}@${ip}" bash << 'PROBE' 2>/dev/null
echo "HOSTNAME=$(hostname)"
echo "OS=$(cat /etc/os-release 2>/dev/null | grep ^ID= | cut -d= -f2 | tr -d '\"')"
echo "OS_PRETTY=$(cat /etc/os-release 2>/dev/null | grep PRETTY | cut -d= -f2 | tr -d '\"')"
echo "ARCH=$(uname -m)"
echo "KERNEL=$(uname -r)"
echo "CORES=$(nproc)"
echo "RAM_MB=$(free -m | awk '/Mem:/{print $2}')"
echo "RAM_FREE_MB=$(free -m | awk '/Mem:/{print $7}')"
echo "DISK_TOTAL=$(df -BG / | tail -1 | awk '{print $2}' | tr -d 'G')"
echo "DISK_FREE=$(df -BG / | tail -1 | awk '{print $4}' | tr -d 'G')"
echo "CPU_MODEL=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
echo "LOAD=$(cat /proc/loadavg | awk '{print $1, $2, $3}')"
echo "UPTIME=$(uptime -p 2>/dev/null || uptime | sed 's/.*up/up/')"

# GPU detection
GPU="none"
if command -v nvidia-smi &>/dev/null; then
    GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    CUDA=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
    GPU_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
    echo "GPU=${GPU}"
    echo "CUDA_DRIVER=${CUDA}"
    echo "GPU_MEM_MB=${GPU_MEM}"
elif lspci 2>/dev/null | grep -qi "nvidia\|radeon\|amd.*display"; then
    GPU=$(lspci 2>/dev/null | grep -i "vga\|3d" | grep -iv "intel" | head -1 | sed 's/.*: //')
    echo "GPU=${GPU}"
else
    echo "GPU=none"
fi

# Software detection
echo "HAS_DOCKER=$(command -v docker &>/dev/null && echo yes || echo no)"
echo "HAS_PYTHON3=$(command -v python3 &>/dev/null && python3 --version 2>/dev/null | awk '{print $2}' || echo no)"
echo "HAS_GCC=$(command -v gcc &>/dev/null && gcc --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' || echo no)"
echo "HAS_MAKE=$(command -v make &>/dev/null && echo yes || echo no)"
echo "HAS_GIT=$(command -v git &>/dev/null && echo yes || echo no)"
echo "HAS_PARALLEL=$(command -v parallel &>/dev/null && echo yes || echo no)"
echo "HAS_DISTCC=$(command -v distcc &>/dev/null && echo yes || echo no)"
PROBE
}

probe_windows_node() {
    local ip="$1" user="$2" port="${3:-22}"
    ssh $SSH_OPTS -p "$port" "${user}@${ip}" << 'PROBE' 2>/dev/null
@echo off
for /f "tokens=2 delims==" %%a in ('hostname') do set HNULL=%%a
hostname
echo OS=windows
for /f "tokens=2 delims=:" %%a in ('systeminfo ^| findstr /C:"OS Name"') do echo OS_PRETTY=%%a
wmic cpu get name /value 2>nul | findstr Name
wmic cpu get numberoflogicalprocessors /value 2>nul | findstr Number
wmic os get totalvisiblememorysize /value 2>nul | findstr Total
wmic os get freephysicalmemory /value 2>nul | findstr Free
wmic path win32_videocontroller get name /value 2>nul | findstr Name
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader,nounits 2>nul
systeminfo | findstr /C:"System Type"
python --version 2>nul || python3 --version 2>nul
docker --version 2>nul
PROBE
}

probe_node() {
    local ip="$1" user="$2" port="${3:-22}"

    # First, detect OS type
    local os_type
    os_type=$(ssh $SSH_OPTS -p "$port" "${user}@${ip}" "uname -s 2>/dev/null || echo Windows" 2>/dev/null)

    if [[ "$os_type" == *"Linux"* ]]; then
        echo "PROBE_OS=linux"
        probe_linux_node "$ip" "$user" "$port"
    elif [[ "$os_type" == *"MINGW"* ]] || [[ "$os_type" == *"MSYS"* ]] || [[ "$os_type" == *"CYGWIN"* ]]; then
        echo "PROBE_OS=linux-compat"
        probe_linux_node "$ip" "$user" "$port"
    else
        echo "PROBE_OS=windows"
        probe_windows_node "$ip" "$user" "$port"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# ADD NODE
# ═══════════════════════════════════════════════════════════════════════════════

cmd_add() {
    local ip="$1" user="${2:-$USER}" port="${3:-22}"

    if [[ -z "$ip" ]]; then
        echo -e "${WHITE}Usage:${NC} $0 add <ip> [user] [port]"
        echo -e "  Example: $0 add 192.168.1.100 user 22"
        return 1
    fi

    header "Adding Node: ${ip}"

    # Test SSH connectivity
    info "Testing SSH connection to ${user}@${ip}:${port}..."
    if ! ssh $SSH_OPTS -p "$port" "${user}@${ip}" "echo ok" &>/dev/null; then
        err "Cannot connect via SSH to ${user}@${ip}:${port}"
        info "Ensure SSH is enabled and your key is authorized:"
        echo -e "  ${CYAN}ssh-copy-id -i ${SSH_KEY} ${user}@${ip}${NC}"
        return 1
    fi
    log "SSH connection OK ✓"

    # Probe the node
    info "Probing hardware and software..."
    local probe_output
    probe_output=$(probe_node "$ip" "$user" "$port")

    if [[ -z "$probe_output" ]]; then
        err "Failed to probe node"
        return 1
    fi

    # Parse probe results
    local hostname os arch cores ram_mb gpu role tags cpu_model
    local probe_os
    probe_os=$(echo "$probe_output" | grep "^PROBE_OS=" | cut -d= -f2)

    if [[ "$probe_os" == "windows" ]]; then
        # Parse hostname: skip PROBE_OS line + any "Microsoft Windows" version banners
        hostname=$(echo "$probe_output" | grep -v "^PROBE_OS=" | grep -vi "Microsoft Windows" | grep -vi "^Name=" | grep -vi "Number" | grep -vi "Total" | grep -vi "Free" | grep -vi "OS=" | grep -vi "nvidia" | grep -vi "System Type" | grep -vi "Python\|Docker\|docker" | grep -vi "^$" | head -1 | tr -d '\r\n ')
        # Fallback: use SSH to just get hostname directly
        [[ -z "$hostname" || "$hostname" == *"Microsoft"* || "$hostname" == *"Version"* ]] && \
            hostname=$(ssh $SSH_OPTS -p "$port" "${user}@${ip}" "hostname" </dev/null 2>/dev/null | tr -d '\r\n ')
        os="windows"
        arch="x86_64"
        cores=$(echo "$probe_output" | grep "NumberOfLogicalProcessors=" | cut -d= -f2 | tr -d '\r\n ')
        ram_mb=$(echo "$probe_output" | grep "TotalVisibleMemorySize=" | cut -d= -f2 | tr -d '\r\n ')
        ram_mb=$(( ${ram_mb:-0} / 1024 ))
        gpu=$(echo "$probe_output" | grep "^Name=" | tail -1 | cut -d= -f2 | tr -d '\r\n')
        cpu_model=$(echo "$probe_output" | grep "^Name=" | head -1 | cut -d= -f2 | tr -d '\r\n')
        tags="windows,x86_64,ssh"

        # Check for CUDA - must be actual nvidia-smi output, not just GPU name containing "nvidia"
        if echo "$probe_output" | grep -qi "nvidia-smi\|cuda"; then
            tags="${tags},cuda,gpu"
            role="gpu-worker"
        elif echo "$probe_output" | grep -qi "nvidia" && echo "$probe_output" | grep -qi "GeForce\|RTX\|GTX\|Quadro\|Tesla"; then
            tags="${tags},gpu"
            role="gpu-worker"
        else
            role="worker"
        fi

        # Check for python/docker
        echo "$probe_output" | grep -qi "Python" && tags="${tags},python"
        echo "$probe_output" | grep -qi "Docker" && tags="${tags},docker"
    else
        hostname=$(echo "$probe_output" | grep "^HOSTNAME=" | cut -d= -f2)
        os=$(echo "$probe_output" | grep "^OS=" | head -1 | cut -d= -f2)
        arch=$(echo "$probe_output" | grep "^ARCH=" | cut -d= -f2)
        cores=$(echo "$probe_output" | grep "^CORES=" | cut -d= -f2)
        ram_mb=$(echo "$probe_output" | grep "^RAM_MB=" | cut -d= -f2)
        gpu=$(echo "$probe_output" | grep "^GPU=" | head -1 | cut -d= -f2)
        cpu_model=$(echo "$probe_output" | grep "^CPU_MODEL=" | cut -d= -f2-)
        tags="linux,${arch},ssh"

        # Determine role
        if [[ "$gpu" != "none" && -n "$gpu" ]]; then
            role="gpu-worker"
            tags="${tags},gpu"
            echo "$probe_output" | grep -q "CUDA_DRIVER=" && tags="${tags},cuda"
        elif [[ "$arch" == "aarch64" || "$arch" == "armv7l" ]]; then
            role="arm-worker"
            tags="${tags},arm"
        else
            role="worker"
        fi

        # Software tags
        [[ "$(echo "$probe_output" | grep "HAS_DOCKER=" | cut -d= -f2)" == "yes" ]] && tags="${tags},docker"
        [[ "$(echo "$probe_output" | grep "HAS_PYTHON3=" | cut -d= -f2)" != "no" ]] && tags="${tags},python"
        [[ "$(echo "$probe_output" | grep "HAS_GCC=" | cut -d= -f2)" != "no" ]] && tags="${tags},gcc"
        [[ "$(echo "$probe_output" | grep "HAS_DISTCC=" | cut -d= -f2)" == "yes" ]] && tags="${tags},distcc"
    fi

    # Register the node
    add_node_entry "$hostname" "$ip" "$user" "$port" "$os" "$arch" \
                   "${cores:-1}" "${ram_mb:-0}" "${gpu:-none}" "$role" "$tags"

    # Save full probe data
    echo "$probe_output" > "${STATE_DIR}/${hostname}.probe"

    log "Node registered ✓"
    echo ""
    echo -e "  ${WHITE}Hostname:${NC}  ${hostname}"
    echo -e "  ${WHITE}IP:${NC}        ${ip}"
    echo -e "  ${WHITE}OS:${NC}        ${os} (${arch})"
    echo -e "  ${WHITE}CPU:${NC}       ${cpu_model:-unknown}"
    echo -e "  ${WHITE}Cores:${NC}     ${cores}"
    echo -e "  ${WHITE}RAM:${NC}       ${ram_mb} MB"
    echo -e "  ${WHITE}GPU:${NC}       ${gpu:-none}"
    echo -e "  ${WHITE}Role:${NC}      ${role}"
    echo -e "  ${WHITE}Tags:${NC}      ${tags}"
    echo ""

    # Update GNU Parallel and distcc configs
    update_parallel_config
    update_distcc_config
}

cmd_add_local() {
    header "Registering Local Node (controller)"

    local hostname=$(hostname)
    local cores=$(nproc)
    local ram_mb=$(free -m | awk '/Mem:/{print $2}')
    local arch=$(uname -m)
    local gpu="none"
    local tags="linux,${arch},ssh,controller"

    # Detect GPU
    if lspci 2>/dev/null | grep -qi "nvidia"; then
        gpu=$(lspci | grep -i "vga\|3d" | grep -iv "intel" | head -1 | sed 's/.*: //' | xargs)
        tags="${tags},gpu"
        if command -v nvidia-smi &>/dev/null; then
            tags="${tags},cuda"
        fi
    fi

    # Software
    command -v docker &>/dev/null && tags="${tags},docker"
    command -v python3 &>/dev/null && tags="${tags},python"
    command -v gcc &>/dev/null && tags="${tags},gcc"
    command -v distcc &>/dev/null && tags="${tags},distcc"
    command -v make &>/dev/null && tags="${tags},make"

    local cpu_model
    cpu_model=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)

    add_node_entry "$hostname" "127.0.0.1" "$USER" "22" "linux" "$arch" \
                   "$cores" "$ram_mb" "$gpu" "controller" "$tags"

    # Save probe data
    probe_linux_node "127.0.0.1" "$USER" "22" > "${STATE_DIR}/${hostname}.probe" 2>/dev/null || true

    log "Controller node registered: ${hostname}"
    echo -e "  ${WHITE}CPU:${NC}    ${cpu_model}"
    echo -e "  ${WHITE}Cores:${NC}  ${cores}"
    echo -e "  ${WHITE}RAM:${NC}    ${ram_mb} MB"
    echo -e "  ${WHITE}GPU:${NC}    ${gpu}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# REMOVE NODE
# ═══════════════════════════════════════════════════════════════════════════════

cmd_remove() {
    local target="$1"
    if [[ -z "$target" ]]; then
        echo -e "${WHITE}Usage:${NC} $0 remove <hostname|ip>"
        return 1
    fi

    if grep -q "$target" "$NODES_FILE" 2>/dev/null; then
        sed -i "/${target}/d" "$NODES_FILE"
        rm -f "${STATE_DIR}/${target}.probe"
        log "Removed node: ${target}"
        update_parallel_config
        update_distcc_config
    else
        err "Node not found: ${target}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# DISCOVER - Auto-find new machines on the network
# ═══════════════════════════════════════════════════════════════════════════════

cmd_discover() {
    header "Auto-Discovering Compute Nodes"

    local my_ip
    my_ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' || true)
    [[ -z "$my_ip" ]] && my_ip=$(hostname -I | awk '{print $1}')

    info "Scanning ${SUBNET} for SSH-capable hosts..."
    echo ""

    # Fast ping sweep + SSH check
    local found=0
    local known_ips=""
    known_ips=$(get_nodes | cut -d'|' -f2 | tr '\n' ' ')

    # Use nmap for speed
    local hosts
    hosts=$(nmap -sn -T4 "$SUBNET" 2>/dev/null | grep "scan report" | awk '{print $NF}' | tr -d '()')

    for ip in $hosts; do
        # Skip self, router, and known nodes
        [[ "$ip" == "$my_ip" ]] && continue
        # Skip the default gateway
        local gw_ip
        gw_ip=$(ip route | awk '/default/{print $3}' 2>/dev/null || echo "")
        [[ "$ip" == "$gw_ip" ]] && continue
        echo "$known_ips" | grep -q "$ip" && continue

        # Check for SSH
        if nc -zw2 "$ip" 22 &>/dev/null; then
            local mac vendor
            mac=$(arp -a 2>/dev/null | grep "$ip" | awk '{print $4}' || true)
            vendor=$(grep -i "$(echo "$mac" | tr ':' '' | cut -c1-6)" /usr/share/nmap/nmap-mac-prefixes 2>/dev/null | head -1 | awk '{$1=""; print $0}' | xargs || true)

            echo -e "  ${GREEN}FOUND${NC} ${ip} (${vendor:-unknown vendor}) — SSH open"

            # Try passwordless auth
            local ssh_user=""
            for tryuser in "$USER" root pi admin; do
                if ssh $SSH_OPTS "${tryuser}@${ip}" "echo ok" &>/dev/null; then
                    ssh_user="$tryuser"
                    break
                fi
            done

            if [[ -n "$ssh_user" ]]; then
                echo -e "    ${CYAN}→ SSH key auth works as '${ssh_user}' — auto-adding...${NC}"
                cmd_add "$ip" "$ssh_user" 22
                ((found++))
            else
                echo -e "    ${YELLOW}→ SSH key auth failed. To add manually:${NC}"
                echo -e "      ${DIM}ssh-copy-id -i ${SSH_KEY} user@${ip}${NC}"
                echo -e "      ${DIM}$0 add ${ip} user${NC}"
            fi
        fi
    done

    echo ""
    if [[ $found -eq 0 ]]; then
        info "No new SSH-accessible nodes found"
    else
        log "Discovered and added ${found} new node(s)"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATUS - Show cluster overview
# ═══════════════════════════════════════════════════════════════════════════════

cmd_status() {
    header "NullSec Compute Cluster Status"

    local total_cores=0 total_ram=0 total_nodes=0
    local online_nodes=0 gpu_nodes=0

    printf "  ${WHITE}%-14s %-16s %-8s %-6s %-8s %-20s %-10s %s${NC}\n" \
        "HOSTNAME" "IP" "OS" "CORES" "RAM" "GPU" "ROLE" "STATUS"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────────────────────────────────────${NC}"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local hostname ip user port os arch cores ram_mb gpu role
        hostname=$(get_node_field "$line" $F_HOSTNAME)
        ip=$(get_node_field "$line" $F_IP)
        user=$(get_node_field "$line" $F_USER)
        port=$(get_node_field "$line" $F_PORT)
        os=$(get_node_field "$line" $F_OS)
        cores=$(get_node_field "$line" $F_CORES)
        ram_mb=$(get_node_field "$line" $F_RAM)
        gpu=$(get_node_field "$line" $F_GPU)
        role=$(get_node_field "$line" $F_ROLE)

        ((total_nodes++))

        # Check if online
        local status status_color
        if [[ "$ip" == "127.0.0.1" ]]; then
            status="🟢 ONLINE"
            status_color="$GREEN"
            ((online_nodes++))
        elif ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR -p "$port" "${user}@${ip}" "echo ok" </dev/null &>/dev/null; then
            status="🟢 ONLINE"
            status_color="$GREEN"
            ((online_nodes++))
        else
            status="🔴 OFFLINE"
            status_color="$RED"
        fi

        total_cores=$((total_cores + ${cores:-0}))
        total_ram=$((total_ram + ${ram_mb:-0}))
        [[ "$gpu" != "none" && -n "$gpu" && ! "$gpu" =~ [Ii]ntel ]] && ((gpu_nodes++))

        # Format RAM
        local ram_str
        if [[ ${ram_mb:-0} -ge 1024 ]]; then
            ram_str="$(( ram_mb / 1024 ))GB"
        else
            ram_str="${ram_mb}MB"
        fi

        # Truncate GPU name
        local gpu_short
        if [[ "$gpu" == "none" || -z "$gpu" ]]; then
            gpu_short="—"
        else
            gpu_short=$(echo "$gpu" | sed 's/NVIDIA //' | sed 's/GeForce //' | cut -c1-18)
        fi

        printf "  ${status_color}%-14s${NC} %-16s %-8s %-6s %-8s %-20s %-10s %s\n" \
            "$hostname" "$ip" "$os" "$cores" "$ram_str" "$gpu_short" "$role" "$status"

    done <<< "$(get_nodes)"

    echo ""
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${WHITE}Cluster Total:${NC}  ${online_nodes}/${total_nodes} nodes online  │  ${total_cores} CPU cores  │  $((total_ram / 1024))GB RAM  │  ${gpu_nodes} GPU node(s)"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# LIVE MONITORING - Real-time resource usage across all nodes
# ═══════════════════════════════════════════════════════════════════════════════

cmd_monitor() {
    header "Live Cluster Monitor (Ctrl+C to exit)"

    while true; do
        clear
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${WHITE}NullSec Compute Cluster — Live Monitor${NC}         $(date '+%H:%M:%S')               ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        printf "  ${WHITE}%-14s %-6s %-10s %-10s %-12s %-8s %s${NC}\n" \
            "NODE" "CORES" "CPU LOAD" "RAM USED" "DISK FREE" "PROCS" "STATUS"
        echo -e "  ${DIM}──────────────────────────────────────────────────────────────────────────────${NC}"

        while IFS= read -r line; do
            [[ -z "$line" ]] && continue

            local hostname ip user port os cores ram_mb
            hostname=$(get_node_field "$line" $F_HOSTNAME)
            ip=$(get_node_field "$line" $F_IP)
            user=$(get_node_field "$line" $F_USER)
            port=$(get_node_field "$line" $F_PORT)
            os=$(get_node_field "$line" $F_OS)
            cores=$(get_node_field "$line" $F_CORES)
            ram_mb=$(get_node_field "$line" $F_RAM)

            local cpu_load ram_used disk_free procs status_icon

            if [[ "$ip" == "127.0.0.1" ]]; then
                cpu_load=$(cat /proc/loadavg | awk '{print $1}')
                ram_used=$(free -m | awk '/Mem:/{printf "%.0f%%", ($3/$2)*100}')
                disk_free=$(df -h / | tail -1 | awk '{print $4}')
                procs=$(ps aux | wc -l)
                status_icon="🟢"
            elif [[ "$os" == "windows" ]]; then
                local win_stats
                win_stats=$(ssh $SSH_OPTS -p "$port" "${user}@${ip}" \
                    'wmic cpu get loadpercentage /value 2>nul & wmic os get freephysicalmemory,totalvisiblememorysize /value 2>nul' </dev/null 2>/dev/null) || {
                    printf "  ${RED}%-14s %-6s %-10s %-10s %-12s %-8s %s${NC}\n" "$hostname" "$cores" "—" "—" "—" "—" "🔴 OFFLINE"
                    continue
                }
                cpu_load=$(echo "$win_stats" | grep "LoadPercentage=" | cut -d= -f2 | tr -d '\r\n')
                cpu_load="${cpu_load}%"
                local win_free win_total
                win_free=$(echo "$win_stats" | grep "FreePhysicalMemory=" | cut -d= -f2 | tr -d '\r\n ')
                win_total=$(echo "$win_stats" | grep "TotalVisibleMemorySize=" | cut -d= -f2 | tr -d '\r\n ')
                if [[ -n "$win_total" && "$win_total" -gt 0 ]]; then
                    ram_used="$(( (win_total - win_free) * 100 / win_total ))%"
                else
                    ram_used="—"
                fi
                disk_free="—"
                procs="—"
                status_icon="🟢"
            else
                local stats
                stats=$(ssh $SSH_OPTS -p "$port" "${user}@${ip}" \
                    'echo "$(cat /proc/loadavg | awk "{print \$1}") $(free -m | awk "/Mem:/{printf \"%.0f%%\", (\$3/\$2)*100}") $(df -h / | tail -1 | awk "{print \$4}") $(ps aux | wc -l)"' </dev/null 2>/dev/null) || {
                    printf "  ${RED}%-14s %-6s %-10s %-10s %-12s %-8s %s${NC}\n" "$hostname" "$cores" "—" "—" "—" "—" "🔴 OFFLINE"
                    continue
                }
                cpu_load=$(echo "$stats" | awk '{print $1}')
                ram_used=$(echo "$stats" | awk '{print $2}')
                disk_free=$(echo "$stats" | awk '{print $3}')
                procs=$(echo "$stats" | awk '{print $4}')
                status_icon="🟢"
            fi

            # Color code CPU load
            local load_color="$GREEN"
            local load_val=${cpu_load%\%}
            if (( $(echo "$load_val > ${cores:-1}" | bc -l 2>/dev/null || echo 0) )); then
                load_color="$RED"
            elif (( $(echo "$load_val > ${cores:-1} * 0.7" | bc -l 2>/dev/null || echo 0) )); then
                load_color="$YELLOW"
            fi

            printf "  %-14s %-6s ${load_color}%-10s${NC} %-10s %-12s %-8s %s\n" \
                "$hostname" "$cores" "$cpu_load" "$ram_used" "$disk_free" "$procs" "$status_icon"

        done <<< "$(get_nodes)"

        echo ""
        echo -e "  ${DIM}Press Ctrl+C to exit${NC}"
        sleep 5
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# GNU PARALLEL CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

update_parallel_config() {
    # Generate GNU Parallel --sshloginfile
    local sshlogin_file="${CLUSTER_DIR}/parallel-nodes"
    > "$sshlogin_file"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local hostname ip user port cores os
        hostname=$(get_node_field "$line" $F_HOSTNAME)
        ip=$(get_node_field "$line" $F_IP)
        user=$(get_node_field "$line" $F_USER)
        port=$(get_node_field "$line" $F_PORT)
        cores=$(get_node_field "$line" $F_CORES)
        os=$(get_node_field "$line" $F_OS)

        # Skip Windows nodes for parallel (shell compat issues)
        [[ "$os" == "windows" ]] && continue

        if [[ "$ip" == "127.0.0.1" ]]; then
            echo "${cores}/:" >> "$sshlogin_file"
        else
            echo "${cores}/ssh -p ${port} ${user}@${ip}" >> "$sshlogin_file"
        fi
    done <<< "$(get_nodes)"

    debug "Updated parallel-nodes: $(cat "$sshlogin_file" | tr '\n' ' ')"
}

update_distcc_config() {
    # Generate distcc hosts file
    > "$DISTCC_HOSTS_FILE"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local ip cores os arch tags
        ip=$(get_node_field "$line" $F_IP)
        cores=$(get_node_field "$line" $F_CORES)
        os=$(get_node_field "$line" $F_OS)
        arch=$(get_node_field "$line" $F_ARCH)
        tags=$(get_node_field "$line" $F_TAGS)

        # Only x86_64 Linux nodes with gcc for distcc
        [[ "$os" == "windows" ]] && continue
        [[ "$arch" != "x86_64" ]] && continue

        if [[ "$ip" == "127.0.0.1" ]]; then
            echo "localhost/${cores}" >> "$DISTCC_HOSTS_FILE"
        else
            echo "${ip}/${cores}" >> "$DISTCC_HOSTS_FILE"
        fi
    done <<< "$(get_nodes)"

    debug "Updated distcc-hosts: $(cat "$DISTCC_HOSTS_FILE" | tr '\n' ' ')"
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALL TOOLS - Install cluster tools on all nodes
# ═══════════════════════════════════════════════════════════════════════════════

cmd_install_tools() {
    header "Installing Cluster Tools on All Nodes"

    # Install on controller first
    info "Installing tools on controller..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y parallel distcc ccache 2>/dev/null | tail -3
    elif command -v xbps-install &>/dev/null; then
        sudo xbps-install -Sy parallel distcc ccache 2>/dev/null
    fi

    # Install on remote Linux nodes
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local hostname ip user port os role
        hostname=$(get_node_field "$line" $F_HOSTNAME)
        ip=$(get_node_field "$line" $F_IP)
        user=$(get_node_field "$line" $F_USER)
        port=$(get_node_field "$line" $F_PORT)
        os=$(get_node_field "$line" $F_OS)
        role=$(get_node_field "$line" $F_ROLE)

        [[ "$ip" == "127.0.0.1" ]] && continue
        [[ "$os" == "windows" ]] && { info "Skipping Windows node: ${hostname}"; continue; }

        info "Installing tools on ${hostname} (${ip})..."
        ssh $SSH_OPTS -p "$port" "${user}@${ip}" 'bash -c "
if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq parallel distcc ccache 2>/dev/null
elif command -v xbps-install &>/dev/null; then
    sudo xbps-install -Sy parallel distcc ccache 2>/dev/null
elif command -v pacman &>/dev/null; then
    sudo pacman -Sy --noconfirm parallel distcc ccache 2>/dev/null
fi
echo TOOLS_INSTALLED=yes
"' </dev/null 2>/dev/null || warn "Failed on ${hostname}"
        log "Tools installed on ${hostname} ✓"
    done <<< "$(get_nodes)"

    log "Cluster tools installation complete ✓"
}

# ═══════════════════════════════════════════════════════════════════════════════
# RUN - Execute command across the cluster
# ═══════════════════════════════════════════════════════════════════════════════

cmd_run() {
    local cmd="$*"

    if [[ -z "$cmd" ]]; then
        echo -e "${WHITE}Usage:${NC} $0 run <command>"
        echo -e "  Example: $0 run hostname"
        echo -e "  Example: $0 run 'uname -a'"
        return 1
    fi

    header "Running on All Nodes: ${cmd}"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local hostname ip user port os
        hostname=$(get_node_field "$line" $F_HOSTNAME)
        ip=$(get_node_field "$line" $F_IP)
        user=$(get_node_field "$line" $F_USER)
        port=$(get_node_field "$line" $F_PORT)
        os=$(get_node_field "$line" $F_OS)

        echo -e "${CYAN}━━━ ${hostname} (${ip}) ━━━${NC}"

        if [[ "$ip" == "127.0.0.1" ]]; then
            eval "$cmd" 2>&1
        else
            ssh $SSH_OPTS -p "$port" "${user}@${ip}" "$cmd" </dev/null 2>/dev/null || \
                echo -e "${RED}  Connection failed${NC}"
        fi
        echo ""
    done <<< "$(get_nodes)"
}

# ═══════════════════════════════════════════════════════════════════════════════
# DISTRIBUTE - Run jobs in parallel across the cluster using GNU Parallel
# ═══════════════════════════════════════════════════════════════════════════════

cmd_distribute() {
    local jobs_input="$1"
    shift 2>/dev/null
    local extra_args="$*"

    if [[ -z "$jobs_input" ]]; then
        echo -e "${WHITE}Usage:${NC}"
        echo -e "  $0 distribute <jobs_file>           Run file of jobs across cluster"
        echo -e "  $0 distribute -c '<cmd> {}' ::: args  Run command with args distributed"
        echo ""
        echo -e "${WHITE}Examples:${NC}"
        echo -e "  echo 'compile file1.c' > jobs.txt && $0 distribute jobs.txt"
        echo -e "  $0 distribute -c 'python3 train.py --split {}' ::: 1 2 3 4 5"
        echo -e "  find src/ -name '*.c' | $0 distribute -c 'gcc -c {} -o {.}.o'"
        echo ""
        echo -e "${WHITE}Pipeline:${NC}"
        echo -e "  seq 100 | $0 distribute -c 'echo Processing job {}'"
        return 1
    fi

    local sshlogin_file="${CLUSTER_DIR}/parallel-nodes"
    if [[ ! -s "$sshlogin_file" ]]; then
        update_parallel_config
    fi

    if ! command -v parallel &>/dev/null; then
        err "GNU Parallel not installed. Run: $0 install-tools"
        return 1
    fi

    header "Distributing Jobs Across Cluster"

    local node_count
    node_count=$(wc -l < "$sshlogin_file")
    local total_cores
    total_cores=$(awk -F/ '{sum+=$1} END{print sum}' "$sshlogin_file")
    info "Using ${node_count} nodes with ${total_cores} total cores"
    echo ""

    if [[ "$jobs_input" == "-c" ]]; then
        # Command mode: distribute -c 'command {}' ::: arg1 arg2
        parallel --sshloginfile "$sshlogin_file" --progress --eta \
            --joblog "${JOBS_DIR}/job-$(date +%s).log" \
            --retries 2 --timeout 3600 \
            $extra_args
    elif [[ -f "$jobs_input" ]]; then
        # File mode: each line is a job
        parallel --sshloginfile "$sshlogin_file" --progress --eta \
            --joblog "${JOBS_DIR}/job-$(date +%s).log" \
            --retries 2 --timeout 3600 \
            < "$jobs_input"
    else
        # Direct pipe mode
        echo "$jobs_input" | parallel --sshloginfile "$sshlogin_file" --progress --eta \
            --joblog "${JOBS_DIR}/job-$(date +%s).log" \
            --retries 2 --timeout 3600 \
            $extra_args
    fi

    log "Job distribution complete ✓"
}

# ═══════════════════════════════════════════════════════════════════════════════
# DEPLOY - Push files/projects to all nodes
# ═══════════════════════════════════════════════════════════════════════════════

cmd_deploy() {
    local source="$1" dest="${2:-/tmp/nullsec-deploy}"

    if [[ -z "$source" ]]; then
        echo -e "${WHITE}Usage:${NC} $0 deploy <file_or_dir> [remote_path]"
        echo -e "  Example: $0 deploy ./project /tmp/project"
        return 1
    fi

    header "Deploying: ${source} → ${dest}"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local hostname ip user port os
        hostname=$(get_node_field "$line" $F_HOSTNAME)
        ip=$(get_node_field "$line" $F_IP)
        user=$(get_node_field "$line" $F_USER)
        port=$(get_node_field "$line" $F_PORT)
        os=$(get_node_field "$line" $F_OS)

        [[ "$ip" == "127.0.0.1" ]] && continue

        info "Deploying to ${hostname}..."

        if [[ "$os" == "windows" ]]; then
            scp -r $SSH_OPTS -P "$port" "$source" "${user}@${ip}:${dest}" </dev/null 2>/dev/null && \
                log "  ${hostname}: deployed ✓" || warn "  ${hostname}: deploy failed"
        else
            rsync -avz --progress -e "ssh $SSH_OPTS -p $port" "$source" "${user}@${ip}:${dest}" </dev/null 2>/dev/null && \
                log "  ${hostname}: deployed ✓" || warn "  ${hostname}: deploy failed"
        fi
    done <<< "$(get_nodes)"
}

# ═══════════════════════════════════════════════════════════════════════════════
# COLLECT - Gather results from all nodes
# ═══════════════════════════════════════════════════════════════════════════════

cmd_collect() {
    local remote_path="$1" local_dest="${2:-${CLUSTER_DIR}/collected}"

    if [[ -z "$remote_path" ]]; then
        echo -e "${WHITE}Usage:${NC} $0 collect <remote_path> [local_dest]"
        echo -e "  Example: $0 collect /tmp/results ./results"
        return 1
    fi

    mkdir -p "$local_dest"
    header "Collecting: ${remote_path} → ${local_dest}"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local hostname ip user port
        hostname=$(get_node_field "$line" $F_HOSTNAME)
        ip=$(get_node_field "$line" $F_IP)
        user=$(get_node_field "$line" $F_USER)
        port=$(get_node_field "$line" $F_PORT)

        [[ "$ip" == "127.0.0.1" ]] && continue

        info "Collecting from ${hostname}..."
        mkdir -p "${local_dest}/${hostname}"
        rsync -avz -e "ssh $SSH_OPTS -p $port" "${user}@${ip}:${remote_path}" "${local_dest}/${hostname}/" </dev/null 2>/dev/null && \
            log "  ${hostname}: collected ✓" || warn "  ${hostname}: nothing to collect"
    done <<< "$(get_nodes)"
}

# ═══════════════════════════════════════════════════════════════════════════════
# GPU - Offload GPU jobs to CUDA-capable nodes
# ═══════════════════════════════════════════════════════════════════════════════

cmd_gpu() {
    local cmd="$*"

    if [[ -z "$cmd" ]]; then
        echo -e "${WHITE}Usage:${NC} $0 gpu <command>"
        echo -e "  Runs command on GPU-capable nodes only"
        echo -e "  Example: $0 gpu 'nvidia-smi'"
        echo -e "  Example: $0 gpu 'python3 train.py --device cuda'"
        return 1
    fi

    header "Running on GPU Nodes: ${cmd}"

    local found=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local hostname ip user port gpu role tags
        hostname=$(get_node_field "$line" $F_HOSTNAME)
        ip=$(get_node_field "$line" $F_IP)
        user=$(get_node_field "$line" $F_USER)
        port=$(get_node_field "$line" $F_PORT)
        gpu=$(get_node_field "$line" $F_GPU)
        role=$(get_node_field "$line" $F_ROLE)
        tags=$(get_node_field "$line" $F_TAGS)

        # Only GPU nodes
        [[ "$gpu" == "none" || -z "$gpu" ]] && continue
        echo "$tags" | grep -q "cuda" || echo "$tags" | grep -q "gpu" || continue

        echo -e "${CYAN}━━━ ${hostname} (${gpu}) ━━━${NC}"
        ((found++))

        if [[ "$ip" == "127.0.0.1" ]]; then
            eval "$cmd" 2>&1
        else
            ssh $SSH_OPTS -p "$port" "${user}@${ip}" "$cmd" </dev/null 2>/dev/null || \
                echo -e "${RED}  Connection failed${NC}"
        fi
        echo ""
    done <<< "$(get_nodes)"

    [[ $found -eq 0 ]] && warn "No GPU nodes found in cluster"
}

# ═══════════════════════════════════════════════════════════════════════════════
# BENCH - Quick benchmark across all nodes
# ═══════════════════════════════════════════════════════════════════════════════

cmd_bench() {
    header "Cluster Benchmark"

    printf "  ${WHITE}%-14s %-8s %-14s %-14s %-14s${NC}\n" \
        "NODE" "CORES" "SINGLE-CORE" "MULTI-CORE" "MEMORY BW"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────────────${NC}"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local hostname ip user port os cores
        hostname=$(get_node_field "$line" $F_HOSTNAME)
        ip=$(get_node_field "$line" $F_IP)
        user=$(get_node_field "$line" $F_USER)
        port=$(get_node_field "$line" $F_PORT)
        os=$(get_node_field "$line" $F_OS)
        cores=$(get_node_field "$line" $F_CORES)

        [[ "$os" == "windows" ]] && { printf "  %-14s %-8s %-14s %-14s %-14s\n" "$hostname" "$cores" "—" "—" "(Windows)"; continue; }

        local bench_cmd='
SC=$(dd if=/dev/zero bs=1M count=256 2>&1 | grep -oP "[\d.]+ [GM]B/s" | head -1)
T1=$(date +%s%N)
for i in $(seq 1 5000); do echo "$i * $i" | bc > /dev/null; done
T2=$(date +%s%N)
SINGLE=$(( (T2 - T1) / 1000000 ))
echo "${SINGLE}ms|${SC}"
'
        local result
        if [[ "$ip" == "127.0.0.1" ]]; then
            result=$(bash -c "$bench_cmd" 2>/dev/null)
        else
            result=$(ssh $SSH_OPTS -p "$port" "${user}@${ip}" "$bench_cmd" </dev/null 2>/dev/null)
        fi

        local single_ms mem_bw
        single_ms=$(echo "$result" | cut -d'|' -f1)
        mem_bw=$(echo "$result" | cut -d'|' -f2)

        printf "  %-14s %-8s %-14s %-14s %-14s\n" \
            "$hostname" "$cores" "${single_ms:-—}" "${cores}x parallel" "${mem_bw:-—}"

    done <<< "$(get_nodes)"

    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# INIT - Initialize cluster with known nodes
# ═══════════════════════════════════════════════════════════════════════════════

cmd_init() {
    banner
    header "Initializing NullSec Compute Cluster"

    init_dirs
    init_nodes_file

    # Register local controller
    cmd_add_local

    # Auto-discover nodes on the network
    info "Scanning network for SSH-accessible hosts..."
    cmd_discover

    # Generate configs
    update_parallel_config
    update_distcc_config

    header "Cluster Initialized"
    cmd_status

    echo -e "  ${WHITE}Quick Start:${NC}"
    echo -e "    ${CYAN}$0 status${NC}                     View cluster status"
    echo -e "    ${CYAN}$0 monitor${NC}                    Live resource monitoring"
    echo -e "    ${CYAN}$0 run 'uname -a'${NC}             Run command on all nodes"
    echo -e "    ${CYAN}$0 discover${NC}                   Find new machines on network"
    echo -e "    ${CYAN}$0 add <ip> [user]${NC}            Add a new machine"
    echo -e "    ${CYAN}$0 distribute jobs.txt${NC}         Distribute jobs via GNU Parallel"
    echo -e "    ${CYAN}$0 gpu 'nvidia-smi'${NC}           Run on GPU nodes only"
    echo -e "    ${CYAN}$0 deploy ./project /tmp${NC}      Push files to all nodes"
    echo -e "    ${CYAN}$0 collect /tmp/results${NC}       Gather results from nodes"
    echo -e "    ${CYAN}$0 bench${NC}                      Benchmark all nodes"
    echo -e "    ${CYAN}$0 install-tools${NC}              Install parallel/distcc on nodes"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# HELP
# ═══════════════════════════════════════════════════════════════════════════════

show_help() {
    banner
    echo -e "${WHITE}USAGE:${NC}"
    echo "  $0 [command] [args]"
    echo ""
    echo -e "${WHITE}CLUSTER MANAGEMENT:${NC}"
    echo -e "  ${CYAN}init${NC}                         Initialize cluster & register known nodes"
    echo -e "  ${CYAN}add <ip> [user] [port]${NC}       Add a machine to the cluster"
    echo -e "  ${CYAN}remove <hostname|ip>${NC}         Remove a node from the cluster"
    echo -e "  ${CYAN}discover${NC}                     Auto-find new machines on the network"
    echo -e "  ${CYAN}status${NC}                       Show cluster overview"
    echo -e "  ${CYAN}monitor${NC}                      Live resource monitoring (auto-refresh)"
    echo -e "  ${CYAN}install-tools${NC}                Install parallel/distcc on all nodes"
    echo ""
    echo -e "${WHITE}JOB EXECUTION:${NC}"
    echo -e "  ${CYAN}run <command>${NC}                Run command on ALL nodes"
    echo -e "  ${CYAN}distribute <jobs_file>${NC}       Distribute jobs via GNU Parallel"
    echo -e "  ${CYAN}distribute -c 'cmd {}' ::: args${NC}"
    echo -e "                               Parallel command with args"
    echo -e "  ${CYAN}gpu <command>${NC}                Run on GPU/CUDA nodes only"
    echo -e "  ${CYAN}bench${NC}                        Quick benchmark all nodes"
    echo ""
    echo -e "${WHITE}FILE MANAGEMENT:${NC}"
    echo -e "  ${CYAN}deploy <src> [dest]${NC}          Push files to all nodes"
    echo -e "  ${CYAN}collect <remote> [local]${NC}     Gather results from all nodes"
    echo ""
    echo -e "${WHITE}EXAMPLES:${NC}"
    echo -e "  ${DIM}# Add a new machine${NC}"
    echo -e "  $0 add 192.168.1.100 user"
    echo ""
    echo -e "  ${DIM}# Check what all nodes are running${NC}"
    echo -e "  $0 run 'ps aux | head -5'"
    echo ""
    echo -e "  ${DIM}# Distribute Python ML training${NC}"
    echo -e "  $0 distribute -c 'python3 train.py --fold {}' ::: 1 2 3 4 5"
    echo ""
    echo -e "  ${DIM}# Compile project across all nodes${NC}"
    echo -e "  DISTCC_HOSTS=@${DISTCC_HOSTS_FILE} make -j\$(nproc) CC=distcc"
    echo ""
    echo -e "  ${DIM}# GPU workload${NC}"
    echo -e "  $0 gpu 'python3 -c \"import torch; print(torch.cuda.get_device_name(0))\"'"
    echo ""
    echo -e "${GRAY}NullSec Compute Cluster v1.0 - Developed by bad-antics${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    init_dirs

    case "${1:-help}" in
        init|setup)
            cmd_init
            ;;
        add)
            shift
            init_nodes_file
            cmd_add "$@"
            ;;
        remove|rm|del)
            shift
            cmd_remove "$@"
            ;;
        discover|scan)
            init_nodes_file
            cmd_discover
            ;;
        status|stat|nodes)
            cmd_status
            ;;
        monitor|mon|top)
            cmd_monitor
            ;;
        run|exec)
            shift
            cmd_run "$@"
            ;;
        distribute|dist|parallel)
            shift
            cmd_distribute "$@"
            ;;
        deploy|push|sync)
            shift
            cmd_deploy "$@"
            ;;
        collect|pull|gather)
            shift
            cmd_collect "$@"
            ;;
        gpu|cuda)
            shift
            cmd_gpu "$@"
            ;;
        bench|benchmark)
            cmd_bench
            ;;
        install-tools|install)
            cmd_install_tools
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
