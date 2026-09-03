#!/usr/bin/env bash
# Generates Resources/AppIcon.icns. Re-run only when the icon design changes.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

swiftc -O "$ROOT/scripts/make-icon.swift" -o "$WORK/render"
"$WORK/render" "$WORK"

for pair in "16 16x16" "32 16x16@2x" "32 32x32" "64 32x32@2x" \
            "128 128x128" "256 128x128@2x" "256 256x256" "512 256x256@2x" \
            "512 512x512" "1024 512x512@2x"; do
    set -- $pair
    cp "$WORK/icon_$1.png" "$ICONSET/icon_$2.png"
done

iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"

# Keep the largest render around so the icon can be eyeballed without unpacking
# the .icns file.
cp "$WORK/icon_1024.png" "$ROOT/assets/app-icon-preview.png"

rm -rf "$WORK"
echo "wrote Resources/AppIcon.icns"
