#!/bin/bash
# Emergency: restore normal sleep no matter what state app/daemon are in.
# Safe to run any time, repeatedly.
rm -f /usr/local/var/wakeguard/lease.json
sudo pmset -a disablesleep 0
pmset -g | grep -i sleepdisabled || echo "SleepDisabled not set (normal sleep active)"
echo "Sleep restored."
