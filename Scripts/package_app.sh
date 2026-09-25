#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
engine_source="${MYTHIC_ENGINE_SOURCE:-$HOME/Library/Application Support/Mythic/Engine}"
output_dir="${GAL4MAC_OUTPUT_DIR:-$repo_dir/dist}"
app="$output_dir/Gal4Mac.app"

if [[ ! -f "$engine_source/Properties.plist" || ! -x "$engine_source/wine/bin/wine64" ]]; then
    echo "Mythic Engine 无效: $engine_source" >&2
    echo "设置 MYTHIC_ENGINE_SOURCE 指向已安装 Engine 的目录。" >&2
    exit 1
fi

cd "$repo_dir"
swift build -c release --product Gal4MacApp
binary_dir="$(swift build -c release --show-bin-path)"

mkdir -p "$output_dir"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/Gal4MacApp" "$app/Contents/MacOS/Gal4Mac"
ditto "$engine_source" "$app/Contents/Resources/Engine"
# Mythic 2.6.1 ships an unused Headers link with no target. A dangling link
# prevents strict bundle signature verification.
framework_headers="$app/Contents/Resources/Engine/wine/lib/external/D3DMetal.framework/Headers"
if [[ -L "$framework_headers" && ! -e "$framework_headers" ]]; then
    rm "$framework_headers"
fi
ditto "$repo_dir/Resources/EngineLogos" "$app/Contents/Resources/EngineLogos"
cp "$repo_dir/LICENSE" "$app/Contents/Resources/Gal4Mac-LICENSE"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleName</key><string>Gal4Mac</string>
    <key>CFBundleDisplayName</key><string>Gal4Mac</string>
    <key>CFBundleIdentifier</key><string>io.github.chenmou2012.Gal4Mac</string>
    <key>CFBundleExecutable</key><string>Gal4Mac</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.games</string>
    <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

# The app is signed for local use. A public release needs a Developer ID
# signature and notarization, which require the publisher's credentials.
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"

echo "已生成 $app"
echo "内置 Engine: $(du -sh "$app/Contents/Resources/Engine" | awk '{print $1}')"
