# 🐳 ContainerEscape

**Container Escape & Breakout Detector**

Audit Docker/Podman containers and host configuration for escape vectors, misconfigurations, and security weaknesses.

## Features

- 🔓 **Privileged mode detection** — Flag --privileged containers
- ⚡ **Capability analysis** — Audit dangerous caps (SYS_ADMIN, SYS_PTRACE, etc.)
- 📁 **Mount audit** — Detect docker.sock, /proc, /sys, host root mounts
- 🌐 **Network namespace check** — Flag host network mode
- 🔒 **Security profile audit** — Seccomp, AppArmor, SELinux status
- 👤 **Root user detection** — Flag containers running as root
- 🔑 **Secret detection** — Find passwords/tokens in environment variables
- 🖥️ **Host audit** — Socket permissions, daemon config, kernel CVEs

## Usage

```bash
# Audit all containers + host
sudo python3 containerescape.py --all --verbose

# Audit specific container
sudo python3 containerescape.py -c my-container

# Host-only audit
sudo python3 containerescape.py --host-only

# Use podman instead of docker
sudo python3 containerescape.py --all -r podman
```

## Escape Vectors Detected

| Vector | Severity | Description |
|--------|----------|-------------|
| docker.sock mount | Critical | Full Docker API = instant escape |
| --privileged | Critical | All capabilities + all devices |
| SYS_ADMIN cap | Critical | Mount, namespace access |
| SYS_PTRACE cap | Critical | Process injection to host |
| Host PID namespace | Critical | See/signal host processes |
| Host network | High | Full host network access |
| Seccomp disabled | High | All syscalls permitted |
| Running as root | Medium | No user isolation |

## Requirements

- Python 3.6+
- Docker or Podman installed
- Root recommended for full audit

## Part of [NullSec Security Suite](https://github.com/bad-antics/nullsec-suite)
