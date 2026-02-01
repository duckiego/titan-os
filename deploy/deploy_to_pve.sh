#!/bin/bash
set -e

# --- Configuration ---
if [ -z "$1" ]; then
    echo "Usage: $0 <user@pve-host>"
    exit 1
fi
PVE_HOST="$1"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE_IMG_PATH=$(ls -t "$PROJECT_ROOT"/*.img 2>/dev/null | head -n1)

if [ -z "$REMOTE_IMG_PATH" ]; then
    echo "Error: No .img file found in $PROJECT_ROOT"
    exit 1
fi
echo "Using image: $REMOTE_IMG_PATH" 
VM_ID=200
VM_NAME="titan-os-test"
STORAGE="local-lvm"

echo "=== Titan-OS Deployer ==="
echo "Source: $REMOTE_IMG_PATH"
echo "Target: $PVE_HOST (VM $VM_ID)"

# 1. Clean previous VM
echo "[1/5] Cleaning up old VM..."
ssh "$PVE_HOST" "
    if qm status $VM_ID >/dev/null 2>&1;
        then
        echo 'Stopping existing VM...'
        qm stop $VM_ID && qm wait $VM_ID 
        echo 'Destroying existing VM...'
        qm destroy $VM_ID --purge
    fi
"

# 2. Create new VM skeleton
echo "[2/5] Creating VM skeleton..."
# efidisk0 on local-lvm needed for OVMF vars
ssh "$PVE_HOST" "qm create $VM_ID --name $VM_NAME --memory 4096 --net0 virtio,bridge=vmbr0 --bios ovmf --machine q35 --efidisk0 $STORAGE:0"

# 3. Stream & Import Disk
echo "[3/5] Streaming Image..."
# Running locally on build server
gzip -c "$REMOTE_IMG_PATH" | \
ssh "$PVE_HOST" "gunzip -c > /tmp/titan-import.img"

echo "[3/5] Importing Disk..."
ssh "$PVE_HOST" "qm importdisk $VM_ID /tmp/titan-import.img $STORAGE"
ssh "$PVE_HOST" "rm /tmp/titan-import.img"

# 4. Attach Disk & Boot Order
echo "[4/5] Configuring Hardware..."
# We assume the imported disk is vm-ID-disk-1 (since disk-0 is efidisk)
# Rescan to be sure PVE sees it
ssh "$PVE_HOST" "
    qm rescan --vmid $VM_ID
    qm set $VM_ID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-$VM_ID-disk-1
    qm set $VM_ID --boot order=scsi0
"

# 5. Start
echo "[5/5] Starting VM..."
ssh "$PVE_HOST" "qm start $VM_ID"

echo "✅ Deployment Complete!"
