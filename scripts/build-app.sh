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

codesign --force --sign - \
    --entitlements "$ROOT/Resources/CutX.entitlements" \
    --options runtime \
    "$APP"

echo "Built $APP"
