#!/bin/bash
#
# NullSec Pineapple Suite - Package Downloader
# Downloads OpenWrt packages for offline installation on WiFi Pineapple Pager
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_DIR="$SCRIPT_DIR/packages"

# OpenWrt URLs for Pineapple Pager (mipsel_24kc)
PKG_URL="https://downloads.openwrt.org/releases/24.10.1/packages/mipsel_24kc/packages"
BASE_URL="https://downloads.openwrt.org/releases/24.10.1/packages/mipsel_24kc/base"

# Package lists
BASE_PACKAGES=(
    "wireless-tools_29-r6_mipsel_24kc.ipk"
    "ethtool_6.11-r1_mipsel_24kc.ipk"
    "libxml2-16_2.14.5-r2_mipsel_24kc.ipk"
    "libnl-core200_3.10.0-r1_mipsel_24kc.ipk"
    "libnl-genl200_3.10.0-r1_mipsel_24kc.ipk"
    "libpcre2_10.42-r1_mipsel_24kc.ipk"
)

PACKAGES=(
    "aircrack-ng_1.7-r1_mipsel_24kc.ipk"
    "airmon-ng_1.7-r1_mipsel_24kc.ipk"
    "hcxdumptool_6.3.4-r1_mipsel_24kc.ipk"
    "php8_8.3.29-r1_mipsel_24kc.ipk"
    "php8-cli_8.3.29-r1_mipsel_24kc.ipk"
    "libpython3-3.11_3.11.14-r1_mipsel_24kc.ipk"
    "python3-base_3.11.14-r1_mipsel_24kc.ipk"
    "python3-light_3.11.14-r1_mipsel_24kc.ipk"
    "zoneinfo-core_2025c-r1_mipsel_24kc.ipk"
    "procps-ng_4.0.4-r1_mipsel_24kc.ipk"
)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NullSec Pineapple Suite - Package Downloader"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

mkdir -p "$PKG_DIR"
cd "$PKG_DIR"

echo "[*] Downloading base packages..."
for pkg in "${BASE_PACKAGES[@]}"; do
    if [ -f "$pkg" ]; then
        echo "    [~] Skip: $pkg (exists)"
    else
        echo "    [+] Downloading: $pkg"
        wget -q "$BASE_URL/$pkg" || echo "    [!] Failed: $pkg"
    fi
done

echo ""
echo "[*] Downloading additional packages..."
for pkg in "${PACKAGES[@]}"; do
    if [ -f "$pkg" ]; then
        echo "    [~] Skip: $pkg (exists)"
    else
        echo "    [+] Downloading: $pkg"
        wget -q "$PKG_URL/$pkg" || echo "    [!] Failed: $pkg"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Download Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Downloaded packages: $PKG_DIR"
echo ""
echo "Total: $(ls -1 *.ipk 2>/dev/null | wc -l) packages"
echo "Size:  $(du -sh . | cut -f1)"
echo ""
echo "To install on your Pineapple:"
echo "  1. scp -r packages/ root@172.16.52.1:/mmc/packages/"
echo "  2. ssh root@172.16.52.1"
echo "  3. cd /mmc/packages && opkg install *.ipk"
echo ""
