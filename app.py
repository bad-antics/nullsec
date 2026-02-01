#!/usr/bin/env python3
"""
NullSec Web Dashboard
Flask API server for network monitoring and security tools
Version: 1.1
Author: bad-antics
GitHub: https://github.com/bad-antics/nullsec
"""

__version__ = "1.1"
__author__ = "bad-antics"

from flask import Flask, jsonify, send_from_directory, request
import subprocess
import os
import re
from datetime import datetime

app = Flask(__name__, static_url_path='', static_folder='static')

# Ensure logs directory exists
os.makedirs('logs', exist_ok=True)


def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as e:
        return e.output


def list_connections():
    out = run("ss -tunap 2>/dev/null || netstat -tunap 2>/dev/null")
    return out.splitlines()


def parse_connections():
    """Parse connections into structured data"""
    lines = list_connections()
    connections = []
    for line in lines[1:]:  # Skip header
        parts = line.split()
        if len(parts) >= 5:
            conn = {
                'protocol': parts[0] if parts else '',
                'state': parts[1] if len(parts) > 1 else '',
                'recv_q': parts[2] if len(parts) > 2 else '',
                'send_q': parts[3] if len(parts) > 3 else '',
                'local': parts[4] if len(parts) > 4 else '',
                'remote': parts[5] if len(parts) > 5 else '',
                'process': parts[6] if len(parts) > 6 else '',
                'raw': line
            }
            connections.append(conn)
    return connections


def list_processes():
    out = run("ps -eo pid,ppid,user,stat,%cpu,%mem,comm,cmd --sort=-%cpu")
    return out.splitlines()


def parse_processes():
    """Parse processes into structured data"""
    lines = list_processes()
    processes = []
    for line in lines[1:]:  # Skip header
        parts = line.split(None, 7)
        if len(parts) >= 7:
            proc = {
                'pid': parts[0],
                'ppid': parts[1],
                'user': parts[2],
                'stat': parts[3],
                'cpu': parts[4],
                'mem': parts[5],
                'comm': parts[6],
                'cmd': parts[7] if len(parts) > 7 else parts[6],
                'raw': line
            }
            processes.append(proc)
    return processes


def list_devices():
    out = run("ip neigh show 2>/dev/null || arp -a 2>/dev/null")
    return out.splitlines()


def parse_devices():
    """Parse devices into structured data with connection info"""
    lines = list_devices()
    devices = []
    connections = parse_connections()
    
    for line in lines:
        if not line.strip():
            continue
        parts = line.split()
        if len(parts) >= 4:
            ip = parts[0]
            mac = ''
            state = ''
            interface = ''
            
            # Parse ip neigh format: IP dev IFACE lladdr MAC STATE
            for i, p in enumerate(parts):
                if p == 'lladdr' and i + 1 < len(parts):
                    mac = parts[i + 1]
                if p == 'dev' and i + 1 < len(parts):
                    interface = parts[i + 1]
            state = parts[-1] if parts else ''
            
            # Find connections to/from this IP
            device_connections = [c for c in connections 
                                  if ip in c.get('remote', '') or ip in c.get('local', '')]
            
            device = {
                'ip': ip,
                'mac': mac,
                'interface': interface,
                'state': state,
                'connections': len(device_connections),
                'connection_details': device_connections[:10],  # Limit for perf
                'raw': line
            }
            devices.append(device)
    
    return devices


def get_process_details(pid):
    """Get detailed info about a specific process"""
    details = {}
    
    # Basic process info
    details['status'] = run(f"cat /proc/{pid}/status 2>/dev/null").splitlines()
    details['cmdline'] = run(f"cat /proc/{pid}/cmdline 2>/dev/null | tr '\\0' ' '").strip()
    details['cwd'] = run(f"readlink /proc/{pid}/cwd 2>/dev/null").strip()
    details['exe'] = run(f"readlink /proc/{pid}/exe 2>/dev/null").strip()
    
    # File descriptors (network connections)
    fd_out = run(f"ls -la /proc/{pid}/fd 2>/dev/null")
    details['fds'] = fd_out.splitlines()
    
    # Network connections for this process
    conn_out = run(f"ss -tunap 2>/dev/null | grep 'pid={pid},'")
    details['connections'] = conn_out.splitlines()
    
    # Environment (limited)
    env_out = run(f"cat /proc/{pid}/environ 2>/dev/null | tr '\\0' '\\n' | head -20")
    details['environ'] = env_out.splitlines()
    
    return details


def get_device_connections(ip):
    """Get all connections for a specific device IP"""
    connections = parse_connections()
    return [c for c in connections if ip in c.get('remote', '') or ip in c.get('local', '')]


@app.route('/')
def index():
    return send_from_directory('static', 'index.html')


@app.route('/api/connections')
def api_connections():
    return jsonify({
        "timestamp": datetime.now().isoformat(),
        "lines": list_connections(),
        "parsed": parse_connections()
    })


@app.route('/api/processes')
def api_processes():
    return jsonify({
        "timestamp": datetime.now().isoformat(),
        "lines": list_processes(),
        "parsed": parse_processes()
    })


@app.route('/api/process/<pid>')
def api_process_detail(pid):
    """Get detailed info for a specific process"""
    return jsonify({
        "timestamp": datetime.now().isoformat(),
        "pid": pid,
        "details": get_process_details(pid)
    })


@app.route('/api/devices')
def api_devices():
    return jsonify({
        "timestamp": datetime.now().isoformat(),
        "lines": list_devices(),
        "parsed": parse_devices()
    })


@app.route('/api/device/<ip>/connections')
def api_device_connections(ip):
    """Get connections for a specific device"""
    return jsonify({
        "timestamp": datetime.now().isoformat(),
        "ip": ip,
        "connections": get_device_connections(ip)
    })


@app.route('/api/logs', methods=['POST'])
def save_log():
    """Save a log dump to the server"""
    data = request.json
    log_type = data.get('type', 'general')
    content = data.get('content', '')
    
    ts = datetime.now().strftime('%Y%m%d-%H%M%S')
    filename = f"{log_type}-{ts}.log"
    filepath = os.path.join('logs', filename)
    
    with open(filepath, 'w') as f:
        f.write(f"# NullSec Log Dump\n")
        f.write(f"# Type: {log_type}\n")
        f.write(f"# Timestamp: {datetime.now().isoformat()}\n")
        f.write(f"# {'='*60}\n\n")
        f.write(content)
    
    return jsonify({
        "success": True,
        "filename": filename,
        "path": filepath
    })


@app.route('/api/logs')
def list_logs():
    """List available log files"""
    logs = []
    if os.path.exists('logs'):
        for f in sorted(os.listdir('logs'), reverse=True):
            if f.endswith('.log'):
                path = os.path.join('logs', f)
                logs.append({
                    'name': f,
                    'size': os.path.getsize(path),
                    'modified': datetime.fromtimestamp(os.path.getmtime(path)).isoformat()
                })
    return jsonify({"logs": logs})


@app.route('/api/logs/<filename>')
def get_log(filename):
    """Get contents of a specific log file"""
    filepath = os.path.join('logs', filename)
    if os.path.exists(filepath):
        with open(filepath, 'r') as f:
            return jsonify({"content": f.read(), "filename": filename})
    return jsonify({"error": "Log not found"}), 404


@app.route('/api/desktop')
def launch_desktop():
    """Launch NULLSEC Desktop GUI"""
    desktop_path = os.path.join(os.path.dirname(__file__), 'nullsec-desktop', 'launcher.sh')
    if os.path.exists(desktop_path):
        subprocess.Popen(['bash', desktop_path], 
                        stdout=subprocess.DEVNULL, 
                        stderr=subprocess.DEVNULL)
        return jsonify({"success": True, "message": "NULLSEC Desktop launched"})
    return jsonify({"error": "Desktop application not found"}), 404


@app.route('/api/modules')
def list_modules():
    """List available attack modules"""
    modules_dir = os.path.join(os.path.dirname(__file__), 'nullsecurity')
    modules = []
    if os.path.exists(modules_dir):
        for f in sorted(os.listdir(modules_dir)):
            if f.endswith('.sh') and f not in ['nullsec-common.sh', 'dep-check.sh']:
                name = f.replace('.sh', '').replace('-', ' ').title()
                modules.append({
                    'name': name,
                    'script': f,
                    'path': os.path.join(modules_dir, f)
                })
    return jsonify({"modules": modules, "count": len(modules)})


if __name__ == '__main__':
    port = int(os.environ.get('PORT', '5000'))
    app.run(host='0.0.0.0', port=port, debug=True)
