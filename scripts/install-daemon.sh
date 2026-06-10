#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL=com.skopetskyi.wakeguardd
BIN=/usr/local/libexec/wakeguardd
PLIST=/Library/LaunchDaemons/$LABEL.plist
LEASE_DIR=/usr/local/var/wakeguard

swift build -c release --product wakeguardd

sudo mkdir -p /usr/local/libexec "$LEASE_DIR"
sudo cp .build/release/wakeguardd "$BIN"
sudo chown root:wheel "$BIN"
sudo chmod 755 "$BIN"

# The app (running as the login user) writes the lease without root;
# the daemon (root) only reads it.
sudo chown "$(whoami)":staff "$LEASE_DIR"
sudo chmod 755 "$LEASE_DIR"

sudo cp daemon/$LABEL.plist "$PLIST"
sudo chown root:wheel "$PLIST"
sudo chmod 644 "$PLIST"

sudo launchctl bootout system/$LABEL 2>/dev/null || true
sudo launchctl bootstrap system "$PLIST"
sudo launchctl print system/$LABEL | head -5
echo "wakeguardd installed and running. Log: /var/log/wakeguardd.log"
