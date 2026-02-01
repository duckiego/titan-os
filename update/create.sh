#!/bin/bash
set -e

# --- Configuration ---
# Source build config for paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_CONFIG="$SCRIPT_DIR/../build/stages/config.sh"

if [ -f "$BUILD_CONFIG" ]; then
    source "$BUILD_CONFIG"
else
    echo "Error: Build config not found at $BUILD_CONFIG"
    exit 1
fi

# Override specific update settings
OS_VERSION="1.0.1"
VERSION="$OS_VERSION"
WORKDIR="swu_build"
OUTPUT_SWU="titan-update-v${VERSION}.swu"
TEMPLATES_DIR="$SCRIPT_DIR/templates/swupdate"

echo "=== Titan-OS Update Builder (Rebuild Mode) ==="
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

# Check ROOTFS_DIR
if [ ! -d "$ROOTFS_DIR" ]; then
    echo "Error: ROOTFS_DIR ($ROOTFS_DIR) not found. Please run build.sh first."
    exit 1
fi

# 1. Update Version in RootFS
echo "[+] Updating OS Version to $OS_VERSION..."
# Remove old CUSTOM_VERSION if exists to avoid duplicates
sudo sed -i '/CUSTOM_VERSION=/d' "$ROOTFS_DIR/etc/os-release"
echo "CUSTOM_VERSION=\"$OS_VERSION\"" | sudo tee -a "$ROOTFS_DIR/etc/os-release" >/dev/null

# 2. Rebuild SquashFS
echo "[+] Rebuilding SquashFS..."
sudo mksquashfs "$ROOTFS_DIR" "$WORKDIR/filesystem.squashfs" -comp zstd -Xcompression-level 1 -no-progress

# 3. Rebuild UKI (system_b.efi)
echo "[+] Rebuilding UKI (system_b.efi)..."
# Find kernel version again (logic from 04_pack_artifacts.sh)
K_VER=$(ls "$ROOTFS_DIR/boot/" | grep vmlinuz | cut -d- -f2- | sort -V | tail -n1)
EFI_STUB="/usr/lib/systemd/boot/efi/linuxx64.efi.stub"
[ ! -f "$EFI_STUB" ] && EFI_STUB="$ROOTFS_DIR/usr/lib/systemd/boot/efi/linuxx64.efi.stub"

# Prepare components
cp "$ROOTFS_DIR/boot/vmlinuz-$K_VER" "$WORKDIR/vmlinuz.efi"
cp "$ROOTFS_DIR/boot/initrd.img-$K_VER" "$WORKDIR/initrd.img"
echo "boot=live components TORAM=1 live-media-path=/live/slot_b console=ttyS0" > "$WORKDIR/cmdline_b.txt"

# Build UKI
sudo objcopy \
    --add-section .osrel="$ROOTFS_DIR/etc/os-release" --change-section-vma .osrel=0x20000 \
    --add-section .cmdline="$WORKDIR/cmdline_b.txt" --change-section-vma .cmdline=0x30000 \
    --add-section .linux="$WORKDIR/vmlinuz.efi" --change-section-vma .linux=0x2000000 \
    --add-section .initrd="$WORKDIR/initrd.img" --change-section-vma .initrd=0x3000000 \
    "$EFI_STUB" "$WORKDIR/system_b.efi"

# 4. Copy Update Script
echo "[+] Copying Update Script..."
cp "$TEMPLATES_DIR/update.sh" "$WORKDIR/update.sh"
chmod +x "$WORKDIR/update.sh"

# 5. Generate SW-Description
echo "[+] Generating SW-Description..."
export VERSION
envsubst < "$TEMPLATES_DIR/sw-description.template" > "$WORKDIR/sw-description"

# 6. Pack SWU
echo "[+] Packing SWU..."
cd "$WORKDIR"
for f in sw-description update.sh system_b.efi filesystem.squashfs; do
    echo "$f"
done | cpio -ov -H crc > "../$OUTPUT_SWU"

echo "✅ Update Package Ready: $OUTPUT_SWU"
echo "To install on device: swupdate -i $OUTPUT_SWU"
