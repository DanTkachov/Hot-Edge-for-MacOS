#!/bin/bash
# Builds Hot Edge.app. Pass --install to copy it into /Applications and launch it.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Hot Edge.app"

swift build -c release
.build/release/HotEdge --selftest

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/HotEdge "$APP/Contents/MacOS/HotEdge"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# App icon
TMP="$(mktemp -d)"
ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"
swift scripts/make_icon.swift "$TMP/icon.png"
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/icon.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$TMP/icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$TMP"

codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x HotEdge 2>/dev/null && sleep 0.5 || true
  rm -rf "/Applications/Hot Edge.app"
  cp -R "$APP" "/Applications/Hot Edge.app"
  open "/Applications/Hot Edge.app"
  echo "Installed to /Applications/Hot Edge.app and launched."
fi
