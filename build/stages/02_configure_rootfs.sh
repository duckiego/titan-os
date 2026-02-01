#!/bin/bash
# Step 2: Configure RootFS

echo "[+] Configuring RootFS..."

# Disable services start during install
echo -e "#!/bin/sh\nexit 101" | sudo tee "$ROOTFS_DIR/usr/sbin/policy-rc.d" >/dev/null
sudo chmod +x "$ROOTFS_DIR/usr/sbin/policy-rc.d"

# Install additional packages
sudo chroot "$ROOTFS_DIR" apt-get update
sudo chroot "$ROOTFS_DIR" apt-get install -y systemd-resolved || true

# System Settings
echo "CUSTOM_VERSION=\"$OS_VERSION\"" | sudo tee -a "$ROOTFS_DIR/etc/os-release" >/dev/null
echo "titan-node" | sudo tee "$ROOTFS_DIR/etc/hostname" >/dev/null
echo "secure-server 1.0" | sudo tee "$ROOTFS_DIR/etc/hwrevision" >/dev/null
echo "root:root" | sudo chroot "$ROOTFS_DIR" chpasswd

# Network configuration
sudo chroot "$ROOTFS_DIR" systemctl enable systemd-networkd systemd-resolved ssh || true
sudo mkdir -p "$ROOTFS_DIR/etc/systemd/network"
printf "[Match]\nName=en* eth*\n\n[Network]\nDHCP=yes\n" | sudo tee "$ROOTFS_DIR/etc/systemd/network/20-wired.network" >/dev/null
sudo ln -sf /run/systemd/resolve/stub-resolv.conf "$ROOTFS_DIR/etc/resolv.conf"

# SSH Config
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' "$ROOTFS_DIR/etc/ssh/sshd_config"

# Persistence Mount
sudo mkdir -p "$ROOTFS_DIR/var/lib/data"
echo "LABEL=PERSISTENT /var/lib/data ext4 defaults,nofail 0 2" | sudo tee -a "$ROOTFS_DIR/etc/fstab" >/dev/null
