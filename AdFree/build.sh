#!/bin/bash
# Builds AdFree and assembles build/AdFree.app. Usage: ./build.sh [run]
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP=build/AdFree.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/AdFree" "$APP/Contents/MacOS/AdFree"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/ContentRules.json Resources/*.js Resources/AdFree.icns "$APP/Contents/Resources/"
for _ in 1 2 3; do xattr -cr "$APP"; codesign --force --sign - --entitlements Resources/AdFree.entitlements "$APP" 2>/dev/null && break; done
echo "Built $APP"
[ "${1:-}" = "run" ] && open "$APP"
