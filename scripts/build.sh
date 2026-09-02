#!/bin/bash
#
# build.sh — RunCat preservation rebuild
#
# Assembles RunCat.app from the SPM release binary without requiring a
# full Xcode installation (Command Line Tools only).
#
#   1. swift build -c release          → .build/release/RunCat
#   2. hand-assemble RunCat.app bundle:
#        Contents/MacOS/RunCat         (binary)
#        Contents/Info.plist           (from Resources/Info.plist)
#        Contents/Resources/           (cat frames, icns icon, .lproj strings)
#   3. ad-hoc codesign (optional, forced)
#
# The script is idempotent: it wipes previous products and rebuilds.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="RunCat"
APP_BUNDLE="$REPO_ROOT/$APP_NAME.app"
PLIST="$REPO_ROOT/Resources/Info.plist"

echo "==> [1/4] swift build -c release"
cd "$REPO_ROOT"
swift build -c release

BINARY="$(swift build -c release --show-bin-path)/RunCat"
if [ ! -x "$BINARY" ]; then
    echo "error: built binary not found at $BINARY" >&2
    exit 1
fi

echo "==> [2/4] assembling $APP_NAME.app bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$PLIST"  "$APP_BUNDLE/Contents/Info.plist"

# Animation frames: loaded at runtime from the bundle Resources
# directory (see AppDelegate.swift) — no asset-catalog compiler needed.
for n in 0 1 2 3 4; do
    cp "$REPO_ROOT/Resources/Assets.xcassets/cat-page-$n.imageset/cat-page-$n@1x.png" \
       "$APP_BUNDLE/Contents/Resources/cat-page-$n.png"
done

# App icon: convert the original 1024px PNG to an .icns via iconset.
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
ICON_PNG="$REPO_ROOT/Resources/Assets.xcassets/AppIcon.appiconset/Icon-App-512x512@2x.png"
if [ ! -f "$ICON_PNG" ]; then
    echo "error: $ICON_PNG not found" >&2
    exit 1
fi
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Localized menu strings (.lproj folders from Resources/)
for lproj in "$REPO_ROOT"/Resources/*.lproj; do
    if [ -d "$lproj" ]; then
        cp -R "$lproj" "$APP_BUNDLE/Contents/Resources/"
    fi
done

echo "==> [3/4] ad-hoc codesign"
codesign --force --sign - "$APP_BUNDLE"

echo "==> [4/4] done"
echo
echo "App bundle: $APP_BUNDLE"
echo "Run with:   open $APP_BUNDLE"
