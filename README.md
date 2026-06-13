# WakeGuard

Personal macOS keep-awake tool. Menu bar app + root daemon.

## What it does
- Keep the Mac awake for a chosen duration (presets or custom minutes).
- Optionally let the display sleep while the system stays awake ("Allow Display to Sleep"),
  plus a "Turn Display Off Now" action.
- Optionally keep the Mac awake **with the lid closed** ("Keep Awake When Lid Closed") —
  requires the wakeguardd daemon.
- Keep presence tools (Slack, Teams) showing active — see below.
- Dock icon + countdown badge appear ONLY while a session is active.

## Keep Slack/Teams active

The **"Simulate Activity (Keep Slack/Teams Active)"** menu checkbox posts an
invisible F15 key down+up event every 60 seconds via CoreGraphics. F15 has no
default binding on modern Mac keyboards, so the keypress is a no-op for the
user; it does, however, register as HID user activity, resetting the system
idle timer that presence tools (Slack, Teams, etc.) rely on to decide when to
show you as away.

- **Off by default.** Toggle it independently of any keep-awake session — you
  can run it with or without an active WakeGuard session.
- **60-second cadence** — well under Teams' ~5-minute and Slack's ~10-minute
  away thresholds.

**Trade-offs to be aware of:**
- The F15 event resets the display idle timer, so it can wake the display. If
  you have "Allow Display to Sleep" enabled, or you've just used "Turn Display
  Off Now", the screen will briefly wake every 60 seconds. Don't combine these
  with activity simulation if you want the display to stay dark.
- On first use macOS may prompt for **Accessibility** or **Input Monitoring**
  permission so that WakeGuard can post synthetic input events. Grant it in
  System Settings → Privacy & Security.

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
