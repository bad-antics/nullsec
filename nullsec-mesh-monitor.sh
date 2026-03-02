#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# NullSec Mesh Monitor - Launcher
# Installs dependencies and launches the mesh monitor app
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$SCRIPT_DIR/nullsec-mesh-monitor.py"

# Check Python3
if ! command -v python3 &>/dev/null; then
    echo "[!] Python3 not found. Installing..."
    sudo apt-get install -y python3 python3-tk python3-pip 2>/dev/null || {
        sudo pacman -S python python-tk 2>/dev/null
    }
fi

# Check tkinter
python3 -c "import tkinter" 2>/dev/null || {
    echo "[*] Installing tkinter..."
    sudo apt-get install -y python3-tk 2>/dev/null
}

# Check psutil
python3 -c "import psutil" 2>/dev/null || {
    echo "[*] Installing psutil..."
    pip3 install psutil 2>/dev/null || sudo apt-get install -y python3-psutil 2>/dev/null
}

# Ensure nodes.conf directory exists
mkdir -p ~/.nullsec/cluster

echo "[*] Launching NullSec Mesh Monitor..."
exec python3 "$APP" "$@"
