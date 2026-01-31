#!/bin/bash
# Step 3: Install persistence hooks

echo "[+] Installing Persistence Hooks..."

# Install persist-ssh script
sudo cp "$PROJECT_ROOT/rootfs/usr/local/bin/persist-ssh" "$ROOTFS_DIR/usr/local/bin/"
sudo chmod +x "$ROOTFS_DIR/usr/local/bin/persist-ssh"

# Install systemd service
sudo cp "$PROJECT_ROOT/rootfs/etc/systemd/system/persist-ssh.service" "$ROOTFS_DIR/etc/systemd/system/"
sudo chroot "$ROOTFS_DIR" systemctl enable persist-ssh.service

# Clean policy
sudo rm "$ROOTFS_DIR/usr/sbin/policy-rc.d"
