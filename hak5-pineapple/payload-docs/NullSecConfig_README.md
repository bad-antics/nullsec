<div align="center">

# 🔥 NullSec Payload: NullSecConfig

**Configure NullSec suite settings**

![Category](https://img.shields.io/badge/category-utility-blue)
![Platform](https://img.shields.io/badge/platform-WiFi%20Pineapple%20Pager-red)
![Version](https://img.shields.io/badge/version-1.0-green)

</div>

---

## 📖 Description

Configure NullSec suite settings. This payload is part of the NullSec Pineapple Suite - the ultimate payload collection for WiFi Pineapple Pager.

## ✨ Features

- ✅ Preference management
- ✅ Default targets
- ✅ Logging options
- ✅ Theme settings

## 📋 Requirements

- WiFi Pineapple Pager
- Firmware 1.0+
- NullSec library (included in suite)

## 🚀 Installation

### Via NullSec Suite (Recommended)
```bash
# Install full suite
git clone https://github.com/bad-antics/nullsec-pineapple-suite.git
cd nullsec-pineapple-suite
./install.sh
```

### Standalone Installation
```bash
# Download payload
wget https://raw.githubusercontent.com/bad-antics/nullsec-pineapple-suite/main/payloads/utility/NullSecConfig/payload.sh

# Upload to Pager
scp payload.sh root@172.16.42.1:/root/payloads/user/nullsec/NullSecConfig/
```

## 📱 Usage

### From Pager UI
1. Navigate to **Dashboard** → **Payloads**
2. Go to **User** → **nullsec**
3. Select **NullSecConfig**
4. Configure options and run

### From Terminal
```bash
ssh root@172.16.42.1
/root/payloads/user/nullsec/NullSecConfig/payload.sh [options]
```

### As Targeted Payload (Recon)
1. **Recon** → Start scan
2. Select target AP or Client
3. Choose **NullSec-NullSecConfig** from payload menu
4. Target info auto-injected!

## ⚙️ Options

| Option | Description | Default |
|--------|-------------|---------|
| `-h` | Show help | - |
| `-t` | Target BSSID/MAC | Auto (from Recon) |
| `-c` | Channel | Auto-detect |
| `-v` | Verbose output | Off |

## 📂 Output

Logs and captured data saved to:
```
/root/loot/nullsecconfig/
├── nullsecconfig_YYYYMMDD_HHMMSS.log
└── captures/
```

## 🔧 Configuration

Edit `/root/payloads/library/nullsec-lib.sh` for global settings, or modify the payload script directly for NullSecConfig-specific options.

## ⚠️ Disclaimer

```
This payload is provided for EDUCATIONAL and AUTHORIZED PENETRATION TESTING
purposes only. Unauthorized access to computer networks is ILLEGAL.
Always obtain proper authorization before use.
```

## 🔗 Related Payloads

Other utility payloads you might like:

- [BootOptimizer](BootOptimizer_README.md)
- [Reaper](Reaper_README.md)
- [RangeExtender](RangeExtender_README.md)
- [WordlistManager](WordlistManager_README.md)
- [WiFiAudit](WiFiAudit_README.md)

## 📜 License

MIT License - Part of [NullSec Pineapple Suite](https://github.com/bad-antics/nullsec-pineapple-suite)

## 👤 Author

**bad-antics** - [GitHub](https://github.com/bad-antics)

---

<div align="center">

**⭐ Star the [main repo](https://github.com/bad-antics/nullsec-pineapple-suite) if you find this useful! ⭐**

Made with 💀 by NullSec Team

</div>
