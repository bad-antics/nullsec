# 🚀 NullSec Ollama Cluster Accelerator

## Power Up Your Mesh Network for Lightning-Fast AI

Combine the full power of your mesh network to run distributed Ollama AI inference at **localhost:3080** with automatic load balancing, model caching, and network optimization across all your cluster nodes.

---

## 🎯 Quick Start (5 minutes)

### 1. Initialize Cluster
```bash
./nullsec-ollama-cluster.sh init
```

### 2. Register Your Nodes
Add each cluster node (worker machine with Ollama):
```bash
./nullsec-ollama-cluster.sh add-node node-1 192.168.1.100 root
./nullsec-ollama-cluster.sh add-node node-2 192.168.1.101 root
./nullsec-ollama-cluster.sh add-node node-3 192.168.1.102 root
```

### 3. Optimize Mesh for AI Workloads
```bash
# Standard optimization
sudo ./nullsec-mesh-ollama-tuning.sh

# Or for maximum throughput
sudo ./nullsec-mesh-ollama-tuning.sh --ultra
```

### 4. Deploy & Start Services
```bash
# Deploy Ollama to all nodes (parallel)
./nullsec-ollama-cluster.sh deploy

# Start all Ollama instances
./nullsec-ollama-cluster.sh start

# Start load-balancing proxy (runs in background)
./nullsec-ollama-cluster.sh proxy &

# Monitor cluster health
./nullsec-ollama-cluster.sh monitor
```

### 5. Test It Works
```bash
# Check proxy health
curl http://localhost:3080/health

# List available models
curl http://localhost:3080/api/tags

# Run inference (distributed across cluster)
curl -X POST http://localhost:3080/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral",
    "prompt": "The future of AI is",
    "stream": false
  }'
```

### 6. View Real-Time Dashboard
```bash
python3 nullsec-ollama-monitor.py &
# Visit http://localhost:9008 in browser
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Your Machine (Master Node)                             │
│  ├─ Ollama Instance (port 11434)                        │
│  ├─ FastAPI Load Balancer (localhost:3080)              │
│  └─ Monitor Dashboard (localhost:9008)                  │
├─────────────────────────────────────────────────────────┤
│              Batman-adv Mesh Network                    │
│         (Optimized for low-latency AI)                  │
├─────────────────────────────────────────────────────────┤
│  Worker Nodes                                           │
│  ├─ node-1: Ollama + GPU Support (11434)                │
│  ├─ node-2: Ollama + CPU Inference (11434)              │
│  └─ node-3: Ollama + Cache Layer (11434)                │
└─────────────────────────────────────────────────────────┘
```

### How It Works

1. **Request Routing**: Requests to `localhost:3080` are intercepted by the FastAPI proxy
2. **Node Selection**: Proxy measures latency to each node and selects the fastest responder
3. **Load Distribution**: Multiple concurrent requests are distributed across available nodes
4. **Automatic Failover**: If a node goes offline, requests route to healthy nodes
5. **Model Caching**: Models are cached on each node, avoiding repeated downloads
6. **Mesh Optimization**: Batman-adv is tuned for low-latency, high-throughput AI workloads

---

## 📊 Commands Reference

### Cluster Management

```bash
# Initialize cluster infrastructure
./nullsec-ollama-cluster.sh init

# Register a new worker node
./nullsec-ollama-cluster.sh add-node <hostname> <ip> <user> [ssh-port]

# Deploy Ollama to all registered nodes
./nullsec-ollama-cluster.sh deploy

# Start all Ollama instances
./nullsec-ollama-cluster.sh start

# Stop all services
./nullsec-ollama-cluster.sh stop
```

### Proxy & Monitoring

```bash
# Start load-balancing proxy (localhost:3080)
./nullsec-ollama-cluster.sh proxy

# Check cluster health status
./nullsec-ollama-cluster.sh status

# Real-time cluster monitor
./nullsec-ollama-cluster.sh monitor

# Benchmark inference speed across nodes
./nullsec-ollama-cluster.sh bench
```

### Network Optimization

```bash
# Standard mesh optimization for AI workloads
sudo ./nullsec-mesh-ollama-tuning.sh

# Ultra-aggressive mode (maximum throughput)
sudo ./nullsec-mesh-ollama-tuning.sh --ultra
```

### Dashboard

```bash
# Start monitoring dashboard
python3 nullsec-ollama-monitor.py

# Custom port
OLLAMA_MONITOR_PORT=8080 python3 nullsec-ollama-monitor.py
```

---

## 🔧 Advanced Configuration

### Mesh Network Tuning

The `nullsec-mesh-ollama-tuning.sh` script optimizes:

- **Batman-adv**: Gateway bandwidth, hop penalty, originator interval, network coding
- **Kernel buffers**: Large 256MB+ buffers for multi-GB model transfers
- **TCP tuning**: Window scaling, FIN timeout, slow-start optimization
- **QDisc**: CAKE or fq_codel for low-latency packet scheduling
- **Connection tracking**: Increased limits for parallel model downloads

#### Ultra Mode (`--ultra`)

```bash
sudo ./nullsec-mesh-ollama-tuning.sh --ultra
```

Enables maximum throughput configuration:
- 2GB buffer ranges
- Aggressive TCP retransmission
- UDP offload acceleration
- Netfilter connection tracking at 1 million+ concurrent

### Custom Model Pre-caching

Edit the `MODELS` variable in `nullsec-ollama-cluster.sh`:

```bash
MODELS=("mistral" "neural-chat" "orca-mini" "llama2" "dolphin-mixtral")
```

Then pull them on all nodes:

```bash
for node in node-1 node-2 node-3; do
  ssh root@$node "ollama pull mistral"
done
```

### Load Balancer Configuration

The proxy in `nullsec-ollama-cluster.sh` has built-in:

- **Health checking**: Probes each node every ~100ms
- **Latency measurement**: Selects fastest responding node
- **Request routing**: Distributes to best node
- **Automatic failover**: Routes around offline nodes
- **Streaming support**: Handles long-running inference requests

---

## 📈 Performance Tips

### 1. Network Optimization

```bash
# Check mesh neighbors and link quality
batctl meshif bat0 neighbors

# Monitor originator table (routing)
batctl meshif bat0 originators

# View gateway mode
batctl meshif bat0 gw_mode
```

### 2. Monitor Network Traffic

```bash
# Real-time mesh throughput
iftop -i bat0

# Per-interface statistics
watch -n 1 'ip -s link | grep -A2 bat0'
```

### 3. Pre-warm Models

Before heavy inference, pull models on all nodes:

```bash
# Pre-cache models to avoid download latency
ollama pull mistral
ollama pull neural-chat
```

### 4. Benchmark Before & After

```bash
# Run benchmark suite
./nullsec-ollama-cluster.sh bench

# Compare results before/after mesh tuning
```

---

## 🔍 Troubleshooting

### Proxy not responding on localhost:3080

```bash
# Check if proxy is running
ps aux | grep proxy.py

# Check logs
tail -f ~/.nullsec/ollama-cluster/logs/proxy.log

# Manually start with debug output
python3 ~/.nullsec/ollama-cluster/proxy.py
```

### Remote nodes offline

```bash
# Test SSH connectivity
ssh -vvv root@192.168.1.100 "echo ok"

# Check Ollama running on remote
ssh root@192.168.1.100 "pgrep -f 'ollama serve' && echo OK"

# Check firewall on port 11434
ssh root@192.168.1.100 "netstat -tlnp | grep 11434"
```

### Slow model transfers

```bash
# Check mesh link quality
batctl meshif bat0 neighbors

# Monitor network buffers
cat /proc/sys/net/core/rmem_default

# Re-run mesh optimization
sudo ./nullsec-mesh-ollama-tuning.sh --ultra
```

### Models not visible on proxy

```bash
# Check models on local
curl http://localhost:11434/api/tags

# Check models on remote node
curl http://192.168.1.100:11434/api/tags

# Reload proxy configuration
pkill -f proxy.py && sleep 1 && ./nullsec-ollama-cluster.sh proxy &
```

---

## 📋 File Structure

```
~/.nullsec/ollama-cluster/
├── nodes.conf              # Registered cluster nodes
├── state/
│   └── metrics.json        # Current cluster metrics
├── logs/
│   ├── ollama-local.log    # Local Ollama logs
│   └── proxy.log           # Load balancer logs
├── shared/                 # Shared cache directory
└── proxy.py                # Generated load-balancer script
```

---

## 🚀 Performance Expectations

With proper mesh optimization and multiple nodes:

| Configuration | Speed | Notes |
|---|---|---|
| Single Node (no mesh) | 1x | Baseline |
| 2-Node Cluster | 1.8-2.0x | ~80-100% utilization of both nodes |
| 3-Node Cluster | 2.5-2.8x | Near-linear scaling |
| 4-Node Cluster | 3.2-3.7x | With GPU acceleration on some nodes |

*Results vary based on model size, mesh quality, and node hardware.*

---

## 🔐 Security Considerations

- **SSH Authentication**: Uses key-based auth (requires `~/.ssh/id_ed25519`)
- **Network Isolation**: Assumes mesh network is trusted (same LAN)
- **No TLS**: Proxy runs on localhost only (not exposed to internet)
- **No Authentication**: Proxy assumes trusted local users

For production:
- Use VPN for remote nodes
- Add authentication to proxy
- Enable TLS on all connections
- Restrict network access

---

## 📚 Related Scripts

- `./nullsec-cluster.sh` - General-purpose cluster management
- `./nullsec-mesh-setup.sh` - Initial mesh network setup
- `./nullsec-cluster-health.sh` - Cluster health monitoring
- `./nullsec-mesh-optimize.sh` - General mesh optimization

---

## 💡 Examples

### Example 1: Text Generation

```bash
curl -X POST http://localhost:3080/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral",
    "prompt": "Explain quantum computing in simple terms:",
    "stream": false,
    "temperature": 0.7,
    "num_predict": 100
  }' | jq .response
```

### Example 2: Streaming Response

```bash
curl -X POST http://localhost:3080/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "neural-chat",
    "prompt": "Write a haiku about cats",
    "stream": true
  }' | grep -o '"response":"[^"]*"' | cut -d'"' -f4
```

### Example 3: Batch Processing

```bash
for prompt in "What is AI?" "What is ML?" "What is DL?"; do
  curl -s -X POST http://localhost:3080/api/generate \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"mistral\",\"prompt\":\"$prompt\",\"stream\":false}" &
done
wait
```

---

## 📞 Support & Contribution

For issues, improvements, or contributions:
- Check logs: `tail -f ~/.nullsec/ollama-cluster/logs/*`
- Run status: `./nullsec-ollama-cluster.sh status`
- Check monitor: `http://localhost:9008`

---

**Built with ❤️ by NullSec | Developed by: bad-antics**
