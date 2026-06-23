# Overview & Architecture

WakeGuard keeps a Mac awake for a chosen duration — optionally with the display
off, optionally with the lid closed — and can simulate user activity so presence
tools stay active. It **fails safe**: normal sleep behavior is restored on any
app exit, crash, daemon restart, reboot, or low battery.

## Three components (Swift Package, no Xcode project)

1. **`WakeGuardCore`** — pure logic, fully unit-tested (50 tests). No AppKit.
   - `SessionConfig` — a session = duration + display policy + lid policy.
   - `CaffeinateCommand` — builds the `caffeinate` argv.
   - `Shell` — the one place external commands run; returns `""` on failure.
   - `PMSetParser` — reads `SleepDisabled` from `pmset -g` (absent line = false).
   - `BatteryStatus` / `BatteryStatusParser` — parses `pmset -g batt` (fail-safe).
   - `Lease` / `LeaseStore` — the dead-man's-switch model (see [[Closed-Lid Mode]]).
   - `SafetyPolicy` — pure verdict function (see [[Safety Policies]]).
   - `SessionController` — start/stop sessions, renew leases, end timer.
   - `ActivitySimulator` — timer that drives an injected emitter (see [[Activity Simulation]]).
   - `SingleInstanceGuard` — advisory `flock` so only one instance runs.
2. **`WakeGuardApp`** — the AppKit menu-bar app.
   - `AppDelegate` — status item, Dock policy, wiring, the icon/label.
   - `MenuBuilder` — menu construction + the toggle actions.
   - `SafetyMonitor` — 15 s poll feeding `SafetyPolicy`.
   - `SystemStatus` — truth-from-system probe (assertions + `SleepDisabled`).
   - `VolumeTapActivityEmitter` — posts the real net-zero volume-key media events.
   - `Notify` — osascript notifications.
3. **`wakeguardd`** — a tiny **root LaunchDaemon** that flips `pmset disablesleep`
   for closed-lid mode, governed entirely by the lease file.

## Tech stack

- Swift 6 toolchain in Swift 5 language mode (`// swift-tools-version:5.9`).
- AppKit (`NSStatusItem`, `NSApp.dockTile`), Foundation `Process`, XCTest, launchd.
- Targets macOS 13+. Developed/verified on Apple Silicon (M-series).

## Dependency / data flow

```
Menu toggle ─► AppDelegate ─► SessionController ─► caffeinate (-w app pid)
                                   │
                                   └─► LeaseStore ─► lease.json ◄─ wakeguardd (root) ─► pmset disablesleep
ActivitySimulator ─► ActivityEmitterCG ─► CGEvent (selected key) ─► resets HID idle timer
```

See [[Build, Install & Scripts]] to build and run it.
