#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║                   NullSec NetMap v1.0                                        ║
║       Network Topology Visualizer — Interactive HTML Dashboard               ║
║                    Author: bad-antics                                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

Scans the local network and generates an interactive D3.js-powered HTML map
showing all discovered hosts, services, and connections.

Usage:
    nullsec-netmap.py [--subnet 192.168.40.0/24] [--output map.html] [--scan]
"""

import argparse
import json
import os
import re
import socket
import subprocess
import sys
from datetime import datetime
from pathlib import Path

VERSION = "1.0.0"

# ═══════════════════════════════════════════════════════════════════════════════
# Network Scanner
# ═══════════════════════════════════════════════════════════════════════════════

def get_local_subnet():
    """Detect the local subnet from active interfaces."""
    try:
        out = subprocess.check_output(["ip", "-4", "route", "show", "default"], text=True)
        match = re.search(r"dev\s+(\S+)", out)
        if match:
            iface = match.group(1)
            out2 = subprocess.check_output(["ip", "-4", "addr", "show", iface], text=True)
            match2 = re.search(r"inet\s+(\d+\.\d+\.\d+)\.\d+/(\d+)", out2)
            if match2:
                return f"{match2.group(1)}.0/{match2.group(2)}"
    except Exception:
        pass
    return "192.168.40.0/24"


def arp_scan(subnet):
    """Fast ARP scan using arping/nmap."""
    hosts = []

    # Try nmap first (fastest for discovery)
    try:
        out = subprocess.check_output(
            ["nmap", "-sn", "-n", "--min-rate", "500", subnet],
            text=True, timeout=30, stderr=subprocess.DEVNULL
        )
        for block in out.split("Nmap scan report for "):
            if not block.strip():
                continue
            ip_match = re.search(r"(\d+\.\d+\.\d+\.\d+)", block)
            mac_match = re.search(r"MAC Address:\s+([0-9A-F:]+)\s+\((.+?)\)", block, re.IGNORECASE)
            if ip_match:
                host = {
                    "ip": ip_match.group(1),
                    "mac": mac_match.group(1) if mac_match else "",
                    "vendor": mac_match.group(2) if mac_match else "",
                    "hostname": "",
                    "ports": [],
                    "os": "",
                    "status": "up",
                }
                # Reverse DNS
                try:
                    host["hostname"] = socket.gethostbyaddr(host["ip"])[0]
                except Exception:
                    pass
                hosts.append(host)
        return hosts
    except Exception:
        pass

    # Fallback: ping sweep
    try:
        base = ".".join(subnet.split("/")[0].split(".")[:3])
        for i in range(1, 255):
            ip = f"{base}.{i}"
            result = subprocess.run(
                ["ping", "-c", "1", "-W", "1", ip],
                capture_output=True, timeout=2
            )
            if result.returncode == 0:
                hosts.append({
                    "ip": ip, "mac": "", "vendor": "", "hostname": "",
                    "ports": [], "os": "", "status": "up",
                })
    except Exception:
        pass

    return hosts


def port_scan(host, ports="22,80,443,8080,8443,53,21,25,445,3389,5900"):
    """Quick port scan on a single host."""
    open_ports = []
    try:
        out = subprocess.check_output(
            ["nmap", "-Pn", "-n", "--min-rate", "1000", "-p", ports, host["ip"]],
            text=True, timeout=15, stderr=subprocess.DEVNULL
        )
        for line in out.split("\n"):
            match = re.match(r"(\d+)/tcp\s+open\s+(\S+)", line)
            if match:
                open_ports.append({"port": int(match.group(1)), "service": match.group(2)})
    except Exception:
        pass
    return open_ports


def load_cluster_nodes():
    """Load nodes from cluster config if available."""
    nodes = {}
    conf = os.path.expanduser("~/.nullsec/cluster/nodes.conf")
    if os.path.exists(conf):
        with open(conf) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split("|")
                if len(parts) >= 8:
                    nodes[parts[1].strip()] = {
                        "hostname": parts[0].strip(),
                        "role": parts[9].strip() if len(parts) > 9 else "worker",
                        "cores": int(parts[6]) if len(parts) > 6 and parts[6].strip().isdigit() else 0,
                        "ram_mb": int(parts[7]) if len(parts) > 7 and parts[7].strip().isdigit() else 0,
                        "gpu": parts[8].strip() if len(parts) > 8 else "none",
                        "os": parts[4].strip() if len(parts) > 4 else "",
                    }
    return nodes


# ═══════════════════════════════════════════════════════════════════════════════
# HTML Generator
# ═══════════════════════════════════════════════════════════════════════════════

def generate_html(hosts, subnet, cluster_nodes):
    """Generate interactive HTML network map."""

    # Enrich hosts with cluster data
    for host in hosts:
        ip = host["ip"]
        if ip in cluster_nodes:
            cn = cluster_nodes[ip]
            host["hostname"] = host["hostname"] or cn["hostname"]
            host["role"] = cn.get("role", "")
            host["cores"] = cn.get("cores", 0)
            host["ram_mb"] = cn.get("ram_mb", 0)
            host["gpu"] = cn.get("gpu", "none")
            host["cluster_os"] = cn.get("os", "")
            host["is_cluster"] = True
        else:
            host["is_cluster"] = False
            host["role"] = ""

    hosts_json = json.dumps(hosts, indent=2)
    scan_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    return f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>NullSec NetMap — {subnet}</title>
<style>
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
body {{ background: #0a0a0f; color: #c8c8d8; font-family: 'JetBrains Mono', 'Fira Code', monospace; overflow: hidden; }}
#header {{ background: #111118; padding: 12px 24px; border-bottom: 2px solid #00ff88; display: flex; justify-content: space-between; align-items: center; }}
#header h1 {{ color: #00ff88; font-size: 18px; }}
#header .meta {{ color: #666680; font-size: 12px; }}
#main {{ display: flex; height: calc(100vh - 50px); }}
#map {{ flex: 1; position: relative; }}
#sidebar {{ width: 350px; background: #111118; border-left: 1px solid #2a2a3a; overflow-y: auto; padding: 16px; display: none; }}
#sidebar.active {{ display: block; }}
#sidebar h2 {{ color: #00ff88; font-size: 14px; margin-bottom: 12px; border-bottom: 1px solid #2a2a3a; padding-bottom: 8px; }}
.detail-row {{ display: flex; justify-content: space-between; padding: 4px 0; font-size: 12px; }}
.detail-label {{ color: #666680; }}
.detail-value {{ color: #c8c8d8; }}
.detail-value.green {{ color: #00ff88; }}
.detail-value.red {{ color: #ff3355; }}
.detail-value.yellow {{ color: #ffaa00; }}
.detail-value.cyan {{ color: #00ccff; }}
.port-tag {{ display: inline-block; background: #1a1a2a; border: 1px solid #2a2a3a; border-radius: 3px; padding: 2px 6px; margin: 2px; font-size: 11px; }}
.port-tag.ssh {{ border-color: #00ff88; color: #00ff88; }}
.port-tag.http {{ border-color: #00ccff; color: #00ccff; }}
.port-tag.other {{ border-color: #aa55ff; color: #aa55ff; }}
.stats-bar {{ display: flex; gap: 20px; }}
.stat {{ text-align: center; }}
.stat-val {{ font-size: 20px; font-weight: bold; color: #00ff88; }}
.stat-label {{ font-size: 10px; color: #666680; }}
svg {{ width: 100%; height: 100%; }}
.node circle {{ cursor: pointer; stroke-width: 2px; transition: all 0.2s; }}
.node circle:hover {{ stroke-width: 4px; filter: brightness(1.3); }}
.node text {{ fill: #c8c8d8; font-size: 11px; font-family: 'JetBrains Mono', monospace; pointer-events: none; }}
.link {{ stroke: #1a2a1a; stroke-width: 1; opacity: 0.5; }}
.link.cluster {{ stroke: #00ff88; opacity: 0.3; }}
.tooltip {{ position: absolute; background: #1a1a25; border: 1px solid #00ff88; border-radius: 4px; padding: 8px 12px; font-size: 12px; pointer-events: none; display: none; z-index: 100; }}
#legend {{ position: absolute; bottom: 20px; left: 20px; background: #111118cc; border: 1px solid #2a2a3a; border-radius: 6px; padding: 12px; }}
#legend .item {{ display: flex; align-items: center; gap: 8px; font-size: 11px; padding: 2px 0; }}
#legend .dot {{ width: 10px; height: 10px; border-radius: 50%; }}
</style>
</head>
<body>
<div id="header">
    <h1>⬡ NullSec NetMap</h1>
    <div class="stats-bar" id="stats"></div>
    <div class="meta">Subnet: {subnet} | Scanned: {scan_time}</div>
</div>
<div id="main">
    <div id="map">
        <svg id="svg"></svg>
        <div class="tooltip" id="tooltip"></div>
        <div id="legend"></div>
    </div>
    <div id="sidebar">
        <h2 id="sidebar-title">Host Details</h2>
        <div id="sidebar-content"></div>
    </div>
</div>
<script>
const hosts = {hosts_json};

const roleColors = {{
    controller: "#00ff88",
    worker: "#4488ff",
    "gpu-worker": "#ff6633",
    "arm-worker": "#aa55ff",
    default: "#444466"
}};

function getColor(h) {{
    if (h.is_cluster && h.role) return roleColors[h.role] || roleColors.default;
    if (h.ports && h.ports.length > 3) return "#ffaa00";
    if (h.ports && h.ports.some(p => p.port === 80 || p.port === 443)) return "#00ccff";
    return roleColors.default;
}}

function getRadius(h) {{
    if (h.role === "controller") return 18;
    if (h.is_cluster) return 14;
    if (h.ports && h.ports.length > 2) return 12;
    return 8;
}}

// Stats
const clusterCount = hosts.filter(h => h.is_cluster).length;
const totalPorts = hosts.reduce((s, h) => s + (h.ports ? h.ports.length : 0), 0);
document.getElementById("stats").innerHTML = `
    <div class="stat"><div class="stat-val">${{hosts.length}}</div><div class="stat-label">HOSTS</div></div>
    <div class="stat"><div class="stat-val" style="color:#00ccff">${{clusterCount}}</div><div class="stat-label">CLUSTER</div></div>
    <div class="stat"><div class="stat-val" style="color:#ffaa00">${{totalPorts}}</div><div class="stat-label">PORTS</div></div>
`;

// Legend
document.getElementById("legend").innerHTML = `
    <div class="item"><div class="dot" style="background:#00ff88"></div>Controller</div>
    <div class="item"><div class="dot" style="background:#4488ff"></div>Worker</div>
    <div class="item"><div class="dot" style="background:#ff6633"></div>GPU Worker</div>
    <div class="item"><div class="dot" style="background:#aa55ff"></div>ARM Worker</div>
    <div class="item"><div class="dot" style="background:#00ccff"></div>Web Server</div>
    <div class="item"><div class="dot" style="background:#444466"></div>Other</div>
`;

// D3-like force simulation (vanilla JS)
const svg = document.getElementById("svg");
const width = svg.clientWidth;
const height = svg.clientHeight;
const centerX = width / 2, centerY = height / 2;

// Create nodes with initial positions
const nodes = hosts.map((h, i) => ({{
    ...h, x: centerX + (Math.random() - 0.5) * 400,
    y: centerY + (Math.random() - 0.5) * 400,
    vx: 0, vy: 0, idx: i
}}));

// Create links (cluster nodes connect to controller)
const links = [];
const controllerIdx = nodes.findIndex(n => n.role === "controller");
nodes.forEach((n, i) => {{
    if (n.is_cluster && i !== controllerIdx && controllerIdx >= 0) {{
        links.push({{ source: controllerIdx, target: i, cluster: true }});
    }}
}});

// Create SVG elements
const ns = "http://www.w3.org/2000/svg";

links.forEach(l => {{
    const line = document.createElementNS(ns, "line");
    line.classList.add("link");
    if (l.cluster) line.classList.add("cluster");
    l.el = line;
    svg.appendChild(line);
}});

nodes.forEach(n => {{
    const g = document.createElementNS(ns, "g");
    g.classList.add("node");

    const circle = document.createElementNS(ns, "circle");
    circle.setAttribute("r", getRadius(n));
    circle.setAttribute("fill", getColor(n));
    circle.setAttribute("stroke", getColor(n));
    circle.setAttribute("stroke-opacity", "0.5");

    const text = document.createElementNS(ns, "text");
    text.setAttribute("dy", getRadius(n) + 14);
    text.setAttribute("text-anchor", "middle");
    text.textContent = n.hostname || n.ip.split(".").pop();

    g.appendChild(circle);
    g.appendChild(text);
    n.el = g;
    svg.appendChild(g);

    // Drag
    let dragging = false;
    circle.addEventListener("mousedown", e => {{ dragging = true; n.fixed = true; }});
    document.addEventListener("mousemove", e => {{
        if (dragging) {{ n.x = e.clientX; n.y = e.clientY - 50; }}
    }});
    document.addEventListener("mouseup", () => {{ dragging = false; }});

    // Click
    circle.addEventListener("click", () => showDetails(n));

    // Hover
    const tooltip = document.getElementById("tooltip");
    circle.addEventListener("mouseenter", e => {{
        tooltip.innerHTML = `<b>${{n.hostname || n.ip}}</b><br>${{n.ip}}${{n.role ? " [" + n.role + "]" : ""}}`;
        tooltip.style.display = "block";
        tooltip.style.left = (e.clientX + 15) + "px";
        tooltip.style.top = (e.clientY + 15) + "px";
    }});
    circle.addEventListener("mouseleave", () => {{ tooltip.style.display = "none"; }});
}});

// Simple force simulation
function simulate() {{
    nodes.forEach(n => {{
        if (n.fixed) return;
        // Gravity toward center
        n.vx += (centerX - n.x) * 0.001;
        n.vy += (centerY - n.y) * 0.001;

        // Repulsion between nodes
        nodes.forEach(m => {{
            if (m.idx === n.idx) return;
            const dx = n.x - m.x, dy = n.y - m.y;
            const dist = Math.sqrt(dx * dx + dy * dy) || 1;
            if (dist < 150) {{
                const force = 200 / (dist * dist);
                n.vx += dx * force;
                n.vy += dy * force;
            }}
        }});

        // Link attraction
        links.forEach(l => {{
            const s = nodes[l.source], t = nodes[l.target];
            if (n.idx !== l.source && n.idx !== l.target) return;
            const other = n.idx === l.source ? t : s;
            const dx = other.x - n.x, dy = other.y - n.y;
            const dist = Math.sqrt(dx * dx + dy * dy) || 1;
            n.vx += dx * 0.003;
            n.vy += dy * 0.003;
        }});

        n.vx *= 0.9;
        n.vy *= 0.9;
        n.x += n.vx;
        n.y += n.vy;
        n.x = Math.max(30, Math.min(width - 30, n.x));
        n.y = Math.max(30, Math.min(height - 30, n.y));
    }});

    // Update positions
    nodes.forEach(n => {{
        n.el.setAttribute("transform", `translate(${{n.x}},${{n.y}})`);
    }});
    links.forEach(l => {{
        const s = nodes[l.source], t = nodes[l.target];
        l.el.setAttribute("x1", s.x);
        l.el.setAttribute("y1", s.y);
        l.el.setAttribute("x2", t.x);
        l.el.setAttribute("y2", t.y);
    }});

    requestAnimationFrame(simulate);
}}
simulate();

function showDetails(n) {{
    const sidebar = document.getElementById("sidebar");
    const title = document.getElementById("sidebar-title");
    const content = document.getElementById("sidebar-content");
    sidebar.classList.add("active");
    title.textContent = n.hostname || n.ip;

    let html = `
        <div class="detail-row"><span class="detail-label">IP</span><span class="detail-value cyan">${{n.ip}}</span></div>
        <div class="detail-row"><span class="detail-label">MAC</span><span class="detail-value">${{n.mac || "N/A"}}</span></div>
        <div class="detail-row"><span class="detail-label">Vendor</span><span class="detail-value">${{n.vendor || "Unknown"}}</span></div>
        <div class="detail-row"><span class="detail-label">Status</span><span class="detail-value green">●  UP</span></div>
    `;

    if (n.is_cluster) {{
        html += `
            <h2 style="margin-top:12px">Cluster Node</h2>
            <div class="detail-row"><span class="detail-label">Role</span><span class="detail-value green">${{n.role}}</span></div>
            <div class="detail-row"><span class="detail-label">Cores</span><span class="detail-value">${{n.cores || "?"}}</span></div>
            <div class="detail-row"><span class="detail-label">RAM</span><span class="detail-value">${{n.ram_mb ? (n.ram_mb/1024).toFixed(1) + " GB" : "?"}}</span></div>
            <div class="detail-row"><span class="detail-label">GPU</span><span class="detail-value yellow">${{n.gpu || "none"}}</span></div>
            <div class="detail-row"><span class="detail-label">OS</span><span class="detail-value">${{n.cluster_os || "?"}}</span></div>
        `;
    }}

    if (n.ports && n.ports.length) {{
        html += `<h2 style="margin-top:12px">Open Ports</h2><div>`;
        n.ports.forEach(p => {{
            let cls = p.port === 22 ? "ssh" : (p.port === 80 || p.port === 443) ? "http" : "other";
            html += `<span class="port-tag ${{cls}}">${{p.port}}/${{p.service}}</span>`;
        }});
        html += `</div>`;
    }}

    content.innerHTML = html;
}}
</script>
</body>
</html>'''


# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(description="NullSec NetMap — Network Topology Visualizer")
    parser.add_argument("--subnet", "-s", help="Subnet to scan (default: auto-detect)")
    parser.add_argument("--output", "-o", default="netmap.html", help="Output HTML file")
    parser.add_argument("--scan-ports", action="store_true", help="Also scan common ports")
    parser.add_argument("--no-scan", action="store_true", help="Skip scan, use cached data")
    parser.add_argument("--json", help="Load hosts from JSON file instead of scanning")
    parser.add_argument("--version", action="version", version=f"%(prog)s {VERSION}")
    args = parser.parse_args()

    print(f"\033[32m⬡ NullSec NetMap v{VERSION}\033[0m\n")

    subnet = args.subnet or get_local_subnet()
    print(f"  Subnet: {subnet}")

    # Load cluster data
    cluster_nodes = load_cluster_nodes()
    print(f"  Cluster nodes: {len(cluster_nodes)}")

    if args.json:
        with open(args.json) as f:
            hosts = json.load(f)
        print(f"  Loaded {len(hosts)} hosts from {args.json}")
    elif args.no_scan:
        hosts = [{"ip": ip, "hostname": cn["hostname"], "mac": "", "vendor": "",
                   "ports": [], "os": cn.get("os", ""), "status": "up"}
                 for ip, cn in cluster_nodes.items()]
        print(f"  Using {len(hosts)} cluster nodes (no scan)")
    else:
        print(f"  Scanning {subnet}...")
        hosts = arp_scan(subnet)
        print(f"  Found {len(hosts)} hosts")

        if args.scan_ports and hosts:
            print(f"  Port scanning {len(hosts)} hosts...")
            for i, host in enumerate(hosts):
                host["ports"] = port_scan(host)
                sys.stdout.write(f"\r  Scanned {i+1}/{len(hosts)}...")
                sys.stdout.flush()
            print(" done")

    # Generate map
    output = Path(args.output)
    html = generate_html(hosts, subnet, cluster_nodes)
    output.write_text(html)
    print(f"\n  \033[32m✓\033[0m Map saved: {output.resolve()}")
    print(f"  Open in browser: file://{output.resolve()}")

    # Also save JSON
    json_out = output.with_suffix(".json")
    json_out.write_text(json.dumps(hosts, indent=2))
    print(f"  JSON data: {json_out}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
