# Build, Install & Scripts

## Build & test

```bash
swift build            # debug build
swift test             # 50 unit tests (WakeGuardCore)
```

Targets macOS 13+, Swift 5.9 language mode. Apple Silicon (M-series); rebuilding
from source handles any M3/M5 difference automatically.

## Make the double-clickable app

```bash
./scripts/build-app.sh             # builds ./WakeGuard.app (ad-hoc signed)
./scripts/build-app.sh --install   # also copies it to ~/Applications
```

- Bundle id `com.skopetskyi.wakeguard`, executable `WakeGuardApp`, heartbeat icon
  `app/AppIcon.icns`.
- Launch from Launchpad/Spotlight, or drag to the Dock. Add to **Login Items** to
  start at login.
- Ad-hoc signing note: after a rebuild, macOS may ask you to re-grant
  [[Activity Simulation|Accessibility]].

## App icon

Custom heartbeat icon, generated (no design tools):

```bash
./scripts/make-icon.sh             # regenerates app/AppIcon.icns
```

Source: `scripts/make-icon.swift` draws it with AppKit/CoreGraphics at every size.

## Root daemon (only for [[Closed-Lid Mode]])

```bash
./scripts/install-daemon.sh        # one-time, sudo
./scripts/uninstall-daemon.sh      # remove it, restore sleep
```

- Installs `wakeguardd` to `/usr/local/libexec`, the plist to
  `/Library/LaunchDaemons`, and the lease dir to `/usr/local/var/wakeguard`.
- The basic keep-awake and [[Activity Simulation]] features do **not** need this.

## Emergency

```bash
./scripts/panic-restore-sleep.sh   # restore normal sleep no matter the state
```

## Permissions summary

| For… | Grant |
|---|---|
| [[Activity Simulation]] | Accessibility / Input Monitoring (one-time) |
| [[Closed-Lid Mode]] daemon install | sudo password (one-time) |

## Install on another Mac

Copy the repo (or `git clone`), then `./scripts/build-app.sh --install`. Build
artifacts (`.build/`, `WakeGuard.app/`) are git-ignored and regenerated — never
copy them between machines (they bake in absolute paths / architecture).
