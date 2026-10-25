#!/bin/bash
# Builds AdFree and assembles build/AdFree.app. Usage: ./build.sh [run]
set -euo pipefail
cd "$(dirname "$0")"

# yt-dlp (plays YouTube videos). Downloaded once into vendor/, which is not committed.
# To update it, delete vendor/yt-dlp-macos and build again.
YTDLP=vendor/yt-dlp-macos
if [ ! -x "$YTDLP/yt-dlp_macos" ]; then
  echo "Downloading yt-dlp..."
  mkdir -p vendor
  curl -fsSL -o vendor/yt-dlp_macos.zip https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos.zip
  rm -rf "$YTDLP"; mkdir -p "$YTDLP"
  unzip -q vendor/yt-dlp_macos.zip -d "$YTDLP"
  rm vendor/yt-dlp_macos.zip
fi

swift build -c release
FINAL=build/AdFree.app
# Assemble and sign in a temp folder: iCloud adds file attributes inside ~/Documents while a
# bundle is being signed, which makes codesign fail ("detritus not allowed").
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
APP="$WORK/AdFree.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/AdFree" "$APP/Contents/MacOS/AdFree"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/ContentRules.json Resources/*.js Resources/AdFree.icns "$APP/Contents/Resources/"
mkdir -p "$APP/Contents/Resources/mcp"
cp mcp/server.js "$APP/Contents/Resources/mcp/"
# yt-dlp sits in Resources (not Helpers): codesign requires everything under Helpers to be signed code.
HELPER="$APP/Contents/Resources/yt-dlp/yt-dlp_macos"
cp -R "$YTDLP" "$APP/Contents/Resources/yt-dlp"
# The helper must inherit the app's sandbox, so it is signed first with its own entitlements.
signed=no
for _ in 1 2 3; do
  xattr -cr "$APP"
  codesign --force --sign - --entitlements Resources/Helper.entitlements "$HELPER" 2>/dev/null || continue
  xattr -cr "$APP" # signing the helper can add attributes back, which would fail the app signature
  if codesign --force --sign - --entitlements Resources/AdFree.entitlements "$APP" 2>/dev/null; then signed=yes; break; fi
done
[ "$signed" = yes ] || { echo "Code signing failed" >&2; exit 1; }
# Never ship an unsandboxed build by accident.
codesign -d --entitlements - "$APP" 2>&1 | grep -q "app-sandbox" || { echo "Built app is not sandboxed" >&2; exit 1; }
rm -rf "$FINAL"
mkdir -p build
ditto --noextattr --norsrc "$APP" "$FINAL"
echo "Built $FINAL"
[ "${1:-}" = "run" ] && open "$FINAL"
exit 0
