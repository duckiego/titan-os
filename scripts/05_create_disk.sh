#!/bin/bash
# Step 5: Create disk image and populate ESP

echo "[+] Creating Disk Image ($IMG_SIZE MB)..."
dd if=/dev/zero of="$OUTPUT_IMG" bs=1M count="$IMG_SIZE" status=none

# Partitioning
sudo sgdisk -Z "$OUTPUT_IMG" >/dev/null
sudo sgdisk -n 1:2048:+2G -t 1:ef00 -c 1:"EFI System" "$OUTPUT_IMG" >/dev/null
sudo sgdisk -n 2:0:0      -t 2:8300 -c 2:"Persistent Data" "$OUTPUT_IMG" >/dev/null

LOOP_DEV=$(sudo losetup -fP --show "$OUTPUT_IMG")

echo "[+] Formatting..."
sudo mkfs.vfat -F 32 -n "EFI_SYSTEM" "${LOOP_DEV}p1" >/dev/null
sudo mkfs.ext4 -L "PERSISTENT" "${LOOP_DEV}p2" >/dev/null

echo "[+] Populating ESP..."
sudo mkdir -p /mnt/titan_esp
sudo mount "${LOOP_DEV}p1" /mnt/titan_esp
sudo mkdir -p /mnt/titan_esp/EFI/BOOT /mnt/titan_esp/EFI/Linux
sudo mkdir -p /mnt/titan_esp/live/slot_a /mnt/titan_esp/live/slot_b

# Efibootguard
EBG_BIN="/usr/lib/x86_64-linux-gnu/efibootguard/efibootguardx64.efi"
[ ! -f "$EBG_BIN" ] && EBG_BIN="$ROOTFS_DIR/usr/lib/x86_64-linux-gnu/efibootguard/efibootguardx64.efi"
sudo cp "$EBG_BIN" /mnt/titan_esp/EFI/BOOT/BOOTX64.EFI

# Payload A (Default)
sudo cp "$IMAGE_DIR/system_a.efi" /mnt/titan_esp/EFI/Linux/system_a.efi
sudo cp "$IMAGE_DIR/filesystem.squashfs" /mnt/titan_esp/live/slot_a/filesystem.squashfs

# Payload B (Backup)
sudo cp "$IMAGE_DIR/system_b.efi" /mnt/titan_esp/EFI/Linux/system_b.efi
sudo cp "$IMAGE_DIR/filesystem.squashfs" /mnt/titan_esp/live/slot_b/filesystem.squashfs

# BGENV Config
echo "[+] Configuring Boot Environment..."
# Slot 0 (A) - Revision 1
sudo bg_setenv -f /mnt/titan_esp/BGENV.DAT -p 0 -r 1 -i 0 -k "EFI\Linux\system_a.efi" -w 0
# Slot 1 (B) - Revision 0
sudo bg_setenv -f /mnt/titan_esp/BGENV.DAT -p 1 -r 0 -i 0 -k "EFI\Linux\system_b.efi" -w 0

# Cleanup
sudo umount /mnt/titan_esp
sudo losetup -d "$LOOP_DEV"
