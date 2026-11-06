#!/bin/bash
# Builds dist/Serato Crates Sync.app and a zip to share. Needs only the Command Line Tools.
# The app is signed ad hoc: no Apple Developer account, so see README.md for the first launch.
set -euo pipefail
cd "$(dirname "$0")/.."

app="dist/Serato Crates Sync.app"
rm -rf dist
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

swift build -c release --product CrateSync --arch arm64 --arch x86_64
bin_path="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
cp "$bin_path/CrateSync" "$app/Contents/MacOS/CrateSync"
cp Resources/Info.plist "$app/Contents/Info.plist"

iconset="$(mktemp -d)/AppIcon.iconset"
mkdir "$iconset"
for size in 16 32 128 256 512; do
    swift scripts/make-icon.swift "$size" "$iconset/icon_${size}x${size}.png"
    swift scripts/make-icon.swift "$((size * 2))" "$iconset/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$app"
ditto -c -k --keepParent "$app" "dist/Serato-Crates-Sync.zip"

echo "Built: $app"
lipo -archs "$app/Contents/MacOS/CrateSync"
