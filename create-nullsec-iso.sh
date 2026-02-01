#!/bin/bash
#
# NullSec Linux - System ISO Creator
# Creates a bootable ISO from the current running system
#

set -e

RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[1;35m'
NC='\033[0m'

ISO_NAME="nullsec-linux-1.0-amd64.iso"
ISO_DIR="/home/antics/nullsec-iso"
WORK_DIR="$ISO_DIR/build"

echo -e "${RED}"
cat << "BANNER"
====
|                                                                       |
|   ███==   ██==██==   ██==██==     ██==     ███████==███████== ██████==        |
|   ████==  ██|██|   ██|██|     ██|     ██====██====██====        |
|   ██==██== ██|██|   ██|██|     ██|     ███████==█████==  ██|             |
|   ██|==██==██|██|   ██|██|     ██|     ==██|██====  ██|             |
|   ██| ==████|==██████====███████==███████==███████|███████====██████==        |
|   ====  ==== ==== ================ ====        |
|                                                                       |
|              S Y S T E M   I S O   C R E A T O R                     |
|                                                                       |
====
BANNER
echo -e "${NC}"

echo -e "${CYAN}[*] Creating NullSec Linux 1.0 (void) ISO${NC}"
echo -e "${CYAN}[*] Output: $ISO_DIR/$ISO_NAME${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[!] Please run as root${NC}"
    exit 1
fi

# Check free space
FREE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
echo -e "${CYAN}[*] Available disk space: ${FREE_SPACE}GB${NC}"
if [ "$FREE_SPACE" -lt 15 ]; then
    echo -e "${RED}[!] Need at least 15GB free space${NC}"
    exit 1
fi

# Clean previous builds
echo -e "${CYAN}[*] Cleaning previous builds...${NC}"
rm -rf "$WORK_DIR" 2>/dev/null || true
mkdir -p "$WORK_DIR"/{squashfs,iso/{live,isolinux,boot/grub}}
mkdir -p "$ISO_DIR"

# ============================================================================
# Step 1: Create filesystem snapshot
# ============================================================================
echo -e "${GREEN}[+] Step 1/5: Creating filesystem snapshot...${NC}"
echo -e "${YELLOW}    This will take 10-20 minutes...${NC}"

# Create exclusion list
cat > /tmp/exclude-list.txt << 'EXCLUDE'
/proc
/sys
/dev
/run
/tmp
/mnt
/media
/lost+found
/home/*/.cache
/home/*/.local/share/Trash
/var/cache/apt/archives
/var/tmp
/swapfile
/home/antics/nullsec-iso
/home/antics/nullsec/logs
EXCLUDE

# Copy system using rsync
rsync -aAXv --info=progress2 \
    --exclude-from=/tmp/exclude-list.txt \
    / "$WORK_DIR/squashfs/" 2>&1 | grep -E "^sending|to-check|%" || true

# Create required directories
mkdir -p "$WORK_DIR/squashfs"/{proc,sys,dev,run,tmp,mnt,media}

echo -e "${GREEN}    ✓ Filesystem snapshot complete${NC}"

# ============================================================================
# Step 2: Configure live boot
# ============================================================================
echo -e "${GREEN}[+] Step 2/5: Configuring live boot...${NC}"

# Create live boot hook
cat > "$WORK_DIR/squashfs/etc/rc.local" << 'RCLOCAL'
#!/bin/bash
# NullSec Linux Live Boot Configuration
export NULLSEC_LIVE=1
export NULLSEC_HOME=/opt/nullsec
export PATH="$PATH:/opt/nullsec"

# Set up nullsec in live mode
if [ -d /opt/nullsec ]; then
    chmod +x /opt/nullsec/*.py /opt/nullsec/*.sh 2>/dev/null
fi

echo "NullSec Linux 1.0 (void) - Live Mode Active" > /tmp/nullsec-live.flag
exit 0
RCLOCAL
chmod +x "$WORK_DIR/squashfs/etc/rc.local"

echo -e "${GREEN}    ✓ Live boot configured${NC}"

# ============================================================================
# Step 3: Create SquashFS
# ============================================================================
echo -e "${GREEN}[+] Step 3/5: Creating compressed filesystem...${NC}"
echo -e "${YELLOW}    This will take 15-30 minutes...${NC}"

mksquashfs "$WORK_DIR/squashfs" "$WORK_DIR/iso/live/filesystem.squashfs" \
    -comp xz -b 1M -Xdict-size 100% \
    -e boot/grub -e boot/efi \
    -info 2>&1 | tail -5

SQUASH_SIZE=$(du -h "$WORK_DIR/iso/live/filesystem.squashfs" | cut -f1)
echo -e "${GREEN}    ✓ SquashFS created: $SQUASH_SIZE${NC}"

# ============================================================================
# Step 4: Set up boot loader
# ============================================================================
echo -e "${GREEN}[+] Step 4/5: Setting up boot loader...${NC}"

# Copy kernel and initrd
KERNEL=$(ls "$WORK_DIR/squashfs/boot/vmlinuz-"* 2>/dev/null | tail -1)
INITRD=$(ls "$WORK_DIR/squashfs/boot/initrd.img-"* 2>/dev/null | tail -1)

if [ -z "$KERNEL" ]; then
    KERNEL="$WORK_DIR/squashfs/boot/vmlinuz"
fi
if [ -z "$INITRD" ]; then
    INITRD="$WORK_DIR/squashfs/boot/initrd.img"
fi

cp "$KERNEL" "$WORK_DIR/iso/live/vmlinuz"
cp "$INITRD" "$WORK_DIR/iso/live/initrd"

# Copy ISOLINUX files
cp /usr/lib/ISOLINUX/isolinux.bin "$WORK_DIR/iso/isolinux/"
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 "$WORK_DIR/iso/isolinux/"
cp /usr/lib/syslinux/modules/bios/libcom32.c32 "$WORK_DIR/iso/isolinux/"
cp /usr/lib/syslinux/modules/bios/libutil.c32 "$WORK_DIR/iso/isolinux/"
cp /usr/lib/syslinux/modules/bios/vesamenu.c32 "$WORK_DIR/iso/isolinux/"

# Create ISOLINUX config
cat > "$WORK_DIR/iso/isolinux/isolinux.cfg" << 'ISOLINUX'
UI vesamenu.c32
TIMEOUT 50
PROMPT 0

MENU TITLE NullSec Linux 1.0 (void)
MENU BACKGROUND #000000
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #c000ff00 #00000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
MENU COLOR msg07        37;40   #90ffffff #a0000000 std
MENU COLOR tabmsg       31;40   #30ffffff #00000000 std

LABEL live
  MENU LABEL ^NullSec Linux Live
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live quiet splash

LABEL live-failsafe
  MENU LABEL NullSec Linux (^Failsafe)
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live nomodeset

LABEL live-forensics
  MENU LABEL NullSec Linux (^Forensics - No Mount)
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live noswap noautomount

LABEL memtest
  MENU LABEL ^Memory Test
  KERNEL /live/memtest
ISOLINUX

# Create GRUB config for UEFI
cat > "$WORK_DIR/iso/boot/grub/grub.cfg" << 'GRUB'
set timeout=5
set default=0

menuentry "NullSec Linux Live" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd
}

menuentry "NullSec Linux (Failsafe)" {
    linux /live/vmlinuz boot=live nomodeset
    initrd /live/initrd
}

menuentry "NullSec Linux (Forensics)" {
    linux /live/vmlinuz boot=live noswap noautomount
    initrd /live/initrd
}
GRUB

# Create EFI boot image
mkdir -p "$WORK_DIR/iso/EFI/boot"
grub-mkimage -o "$WORK_DIR/iso/EFI/boot/bootx64.efi" -O x86_64-efi -p /boot/grub \
    part_gpt part_msdos fat iso9660 normal boot linux configfile loopback chain \
    efifwsetup efi_gop efi_uga ls search search_label search_fs_uuid search_fs_file \
    gfxterm gfxterm_background gfxterm_menu test all_video loadenv exfat ext2 2>/dev/null || \
    cp /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi "$WORK_DIR/iso/EFI/boot/bootx64.efi" 2>/dev/null || true

# Create EFI image for ISO
dd if=/dev/zero of="$WORK_DIR/iso/boot/grub/efi.img" bs=1M count=10 2>/dev/null
mkfs.vfat "$WORK_DIR/iso/boot/grub/efi.img" 2>/dev/null
mmd -i "$WORK_DIR/iso/boot/grub/efi.img" ::/EFI ::/EFI/boot 2>/dev/null || true
mcopy -i "$WORK_DIR/iso/boot/grub/efi.img" "$WORK_DIR/iso/EFI/boot/bootx64.efi" ::/EFI/boot/ 2>/dev/null || true

echo -e "${GREEN}    ✓ Boot loader configured${NC}"

# ============================================================================
# Step 5: Create ISO
# ============================================================================
echo -e "${GREEN}[+] Step 5/5: Creating ISO image...${NC}"

cd "$WORK_DIR/iso"

xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "NULLSEC_LINUX" \
    -eltorito-boot isolinux/isolinux.bin \
    -eltorito-catalog isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -output "$ISO_DIR/$ISO_NAME" \
    . 2>&1 | tail -10

# ============================================================================
# Complete
# ============================================================================
ISO_SIZE=$(du -h "$ISO_DIR/$ISO_NAME" | cut -f1)

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  ✓ NullSec Linux ISO Created Successfully!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "${CYAN}  File: $ISO_DIR/$ISO_NAME${NC}"
echo -e "${CYAN}  Size: $ISO_SIZE${NC}"
echo ""
echo -e "${MAGENTA}  Boot Modes:${NC}"
echo "    • NullSec Linux Live (default)"
echo "    • Failsafe Mode"
echo "    • Forensics Mode (no auto-mount)"
echo ""
echo -e "${MAGENTA}  Features Included:${NC}"
echo "    ✓ NullSec Framework v2.0"
echo "    ✓ 188 attack modules"
echo "    ✓ Enhanced launcher (14 browse modes)"
echo "    ✓ Desktop integration"
echo "    ✓ Resource library"
echo "    ✓ Log encryption system"
echo ""
echo -e "${YELLOW}  Copy to USB:${NC}"
echo "    sudo dd if=$ISO_DIR/$ISO_NAME of=/dev/sdX bs=4M status=progress"
echo ""
echo -e "${YELLOW}  Or use the copy script:${NC}"
echo "    sudo bash /home/antics/nullsec/copy-iso-to-lulzboat.sh"
echo ""

# Cleanup
rm -rf "$WORK_DIR"
echo -e "${GREEN}  ✓ Build directory cleaned up${NC}"
