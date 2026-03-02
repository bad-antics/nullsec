# 🐟 nullsec-lamprey
**Dependency Infection Analyzer — Supply Chain Lamprey Detection**

Scans requirements.txt and package.json for parasitic dependencies, generates typosquat variants, and detects supply chain infection vectors.

## ⚡ Quick Start
```bash
lamprey scan requirements.txt     # Scan pip dependencies
lamprey scan package.json         # Scan npm dependencies
lamprey typosquat requests        # Generate typosquat variants
lamprey installed                 # Scan installed pip packages
```
## 📄 License
MIT — [bad-antics](https://github.com/bad-antics)
