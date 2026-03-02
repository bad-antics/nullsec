"""NullSec WebTools — Web Terminal
WebSocket-based SSH terminal in the browser."""

import asyncio
import json
from fastapi import APIRouter, Request, WebSocket, WebSocketDisconnect
from fastapi.templating import Jinja2Templates
from pathlib import Path
from ..services import load_nodes, check_port

router = APIRouter()
templates = Jinja2Templates(directory=str(Path(__file__).parent.parent / "templates"))

try:
    import paramiko
    HAS_PARAMIKO = True
except ImportError:
    HAS_PARAMIKO = False


@router.get("/")
async def terminal_page(request: Request):
    nodes = load_nodes()
    return templates.TemplateResponse("terminal.html", {
        "request": request,
        "page": "terminal",
        "nodes": [{"name": n.name, "ip": n.ip} for n in nodes],
    })


@router.websocket("/ws/{node_name}")
async def terminal_ws(websocket: WebSocket, node_name: str):
    """WebSocket SSH terminal session."""
    await websocket.accept()

    if not HAS_PARAMIKO:
        await websocket.send_text(json.dumps({"error": "paramiko not installed"}))
        await websocket.close()
        return

    nodes = load_nodes()
    node = next((n for n in nodes if n.name == node_name), None)

    if not node:
        await websocket.send_text(json.dumps({"error": f"Node '{node_name}' not found"}))
        await websocket.close()
        return

    if not check_port(node.ip, node.port):
        await websocket.send_text(json.dumps({"error": f"Node '{node_name}' is offline"}))
        await websocket.close()
        return

    # Connect SSH
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        kwargs = {
            "hostname": node.ip, "port": node.port,
            "username": node.user, "timeout": 10,
            "allow_agent": False, "look_for_keys": True,
        }
        if node.password:
            kwargs["password"] = node.password
            kwargs["look_for_keys"] = False
        client.connect(**kwargs)

        channel = client.invoke_shell(term="xterm-256color", width=120, height=40)
        channel.settimeout(0.1)

        await websocket.send_text(json.dumps({
            "connected": True,
            "node": node.name,
            "host": f"{node.user}@{node.ip}",
        }))

        # Bidirectional relay
        async def read_ssh():
            """Read from SSH channel and send to WebSocket."""
            while True:
                try:
                    if channel.recv_ready():
                        data = channel.recv(4096).decode(errors="replace")
                        await websocket.send_text(json.dumps({"output": data}))
                    elif channel.recv_stderr_ready():
                        data = channel.recv_stderr(4096).decode(errors="replace")
                        await websocket.send_text(json.dumps({"output": data}))
                    else:
                        await asyncio.sleep(0.05)
                except Exception:
                    break

        read_task = asyncio.create_task(read_ssh())

        try:
            while True:
                msg = await websocket.receive_text()
                data = json.loads(msg)

                if "input" in data:
                    channel.send(data["input"])
                elif "resize" in data:
                    w = data["resize"].get("cols", 120)
                    h = data["resize"].get("rows", 40)
                    channel.resize_pty(width=w, height=h)

        except WebSocketDisconnect:
            pass
        finally:
            read_task.cancel()
            channel.close()
            client.close()

    except Exception as e:
        await websocket.send_text(json.dumps({"error": str(e)}))
        await websocket.close()
