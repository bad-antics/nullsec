# NullSec Pineapple Pager - System Audit Report
**Date:** January 31, 2026  
**Device:** WiFi Pineapple Pager  
**Firmware:** Linux 6.6.86 (OpenWrt-based)

---

## 📊 Hardware Specifications

| Component | Specification |
|-----------|---------------|
| **CPU** | MIPS 24KEc V5.5 @ 385 BogoMIPS |
| **RAM** | 251 MB Total (128 MB Used, ~75 MB Available) |
| **Internal Flash** | 25 MB ROM (100% used - read-only) |
| **Overlay Storage** | 37.1 MB (3% used) |
| **SD Card** | 3.5 GB (2.1 GB Used = 63%) |
| **WiFi Chip 1** | MediaTek MT7628 (internal) |
| **WiFi Chip 2** | MediaTek MT7921AU (USB) |

---

## 💾 Storage Analysis

### SD Card Breakdown (`/mmc`)
| Directory | Size | Notes |
|-----------|------|-------|
| `/mmc/root/loot` | **2.0 GB** | ⚠️ CRITICAL - Needs cleanup |
| `/mmc/root/themes` | 48.5 MB | 11 themes installed |
| `/mmc/root/payloads` | 4.4 MB | User payloads |
| `/mmc/root/recon` | 3.8 MB | Recon database |
| `/mmc/nullsec` | 72 KB | NullSec libraries |

### Loot Folder Issues
| Subfolder | Size | Action |
|-----------|------|--------|
| `pcap/` | **2.0 GB** | 🔴 DELETE - Contains 1.9GB single capture |
| `archive/` | 28.1 MB | Review and archive |
| `handshakes/` | 144 KB | Keep - valuable |
| Others | <8 KB | Keep |

### Problem Files
```
/mmc/root/loot/pcap/pcap-2026-01-15T18:46+0000.pcap - 1.9 GB (!)
/mmc/root/loot/pcap/pcap-2026-01-29T08:08+0000.pcap - 78.2 MB
/mmc/root/loot/pcap/pcap-2025-12-31T20:51+0000.pcap - 1.0 MB
```

---

## 🚀 Boot Services Audit

### Enabled at Startup (by priority)
| Service | Priority | Purpose | Optimization |
|---------|----------|---------|--------------|
| sysfixtime | S00 | Fix system time | Keep |
| scheduler | S01 | Task scheduler | Keep |
| boot | S10 | Boot scripts | Keep |
| system | S10 | System init | Keep |
| mmc | S15 | SD card mount | Keep |
| mt7921 | S15 | External WiFi | Keep |
| dnsmasq | S19 | DHCP/DNS | Keep |
| firewall | S19 | iptables | Keep |
| network | S20 | Networking | Keep |
| pineapplepager | S50 | **Pager UI** | Optimize |
| sshd | S50 | SSH server | Keep |
| dbus | S60 | IPC | Review |
| bluetoothd | S62 | Bluetooth | **Disable if unused** |
| autossh | S80 | Auto SSH tunnels | **Disable if unused** |
| openvpn | S90 | VPN | **Disable if unused** |
| sysntpd | S98 | NTP time sync | Lower priority |

### Recommended Disables (for faster boot)
- `bluetoothd` - Rarely used, saves 2-3 seconds
- `autossh` - Only if using C2
- `openvpn` - Only if using VPN

---

## 📺 Boot Screen Configuration

### Current State
- **Theme:** `nullsec` (correctly set)
- **Boot Animation:** Uses theme's `boot_animation.json`
- **Location:** `/mmc/root/themes/nullsec/assets/boot_animation/`

### Boot Animation Files
```
init-1.png (3.7 KB) - Frame 1
init-2.png (10.7 KB) - Frame 2  
init-3.png (5.1 KB) - Frame 3
init-4.png (5.2 KB) - Frame 4
```

### Boot Sequence
1. **Kernel Boot** → Hak5 splash (hardcoded in firmware)
2. **Pager Init** → Theme boot_animation.json plays
3. **UI Ready** → Theme fully loads

**Note:** The initial Hak5 boot animation is in firmware (cannot change). The theme animation only shows during pager UI initialization.

---

## 🎨 Theme Storage (48.5 MB total)

| Theme | Size | Action |
|-------|------|--------|
| dedsec | 6.7 MB | Keep or remove |
| StarWars | 4.1 MB | Keep or remove |
| cambridge | 3.1 MB | Keep or remove |
| radar | 3.5 MB | Keep or remove |
| chromatic_trout | 2.9 MB | Keep or remove |
| finalfantasy | 2.4 MB | Keep or remove |
| **nullsec** | **2.3 MB** | **KEEP** |
| mayhem-red | 2.7 MB | Keep or remove |
| old-skool-green | 2.5 MB | Keep or remove |
| quake-n-page | 2.8 MB | Keep or remove |
| wargames | 2.5 MB | Keep or remove |

**Potential savings:** ~46 MB by removing unused themes

---

## 🔧 Optimization Recommendations

### Immediate Actions (Save ~2 GB)
1. **Delete old pcap files** - Recovers 2 GB
2. **Archive handshakes** - Already small, keep
3. **Clear recon.db if needed** - 3.8 MB

### Boot Speed Optimizations
1. Disable unused services (bluetooth, autossh, openvpn)
2. Reduce boot animation frames
3. Pre-compile Python bytecode

### Memory Optimizations
1. Lower scrollback buffers in UI
2. Disable verbose logging
3. Use tmpfs for temporary files

---

## 📋 NullSec Suite Status

### Payloads Installed
- **Location:** `/root/payloads/user/nullsec/`
- **Count:** 50 payloads
- **Status:** ✅ All uploaded and executable

### Libraries Installed
- **Location:** `/mmc/nullsec/lib/`
- **Files:**
  - `nullsec-lib.sh` (14 KB) - Core library
  - `nullsec-scanner.sh` (7 KB) - Target scanner

---

## 🎯 Action Items

### Priority 1 - Storage Cleanup
```bash
# Delete massive pcap files
rm /mmc/root/loot/pcap/pcap-2026-01-15*.pcap
rm /mmc/root/loot/pcap/pcap-2026-01-29*.pcap
```

### Priority 2 - Disable Unused Services  
```bash
# Disable bluetooth (if not using)
/etc/init.d/bluetoothd disable

# Disable autossh (if not using C2)
/etc/init.d/autossh disable

# Disable openvpn (if not using VPN)
/etc/init.d/openvpn disable
```

### Priority 3 - Remove Unused Themes
```bash
# Keep only nullsec theme
cd /mmc/root/themes
rm -rf StarWars cambridge chromatic_trout dedsec finalfantasy mayhem-red old-skool-green quake-n-page radar wargames
```

---

## 📈 Expected Improvements

| Metric | Before | After |
|--------|--------|-------|
| Storage Used | 2.1 GB (63%) | ~100 MB (3%) |
| Boot Time | ~25-30 sec | ~18-22 sec |
| Free RAM | 75 MB | ~90 MB |

---

*Report generated by NullSec Framework Audit Tool*
