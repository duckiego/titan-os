#!/bin/bash
set -e

# --- Configuration ---
# Default to the location where create_update.sh outputs
DEFAULT_SWU_PATH="titan-update-v1.0.1.swu"
SWU_PATH="${1:-$DEFAULT_SWU_PATH}"
VM_IP="${2}"

if [ -z "$VM_IP" ]; then
    # Try to guess args if only IP is provided
    if [[ "$SWU_PATH" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        VM_IP="$SWU_PATH"
        SWU_PATH="$DEFAULT_SWU_PATH"
    else
        echo "Usage: $0 [path_to_swu] <vm_ip>"
        echo "Example: $0 192.168.0.243"
        exit 1
    fi
fi

# Resolve absolute path for local file
if [[ ! "$SWU_PATH" = /* ]]; then
    SWU_PATH="$(pwd)/$SWU_PATH"
fi

echo "=== Titan-OS Updater ==="
echo "Payload: $SWU_PATH"
echo "Target:  root@$VM_IP"

# 1. Check Payload
if [ ! -f "$SWU_PATH" ]; then
    echo "Error: SWU file not found at $SWU_PATH"
    echo "Did you run create_update.sh?"
    exit 1
fi

# 2. Transfer
echo "[1/3] Transferring update package..."
# Note: Requires SSH access to target
scp -o StrictHostKeyChecking=no "$SWU_PATH" "root@$VM_IP:/tmp/update.swu"

# 3. Execute Update (Fallback Mode: Manual Script)
# We use this mode because we haven't set up the full PKI infrastructure on the target yet.
echo "[2/3] Installing update (Script Mode)..."
ssh -o StrictHostKeyChecking=no "root@$VM_IP" "
    set -e
    # Clean prev run
    rm -rf /tmp/swu_extract
    mkdir -p /tmp/swu_extract
    cd /tmp/swu_extract
    
    # Extract
    echo 'Extracting package...'
    cpio -id < /tmp/update.swu 2>/dev/null
    
    # Execute payload script
    if [ -f update.sh ]; then
        chmod +x update.sh
        echo 'Running update script...'
        ./update.sh
    else
        echo 'Error: update.sh not found in SWU'
        exit 1
    fi
"

# 4. Reboot
echo "[3/3] Update installed. Rebooting target..."
ssh -o StrictHostKeyChecking=no "root@$VM_IP" "reboot" || true

echo "✅ Update Triggered! Please verify revision after reboot."
