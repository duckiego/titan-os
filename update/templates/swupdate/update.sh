#!/bin/sh
set -e
echo ">>> Starting Titan-OS Update (Slot B)..."

# Mount ESP
mkdir -p /tmp/esp
mount /dev/sda1 /tmp/esp

# Update Slot B Files
echo ">>> Writing Kernel..."
cp system_b.efi /tmp/esp/EFI/Linux/system_b.efi

echo ">>> Writing RootFS..."
mkdir -p /tmp/esp/live/slot_b
cp filesystem.squashfs /tmp/esp/live/slot_b/filesystem.squashfs

# Switch Boot Revision
# We read current revision if possible, or just set a high number.
# Here we hardcode 99 to ensure switch.
echo ">>> Switching Boot Slot..."
bg_setenv -f /tmp/esp/BGENV.DAT -p 1 -r 99 -i 0 -k "EFI\\Linux\\system_b.efi" -w 0

umount /tmp/esp
echo ">>> Update Complete."
exit 0
