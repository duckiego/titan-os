#!/bin/bash
set -e

# --- Configuration ---
VERSION="2.0.0"
WORKDIR="swu_build"
# Point this to where your build_image.sh output artifacts are kept
ARTIFACTS_DIR="/tmp/titan-os-build/image"
OUTPUT_SWU="titan-update-v${VERSION}.swu"

# Script directory (for locating templates)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates/swupdate"

echo "=== Titan-OS Update Builder ==="
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

# 1. Prepare Payload
echo "[+] Preparing Payload..."
if [ ! -f "$ARTIFACTS_DIR/system_b.efi" ]; then
    echo "Error: Artifacts not found in $ARTIFACTS_DIR"
    exit 1
fi
cp "$ARTIFACTS_DIR/system_b.efi" "$WORKDIR/system_b.efi"
cp "$ARTIFACTS_DIR/filesystem.squashfs" "$WORKDIR/filesystem.squashfs"

# 2. Copy Update Script
echo "[+] Copying Update Script..."
cp "$TEMPLATES_DIR/update.sh" "$WORKDIR/update.sh"
chmod +x "$WORKDIR/update.sh"

# 3. Generate SW-Description (substitute VERSION)
echo "[+] Generating SW-Description..."
export VERSION
envsubst < "$TEMPLATES_DIR/sw-description.template" > "$WORKDIR/sw-description"

# 4. Pack (Unsigned)
echo "[+] Packing SWU..."
cd "$WORKDIR"
for f in sw-description update.sh system_b.efi filesystem.squashfs; do
    echo "$f"
done | cpio -ov -H crc > "../$OUTPUT_SWU"

echo "✅ Update Package Ready: $OUTPUT_SWU"
echo "To install on device: swupdate -i $OUTPUT_SWU"
