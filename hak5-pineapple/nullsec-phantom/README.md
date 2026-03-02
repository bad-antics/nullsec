# 👻 nullsec-phantom
**Ghost Network Packets — Spectral Traffic Analysis**

Crafts phantom packets for educational analysis, generates traffic patterns (heartbeat, exfil, scan, ghost), and scans for spectral listeners.

## ⚡ Quick Start
```bash
phantom craft --dst 10.0.0.1 --port 443    # Craft and analyze a phantom packet
phantom traffic --pattern exfil --count 10  # Generate exfil traffic pattern
phantom haunt --target 127.0.0.1            # Scan for ghost listeners
phantom map                                 # Map the spectral network realm
```
## 📄 License
MIT — [bad-antics](https://github.com/bad-antics)
