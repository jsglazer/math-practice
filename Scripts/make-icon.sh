#!/bin/bash
#
# make-icon.sh — (re)generate the Assets.xcassets/AppIcon.appiconset PNGs from
# the rendered base glyph. Run this only when you want to change the artwork;
# the appiconset is checked in, so a normal packaging run (make-dmg.sh) does
# not need it. Uses only swift + sips (both built into macOS).
#
set -euo pipefail
cd "$(dirname "$0")/.."

APPICONSET="Sources/MathPracticeApp/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$APPICONSET"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> rendering base icon"
swift Scripts/makeicon.swift "$TMP/icon_1024.png"

echo "==> scaling appiconset members"
sips -z 16 16   "$TMP/icon_1024.png" --out "$APPICONSET/icon_16x16.png"      >/dev/null
sips -z 32 32   "$TMP/icon_1024.png" --out "$APPICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32   "$TMP/icon_1024.png" --out "$APPICONSET/icon_32x32.png"      >/dev/null
sips -z 64 64   "$TMP/icon_1024.png" --out "$APPICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128 "$TMP/icon_1024.png" --out "$APPICONSET/icon_128x128.png"    >/dev/null
sips -z 256 256 "$TMP/icon_1024.png" --out "$APPICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$TMP/icon_1024.png" --out "$APPICONSET/icon_256x256.png"    >/dev/null
sips -z 512 512 "$TMP/icon_1024.png" --out "$APPICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$TMP/icon_1024.png" --out "$APPICONSET/icon_512x512.png"    >/dev/null
cp              "$TMP/icon_1024.png"        "$APPICONSET/icon_512x512@2x.png"

cat > "$APPICONSET/Contents.json" <<'JSON'
{
  "images" : [
    { "idiom" : "mac", "size" : "16x16",   "scale" : "1x", "filename" : "icon_16x16.png" },
    { "idiom" : "mac", "size" : "16x16",   "scale" : "2x", "filename" : "icon_16x16@2x.png" },
    { "idiom" : "mac", "size" : "32x32",   "scale" : "1x", "filename" : "icon_32x32.png" },
    { "idiom" : "mac", "size" : "32x32",   "scale" : "2x", "filename" : "icon_32x32@2x.png" },
    { "idiom" : "mac", "size" : "128x128", "scale" : "1x", "filename" : "icon_128x128.png" },
    { "idiom" : "mac", "size" : "128x128", "scale" : "2x", "filename" : "icon_128x128@2x.png" },
    { "idiom" : "mac", "size" : "256x256", "scale" : "1x", "filename" : "icon_256x256.png" },
    { "idiom" : "mac", "size" : "256x256", "scale" : "2x", "filename" : "icon_256x256@2x.png" },
    { "idiom" : "mac", "size" : "512x512", "scale" : "1x", "filename" : "icon_512x512.png" },
    { "idiom" : "mac", "size" : "512x512", "scale" : "2x", "filename" : "icon_512x512@2x.png" }
  ],
  "info" : { "version" : 1, "author" : "xcode" }
}
JSON

echo "wrote $APPICONSET"
