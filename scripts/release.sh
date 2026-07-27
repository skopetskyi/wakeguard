#!/bin/bash
# Build → sign (Developer ID + hardened runtime) → NOTARIZE → staple a
# distributable WakeGuard.app: the build that opens with no warning on any Mac
# and whose Accessibility grant persists across versions.
#
# One-time prerequisites (see docs/DISTRIBUTION.md):
#   1. A "Developer ID Application" certificate in your login keychain.
#   2. Notary credentials stored once under a keychain profile:
#        xcrun notarytool store-credentials wakeguard-notary \
#          --apple-id "<you@example.com>" --team-id "<TEAMID>" \
#          --password "<app-specific-password>"
#
# Env overrides:
#   WAKEGUARD_SIGN_ID         full identity string (else auto-detected)
#   WAKEGUARD_NOTARY_PROFILE  keychain profile name (default: wakeguard-notary)
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="WakeGuard"; EXEC_NAME="WakeGuardApp"; BUNDLE="$APP_NAME.app"
NOTARY_PROFILE="${WAKEGUARD_NOTARY_PROFILE:-wakeguard-notary}"

SIGN_ID="${WAKEGUARD_SIGN_ID:-}"
if [ -z "$SIGN_ID" ]; then
    SIGN_ID="$(security find-identity -v -p codesigning \
        | grep 'Developer ID Application' | head -1 \
        | sed -E 's/^[^"]*"([^"]+)".*$/\1/')"
fi
if [ -z "$SIGN_ID" ]; then
    echo "ERROR: no 'Developer ID Application' certificate found in your keychain."
    echo "Create one: Xcode → Settings → Accounts → (your team) → Manage Certificates"
    echo "            → + → Developer ID Application. Then re-run this script."
    exit 1
fi
echo "Signing identity: $SIGN_ID"

echo "Building release binary…"
swift build -c release --product "$EXEC_NAME"

echo "Assembling $BUNDLE…"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp ".build/release/$EXEC_NAME" "$BUNDLE/Contents/MacOS/$EXEC_NAME"
chmod +x "$BUNDLE/Contents/MacOS/$EXEC_NAME"
cp app/Info.plist "$BUNDLE/Contents/Info.plist"
cp app/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"

echo "Signing (Developer ID + hardened runtime + secure timestamp)…"
codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$BUNDLE"
codesign --verify --strict --verbose=2 "$BUNDLE"

echo "Zipping for notarization…"
ZIP="$APP_NAME.zip"; rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$BUNDLE" "$ZIP"

echo "Submitting to Apple notary service (this waits — usually a few minutes)…"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "Stapling the notarization ticket onto the app…"
xcrun stapler staple "$BUNDLE"
xcrun stapler validate "$BUNDLE"
echo "Gatekeeper assessment:"; spctl -a -vvv "$BUNDLE" || true

echo "Re-zipping the STAPLED app for distribution…"
rm -f "$ZIP"; ditto -c -k --sequesterRsrc --keepParent "$BUNDLE" "$ZIP"

echo
echo "Done — notarized + stapled:"
echo "  ./$BUNDLE   (drag to /Applications; opens with no warning on any Mac)"
echo "  ./$ZIP      (upload this to a GitHub Release for friends)"
