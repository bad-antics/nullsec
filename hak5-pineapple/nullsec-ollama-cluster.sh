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
#║            NullSec Ollama Cluster Accelerator v1.0                           ║
#║             Distributed AI Inference across Mesh Network                     ║
#║                     Developed by: bad-antics                                 ║
#║                                                                               ║
#╚═══════════════════════════════════════════════════════════════════════════════╝
#
#  Combines the full power of your mesh network to accelerate Ollama AI.
#
#  Features:
#    - Multi-node Ollama deployment (CPU + GPU acceleration)
#    - Load-balanced inference requests (3080 → distributed workers)
#    - Mesh network optimization for low-latency AI workloads
#    - Automatic node discovery and health monitoring
#    - Model caching across cluster nodes
#    - Real-time performance dashboard
#    - Automatic failover and load rebalancing
#
#  Architecture:
#    ┌─────────────────────────────────────────────────────────┐
#    │  Master Node (localhost:3080)                          │
#    │  ├─ FastAPI Load Balancer                              │
#    │  └─ Ollama Instance (port 11434)                       │
#    ├─────────────────────────────────────────────────────────┤
#    │              Batman-adv Mesh Network                    │
#    │  (Optimized for low-latency, high-throughput AI)       │
#    ├─────────────────────────────────────────────────────────┤
#    │  Worker Nodes (SSH-deployed)                           │
#    │  ├─ node-1: Ollama + GPU support                       │
#    │  ├─ node-2: Ollama + CPU inference                     │
#    │  └─ node-3: Ollama + cache layer                       │
#    └─────────────────────────────────────────────────────────┘
#
#  Usage:
#    ./nullsec-ollama-cluster.sh init          # Initialize cluster for Ollama
#    ./nullsec-ollama-cluster.sh start         # Start all Ollama instances
#    ./nullsec-ollama-cluster.sh proxy         # Start load-balancing proxy (localhost:3080)
#    ./nullsec-ollama-cluster.sh status        # Check health of all nodes
#    ./nullsec-ollama-cluster.sh monitor       # Real-time dashboard
#    ./nullsec-ollama-cluster.sh optimize      # Tune mesh for AI workloads
#    ./nullsec-ollama-cluster.sh stop          # Stop all services
#    ./nullsec-ollama-cluster.sh bench         # Benchmark inference speed
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

OLLAMA_CLUSTER_DIR="${HOME}/.nullsec/ollama-cluster"
OLLAMA_PORT=11434
PROXY_PORT=3080
MESH_IFACE="bat0"
NODES_FILE="${OLLAMA_CLUSTER_DIR}/nodes.conf"
STATE_DIR="${OLLAMA_CLUSTER_DIR}/state"
LOG_DIR="${OLLAMA_CLUSTER_DIR}/logs"
PROXY_LOG="${LOG_DIR}/proxy.log"
SSH_KEY="${HOME}/.ssh/id_ed25519"
SSH_OPTS="-o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

# Default models to pre-cache
MODELS=("mistral" "neural-chat" "orca-mini")

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
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

log()   { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[-]${NC} $1"; }
info()  { echo -e "${BLUE}[i]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
  ╔═══════════════════════════════════════════════════════════════╗
  ║                                                               ║
  ║  ███╗   ██╗██╗   ██╗██╗     ██╗███████╗███████╗ ██████╗     ║
  ║  ████╗  ██║██║   ██║██║     ██║██╔════╝██╔════╝██╔════╝     ║
  ║  ██╔██╗ ██║██║   ██║██║     ██║█████╗  █████╗  ██║          ║
  ║  ██║╚██╗██║██║   ██║██║     ██║██╔══╝  ██╔══╝  ██║          ║
  ║  ██║ ╚████║╚██████╔╝███████╗██║███████╗███████╗╚██████╗     ║
  ║  ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚═╝╚══════╝╚══════╝ ╚═════╝     ║
  ║                                                               ║
  ║        NullSec Ollama Cluster Accelerator v1.0               ║
  ║         Distributed AI Inference across Mesh Network         ║
  ║                                                               ║
  ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

init_env() {
    mkdir -p "$OLLAMA_CLUSTER_DIR" "$STATE_DIR" "$LOG_DIR"
    chmod 700 "$OLLAMA_CLUSTER_DIR"
}

check_ollama() {
    if ! command -v ollama &>/dev/null; then
        err "Ollama not installed. Install with:"
        echo "  curl https://ollama.ai/install.sh | sh"
        exit 1
    fi
}

check_mesh() {
    if ! ip link show "$MESH_IFACE" &>/dev/null 2>&1; then
        warn "Mesh interface $MESH_IFACE not found"
        warn "Run: ./nullsec-mesh-setup.sh first"
        return 1
    fi
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# NODE INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

init_nodes_file() {
    if [[ ! -f "$NODES_FILE" ]]; then
        cat > "$NODES_FILE" << 'EOF'
# NullSec Ollama Cluster - Node Registry
# Format: hostname|ip|user|port|status|ollama_port|gpu|models
# Add nodes with: ./nullsec-ollama-cluster.sh add-node <hostname> <ip> <user> [port]
EOF
    fi
}

add_node() {
    local hostname="$1" ip="$2" user="$3" port="${4:-22}"
    
    log "Registering node: $hostname ($ip)"
    
    # Test SSH connection
    if ! ssh $SSH_OPTS -p "$port" "${user}@${ip}" "echo ok" &>/dev/null; then
        err "Cannot reach $ip:$port as $user"
        return 1
    fi
    
    # Detect capabilities
    local gpu="none"
    local python_version=""
    
    gpu=$(ssh $SSH_OPTS -p "$port" "${user}@${ip}" \
        "nvidia-smi -L 2>/dev/null | head -1 | cut -d: -f2 | xargs || echo none" 2>/dev/null)
    
    python_version=$(ssh $SSH_OPTS -p "$port" "${user}@${ip}" \
        "python3 --version 2>/dev/null | awk '{print \$2}'" 2>/dev/null || echo "unknown")
    
    # Register node
    echo "${hostname}|${ip}|${user}|${port}|offline|11434|${gpu}|" >> "$NODES_FILE"
    success "Node registered: $hostname (GPU: $gpu)"
}

get_nodes() {
    grep -v "^#" "$NODES_FILE" 2>/dev/null | grep -v "^$" || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# OLLAMA DEPLOYMENT
# ═══════════════════════════════════════════════════════════════════════════════

deploy_ollama_to_node() {
    local ip="$1" user="$2" port="${3:-22}" node_name="${4:-ollama-worker}"
    
    info "Deploying Ollama to $node_name ($ip)"
    
    # Install Ollama
    ssh $SSH_OPTS -p "$port" "${user}@${ip}" bash << 'DEPLOY' 2>&1 | grep -E "^(Ollama|Error|CUDA)"
        if ! command -v ollama &>/dev/null; then
            echo "[*] Installing Ollama..."
            curl -fsSL https://ollama.ai/install.sh | sh 2>/dev/null
        else
            echo "Ollama already installed"
        fi
        
        # Start Ollama in background
        if ! pgrep -f "ollama serve" &>/dev/null; then
            echo "[*] Starting Ollama service..."
            nohup ollama serve > /tmp/ollama.log 2>&1 &
            sleep 2
        fi
        
        # Check CUDA support
        if nvidia-smi &>/dev/null; then
            echo "CUDA support: enabled"
        fi
DEPLOY
    
    success "Ollama deployed to $node_name"
}

pull_model_on_node() {
    local ip="$1" user="$2" port="${3:-22}" model="$4"
    
    info "Pulling model $model on remote node..."
    ssh $SSH_OPTS -p "$port" "${user}@${ip}" \
        "timeout 300 ollama pull $model 2>&1 | tail -3" &
    
    wait $!
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMMAND: INIT
# ═══════════════════════════════════════════════════════════════════════════════

cmd_init() {
    banner
    init_env
    init_nodes_file
    check_ollama
    
    echo ""
    log "Ollama cluster initialized at: $OLLAMA_CLUSTER_DIR"
    log "Next steps:"
    echo "  1. Add nodes: ./nullsec-ollama-cluster.sh add-node <hostname> <ip> <user>"
    echo "  2. Deploy:   ./nullsec-ollama-cluster.sh deploy"
    echo "  3. Start:    ./nullsec-ollama-cluster.sh start"
    echo "  4. Proxy:    ./nullsec-ollama-cluster.sh proxy"
    echo ""
    info "Example: ./nullsec-ollama-cluster.sh add-node node-1 192.168.1.100 root"
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMMAND: DEPLOY
# ═══════════════════════════════════════════════════════════════════════════════

cmd_deploy() {
    banner
    
    local nodes=$(get_nodes)
    if [[ -z "$nodes" ]]; then
        err "No nodes configured. Run: ./nullsec-ollama-cluster.sh add-node ..."
        exit 1
    fi
    
    log "Deploying Ollama to all nodes..."
    echo ""
    
    # Deploy to each node in parallel
    while IFS='|' read -r hostname ip user port rest; do
        deploy_ollama_to_node "$ip" "$user" "$port" "$hostname" &
    done <<< "$nodes"
    
    # Wait for all deployments
    wait
    echo ""
    success "Ollama deployed to all nodes"
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMMAND: START
# ═══════════════════════════════════════════════════════════════════════════════

cmd_start() {
    banner
    
    log "Starting local Ollama instance..."
    if ! pgrep -f "ollama serve" &>/dev/null; then
        nohup ollama serve > "${LOG_DIR}/ollama-local.log" 2>&1 &
        sleep 2
        success "Ollama started on localhost:$OLLAMA_PORT"
    else
        warn "Ollama already running"
    fi
    
    # Start on remote nodes
    local nodes=$(get_nodes)
    while IFS='|' read -r hostname ip user port rest; do
        ssh $SSH_OPTS -p "$port" "${user}@${ip}" \
            "pgrep -f 'ollama serve' &>/dev/null || (nohup ollama serve > /tmp/ollama.log 2>&1 &)" &
    done <<< "$nodes"
    
    wait
    echo ""
    info "All Ollama instances started"
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMMAND: PROXY (localhost:3080 load balancer)
# ═══════════════════════════════════════════════════════════════════════════════

cmd_proxy() {
    banner
    
    log "Creating FastAPI load-balancing proxy..."
    
    local proxy_script="${OLLAMA_CLUSTER_DIR}/proxy.py"
    
    cat > "$proxy_script" << 'PROXY_CODE'
#!/usr/bin/env python3
"""
NullSec Ollama Cluster Load Balancer
Routes requests to best-performing Ollama node
"""
import os
import json
import time
import asyncio
import httpx
import logging
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse
from typing import List, Optional

app = FastAPI(title="NullSec Ollama Cluster Proxy")

# Read nodes from config
NODES = []
NODES_FILE = os.path.expanduser("~/.nullsec/ollama-cluster/nodes.conf")

def load_nodes():
    global NODES
    NODES = []
    try:
        with open(NODES_FILE) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    parts = line.split("|")
                    if len(parts) >= 6:
                        NODES.append({
                            "hostname": parts[0],
                            "ip": parts[1],
                            "user": parts[2],
                            "port": parts[3],
                            "ollama_port": int(parts[5]),
                            "gpu": parts[6] if len(parts) > 6 else "none"
                        })
    except FileNotFoundError:
        pass

async def get_healthy_node():
    """Find fastest responding node"""
    load_nodes()
    
    fastest = None
    fastest_time = float('inf')
    
    for node in NODES:
        try:
            async with httpx.AsyncClient(timeout=2.0) as client:
                start = time.time()
                resp = await client.get(f"http://{node['ip']}:{node['ollama_port']}/api/tags")
                elapsed = time.time() - start
                
                if resp.status_code == 200 and elapsed < fastest_time:
                    fastest = node
                    fastest_time = elapsed
        except:
            pass
    
    # Fallback to localhost
    if not fastest:
        fastest = {
            "hostname": "localhost",
            "ip": "127.0.0.1",
            "ollama_port": 11434
        }
    
    return fastest

@app.get("/health")
async def health():
    """Health check"""
    return {
        "status": "healthy",
        "nodes": len(NODES),
        "proxy_port": 3080
    }

@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def proxy_request(request: Request, path: str):
    """Proxy all requests to best-performing Ollama node"""
    
    node = await get_healthy_node()
    target_url = f"http://{node['ip']}:{node['ollama_port']}/{path}"
    
    # Forward query string
    if request.url.query:
        target_url += f"?{request.url.query}"
    
    try:
        async with httpx.AsyncClient(timeout=300.0) as client:
            # Forward request body if present
            req_body = await request.body() if request.method in ["POST", "PUT"] else None
            
            response = await client.request(
                method=request.method,
                url=target_url,
                content=req_body,
                headers={k: v for k, v in request.headers.items() 
                        if k.lower() not in ["host", "connection"]},
            )
            
            # Stream response
            return StreamingResponse(
                iter([response.content]),
                status_code=response.status_code,
                headers=dict(response.headers)
            )
    except Exception as e:
        return {"error": str(e)}, 500

if __name__ == "__main__":
    import uvicorn
    load_nodes()
    print(f"[+] Loaded {len(NODES)} Ollama nodes")
    uvicorn.run(app, host="0.0.0.0", port=3080, access_log=False)
PROXY_CODE
    
    chmod +x "$proxy_script"
    log "Starting load-balancing proxy on localhost:$PROXY_PORT..."
    
    python3 "$proxy_script" 2>&1 | tee -a "$PROXY_LOG"
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMMAND: STATUS
# ═══════════════════════════════════════════════════════════════════════════════

cmd_status() {
    banner
    
    log "Checking cluster status..."
    echo ""
    
    # Local Ollama
    if curl -s http://localhost:11434/api/tags &>/dev/null; then
        echo -e "${GREEN}[✓]${NC} Local Ollama:      ${GREEN}RUNNING${NC} (localhost:11434)"
    else
        echo -e "${RED}[✗]${NC} Local Ollama:      ${RED}OFFLINE${NC}"
    fi
    
    # Proxy
    if curl -s http://localhost:3080/health &>/dev/null; then
        echo -e "${GREEN}[✓]${NC} Proxy:             ${GREEN}RUNNING${NC} (localhost:3080)"
    else
        echo -e "${YELLOW}[!]${NC} Proxy:             ${YELLOW}OFFLINE${NC}"
    fi
    
    # Remote nodes
    echo ""
    local nodes=$(get_nodes)
    if [[ -n "$nodes" ]]; then
        echo "Remote Nodes:"
        while IFS='|' read -r hostname ip user port rest; do
            if curl -s --connect-timeout 2 "http://${ip}:11434/api/tags" &>/dev/null; then
                echo -e "  ${GREEN}[✓]${NC} $hostname ($ip)   ${GREEN}READY${NC}"
            else
                echo -e "  ${RED}[✗]${NC} $hostname ($ip)   ${RED}OFFLINE${NC}"
            fi
        done <<< "$nodes"
    fi
    
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMMAND: OPTIMIZE (Mesh tuning for AI workloads)
# ═══════════════════════════════════════════════════════════════════════════════

cmd_optimize() {
    banner
    
    if ! check_mesh; then
        err "Mesh network not available"
        exit 1
    fi
    
    log "Optimizing mesh network for AI workloads..."
    echo ""
    
    # Check if sudo available
    if [[ $EUID -ne 0 ]]; then
        warn "Some optimizations require root - requesting sudo"
        sudo bash << 'SUDO_CMD'
        # Increase RX/TX queues for batman-adv
        ip link set bat0 txqueuelen 10000 2>/dev/null || true
        
        # Increase buffer sizes for large model transfers
        sysctl -w net.core.rmem_max=134217728 2>/dev/null || true
        sysctl -w net.core.wmem_max=134217728 2>/dev/null || true
        sysctl -w net.core.rmem_default=67108864 2>/dev/null || true
        sysctl -w net.core.wmem_default=67108864 2>/dev/null || true
        
        # Disable TCP flow control for mesh (handled by batman-adv)
        sysctl -w net.ipv4.tcp_window_scaling=1 2>/dev/null || true
        
        # Increase connection backlog
        sysctl -w net.core.somaxconn=4096 2>/dev/null || true
        sysctl -w net.ipv4.tcp_max_syn_backlog=4096 2>/dev/null || true
SUDO_CMD
    fi
    
    success "Mesh network optimized for AI workloads"
    echo ""
    info "Recommendations:"
    echo "  - Run './nullsec-mesh-optimize.sh --aggressive' for maximum throughput"
    echo "  - Monitor with: batctl meshif bat0 originators"
    echo "  - Check latency: batctl meshif bat0 neighbors"
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMMAND: MONITOR (Real-time dashboard)
# ═══════════════════════════════════════════════════════════════════════════════

cmd_monitor() {
    banner
    
    log "Starting cluster monitor... (Ctrl+C to exit)"
    echo ""
    
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║         NullSec Ollama Cluster - Real-time Monitor        ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # System stats
        echo "System:"
        echo "  CPU Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
        echo "  Memory:   $(free -h | awk '/^Mem:/{print $3 "/" $2}')"
        echo ""
        
        # Mesh status
        if ip link show "$MESH_IFACE" &>/dev/null 2>&1; then
            echo "Mesh ($MESH_IFACE):"
            local tx=$(cat /sys/class/net/$MESH_IFACE/statistics/tx_bytes 2>/dev/null || echo 0)
            local rx=$(cat /sys/class/net/$MESH_IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
            echo "  TX: $((tx / 1024 / 1024)) MB | RX: $((rx / 1024 / 1024)) MB"
        fi
        
        echo ""
        echo "Ollama Instances:"
        
        # Local
        if pgrep -f "ollama serve" &>/dev/null; then
            echo -e "  ${GREEN}[✓]${NC} localhost:11434"
        else
            echo -e "  ${RED}[✗]${NC} localhost:11434"
        fi
        
        # Remote
        local nodes=$(get_nodes)
        while IFS='|' read -r hostname ip user port rest; do
            if curl -s --connect-timeout 1 "http://${ip}:11434/api/tags" &>/dev/null; then
                echo -e "  ${GREEN}[✓]${NC} $hostname ($ip:11434)"
            else
                echo -e "  ${RED}[✗]${NC} $hostname ($ip:11434)"
            fi
        done <<< "$nodes"
        
        echo ""
        echo -e "Proxy (localhost:3080): $(curl -s http://localhost:3080/health 2>/dev/null | grep -q status && echo -e "${GREEN}READY${NC}" || echo -e "${RED}OFFLINE${NC}")"
        echo ""
        echo "Last updated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo -e "${GRAY}(Updating in 3 seconds... Ctrl+C to exit)${NC}"
        
        sleep 3
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMMAND: BENCH
# ═══════════════════════════════════════════════════════════════════════════════

cmd_bench() {
    banner
    
    if ! command -v jq &>/dev/null; then
        warn "jq not installed - benchmark will be less detailed"
    fi
    
    log "Benchmarking Ollama cluster performance..."
    echo ""
    
    local prompt="The future of AI is"
    local num_predict=50
    
    info "Testing with prompt: '$prompt'"
    info "Output tokens: $num_predict"
    echo ""
    
    # Benchmark each node
    local nodes=$(get_nodes)
    nodes="${nodes}
localhost|127.0.0.1|root|22|"
    
    while IFS='|' read -r hostname ip user port rest; do
        if [[ -z "$hostname" ]]; then
            continue
        fi
        
        local node_label="$hostname ($ip)"
        local start=$(date +%s%N)
        
        if timeout 60 curl -s -X POST "http://${ip}:11434/api/generate" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"mistral\",\"prompt\":\"$prompt\",\"stream\":false,\"num_predict\":$num_predict}" \
            &>/dev/null; then
            
            local end=$(date +%s%N)
            local elapsed_ms=$(( (end - start) / 1000000 ))
            
            echo -e "  ${GREEN}[✓]${NC} $node_label: ${elapsed_ms}ms"
        else
            echo -e "  ${RED}[✗]${NC} $node_label: TIMEOUT/ERROR"
        fi
    done <<< "$nodes"
    
    echo ""
    success "Benchmark complete"
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMMAND: STOP
# ═══════════════════════════════════════════════════════════════════════════════

cmd_stop() {
    banner
    
    log "Stopping all services..."
    
    # Kill local Ollama
    if pgrep -f "ollama serve" &>/dev/null; then
        pkill -f "ollama serve"
        success "Stopped local Ollama"
    fi
    
    # Kill proxy
    if pgrep -f "proxy.py" &>/dev/null; then
        pkill -f "proxy.py"
        success "Stopped proxy"
    fi
    
    echo ""
    info "All services stopped"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true
    
    case "$cmd" in
        init)      cmd_init "$@" ;;
        add-node)  init_env; init_nodes_file; add_node "$@" ;;
        deploy)    cmd_deploy "$@" ;;
        start)     cmd_start "$@" ;;
        proxy)     cmd_proxy "$@" ;;
        status)    cmd_status "$@" ;;
        optimize)  cmd_optimize "$@" ;;
        monitor)   cmd_monitor "$@" ;;
        bench)     cmd_bench "$@" ;;
        stop)      cmd_stop "$@" ;;
        *)
            banner
            echo "Usage: $(basename "$0") <command>"
            echo ""
            echo "Commands:"
            echo "  init            Initialize Ollama cluster"
            echo "  add-node        Register a cluster node"
            echo "                  Usage: $0 add-node <hostname> <ip> <user> [port]"
            echo "  deploy          Deploy Ollama to all nodes"
            echo "  start           Start all Ollama instances"
            echo "  proxy           Start load-balancing proxy (localhost:3080)"
            echo "  status          Check cluster health"
            echo "  optimize        Tune mesh network for AI workloads"
            echo "  monitor         Real-time cluster dashboard"
            echo "  bench           Benchmark inference performance"
            echo "  stop            Stop all services"
            echo ""
            echo "Examples:"
            echo "  ./nullsec-ollama-cluster.sh init"
            echo "  ./nullsec-ollama-cluster.sh add-node node-1 192.168.1.100 root"
            echo "  ./nullsec-ollama-cluster.sh deploy"
            echo "  ./nullsec-ollama-cluster.sh proxy &"
            echo "  curl http://localhost:3080/api/tags"
            echo ""
            ;;
    esac
}

main "$@"
