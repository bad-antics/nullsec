# 👻 nullsec-banshee
**Log Scream Detector — The Banshee Hears All**

Detects panics, segfaults, auth failures, brute force, OOM kills, disk errors, and suspicious activity in log files and systemd journals.

## ⚡ Quick Start
```bash
banshee listen /var/log/syslog           # Listen to one file
banshee haunt /var/log                   # Haunt all log files
banshee journal --lines 1000             # Listen to journald
banshee scream /var/log/auth.log "root"  # Custom search
```
## 📄 License
MIT — [bad-antics](https://github.com/bad-antics)
