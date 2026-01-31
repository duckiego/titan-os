#!/bin/bash
# Titan-OS Build Configuration

# Build directories
WORKDIR="/tmp/titan-os-build"
ROOTFS_DIR="$WORKDIR/rootfs"
IMAGE_DIR="$WORKDIR/image"

# Output
OUTPUT_IMG="titan-os-v1.img"

# Debian settings
DEBIAN_MIRROR="http://deb.debian.org/debian/"
CODENAME="bookworm"

# Disk size in MB
IMG_SIZE=4096

# Script directory (for locating rootfs files)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
