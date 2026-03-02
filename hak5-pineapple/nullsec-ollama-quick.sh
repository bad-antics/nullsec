#!/bin/bash
#╔═══════════════════════════════════════════════════════════════════════════════╗
#║                                                                               ║
#║        NullSec Ollama Cluster Quick Accelerator v1.0                          ║
#║        One-command setup to power up your mesh network                        ║
#║                                                                               ║
#╚═══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[-]${NC} $1"; }
info()  { echo -e "${BLUE}[i]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }

banner() {
    echo ""
    echo -e "${CYAN}"
    cat << 'EOF'
  ╔═══════════════════════════════════════════════════════════════╗
  ║                                                               ║
  ║   🚀 NullSec Ollama Cluster Accelerator                      ║
  ║      Power Up Your Mesh Network for Lightning-Fast AI        ║
  ║                                                               ║
  ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_deps() {
    log "Checking dependencies..."
    
    # Check Ollama
    if ! command -v ollama &>/dev/null; then
        err "Ollama not found. Install with:"
        echo "  curl https://ollama.ai/install.sh | sh"
        exit 1
    fi
    success "Ollama installed"
    
    # Check mesh
    if ! ip link show bat0 &>/dev/null 2>&1; then
        warn "Mesh network (bat0) not found"
        warn "Run: ./nullsec-mesh-setup.sh first"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        success "Mesh network (bat0) detected"
    fi
    
    # Check for Python FastAPI
    if ! python3 -c "import fastapi" 2>/dev/null; then
        warn "FastAPI not installed, installing now..."
        pip3 install fastapi uvicorn httpx &>/dev/null
        success "FastAPI installed"
    else
        success "FastAPI installed"
    fi
    
    echo ""
}

show_menu() {
    echo "What would you like to do?"
    echo ""
    echo "  1) Full Setup (all steps below)"
    echo "  2) Just Initialize Cluster"
    echo "  3) Just Optimize Mesh Network"
    echo "  4) Just Start Ollama Instances"
    echo "  5) Just Start Load-Balancer Proxy (localhost:3080)"
    echo "  6) Add & Deploy a New Node"
    echo "  7) View Real-Time Monitor"
    echo "  8) Run Benchmark"
    echo ""
    read -p "Select (1-8): " choice
}

full_setup() {
    banner
    check_deps
    
    log "Starting full cluster accelerator setup..."
    echo ""
    
    # Step 1: Initialize
    log "Step 1/4: Initializing cluster..."
    ./nullsec-ollama-cluster.sh init
    echo ""
    
    # Step 2: Mesh optimization
    log "Step 2/4: Optimizing mesh network..."
    if [[ $EUID -eq 0 ]]; then
        ./nullsec-mesh-ollama-tuning.sh --ultra
    else
        warn "Run the following as root for mesh optimization:"
        echo "  sudo ./nullsec-mesh-ollama-tuning.sh --ultra"
    fi
    echo ""
    
    # Step 3: Register nodes (interactive)
    log "Step 3/4: Register cluster nodes"
    echo "Add nodes to your cluster (enter 'skip' to continue):"
    echo ""
    
    node_count=0
    while true; do
        read -p "Node hostname (or 'skip'): " hostname
        if [[ "$hostname" == "skip" ]] || [[ -z "$hostname" ]]; then
            break
        fi
        
        read -p "Node IP address: " ip
        read -p "SSH user (default: root): " user
        user=${user:-root}
        read -p "SSH port (default: 22): " port
        port=${port:-22}
        
        ./nullsec-ollama-cluster.sh add-node "$hostname" "$ip" "$user" "$port"
        node_count=$((node_count + 1))
        echo ""
    done
    
    if [[ $node_count -gt 0 ]]; then
        log "Starting deployment to $node_count nodes..."
        ./nullsec-ollama-cluster.sh deploy
        ./nullsec-ollama-cluster.sh start
        echo ""
    fi
    
    # Step 4: Start services
    log "Step 4/4: Starting services..."
    ./nullsec-ollama-cluster.sh start
    
    log "Starting load-balancing proxy in background..."
    nohup ./nullsec-ollama-cluster.sh proxy > ~/.nullsec/ollama-cluster/logs/proxy.log 2>&1 &
    sleep 2
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    success "SETUP COMPLETE!"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    info "Your accelerated Ollama cluster is ready! 🎉"
    echo ""
    echo "📌 Quick Links:"
    echo "   Proxy:              http://localhost:3080"
    echo "   Monitor Dashboard:  http://localhost:9008 (start with: python3 nullsec-ollama-monitor.py)"
    echo "   API Endpoint:       POST http://localhost:3080/api/generate"
    echo ""
    echo "🔧 Useful Commands:"
    echo "   Check status:       ./nullsec-ollama-cluster.sh status"
    echo "   Watch monitor:      ./nullsec-ollama-cluster.sh monitor"
    echo "   Run benchmark:      ./nullsec-ollama-cluster.sh bench"
    echo "   See all commands:   ./nullsec-ollama-cluster.sh help"
    echo ""
    echo "📖 Full Guide: OLLAMA_CLUSTER_GUIDE.md"
    echo ""
}

add_and_deploy_node() {
    banner
    
    read -p "Node hostname: " hostname
    read -p "Node IP address: " ip
    read -p "SSH user (default: root): " user
    user=${user:-root}
    read -p "SSH port (default: 22): " port
    port=${port:-22}
    
    log "Adding node: $hostname ($ip)"
    ./nullsec-ollama-cluster.sh add-node "$hostname" "$ip" "$user" "$port"
    
    read -p "Deploy Ollama to this node now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./nullsec-ollama-cluster.sh deploy
        ./nullsec-ollama-cluster.sh start
        success "Node deployed and started"
    fi
}

show_monitor() {
    banner
    
    echo "Starting monitor dashboard on http://localhost:9008"
    echo ""
    echo "Requirements: pip3 install fastapi uvicorn httpx"
    echo ""
    
    python3 nullsec-ollama-monitor.py
}

case "${1:-}" in
    1)
        full_setup
        ;;
    2)
        banner
        ./nullsec-ollama-cluster.sh init
        ;;
    3)
        banner
        if [[ $EUID -eq 0 ]]; then
            ./nullsec-mesh-ollama-tuning.sh --ultra
        else
            err "Mesh optimization requires root"
            echo "Run: sudo ./nullsec-mesh-ollama-tuning.sh --ultra"
            exit 1
        fi
        ;;
    4)
        banner
        ./nullsec-ollama-cluster.sh start
        ;;
    5)
        banner
        log "Starting load-balancer proxy on localhost:3080"
        echo "Press Ctrl+C to stop"
        echo ""
        ./nullsec-ollama-cluster.sh proxy
        ;;
    6)
        add_and_deploy_node
        ;;
    7)
        show_monitor
        ;;
    8)
        banner
        ./nullsec-ollama-cluster.sh bench
        ;;
    *)
        banner
        check_deps
        show_menu
        
        case "$choice" in
            1) full_setup ;;
            2) ./nullsec-ollama-cluster.sh init ;;
            3)
                if [[ $EUID -eq 0 ]]; then
                    ./nullsec-mesh-ollama-tuning.sh --ultra
                else
                    err "Run as root for mesh optimization"
                fi
                ;;
            4) ./nullsec-ollama-cluster.sh start ;;
            5) ./nullsec-ollama-cluster.sh proxy ;;
            6) add_and_deploy_node ;;
            7) show_monitor ;;
            8) ./nullsec-ollama-cluster.sh bench ;;
            *) err "Invalid choice"; exit 1 ;;
        esac
        ;;
esac
