#!/bin/bash
set -e

# Titan-OS Image Builder
# Entry point that orchestrates modular build scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/scripts" && pwd)"

# Load configuration
source "$SCRIPT_DIR/config.sh"

echo "=== Titan-OS Builder Started ==="
echo "    Output: $OUTPUT_IMG"
echo "    Codename: $CODENAME"
echo ""

# Execute build stages
source "$SCRIPT_DIR/00_cleanup.sh"
source "$SCRIPT_DIR/01_bootstrap.sh"
source "$SCRIPT_DIR/02_configure_rootfs.sh"
source "$SCRIPT_DIR/03_persistence.sh"
source "$SCRIPT_DIR/04_pack_artifacts.sh"
source "$SCRIPT_DIR/05_create_disk.sh"

echo ""
echo "✅ Build Complete: $OUTPUT_IMG"
