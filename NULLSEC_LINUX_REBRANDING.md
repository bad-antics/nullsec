# NullSec Linux - Complete OS Rebranding Guide

Transform your ParrotOS installation into **NullSec Linux** - a fully customized offensive security platform with the NULLSEC Framework pre-installed.

---

## 🎯 What Gets Rebranded

### System Identification
- **OS Name**: ParrotOS → NullSec Linux 1.0
- **Codename**: echo → void  
- **Hostname**: parrot → nullsec-workstation
- **Terminal Title**: Parrot Terminal → NullSec Console
- **MOTD**: Custom NullSec ASCII art banner
- **Login Banner**: NullSec branding

### Desktop Environment
- MATE terminal profiles
- Desktop backgrounds config
- Application menu entries
- Panel/menu branding
- System tray icons

### Boot/System
- GRUB bootloader entries
- Plymouth boot splash (optional)
- Login manager branding
- System info commands

### Files Modified
```
/etc/os-release          → NullSec Linux identification
/etc/lsb-release         → LSB compliance info
/etc/hostname            → nullsec-workstation
/etc/hosts               → Updated hostname
/etc/motd                → NullSec ASCII banner
/etc/issue               → Pre-login banner
/etc/default/grub        → GRUB distributor name
~/.config/mate/*         → MATE desktop configs
```

---

## 🚀 Quick Start

### Step 1: Rebrand System

```bash
cd /home/antics/nullsec
sudo bash rebrand-to-nullsec-linux.sh
```

**What it does:**
- ✅ Backs up all original files
- ✅ Updates 99 system configuration files
- ✅ Changes OS identification
- ✅ Rebrands desktop environment
- ✅ Updates GRUB bootloader
- ✅ Creates new system commands (`nullsec-info`, `nullsec-fetch`)

**Time:** ~2 minutes

### Step 2: Update GRUB & Reboot

```bash
sudo update-grub
sudo reboot
```

### Step 3: Create ISO Image

```bash
cd /home/antics/nullsec
sudo bash create-nullsec-iso.sh
```

**What it does:**
- ✅ Installs ISO creation tools (squashfs, genisoimage, grub)
- ✅ Creates system snapshot
- ✅ Includes NULLSEC Framework in ISO
- ✅ Builds compressed SquashFS
- ✅ Generates bootable ISO with GRUB
- ✅ Creates MD5/SHA256 checksums

**Requirements:**
- 20GB free disk space
- 30-60 minutes processing time
- Root/sudo access

**Output:**
- ISO file: `/home/antics/nullsec-iso/nullsec-linux-1.0-amd64.iso`
- Size: ~3-5GB (compressed)

---

## 📦 What's Included in the ISO

### Pre-Installed Software
- **NULLSEC Framework v2.0** (185 attack modules)
- **NULLSEC AI v3.0** (12 local AI models)
- **NULLSEC Desktop** (GUI launcher)
- All Debian/Parrot security tools
- Ollama with 12 AI models (~73GB)

### Live Boot Features
- Auto-detects live environment
- NULLSEC Framework available at `/opt/nullsec`
- Full desktop environment (MATE)
- Network configuration tools
- Persistence option (if written to USB)

### Default Credentials
```
Username: antics
Password: nullsec
```

---

## 🛠️ New System Commands

After rebranding, you'll have these new commands:

### `nullsec-info`
Display comprehensive system information:
```bash
nullsec-info
```
Output:
```
==================================
    NullSec Linux System Info
==================================
Distribution: NullSec Linux 1.0
Codename: void
Kernel: 6.4.0-parrot-amd64
Architecture: x86_64
Hostname: nullsec-workstation
Uptime: 2 hours, 34 minutes

NULLSEC Framework: /home/antics/nullsec
AI Models: 12 installed
Attack Modules: 185
==================================
```

### `nullsec-fetch`
Display system stats with ASCII logo (neofetch alternative):
```bash
nullsec-fetch
```

---

## 💿 Using the ISO

### Test with QEMU
```bash
qemu-system-x86_64 -cdrom /home/antics/nullsec-iso/nullsec-linux-1.0-amd64.iso -m 4096
```

### Write to USB Drive
```bash
# Find USB device
lsblk

# Write ISO (replace sdX with your USB device)
sudo dd if=/home/antics/nullsec-iso/nullsec-linux-1.0-amd64.iso \
        of=/dev/sdX \
        bs=4M \
        status=progress \
        conv=fsync

# Alternative: Use Etcher, Rufus, or Balena Etcher
```

### Burn to DVD
```bash
brasero /home/antics/nullsec-iso/nullsec-linux-1.0-amd64.iso
```

### Verify Integrity
```bash
cd /home/antics/nullsec-iso
md5sum -c nullsec-linux-1.0-amd64.iso.md5
sha256sum -c nullsec-linux-1.0-amd64.iso.sha256
```

---

## 🔄 Backup & Restore

### Backup Location
All original files are backed up to:
```
/home/antics/nullsec/parrot-backup-YYYYMMDD-HHMMSS/
```

### Restore Original Parrot Branding
```bash
BACKUP_DIR="/home/antics/nullsec/parrot-backup-YYYYMMDD-HHMMSS"

# Restore system files
sudo cp "$BACKUP_DIR/os-release.bak" /etc/os-release
sudo cp "$BACKUP_DIR/hostname.bak" /etc/hostname
sudo cp "$BACKUP_DIR/hosts.bak" /etc/hosts
sudo cp "$BACKUP_DIR/grub.bak" /etc/default/grub
sudo update-grub
sudo reboot
```

---

## 📊 System Requirements

### Rebranding Script
- Parrot Security OS 7.1 (or Debian-based)
- Sudo/root access
- 100MB free space for backups

### ISO Creation
- 20GB free disk space
- 4GB+ RAM (8GB recommended)
- Multi-core CPU (for faster compression)
- 30-60 minutes time

### ISO Boot Requirements
- 2GB+ RAM (4GB recommended)
- 64-bit processor
- 10GB+ disk (for installation)
- UEFI or Legacy BIOS boot

---

## 🎨 Customization Options

### Change OS Name/Version
Edit `/home/antics/nullsec/rebrand-to-nullsec-linux.sh` and modify:
```bash
PRETTY_NAME="NullSec Linux 2.0 (custom)"
VERSION_ID="2.0"
VERSION_CODENAME=custom
```

### Custom Hostname
```bash
sudo hostnamectl set-hostname your-custom-name
```

### Custom ASCII Art
Edit the MOTD section in the rebranding script to use your own ASCII art.

### Additional Software in ISO
Before running `create-nullsec-iso.sh`, install any additional packages:
```bash
sudo apt install <package-name>
```

---

## 🐛 Troubleshooting

### ISO Creation Fails - Not Enough Space
```bash
# Check free space
df -h /

# Clean up to free space
sudo apt clean
sudo apt autoclean
rm -rf ~/.cache/*
```

### ISO Won't Boot
- Verify checksum: `md5sum -c nullsec-linux-1.0-amd64.iso.md5`
- Try different USB writing tool (Etcher, Rufus)
- Check BIOS boot order
- Disable Secure Boot in UEFI

### GRUB Not Updated
```bash
sudo update-grub
sudo grub-install /dev/sda  # Replace sda with your boot disk
```

### Hostname Not Changed
```bash
sudo hostnamectl set-hostname nullsec-workstation
sudo systemctl restart systemd-hostnamed
```

---

## 📁 File Structure

```
/home/antics/nullsec/
├── rebrand-to-nullsec-linux.sh    # Main rebranding script
├── create-nullsec-iso.sh          # ISO creation script
├── NULLSEC_LINUX_REBRANDING.md    # This file
├── parrot-backup-*/               # Backup directories
└── nullsec-iso/                   # ISO output directory
    ├── nullsec-linux-1.0-amd64.iso
    ├── nullsec-linux-1.0-amd64.iso.md5
    ├── nullsec-linux-1.0-amd64.iso.sha256
    └── work/                      # Temporary build files
```

---

## ⚠️ Important Notes

1. **Package Updates**: The system keeps Parrot repositories for security updates
2. **Kernel**: Uses the same kernel as ParrotOS (6.4.0)
3. **Compatibility**: All Parrot/Debian packages remain compatible
4. **Networking**: Network configurations are preserved
5. **Users**: Existing users and permissions unchanged
6. **Data**: All user data remains intact

---

## 🔐 Security Considerations

### Live Boot Security
- Change default password immediately after installation
- Live boot has no persistence by default
- Sensitive operations should use encrypted volumes
- NULLSEC Framework configured for authorized testing only

### ISO Distribution
- Do not distribute with personal data/credentials
- Remove sensitive files before creating ISO
- Consider creating a separate clean user profile
- Add license/disclaimer documentation

---

## 📜 License & Disclaimer

**NullSec Linux** is a customized distribution based on ParrotOS and Debian.

**Warning**: This platform is designed for authorized security testing and research only. Unauthorized hacking is illegal. Users are responsible for complying with all applicable laws and regulations.

**Credits**:
- Based on ParrotOS (https://parrotsec.org)
- NULLSEC Framework by bad-antics
- Debian Project (https://debian.org)

---

## 🤝 Contributing

Want to improve NullSec Linux? Here's how:

1. Fork the repository
2. Create custom modules for NULLSEC Framework
3. Design better branding assets
4. Optimize ISO creation process
5. Submit pull requests

---

## 📞 Support

- GitHub: https://github.com/bad-antics/nullsec
- Issues: https://github.com/bad-antics/nullsec/issues
- Framework Docs: `/home/antics/nullsec/README.md`

---

**🚀 Ready to transform your system? Run the rebranding script now!**

```bash
cd /home/antics/nullsec && sudo bash rebrand-to-nullsec-linux.sh
```
