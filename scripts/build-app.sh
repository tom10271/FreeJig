#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
export CLANG_MODULE_CACHE_PATH="$root/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$root/.build/ModuleCache"
mkdir -p "$root/.build/cache" "$root/dist"
swift build -c release --disable-sandbox --cache-path "$root/.build/cache"
binary_dir="$(swift build -c release --show-bin-path --disable-sandbox --cache-path "$root/.build/cache")"
app="$root/dist/FreeJig.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/FreeJig" "$app/Contents/MacOS/FreeJig"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>FreeJig</string>
<key>CFBundleDisplayName</key><string>FreeJig</string>
<key>CFBundleExecutable</key><string>FreeJig</string>
<key>CFBundleIdentifier</key><string>io.github.tom10271.FreeJig.macOS</string>
<key>CFBundleVersion</key><string>12</string>
<key>CFBundleShortVersionString</key><string>0.1.4</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><false/>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHumanReadableCopyright</key><string>Copyright 2026 FreeJig contributors. MIT license.</string>
</dict></plist>
PLIST
swift scripts/create-icon.swift "$root/.build/AppIcon.iconset"
iconutil -c icns "$root/.build/AppIcon.iconset" -o "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier io.github.tom10271.FreeJig.macOS "$app"
codesign --verify --strict "$app"
"$app/Contents/MacOS/FreeJig" --self-check
touch "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$root/dist/FreeJig-macOS-$(uname -m).zip"
printf 'Built %s\n' "$app"
