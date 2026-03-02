# 👻 nullsec-poltergeist
**Filesystem Chaos Agent — Anomaly Detection & Honeypots**

Detects filesystem anomalies (hidden executables, SUID binaries, world-writable files, escape symlinks), generates honeypot decoy filesystems, and creates directory fingerprints for tamper detection.

## ⚡ Quick Start
```bash
poltergeist haunt /tmp           # Find filesystem anomalies
poltergeist honeypot ./bait      # Generate honeypot files
poltergeist fingerprint /etc     # Fingerprint for change detection
```
## 📄 License
MIT — [bad-antics](https://github.com/bad-antics)
