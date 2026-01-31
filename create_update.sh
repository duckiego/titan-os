#!/bin/bash
set -e

# --- Configuration ---
VERSION="2.0.0"
WORKDIR="swu_build"
# Point this to where your build_image.sh output artifacts are kept
ARTIFACTS_DIR="/tmp/secure-os-build/image" 
OUTPUT_SWU="titan-update-v${VERSION}.swu"

echo "=== Titan-OS Update Builder ==="
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

# 1. Prepare Payload
echo "[+] Preparing Payload..."
# In a real pipeline, you would build a NEW UKI/RootFS here.
# For demo, we copy the artifacts from the previous build.
if [ ! -f "$ARTIFACTS_DIR/system_b.efi" ]; then
    echo "Error: Artifacts not found in $ARTIFACTS_DIR"
    exit 1
fi
cp "$ARTIFACTS_DIR/system_b.efi" "$WORKDIR/system_b.efi"
cp "$ARTIFACTS_DIR/filesystem.squashfs" "$WORKDIR/filesystem.squashfs"

# 2. Update Script
echo "[+] Generating Update Script..."
cat > "$WORKDIR/update.sh" <<EOF
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
EOF
chmod +x "$WORKDIR/update.sh"

# 3. Description
echo "[+] Generating SW-Description..."
cat > "$WORKDIR/sw-description" <<EOF
software = 
{
	version = "$VERSION";
    hardware-compatibility: [ "secure-server" ];

	files: (
		{
			filename = "system_b.efi";
			path = "system_b.efi";
		},
        {
            filename = "filesystem.squashfs";
            path = "filesystem.squashfs";
        }
	);

	scripts: (
		{
			filename = "update.sh";
			type = "shellscript";
		}
	);
}
EOF

# 4. Pack (Unsigned)
echo "[+] Packing SWU..."
cd "$WORKDIR"
for f in sw-description update.sh system_b.efi filesystem.squashfs; do
    echo "$f"
done | cpio -ov -H crc > "../$OUTPUT_SWU"

echo "✅ Update Package Ready: $OUTPUT_SWU"
echo "To install on device: swupdate -i $OUTPUT_SWU"
