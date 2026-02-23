#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/systemd-networkd"
DST_DIR="/etc/systemd/network"

echo "Source: ${SRC_DIR}"
echo "Dest:   ${DST_DIR}"
echo
echo "WARNING: This will overwrite files with the same name in ${DST_DIR}."
echo "Make sure you have console access before applying network changes."
echo

sudo mkdir -p "${DST_DIR}"
sudo cp -v "${SRC_DIR}/"*.netdev "${DST_DIR}/"
sudo cp -v "${SRC_DIR}/"*.network "${DST_DIR}/"

echo
echo "Done copying. To apply:"
echo "  sudo systemctl restart systemd-networkd"
echo "Then verify:"
echo "  ./scripts/verify.sh"

