#!/usr/bin/env bash
# Builds and signs CutX for the Mac App Store, producing dist/CutX.pkg.
#
# This differs from scripts/build-app.sh in three ways, all of them required by
# the store and none of them optional:
#   1. App Sandbox is on (Resources/CutX-AppStore.entitlements).
#   2. Signing uses the Apple Distribution certificate, not Developer ID.
#   3. The result is a signed .pkg installer, not a .zip.
#
# Requires, from developer.apple.com:
#   - "Apple Distribution" certificate in the login keychain
#   - "3rd Party Mac Developer Installer" certificate in the login keychain
#   - A Mac App Store provisioning profile for com.helalrules.CutX,
#     saved as Resources/CutX_AppStore.provisionprofile
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/CutX.app"
PKG="$ROOT/dist/CutX.pkg"
PROFILE="$ROOT/Resources/CutX_AppStore.provisionprofile"
ENTITLEMENTS="$ROOT/Resources/CutX-AppStore.entitlements"

fail() { echo "error: $*" >&2; exit 1; }

APP_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -o 'Apple Distribution: [^"]*' | head -1 || true)"
[[ -n "$APP_IDENTITY" ]] || fail "no 'Apple Distribution' certificate in the keychain.
  Create one at developer.apple.com > Certificates, download it, and double-click it."

PKG_IDENTITY="$(security find-identity -v 2>/dev/null \
    | grep -o '3rd Party Mac Developer Installer: [^"]*' | head -1 || true)"
[[ -n "$PKG_IDENTITY" ]] || fail "no '3rd Party Mac Developer Installer' certificate.
  Create one at developer.apple.com > Certificates > Mac Installer Distribution."

[[ -f "$PROFILE" ]] || fail "missing $PROFILE
  Create a Mac App Store provisioning profile for com.helalrules.CutX and save it there."

"$ROOT/scripts/build-app.sh" release

echo "==> Embedding the provisioning profile"
cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"

# A profile downloaded through a browser carries com.apple.quarantine, and the
# attribute travels with the copy. The App Store rejects any bundle containing it
# (error 91109), so strip extended attributes from the whole app before signing —
# signing after this point is what makes the cleaned bundle valid.
echo "==> Stripping extended attributes"
xattr -cr "$APP"

echo "==> Signing sandboxed with $APP_IDENTITY"
codesign --force --deep --timestamp \
    --sign "$APP_IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    --options runtime \
    "$APP"

echo "==> Verifying the sandbox is actually on"
codesign -d --entitlements - "$APP" 2>/dev/null \
    | grep -q "com.apple.security.app-sandbox" \
    || fail "the sandbox entitlement did not make it onto the bundle"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Building the installer package"
rm -f "$PKG"
productbuild --component "$APP" /Applications \
    --sign "$PKG_IDENTITY" \
    "$PKG"

echo
echo "Built $PKG"
echo "Upload it with:"
echo "  xcrun altool --upload-app -f \"$PKG\" -t macos --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>"
echo "or open Transporter.app and drag it in."
