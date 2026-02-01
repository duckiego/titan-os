#!/bin/sh
set -e
# Handle arguments: preinst or postinst
case "$1" in
    preinst)
        echo ">>> [preinst] Preparing Update..."
        # Mount ESP
        mkdir -p /tmp/esp
        if ! mountpoint -q /tmp/esp; then
            mount /dev/sda1 /tmp/esp
        fi
        
        # Prepare directories
        mkdir -p /tmp/esp/EFI/Linux
        mkdir -p /tmp/esp/live/slot_b
        
        # Remove old files if they exist to ensure clean copy
        rm -f /tmp/esp/EFI/Linux/system_b.efi
        rm -f /tmp/esp/live/slot_b/filesystem.squashfs
        ;;

    postinst)
        echo ">>> [postinst] Finalizing Update..."
        
        # Switch Boot Revision
        echo ">>> Switching Boot Slot..."
        bg_setenv -f /tmp/esp/BGENV.DAT -p 1 -r 99 -i 0 -k "EFI\\Linux\\system_b.efi" -w 0
        
        # Sync and Umount
        sync
        umount /tmp/esp || true
        echo ">>> Update Complete."
        ;;
        
    *)
        echo "Usage: $0 {preinst|postinst}"
        exit 1
        ;;
esac
exit 0
