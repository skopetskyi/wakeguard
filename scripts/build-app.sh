#!/bin/bash
# Build a double-clickable WakeGuard.app bundle from the SPM executable.
# Usage:
#   ./scripts/build-app.sh            # build ./WakeGuard.app in the repo
#   ./scripts/build-app.sh --install  # also copy it to ~/Applications (no sudo)
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="WakeGuard"
EXEC_NAME="WakeGuardApp"          # inner binary name — matches existing docs/scripts
BUNDLE="$APP_NAME.app"
BIN_SRC=".build/release/$EXEC_NAME"

echo "Building release binary…"
swift build -c release --product "$EXEC_NAME"

echo "Assembling $BUNDLE…"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$BIN_SRC" "$BUNDLE/Contents/MacOS/$EXEC_NAME"
chmod +x "$BUNDLE/Contents/MacOS/$EXEC_NAME"
cp app/Info.plist "$BUNDLE/Contents/Info.plist"
mkdir -p "$BUNDLE/Contents/Resources"
cp app/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"

# Sign with the stable self-signed identity if it exists (run
# scripts/make-signing-cert.sh once to create it), so the Accessibility grant
# PERSISTS across rebuilds. Otherwise fall back to ad-hoc — which changes every
# build, so you must re-grant Accessibility after each rebuild.
IDENTITY="WakeGuard Self-Signed"
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
    codesign --force --sign "$IDENTITY" "$BUNDLE" >/dev/null 2>&1 \
        && echo "Signed with stable identity \"$IDENTITY\" (grant persists across rebuilds)." \
        || echo "warning: signing with \"$IDENTITY\" failed — falling back to ad-hoc" \
           && codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || true
else
    codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || \
        echo "warning: codesign unavailable — bundle is unsigned (still runnable locally)"
    echo "Note: ad-hoc signed — re-grant Accessibility after this rebuild, or run"
    echo "      ./scripts/make-signing-cert.sh once so the grant persists."
fi

if [[ "${1:-}" == "--install" ]]; then
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
    rm -rf "$DEST/$BUNDLE"
    cp -R "$BUNDLE" "$DEST/"
    echo "Installed to $DEST/$BUNDLE"
    echo "Open it from Launchpad/Spotlight (\"WakeGuard\"), or drag it to the Dock."
else
    echo "Built ./$BUNDLE"
    echo "Double-click it in Finder to launch, drag it to /Applications or the Dock,"
    echo "or run: ./scripts/build-app.sh --install   (copies to ~/Applications)"
fi
