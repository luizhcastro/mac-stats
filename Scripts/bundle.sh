#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
VERSION="${VERSION:-0.3.3}"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"
APP="$BIN_PATH/MacStats.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

rm -rf "$APP"
mkdir -p "$MACOS" "$RES"
cp "$BIN_PATH/MacStats" "$MACOS/MacStats"

ICON_SRC="$(cd "$(dirname "$0")/.." && pwd)/Resources/AppIcon.icns"
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$RES/AppIcon.icns"
fi

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>MacStats</string>
    <key>CFBundleDisplayName</key><string>MacStats</string>
    <key>CFBundleIdentifier</key><string>dev.luizcastro.macstats</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleExecutable</key><string>MacStats</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSLocationUsageDescription</key><string>MacStats reads the current Wi-Fi SSID and signal information so it can show the network you are connected to.</string>
    <key>NSLocationWhenInUseUsageDescription</key><string>MacStats reads the current Wi-Fi SSID and signal information so it can show the network you are connected to.</string>
</dict>
</plist>
PLIST

echo "Built: $APP (version $VERSION)"
