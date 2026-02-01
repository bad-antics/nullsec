<div align="center">

# 🔥 NullSec Payload: Honeypot

**Decoy AP with full logging**

![Category](https://img.shields.io/badge/category-social-blue)
![Platform](https://img.shields.io/badge/platform-WiFi%20Pineapple%20Pager-red)
![Version](https://img.shields.io/badge/version-1.0-green)

</div>

---

## 📖 Description

Decoy AP with full logging. This payload is part of the NullSec Pineapple Suite - the ultimate payload collection for WiFi Pineapple Pager.

## ✨ Features

- ✅ Weak password bait
- ✅ Connection logging
- ✅ Attack detection
- ✅ Counter-intel

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
wget https://raw.githubusercontent.com/bad-antics/nullsec-pineapple-suite/main/payloads/social/Honeypot/payload.sh

# Upload to Pager
scp payload.sh root@172.16.42.1:/root/payloads/user/nullsec/Honeypot/
```

## 📱 Usage

### From Pager UI
1. Navigate to **Dashboard** → **Payloads**
2. Go to **User** → **nullsec**
3. Select **Honeypot**
4. Configure options and run

### From Terminal
```bash
ssh root@172.16.42.1
/root/payloads/user/nullsec/Honeypot/payload.sh [options]
```

### As Targeted Payload (Recon)
1. **Recon** → Start scan
2. Select target AP or Client
3. Choose **NullSec-Honeypot** from payload menu
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
/root/loot/honeypot/
├── honeypot_YYYYMMDD_HHMMSS.log
└── captures/
```

## 🔧 Configuration

Edit `/root/payloads/library/nullsec-lib.sh` for global settings, or modify the payload script directly for Honeypot-specific options.

## ⚠️ Disclaimer

```
This payload is provided for EDUCATIONAL and AUTHORIZED PENETRATION TESTING
purposes only. Unauthorized access to computer networks is ILLEGAL.
Always obtain proper authorization before use.
```

## 🔗 Related Payloads

Other social payloads you might like:

- [NullSecPortal](NullSecPortal_README.md)
- [CoffeeShopAttack](CoffeeShopAttack_README.md)
- [PortalMaster](PortalMaster_README.md)
- [FakeUpdate](FakeUpdate_README.md)
- [NullSecDeface](NullSecDeface_README.md)

## 📜 License

MIT License - Part of [NullSec Pineapple Suite](https://github.com/bad-antics/nullsec-pineapple-suite)

## 👤 Author

**bad-antics** - [GitHub](https://github.com/bad-antics)

---

<div align="center">

**⭐ Star the [main repo](https://github.com/bad-antics/nullsec-pineapple-suite) if you find this useful! ⭐**

Made with 💀 by NullSec Team

</div>
