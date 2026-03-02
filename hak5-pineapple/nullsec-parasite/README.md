# 🦠 nullsec-parasite
**Dependency Infection Analyzer — Supply Chain Parasite Detection**

Scans requirements.txt and package.json for parasitic dependencies, generates typosquat variants, and detects supply chain infection vectors.

## ⚡ Quick Start
```bash
parasite scan requirements.txt     # Scan pip dependencies
parasite scan package.json         # Scan npm dependencies
parasite typosquat requests        # Generate typosquat variants
parasite installed                 # Scan installed pip packages
```
## 📄 License
MIT — [bad-antics](https://github.com/bad-antics)
