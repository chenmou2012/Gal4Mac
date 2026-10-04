#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${VERSION:-1.0.0}"
build_number="${BUILD_NUMBER:-1}"
bundle_id="${BUNDLE_ID:-io.github.chenmou2012.Gal4Mac}"
engine_dir="${ENGINE_DIR:-}"
output_dir="${OUTPUT_DIR:-$repo_root/dist-release}"
sign_identity="${SIGN_IDENTITY:--}"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "VERSION must be in major.minor.patch form" >&2
    exit 1
fi
if [[ ! "$build_number" =~ ^[1-9][0-9]*$ ]]; then
    echo "BUILD_NUMBER must be a positive integer" >&2
    exit 1
fi
if [[ -n "$engine_dir" && ( ! -f "$engine_dir/Properties.plist" || ! -x "$engine_dir/wine/bin/wine64" ) ]]; then
    echo "ENGINE_DIR must contain Properties.plist and executable wine/bin/wine64" >&2
    exit 1
fi

cd "$repo_root"
swift build -c release --product Gal4MacApp

architecture="$(uname -m)"
name="Gal4Mac-$version-macos-$architecture"
app="$output_dir/$name.app"
dmg="$output_dir/$name.dmg"
staging="$(mktemp -d "${TMPDIR:-/tmp}/gal4mac-release.XXXXXX")"
trap 'rm -rf "$staging"' EXIT

mkdir -p "$output_dir"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp ".build/release/Gal4MacApp" "$app/Contents/MacOS/Gal4Mac"
cp LICENSE "$app/Contents/Resources/Gal4Mac-LICENSE"
if [[ -n "$engine_dir" ]]; then
    ditto "$engine_dir" "$app/Contents/Resources/Engine"
    # Some installed Engine versions contain dangling framework header links.
    # They cannot be used at runtime and make macOS resource sealing fail.
    find -L "$app/Contents/Resources/Engine" -type l -exec rm -- {} +
fi

cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
<key>CFBundleDisplayName</key><string>Gal4Mac</string>
<key>CFBundleExecutable</key><string>Gal4Mac</string>
<key>CFBundleIdentifier</key><string>$bundle_id</string>
<key>CFBundleName</key><string>Gal4Mac</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>$build_number</string>
<key>LSApplicationCategoryType</key><string>public.app-category.games</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
EOF
plutil -lint "$app/Contents/Info.plist"

if [[ "$sign_identity" == "-" ]]; then
    codesign --force --deep --sign - "$app"
else
    codesign --force --deep --options runtime --timestamp --sign "$sign_identity" "$app"
fi
codesign --verify --deep --strict --verbose=2 "$app"

ditto "$app" "$staging/Gal4Mac.app"
ln -s /Applications "$staging/Applications"
rm -f "$dmg"
hdiutil create -quiet -volname "Gal4Mac $version" -srcfolder "$staging" -format UDZO -o "$dmg"
hdiutil verify "$dmg"
if [[ "$sign_identity" != "-" ]]; then
    codesign --force --timestamp --sign "$sign_identity" --identifier "$bundle_id.disk-image" "$dmg"
    codesign --verify --verbose=2 "$dmg"
fi
shasum -a 256 "$dmg" > "$dmg.sha256"
echo "Created $dmg"
echo "SHA-256: $(cat "$dmg.sha256")"
