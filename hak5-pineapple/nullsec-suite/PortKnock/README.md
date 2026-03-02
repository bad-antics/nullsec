# 🔌 PortKnock

**Cryptographic Port Knocking Daemon & Client**

Secure your services behind invisible doors. PortKnock implements HMAC-SHA256 time-based knock sequences and Single Packet Authorization (SPA) to hide services from port scanners.

## Features

- 🔐 **HMAC-SHA256 time-based knock sequences** — Knock ports change every 30 seconds
- 📦 **Single Packet Authorization (SPA)** — One encrypted UDP packet opens the door
- 🔥 **Dynamic iptables rules** — Auto-opens and auto-closes with configurable timeout
- 🎭 **Static mode** — Traditional fixed-sequence knocking also supported
- ⏱️ **Auto-cleanup** — Rules automatically expire after configurable duration
- 🛡️ **Brute-force protection** — Max attempts before temporary ban

## Usage

### Server Mode
```bash
# Generate config file
sudo python3 portknock.py server --genconfig /etc/portknock.json

# Start server with crypto knocking
sudo python3 portknock.py server -c /etc/portknock.json

# Start with SPA mode
sudo python3 portknock.py server -c /etc/portknock.json --spa
```

### Client Mode
```bash
# Crypto knock (auto-generates time-based sequence)
python3 portknock.py client 192.168.1.100 -k "your-shared-secret"

# Static knock
python3 portknock.py client 192.168.1.100 -k "key" --static 7000,8000,9000

# SPA mode
python3 portknock.py client 192.168.1.100 -k "your-shared-secret" --spa
```

## How It Works

1. **Server** listens for SYN packets on all ports using a raw socket
2. **Client** sends TCP SYN packets to calculated ports in sequence
3. Server validates the HMAC-SHA256 knock sequence against the shared secret
4. On valid knock: iptables rule inserted for client IP → protected port
5. Rule auto-expires after `open_duration` seconds

## Requirements

- Python 3.6+
- Root privileges (raw sockets, iptables)
- No external dependencies

## Part of [NullSec Security Suite](https://github.com/bad-antics/nullsec-suite)
