#!/bin/bash
# Step 0: Cleanup and install build tools

echo "[+] Cleaning up and checking tools..."
sudo rm -rf "$WORKDIR"
mkdir -p "$ROOTFS_DIR" "$IMAGE_DIR"

sudo apt-get update
sudo apt-get install -y \
    gdisk \
    efibootguard \
    dosfstools \
    squashfs-tools \
    binutils \
    systemd-boot-efi \
    debootstrap \
    swupdate \
    openssl
