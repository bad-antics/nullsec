<div align="center">

# 🔥 NullSec Payload: Phantom

**Ghost AP operations**

![Category](https://img.shields.io/badge/category-stealth-blue)
![Platform](https://img.shields.io/badge/platform-WiFi%20Pineapple%20Pager-red)
![Version](https://img.shields.io/badge/version-1.0-green)

</div>

---

## 📖 Description

Ghost AP operations. This payload is part of the NullSec Pineapple Suite - the ultimate payload collection for WiFi Pineapple Pager.

## ✨ Features

- ✅ Ephemeral AP
- ✅ Quick spawn
- ✅ Auto-destruct
- ✅ Trace removal

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
wget https://raw.githubusercontent.com/bad-antics/nullsec-pineapple-suite/main/payloads/stealth/Phantom/payload.sh

# Upload to Pager
scp payload.sh root@172.16.42.1:/root/payloads/user/nullsec/Phantom/
```

## 📱 Usage

### From Pager UI
1. Navigate to **Dashboard** → **Payloads**
2. Go to **User** → **nullsec**
3. Select **Phantom**
4. Configure options and run

### From Terminal
```bash
ssh root@172.16.42.1
/root/payloads/user/nullsec/Phantom/payload.sh [options]
```

### As Targeted Payload (Recon)
1. **Recon** → Start scan
2. Select target AP or Client
3. Choose **NullSec-Phantom** from payload menu
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
/root/loot/phantom/
├── phantom_YYYYMMDD_HHMMSS.log
└── captures/
```

## 🔧 Configuration

Edit `/root/payloads/library/nullsec-lib.sh` for global settings, or modify the payload script directly for Phantom-specific options.

## ⚠️ Disclaimer

```
This payload is provided for EDUCATIONAL and AUTHORIZED PENETRATION TESTING
purposes only. Unauthorized access to computer networks is ILLEGAL.
Always obtain proper authorization before use.
```

## 🔗 Related Payloads

Other stealth payloads you might like:

- [Specter](Specter_README.md)
- [WaveRider](WaveRider_README.md)
- [GhostNetwork](GhostNetwork_README.md)
- [Wraith](Wraith_README.md)

## 📜 License

MIT License - Part of [NullSec Pineapple Suite](https://github.com/bad-antics/nullsec-pineapple-suite)

## 👤 Author

**bad-antics** - [GitHub](https://github.com/bad-antics)

---

<div align="center">

**⭐ Star the [main repo](https://github.com/bad-antics/nullsec-pineapple-suite) if you find this useful! ⭐**

Made with 💀 by NullSec Team

</div>
