#!/usr/bin/env python3
"""
NullSec Ollama Cluster Monitor & Dashboard
Real-time performance monitoring for distributed Ollama inference
"""

import os
import json
import time
import asyncio
import httpx
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
from fastapi import FastAPI, WebSocket
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.staticfiles import StaticFiles
import uvicorn

app = FastAPI(title="NullSec Ollama Cluster Monitor")

# Configuration
NODES_FILE = Path(os.path.expanduser("~/.nullsec/ollama-cluster/nodes.conf"))
STATE_DIR = Path(os.path.expanduser("~/.nullsec/ollama-cluster/state"))
STATE_DIR.mkdir(parents=True, exist_ok=True)

# In-memory node registry
nodes_cache = {}
metrics = {
    "local": {"status": "offline", "latency": 0, "models": []},
    "remote": {}
}

def load_nodes_config() -> List[Dict]:
    """Load registered cluster nodes"""
    nodes = []
    if NODES_FILE.exists():
        with open(NODES_FILE) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    parts = line.split("|")
                    if len(parts) >= 6:
                        nodes.append({
                            "hostname": parts[0],
                            "ip": parts[1],
                            "user": parts[2],
                            "port": int(parts[3]),
                            "ollama_port": int(parts[5]),
                            "gpu": parts[6] if len(parts) > 6 else "none"
                        })
    return nodes

async def probe_ollama_node(ip: str, port: int, timeout: float = 5.0) -> Dict:
    """Check node status and get model list"""
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            start = time.time()
            resp = await client.get(f"http://{ip}:{port}/api/tags")
            latency = int((time.time() - start) * 1000)
            
            if resp.status_code == 200:
                data = resp.json()
                models = [m["name"].split(":")[0] for m in data.get("models", [])]
                return {
                    "status": "online",
                    "latency": latency,
                    "models": models,
                    "model_count": len(models)
                }
    except:
        pass
    
    return {"status": "offline", "latency": 0, "models": [], "model_count": 0}

async def update_metrics():
    """Periodically update cluster metrics"""
    while True:
        nodes = load_nodes_config()
        
        # Probe local Ollama
        local_metrics = await probe_ollama_node("127.0.0.1", 11434)
        metrics["local"] = local_metrics
        
        # Probe remote nodes
        metrics["remote"] = {}
        for node in nodes:
            node_metrics = await probe_ollama_node(node["ip"], node["ollama_port"])
            node_metrics["gpu"] = node["gpu"]
            metrics["remote"][node["hostname"]] = node_metrics
        
        # Save state
        state_file = STATE_DIR / "metrics.json"
        state_file.write_text(json.dumps(metrics, indent=2))
        
        await asyncio.sleep(5)

@app.on_event("startup")
async def startup_event():
    """Start background metric collection"""
    asyncio.create_task(update_metrics())

@app.get("/api/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "metrics": metrics
    }

@app.get("/api/metrics")
async def get_metrics():
    """Get current cluster metrics"""
    return metrics

@app.get("/api/nodes")
async def get_nodes():
    """Get registered nodes"""
    return {
        "local": {
            "ip": "127.0.0.1",
            "port": 11434,
            "status": metrics["local"]["status"]
        },
        "remote": [
            {
                "hostname": hostname,
                "ip": metrics["remote"][hostname].get("ip"),
                "status": metrics["remote"][hostname]["status"],
                "latency": metrics["remote"][hostname]["latency"],
                "models": metrics["remote"][hostname]["models"],
                "gpu": metrics["remote"][hostname].get("gpu", "none")
            }
            for hostname in metrics["remote"]
        ]
    }

@app.websocket("/ws/metrics")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket for real-time metrics"""
    await websocket.accept()
    try:
        while True:
            await websocket.send_json(metrics)
            await asyncio.sleep(2)
    except:
        pass

# Dashboard HTML
DASHBOARD_HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>NullSec Ollama Cluster Monitor</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Courier New', monospace;
            background: #0a0a0a;
            color: #0ff;
            padding: 20px;
        }
        .header {
            text-align: center;
            border-bottom: 2px solid #0ff;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        .header h1 {
            font-size: 28px;
            text-shadow: 0 0 10px #0ff;
            margin-bottom: 5px;
        }
        .header p {
            font-size: 12px;
            color: #088;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .card {
            border: 1px solid #0ff;
            background: #001a1a;
            padding: 15px;
            border-radius: 4px;
            box-shadow: 0 0 20px rgba(0, 255, 255, 0.1);
        }
        .card.online { border-left: 4px solid #0f0; }
        .card.offline { border-left: 4px solid #f00; }
        .card h3 {
            margin-bottom: 10px;
            font-size: 16px;
            color: #0ff;
        }
        .status {
            display: flex;
            justify-content: space-between;
            margin-bottom: 10px;
            font-size: 13px;
        }
        .status-label { color: #088; }
        .status-online { color: #0f0; }
        .status-offline { color: #f00; }
        .models {
            margin-top: 10px;
            padding-top: 10px;
            border-top: 1px solid #033;
            font-size: 12px;
        }
        .model-item {
            display: inline-block;
            background: #0a2a2a;
            padding: 4px 8px;
            border-radius: 3px;
            margin: 3px;
            border: 1px solid #033;
        }
        .metrics {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 10px;
            margin-top: 15px;
        }
        .metric {
            text-align: center;
            padding: 10px;
            background: #0a1a1a;
            border: 1px solid #033;
            border-radius: 3px;
        }
        .metric-value {
            font-size: 20px;
            color: #0f0;
            font-weight: bold;
        }
        .metric-label {
            font-size: 11px;
            color: #088;
            margin-top: 5px;
        }
        .info-panel {
            background: #001a1a;
            border: 1px solid #0ff;
            padding: 15px;
            border-radius: 4px;
            font-size: 13px;
            line-height: 1.6;
        }
        .info-panel strong { color: #0ff; }
        .timestamp {
            text-align: right;
            color: #088;
            font-size: 12px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔮 NullSec Ollama Cluster Monitor</h1>
        <p>Real-time Performance Dashboard</p>
    </div>
    
    <div class="grid" id="nodes-container">
        <!-- Loaded via JavaScript -->
    </div>
    
    <div class="info-panel">
        <strong>📊 Summary:</strong>
        <div id="summary">
            <div>Total Nodes: <span id="total-nodes">-</span></div>
            <div>Online: <span id="online-count" style="color: #0f0;">-</span></div>
            <div>Total Models: <span id="model-count">-</span></div>
        </div>
    </div>
    
    <div class="timestamp">
        Last updated: <span id="timestamp">-</span>
    </div>
    
    <script>
        const ws = new WebSocket(`ws://${window.location.host}/ws/metrics`);
        
        ws.onmessage = (event) => {
            const metrics = JSON.parse(event.data);
            updateDashboard(metrics);
        };
        
        function updateDashboard(metrics) {
            const container = document.getElementById('nodes-container');
            let html = '';
            let onlineCount = 0;
            let totalModels = 0;
            
            // Local node
            const local = metrics.local;
            const localOnline = local.status === 'online';
            onlineCount += localOnline ? 1 : 0;
            totalModels += local.models.length;
            
            html += `
                <div class="card ${local.status}">
                    <h3>🏠 Local Ollama</h3>
                    <div class="status">
                        <span class="status-label">Status:</span>
                        <span class="status-${local.status}">${local.status.toUpperCase()}</span>
                    </div>
                    <div class="status">
                        <span class="status-label">Port:</span>
                        <span>11434</span>
                    </div>
                    <div class="status">
                        <span class="status-label">Latency:</span>
                        <span>${local.latency}ms</span>
                    </div>
                    ${local.models.length > 0 ? `
                        <div class="models">
                            <strong style="color: #088;">Models:</strong><br>
                            ${local.models.map(m => `<span class="model-item">${m}</span>`).join('')}
                        </div>
                    ` : ''}
                </div>
            `;
            
            // Remote nodes
            for (const [hostname, node] of Object.entries(metrics.remote)) {
                const nodeOnline = node.status === 'online';
                onlineCount += nodeOnline ? 1 : 0;
                totalModels += node.models.length;
                
                html += `
                    <div class="card ${node.status}">
                        <h3>🖥️ ${hostname}</h3>
                        <div class="status">
                            <span class="status-label">Status:</span>
                            <span class="status-${node.status}">${node.status.toUpperCase()}</span>
                        </div>
                        <div class="status">
                            <span class="status-label">Latency:</span>
                            <span>${node.latency}ms</span>
                        </div>
                        <div class="status">
                            <span class="status-label">GPU:</span>
                            <span>${node.gpu}</span>
                        </div>
                        ${node.models.length > 0 ? `
                            <div class="models">
                                <strong style="color: #088;">Models:</strong><br>
                                ${node.models.map(m => `<span class="model-item">${m}</span>`).join('')}
                            </div>
                        ` : ''}
                    </div>
                `;
            }
            
            container.innerHTML = html;
            
            // Update summary
            document.getElementById('total-nodes').textContent = Object.keys(metrics.remote).length + 1;
            document.getElementById('online-count').textContent = onlineCount;
            document.getElementById('model-count').textContent = totalModels;
            document.getElementById('timestamp').textContent = new Date().toLocaleTimeString();
        }
    </script>
</body>
</html>
"""

@app.get("/")
async def dashboard():
    """Serve dashboard"""
    return HTMLResponse(DASHBOARD_HTML)

if __name__ == "__main__":
    port = int(os.environ.get("OLLAMA_MONITOR_PORT", "9008"))
    print(f"""
    ╔═══════════════════════════════════════════════════════════╗
    ║  NullSec Ollama Cluster Monitor                          ║
    ║  http://localhost:{port}                                    ║
    ╚═══════════════════════════════════════════════════════════╝
    """)
    uvicorn.run(app, host="0.0.0.0", port=port, access_log=False)
