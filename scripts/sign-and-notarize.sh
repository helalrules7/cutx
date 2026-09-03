#!/usr/bin/env bash
# Produces a distributable, notarized CutX.zip.
#
# Requires:
#   - "Developer ID Application: Ahmed Helal (T958VWM76Z)" in the login keychain
#   - notarytool keychain profile "cutX", created once with:
#       xcrun notarytool store-credentials "cutX" \
#         --apple-id <apple id> --team-id T958VWM76Z --password <app-specific password>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/CutX.app"
ZIP="$ROOT/dist/CutX.zip"
IDENTITY="Developer ID Application: Ahmed Helal (T958VWM76Z)"
PROFILE="cutX"

"$ROOT/scripts/build-app.sh" release

echo "==> Signing with Developer ID"
codesign --force --deep --timestamp \
    --sign "$IDENTITY" \
    --entitlements "$ROOT/Resources/CutX.entitlements" \
    --options runtime \
    "$APP"

echo "==> Verifying signature"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Zipping for submission"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Submitting to Apple (this takes a few minutes)"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait

echo "==> Stapling the ticket"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> Re-zipping the stapled app"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Final Gatekeeper check"
spctl --assess --type execute --verbose=4 "$APP"

echo "Done: $ZIP"
