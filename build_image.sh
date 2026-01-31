#!/bin/bash
set -e

# --- Configuration ---
WORKDIR="/tmp/titan-os-build"
ROOTFS_DIR="$WORKDIR/rootfs"
IMAGE_DIR="$WORKDIR/image"
OUTPUT_IMG="titan-os-v1.img"
DEBIAN_MIRROR="http://deb.debian.org/debian/"
CODENAME="bookworm"
IMG_SIZE=4096 # 4GB Disk

echo "=== Titan-OS Builder Started ==="

# 1. Cleanup & Tools
echo "[+] Cleaning up and checking tools..."
sudo rm -rf "$WORKDIR"
mkdir -p "$ROOTFS_DIR" "$IMAGE_DIR"
sudo apt-get update
sudo apt-get install -y gdisk efibootguard dosfstools squashfs-tools binutils systemd-boot-efi debootstrap swupdate openssl

# 2. Bootstrap RootFS
echo "[+] Bootstrapping Debian $CODENAME..."
sudo debootstrap --arch=amd64 --variant=minbase \
    --include=systemd,systemd-sysv,linux-image-amd64,busybox,initramfs-tools,squashfs-tools,live-boot,iproute2,curl,openssh-server,nano,isc-dhcp-client,efibootguard,pciutils,swupdate,openssl \
    "$CODENAME" "$ROOTFS_DIR" "$DEBIAN_MIRROR"

# 3. Configure RootFS
echo "[+] Configuring RootFS..."

# Disable services start during install
echo -e "#!/bin/sh\nexit 101" | sudo tee "$ROOTFS_DIR/usr/sbin/policy-rc.d" >/dev/null
sudo chmod +x "$ROOTFS_DIR/usr/sbin/policy-rc.d"

# Install missing bits
sudo chroot "$ROOTFS_DIR" apt-get update
sudo chroot "$ROOTFS_DIR" apt-get install -y systemd-resolved || true

# System Settings
echo "titan-node" | sudo tee "$ROOTFS_DIR/etc/hostname" >/dev/null
echo "secure-server 1.0" | sudo tee "$ROOTFS_DIR/etc/hwrevision" >/dev/null
echo "root:root" | sudo chroot "$ROOTFS_DIR" chpasswd

# Network
sudo chroot "$ROOTFS_DIR" systemctl enable systemd-networkd systemd-resolved ssh || true
sudo mkdir -p "$ROOTFS_DIR/etc/systemd/network"
printf "[Match]\nName=en* eth*\n\n[Network]\nDHCP=yes\n" | sudo tee "$ROOTFS_DIR/etc/systemd/network/20-wired.network" >/dev/null
sudo ln -sf /run/systemd/resolve/stub-resolv.conf "$ROOTFS_DIR/etc/resolv.conf"

# SSH Config
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' "$ROOTFS_DIR/etc/ssh/sshd_config"

# Persistence Mount
sudo mkdir -p "$ROOTFS_DIR/var/lib/data"
echo "LABEL=PERSISTENT /var/lib/data ext4 defaults,nofail 0 2" | sudo tee -a "$ROOTFS_DIR/etc/fstab" >/dev/null

# --- Persistence Hooks ---
echo "[+] Installing Persistence Hooks..."
cat <<'EOF' | sudo tee "$ROOTFS_DIR/usr/local/bin/persist-ssh" >/dev/null
#!/bin/sh
DATA_DIR="/var/lib/data/persistence"
mkdir -p "$DATA_DIR/ssh" "$DATA_DIR/root_ssh"

# 1. Host Keys
if [ -f "$DATA_DIR/ssh/ssh_host_rsa_key" ]; then
    cp "$DATA_DIR/ssh"/ssh_host_* /etc/ssh/
else
    ssh-keygen -A
    cp /etc/ssh/ssh_host_* "$DATA_DIR/ssh/"
fi

# 2. Root Authorized Keys
mkdir -p /root/.ssh
if [ -f "$DATA_DIR/root_ssh/authorized_keys" ]; then
    cp "$DATA_DIR/root_ssh/authorized_keys" /root/.ssh/
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
fi
EOF
sudo chmod +x "$ROOTFS_DIR/usr/local/bin/persist-ssh"

cat <<'EOF' | sudo tee "$ROOTFS_DIR/etc/systemd/system/persist-ssh.service" >/dev/null
[Unit]
Description=Restore SSH Keys
Before=ssh.service
RequiresMountsFor=/var/lib/data

[Service]
Type=oneshot
ExecStart=/usr/local/bin/persist-ssh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo chroot "$ROOTFS_DIR" systemctl enable persist-ssh.service

# Clean policy
sudo rm "$ROOTFS_DIR/usr/sbin/policy-rc.d"

# 4. Pack Artifacts
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

# 5. Create Disk Image
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

echo "✅ Build Complete: $OUTPUT_IMG"
