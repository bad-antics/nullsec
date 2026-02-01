# NullSec Payload: WordlistManager

<p align="center">
  <img src="https://img.shields.io/badge/NullSec-Pineapple%20Suite-00d4ff?style=for-the-badge" alt="NullSec">
  <img src="https://img.shields.io/badge/Category-Utility-9b59b6?style=for-the-badge" alt="Category">
  <img src="https://img.shields.io/badge/Version-1.0-2ecc71?style=for-the-badge" alt="Version">
  <img src="https://img.shields.io/badge/Platform-Pager-e74c3c?style=for-the-badge" alt="Platform">
</p>

## 📋 Description

**Wordlist management tools**

This payload is part of the NullSec Pineapple Suite, optimized for the Hak5 WiFi Pineapple Pager.

## ⚡ Features

- ✅ Download wordlists
- ✅ Combine lists
- ✅ Custom generation
- ✅ Size optimization

## 📦 Requirements

| Requirement | Details |
|-------------|---------|
| Device | WiFi Pineapple Pager |
| Libraries | `nullsec-lib.sh`, `nullsec-scanner.sh` |
| Shell | BusyBox ash (`/bin/sh`) |

## 🚀 Installation

### One-Line Install
```bash
ssh root@172.16.52.1 'mkdir -p /root/payloads/user/nullsec/WordlistManager && wget -qO /root/payloads/user/nullsec/WordlistManager/payload.sh https://raw.githubusercontent.com/bad-antics/nullsec-pineapple-suite/main/payloads/utility/WordlistManager/payload.sh'
```

### Manual Install
```bash
# Clone the suite
git clone https://github.com/bad-antics/nullsec-pineapple-suite.git

# Copy to device
scp nullsec-pineapple-suite/payloads/utility/WordlistManager/payload.sh \
    root@172.16.52.1:/root/payloads/user/nullsec/WordlistManager/
```

### Full Suite Install
```bash
wget -qO- https://raw.githubusercontent.com/bad-antics/nullsec-pineapple-suite/main/install.sh | sh
```

## 📖 Usage

### Standard Execution
```
Dashboard → Payloads → User → nullsec → WordlistManager → Run
```

### Targeted Execution (from Recon)
```
Dashboard → Recon → [Select Target] → Payloads → NullSec-WordlistManager
```

When running as a targeted payload, these variables are automatically set:
- `TARGET_BSSID` - Target AP MAC address
- `TARGET_SSID` - Target network name
- `TARGET_CHANNEL` - Target channel
- `TARGET_CLIENT_MAC` - Target client MAC (client targeted)

### Command Line
```bash
# SSH to Pager
ssh root@172.16.52.1

# Run directly
/root/payloads/user/nullsec/WordlistManager/payload.sh [options]
```

## 📁 Output Location

```
/root/loot/WordlistManager/
├── wordlistmanager_YYYYMMDD_HHMMSS.log    # Execution log
└── [captured data files]             # Payload-specific output
```

## 🔧 Configuration

Edit the payload script to customize:
```bash
vim /root/payloads/user/nullsec/WordlistManager/payload.sh
```

Common configuration options are at the top of the script.

## 🛡️ Targeted Payload Wrapper

For use in Recon menus, the targeted wrapper is auto-created:
```
/root/payloads/recon/access_point/NullSec-WordlistManager/payload.sh
/root/payloads/recon/client/NullSec-WordlistManager/payload.sh
```

## ⚠️ Disclaimer

> **WARNING:** This tool is provided for **educational and authorized penetration testing purposes only**.
> 
> - Unauthorized access to computer networks is illegal
> - Always obtain proper written authorization before testing
> - The authors assume no liability for misuse
> - Use responsibly and ethically

## 📜 License

MIT License - See [LICENSE](../../../LICENSE)

## 👤 Author

**bad-antics** | [GitHub](https://github.com/bad-antics)

---

<p align="center">
  <i>Part of the <a href="https://github.com/bad-antics/nullsec-pineapple-suite">NullSec Pineapple Suite</a></i>
  <br><br>
  <b>🔓 NullSec</b> - <i>Hacking the planet, one pineapple at a time</i>
</p>
