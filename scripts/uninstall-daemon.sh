#!/bin/bash
set -euo pipefail
LABEL=com.skopetskyi.wakeguardd
sudo launchctl bootout system/$LABEL 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/$LABEL.plist /usr/local/libexec/wakeguardd
rm -f /usr/local/var/wakeguard/lease.json
sudo pmset -a disablesleep 0
echo "wakeguardd removed, sleep behavior restored."
