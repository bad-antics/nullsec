# 🧞 nullsec-djinn — Container Escape Surface Analyzer

Part of the **nullsec freakshow** security toolkit.

## What It Does

Djinn analyzes container isolation boundaries and identifies escape vectors.
The djinn is trapped in the lamp — but it always knows the way out.

## Commands

| Command | Description |
|---------|-------------|
| `djinn lamp` | Full container escape surface assessment |
| `djinn wish` | Check Linux capabilities (the djinn's powers) |
| `djinn smoke` | Check namespace isolation (where the smoke leaks) |

## Checks Performed

- **Container Detection** — Docker, Podman, Kubernetes, LXC
- **Docker Socket Access** — writable socket = full escape
- **Privileged Mode** — all capabilities = game over
- **Sensitive Mounts** — host paths mounted into container
- **PID/Network Namespace** — host namespace sharing
- **Capability Audit** — dangerous caps (SYS_ADMIN, SYS_PTRACE, NET_RAW, etc.)
- **Namespace Isolation** — verifies proper namespace boundaries

## Install

```bash
pip install -e nullsec-djinn/
```

## License

MIT — bad-antics / nullsec 2026
