# 🦌 nullsec-wendigo
**Resource Devourer Detector — Hunt the Hungry Processes**

Finds processes that devour CPU, memory, and file descriptors. Monitors system vitals and detects resource exhaustion attacks.

## ⚡ Quick Start
```bash
wendigo cpu --threshold 10      # Hunt CPU devourers
wendigo memory --threshold 100  # Hunt memory devourers
wendigo fds --threshold 50      # Hunt FD hoarders
wendigo vitals                  # System health check
```
## 📄 License
MIT — [bad-antics](https://github.com/bad-antics)
