#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
repo_root="$PWD"
app_dir="${repo_root}/Oatmeal AI.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
# Compile in a writable cache, including when run inside the coding sandbox.
CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/oatmeal-clang-cache" \
  swiftc scripts/macos/OatmealAI.swift -o "$app_dir/Contents/MacOS/OatmealAI.new" \
  -module-cache-path "${TMPDIR:-/tmp}/oatmeal-swift-cache" -framework AppKit
mv "$app_dir/Contents/MacOS/OatmealAI.new" "$app_dir/Contents/MacOS/OatmealAI"
icon_work="$(mktemp -d "${TMPDIR:-/tmp}/oatmeal-icon.XXXXXX")"
trap 'rm -rf "$icon_work"' EXIT
mkdir "$icon_work/Oatmeal.iconset"
"$app_dir/Contents/MacOS/OatmealAI" --render-icon "$icon_work/icon.png"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$icon_work/icon.png" --out "$icon_work/Oatmeal.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$icon_work/icon.png" --out "$icon_work/Oatmeal.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$icon_work/Oatmeal.iconset" -o "$app_dir/Contents/Resources/Oatmeal.icns"
printf '%s\n' "$repo_root" > "$app_dir/Contents/Resources/repo-path.txt"
printf '%s\n' "$PATH" > "$app_dir/Contents/Resources/launch-path.txt"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>OatmealAI</string>
<key>CFBundleIdentifier</key><string>com.oatmeal.local-launcher</string>
<key>CFBundleIconFile</key><string>Oatmeal</string>
<key>CFBundleName</key><string>Oatmeal AI</string>
<key>CFBundleDisplayName</key><string>Oatmeal AI</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app_dir"
echo "Built: $app_dir"
echo "Open it in Finder, then right-click its Dock icon and choose Options > Keep in Dock."
