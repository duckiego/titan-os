#!/bin/bash
# Step 1: Bootstrap Debian RootFS

echo "[+] Bootstrapping Debian $CODENAME..."
sudo debootstrap --arch=amd64 --variant=minbase \
    --include=systemd,systemd-sysv,linux-image-amd64,busybox,initramfs-tools,squashfs-tools,live-boot,iproute2,curl,openssh-server,nano,isc-dhcp-client,efibootguard,pciutils,swupdate,openssl \
    "$CODENAME" "$ROOTFS_DIR" "$DEBIAN_MIRROR"
