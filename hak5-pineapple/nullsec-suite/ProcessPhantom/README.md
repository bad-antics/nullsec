# 👻 ProcessPhantom

**Process Hollowing & Injection Detector**

Detect advanced process manipulation techniques including process hollowing, shared library injection, ptrace-based injection, and fileless malware. Deep /proc inspection for Linux systems.

## Features

- 🕵️ **Deleted executable detection** — Running from deleted binary = hollowed
- 💉 **Memory map analysis** — RWX regions, suspicious .so mappings, memfd usage
- 🔗 **LD_PRELOAD detection** — Per-process and system-wide preload analysis
- 🐛 **ptrace monitoring** — Detect active ptrace attachments
- 👻 **Hidden process detection** — Cross-reference /proc vs ps output
- 📁 **File descriptor analysis** — memfd, deleted libraries, /dev/shm executables
- 🌍 **Environment injection** — LD_PRELOAD, LD_LIBRARY_PATH, LD_AUDIT checks
- 🔐 **Binary integrity** — SHA256 hash of process executables

## Usage

```bash
# Scan all processes
sudo python3 processphantom.py --all --verbose

# Deep scan specific PID
sudo python3 processphantom.py -p 1234

# Check for hidden processes only
sudo python3 processphantom.py --hidden

# Custom output directory
sudo python3 processphantom.py --all -o /tmp/phantom-results/
```

## Detection Matrix

| Technique | Detection Method |
|-----------|-----------------|
| Process Hollowing | Deleted exe in /proc/PID/exe |
| Library Injection | Suspicious .so in /proc/PID/maps |
| ptrace Injection | TracerPid in /proc/PID/status |
| Fileless Malware | memfd FDs, anonymous executable regions |
| Rootkit Hiding | /proc vs ps PID discrepancy |
| LD_PRELOAD | Environment variable + /etc/ld.so.preload |

## Requirements

- Python 3.6+
- Root for full system scan
- Linux with /proc filesystem

## Part of [NullSec Security Suite](https://github.com/bad-antics/nullsec-suite)
