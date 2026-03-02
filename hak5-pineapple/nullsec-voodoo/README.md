# 🪡 nullsec-voodoo
**Stick Pins In Process Memory — Live Memory Analysis**

Reads process memory maps, sticks pins (reads) at arbitrary addresses, extracts strings, and detects cursed memory regions (WX, anonymous executable, shellcode indicators).

## ⚡ Quick Start
```bash
voodoo map 1234              # View memory regions
voodoo pin 1234 0x7fff0000   # Read bytes at address
voodoo strings 1234          # Extract all strings
voodoo doll 1234             # Full process profile
```
## 📄 License
MIT — [bad-antics](https://github.com/bad-antics)
