#!/bin/bash
# Regenerates Resources/AdFree.icns from tools/make-icon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)/AdFree.iconset"
swift tools/make-icon.swift "$TMP"
iconutil -c icns -o Resources/AdFree.icns "$TMP"
echo "Wrote Resources/AdFree.icns"
