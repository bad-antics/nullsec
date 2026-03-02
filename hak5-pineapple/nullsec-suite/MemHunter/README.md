# 🧠 MemHunter

**Memory Forensics & Artifact Extractor**

Analyze live process memory for credentials, encryption keys, shellcode, network artifacts, and indicators of compromise. Pure Python, no Volatility required.

## Features

- 🔑 **Credential extraction** — Passwords, JWT tokens, AWS keys, SSH keys, API tokens
- 🐛 **Shellcode detection** — NOP sleds, syscall instructions, msfvenom patterns, egg hunters
- 🌐 **Network artifacts** — URLs, IPs, domains, email addresses, MAC addresses
- 📊 **Entropy analysis** — Detect encrypted/packed memory regions
- 💉 **Heap spray detection** — Repeated pattern analysis in heap segments
- 📜 **String extraction** — Context-aware strings dump with region attribution
- 🔍 **Per-region analysis** — Maps regions to findings via /proc/PID/maps

## Usage

```bash
# Scan specific process
sudo python3 memhunter.py -p 1234 --verbose

# Scan all accessible processes
sudo python3 memhunter.py --all

# Extract strings from process
sudo python3 memhunter.py --strings 1234

# Custom min string length
sudo python3 memhunter.py --strings 1234 --min-string-len 10
```

## Detection Patterns

| Category | Patterns |
|----------|----------|
| Passwords | password=, passwd=, pwd= fields |
| Tokens | JWT (eyJ...), Bearer tokens, session cookies |
| Cloud | AWS access keys (AKIA...), AWS secrets |
| Keys | RSA/EC/DSA private keys, SSH keys |
| Code | GitHub tokens (ghp_/ghs_) |
| Shellcode | NOP sleds, int80, syscall, /bin/sh, msfvenom |
| Heap Spray | >70% repeated 4-byte patterns in heap |

## How It Works

1. Reads `/proc/PID/maps` to enumerate memory regions
2. Reads process memory via `/proc/PID/mem`
3. Applies regex patterns for credential/artifact extraction
4. Calculates Shannon entropy per region
5. Checks heap for spray patterns
6. Scans for known shellcode signatures

## Requirements

- Python 3.6+
- Root or same-user for memory access
- Linux with /proc filesystem

## Part of [NullSec Security Suite](https://github.com/bad-antics/nullsec-suite)
