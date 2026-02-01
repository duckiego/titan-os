#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYS_DIR="$SCRIPT_DIR/keys"

echo "=== Titan-OS Key Generator ==="
mkdir -p "$KEYS_DIR"

if [ -f "$KEYS_DIR/private.pem" ]; then
    echo "Warning: Keys already exist in $KEYS_DIR."
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo "[+] Generating RSA Private Key..."
openssl genrsa -out "$KEYS_DIR/private.pem" 4096

echo "[+] Generating Self-Signed X.509 Certificate..."
openssl req -x509 -new -nodes -key "$KEYS_DIR/private.pem" \
    -sha256 -days 36500 \
    -out "$KEYS_DIR/public.pem" \
    -subj "/C=US/ST=State/L=City/O=TitanOS/CN=titan-update" \
    -addext "keyUsage = critical,digitalSignature"

echo "✅ Keys generated successfully in $KEYS_DIR"
echo "  - Private Key: $KEYS_DIR/private.pem (KEEP SECRET)"
echo "  - Certificate: $KEYS_DIR/public.pem (Deploy to target)"
