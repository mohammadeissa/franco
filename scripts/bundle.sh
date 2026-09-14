#!/bin/bash
# Builds Franco in release mode and packages build/Franco.app (menu-bar app, no Dock icon).
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP=build/Franco.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Franco "$APP/Contents/MacOS/Franco"
cp -R Resources/profiles Resources/dict "$APP/Contents/Resources/"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Franco</string>
  <key>CFBundleDisplayName</key><string>Franco</string>
  <key>CFBundleIdentifier</key><string>com.mohammadeissa.franco</string>
  <key>CFBundleExecutable</key><string>Franco</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHumanReadableCopyright</key><string>Personal use</string>
</dict></plist>
PLIST
codesign --force --sign - --identifier com.mohammadeissa.franco "$APP" >/dev/null
echo "built $APP"
