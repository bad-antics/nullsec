# NullSec Payload: IoTScanner

<p align="center">
  <img src="https://raw.githubusercontent.com/bad-antics/nullsec-pineapple-suite/main/assets/banner.png" alt="NullSec Banner" width="600">
</p>

<p align="center">
  <a href="#installation"><img src="https://img.shields.io/badge/Platform-WiFi%20Pineapple%20Pager-purple"></a>
  <a href="#license"><img src="https://img.shields.io/badge/License-MIT-green"></a>
  <a href="https://github.com/bad-antics"><img src="https://img.shields.io/badge/Author-bad--antics-cyan"></a>
  <img src="https://img.shields.io/badge/Category-recon-blue">
</p>

## 📝 Description

Discover and identify IoT devices

## ✨ Features

- Fully compatible with WiFi Pineapple Pager
- NullSec library integration
- Detailed logging to `/root/loot/iotscanner/`
- Clean exit handling
- Targeted payload support (use from Recon)

## 📋 Requirements

- WiFi Pineapple Pager
- NullSec libraries (`nullsec-lib.sh`, `nullsec-scanner.sh`)

## 🚀 Installation

### Quick Install
```bash
ssh root@172.16.52.1
mkdir -p /root/payloads/user/nullsec/IoTScanner
wget -O /root/payloads/user/nullsec/IoTScanner/payload.sh \
  https://raw.githubusercontent.com/bad-antics/nullsec-payload-iotscanner/main/payload.sh
chmod +x /root/payloads/user/nullsec/IoTScanner/payload.sh
```

### Via NullSec Suite
```bash
git clone https://github.com/bad-antics/nullsec-pineapple-suite
cd nullsec-pineapple-suite
./install.sh
```

## 📖 Usage

### From Pineapple UI
1. **Payloads** → **User** → **nullsec** → **IoTScanner**
2. Click **Run**

### As Targeted Payload
1. **Recon** → Start scan → Select target
2. **Payloads** → **NullSec-IoTScanner**

### Command Line
```bash
/root/payloads/user/nullsec/IoTScanner/payload.sh [options]
```

## ⚠️ Disclaimer

For **authorized penetration testing only**. Unauthorized access is illegal.

## 🔗 Part of NullSec Collection

[NullSec WiFi Pineapple Suite](https://github.com/bad-antics/nullsec-pineapple-suite) - 58+ payloads

## 📄 License

MIT License - [LICENSE](LICENSE)

---
<p align="center"><b>NullSec</b> - <i>Hacking the planet, one pineapple at a time</i> 🍍</p>
