# 👻 nullsec-wraith
**Ghost Network Packets — Spectral Traffic Analysis**

Crafts wraith packets for educational analysis, generates traffic patterns (heartbeat, exfil, scan, ghost), and scans for spectral listeners.

## ⚡ Quick Start
```bash
wraith craft --dst 10.0.0.1 --port 443    # Craft and analyze a wraith packet
wraith traffic --pattern exfil --count 10  # Generate exfil traffic pattern
wraith haunt --target 127.0.0.1            # Scan for ghost listeners
wraith map                                 # Map the spectral network realm
```
## 📄 License
MIT — [bad-antics](https://github.com/bad-antics)
