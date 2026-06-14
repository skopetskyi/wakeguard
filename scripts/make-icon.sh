#!/bin/bash
# Regenerate app/AppIcon.icns from scripts/make-icon.swift.
# Run this only when changing the icon design; the committed .icns is what
# build-app.sh ships, so end users never need to run this.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)/WakeGuard.iconset"
PREVIEW="/tmp/wakeguard-icon-preview.png"
trap 'rm -rf "$(dirname "$WORK")"' EXIT

swift scripts/make-icon.swift "$WORK" "$PREVIEW"
iconutil -c icns "$WORK" -o app/AppIcon.icns
echo "Built app/AppIcon.icns ($(du -h app/AppIcon.icns | cut -f1)); preview at $PREVIEW"
