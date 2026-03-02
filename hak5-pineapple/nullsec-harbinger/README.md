# 🔔 nullsec-harbinger
**Log Scream Detector — The Harbinger Hears All**

Detects panics, segfaults, auth failures, brute force, OOM kills, disk errors, and suspicious activity in log files and systemd journals.

## ⚡ Quick Start
```bash
harbinger listen /var/log/syslog           # Listen to one file
harbinger haunt /var/log                   # Haunt all log files
harbinger journal --lines 1000             # Listen to journald
harbinger scream /var/log/auth.log "root"  # Custom search
```
## 📄 License
MIT — [bad-antics](https://github.com/bad-antics)
