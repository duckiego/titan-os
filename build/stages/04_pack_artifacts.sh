#!/bin/bash
# Step 4: Pack SquashFS and build UKIs

echo "[+] Packing SquashFS..."
sudo mksquashfs "$ROOTFS_DIR" "$IMAGE_DIR/filesystem.squashfs" -comp zstd -Xcompression-level 1 -no-progress

echo "[+] Building UKIs..."
K_VER=$(ls "$ROOTFS_DIR/boot/" | grep vmlinuz | cut -d- -f2- | sort -V | tail -n1)

# Extract kernel/initrd
sudo cp "$ROOTFS_DIR/boot/vmlinuz-$K_VER" "$IMAGE_DIR/vmlinuz.efi"
sudo cp "$ROOTFS_DIR/boot/initrd.img-$K_VER" "$IMAGE_DIR/initrd.img"

# Stub path check
STUB="/usr/lib/systemd/boot/efi/linuxx64.efi.stub"
[ ! -f "$STUB" ] && STUB="$ROOTFS_DIR/usr/lib/systemd/boot/efi/linuxx64.efi.stub"

# UKI A
echo "boot=live components TORAM=1 live-media-path=/live/slot_a console=ttyS0" > "$IMAGE_DIR/cmdline_a.txt"
sudo objcopy \
    --add-section .osrel="$ROOTFS_DIR/etc/os-release" --change-section-vma .osrel=0x20000 \
    --add-section .cmdline="$IMAGE_DIR/cmdline_a.txt" --change-section-vma .cmdline=0x30000 \
    --add-section .linux="$IMAGE_DIR/vmlinuz.efi" --change-section-vma .linux=0x2000000 \
    --add-section .initrd="$IMAGE_DIR/initrd.img" --change-section-vma .initrd=0x3000000 \
    "$STUB" "$IMAGE_DIR/system_a.efi"

# UKI B
echo "boot=live components TORAM=1 live-media-path=/live/slot_b console=ttyS0" > "$IMAGE_DIR/cmdline_b.txt"
sudo objcopy \
    --add-section .osrel="$ROOTFS_DIR/etc/os-release" --change-section-vma .osrel=0x20000 \
    --add-section .cmdline="$IMAGE_DIR/cmdline_b.txt" --change-section-vma .cmdline=0x30000 \
    --add-section .linux="$IMAGE_DIR/vmlinuz.efi" --change-section-vma .linux=0x2000000 \
    --add-section .initrd="$IMAGE_DIR/initrd.img" --change-section-vma .initrd=0x3000000 \
    "$STUB" "$IMAGE_DIR/system_b.efi"
