#!/usr/bin/env bash
# Builds CutX.app from the SwiftPM product. Ad-hoc signed — good enough to run
# locally. scripts/sign-and-notarize.sh produces the distributable build.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-release}"
APP="$ROOT/dist/CutX.app"

cd "$ROOT"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/CutX"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/CutX"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp -R "$ROOT/Resources/sounds" "$APP/Contents/Resources/sounds"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"

# Localized strings. Lookup stays on the plain Bundle APIs because the .lproj
# directories sit where a real app bundle keeps them.
for lproj in "$ROOT"/Resources/*.lproj; do
    [[ -d "$lproj" ]] || continue
    cp -R "$lproj" "$APP/Contents/Resources/"
done

# Prefer the Developer ID identity when it is available, even for local builds.
# Ad-hoc signatures change on every rebuild, and macOS treats a changed signature
# as a different app — which silently revokes the Accessibility permission and
# makes every rebuild require re-granting it by hand.
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -o 'Developer ID Application: [^"]*' | head -1)"
if [[ -z "$IDENTITY" ]]; then
    IDENTITY="-"
    echo "note: no Developer ID identity found, signing ad-hoc"
fi

codesign --force --sign "$IDENTITY" \
    --entitlements "$ROOT/Resources/CutX.entitlements" \
    --options runtime \
    "$APP"

echo "Built $APP"
