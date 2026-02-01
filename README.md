# Titan-OS Project

An industrial-grade, immutable Linux server OS based on Debian Bookworm.

## Architecture

- **Bootloader**: Efibootguard (A/B Failover)
- **Kernel**: Unified Kernel Image (UKI)
- **RootFS**: SquashFS + OverlayFS (RAM-based, Stateless)
- **Persistence**: 
  - Data: `/var/lib/data` (Auto-mounted ext4 partition)
  - Config: SSH Host Keys & Root Authorized Keys (Auto-restored)
- **Updates**: SWUpdate (OTA Ready)

## Project Structure

```
titan-os/
├── build/                      # 🛠️ Image Builder
│   ├── build.sh                # Main build script
│   ├── stages/                 # Modular build stages
│   └── rootfs/                 # RootFS overlays
│
├── update/                     # 🔄 OTA Update Generator
│   ├── create.sh               # Update package generator
│   └── templates/              # SWUpdate templates
│
└── deploy/                     # 🚀 Deployment Tools
    ├── deploy_to_pve.sh
    └── update_vm.sh
```

## Quick Start

### 1. Build Image
Run the builder on a Debian-based host (requires sudo):
```bash
./build/build.sh
```
Output: `titan-os-v1.img` (4GB GPT Disk Image)

### 2. Deploy
Flash the image to a USB drive or import into a Virtual Machine (UEFI required).
- **Default User**: `root`
- **Password**: `root`

### 3. Persistence
- **First Boot**: SSH Host Keys are generated automatically.
- **SSH Keys**: To persist your public key:
  1. `ssh-copy-id root@<IP>`
  2. Run `cp /root/.ssh/authorized_keys /var/lib/data/persistence/root_ssh/`
  3. Reboot. The key will be restored automatically.

### 4. OTA Update
Generate an update package:
```bash
./update/create.sh
```
Output: `titan-update-v2.0.0.swu`

Install on device:
```bash
swupdate -i titan-update-v2.0.0.swu
```
(Requires `secure-server 1.0` in `/etc/hwrevision`, which is default).
