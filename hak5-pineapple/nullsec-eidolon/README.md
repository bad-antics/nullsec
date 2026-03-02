# 👻 nullsec-eidolon
**Ghost Network Packets — Spectral Traffic Analysis**

Crafts eidolon packets for educational analysis, generates traffic patterns (heartbeat, exfil, scan, ghost), and scans for spectral listeners.

## ⚡ Quick Start
```bash
eidolon craft --dst 10.0.0.1 --port 443    # Craft and analyze an eidolon packet
eidolon traffic --pattern exfil --count 10  # Generate exfil traffic pattern
eidolon haunt --target 127.0.0.1            # Scan for ghost listeners
eidolon map                                 # Map the spectral network realm
```
## 📄 License
MIT — [bad-antics](https://github.com/bad-antics)
