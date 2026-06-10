# WakeGuard

Personal macOS keep-awake tool. Menu bar app + root daemon.

## What it does
- Keep the Mac awake for a chosen duration (presets or custom minutes).
- Optionally let the display sleep while the system stays awake ("Allow Display to Sleep"),
  plus a "Turn Display Off Now" action.
- Optionally keep the Mac awake **with the lid closed** ("Keep Awake When Lid Closed") —
  requires the wakeguardd daemon.
- Dock icon + countdown badge appear ONLY while a session is active.

## Fail-safe design
Closed-lid mode works through a dead-man's switch: the app must renew a 30-second
lease every 10 seconds; the root daemon enables `pmset disablesleep` only while a
fresh lease exists. App crash, force-quit, freeze, quit, reboot, daemon crash —
all of them end with normal sleep restored within ~35 seconds, plus:
- daemon reverts on every start (boot reconciliation) and on SIGTERM,
- daemon force-reverts below a 15% hard battery floor,
- app refuses/ends closed-lid sessions below 30% battery (on battery), at
  critical thermal state, or past 12 hours; serious thermal state warns,
- app verifies the system state 8s after enabling and warns "NOT SAFE TO CLOSE LID"
  if disablesleep didn't engage; the menu shows what `pmset` actually reports.

## Install
    swift build -c release
    ./scripts/install-daemon.sh       # one-time, needs sudo
    .build/release/WakeGuardApp &     # or add to Login Items

## Emergency
If anything ever looks wrong:
    ./scripts/panic-restore-sleep.sh
(The script also quits a running WakeGuardApp — a live app would otherwise
re-create the lease and the daemon would re-enable disablesleep.)

## Uninstall
    ./scripts/uninstall-daemon.sh

## Known trade-offs (personal-use scope)
- While installed, wakeguardd owns `disablesleep`: manual `sudo pmset -a disablesleep 1`
  changes are reverted within ~5s unless a fresh lease exists.
- The lease directory is writable by the login user, so any process running as
  you could keep the Mac awake. Acceptable single-user trade-off; the daemon
  only reads timestamps/ints from the lease and caps grants at 60s.
- Unbundled binary: generic dock icon, osascript notifications. A proper .app
  bundle with a custom icon is a possible later improvement.
