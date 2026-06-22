# WakeGuard

Personal macOS keep-awake tool. Menu bar app + root daemon.

📖 Full behavior docs live in the Obsidian vault at [`docs/vault/`](docs/vault/Home.md)
(open the folder as a vault in Obsidian, or read the Markdown directly).

## What it does
- Keep the Mac awake for a chosen duration (presets or custom minutes).
- Optionally let the display sleep while the system stays awake ("Allow Display to Sleep"),
  plus a "Turn Display Off Now" action.
- Optionally keep the Mac awake **with the lid closed** ("Keep Awake When Lid Closed") —
  requires the wakeguardd daemon. Closed-lid mode lets the **display sleep** (a shut lid
  has no display), regardless of the "Allow Display to Sleep" toggle.
- Keep presence tools (Slack, Teams) showing active — see below.
- The Dock icon and menu-bar cup are always present while WakeGuard runs; the
  countdown-timer badge on the Dock icon appears only during an active session.
- Only one instance runs at a time (an `flock` guard plus `LSMultipleInstancesProhibited`).

## Keep Slack/Teams active

The **"Simulate Activity (Keep Slack/Teams Active)"** menu checkbox does two
independent things while it's on:

1. **Keeps the Mac awake** by holding a power assertion (`caffeinate -i -w`). This
   is guaranteed and needs **no permission** — the Mac stays awake even if the step
   below is blocked.
2. **Keeps presence active** with a **net-zero mouse nudge** every 60 seconds: the
   cursor moves 1px and immediately back to the exact same spot. Mouse movement is
   the most reliable "user is active" signal, so it resets the system idle timer
   that Slack (~10 min) and Teams (~5 min) read. No HUD, no character, no net cursor
   movement.

- **Off by default.** Toggle it independently of any keep-awake session.

**Trade-offs to be aware of:**
- The mouse nudge resets the display idle timer too, so the display won't sleep
  while presence is active — keeping Slack/Teams green inherently needs a real
  input event, and that wakes the display.
- The **presence** nudge needs **Accessibility** / **Input Monitoring** permission
  (System Settings → Privacy & Security). If it's missing, presence won't update —
  but **the Mac still stays awake** via the power assertion.

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
    ./scripts/install-daemon.sh       # one-time, needs sudo (only for closed-lid mode)
    .build/release/WakeGuardApp &     # quick CLI launch

## Open it like a normal app (no terminal)
Build a double-clickable `WakeGuard.app` bundle:

    ./scripts/build-app.sh --install   # builds the bundle and copies it to ~/Applications

Then launch **WakeGuard** from Launchpad / Spotlight, or drag it onto the Dock to
keep a one-click launcher there. (Omit `--install` to leave `WakeGuard.app` in the
repo folder so you can drag it wherever you like.)

WakeGuard shows a **Dock icon whenever it is running**, plus a cup in the **menu
bar**. The countdown-timer badge on the Dock icon appears only while a keep-awake
session is active; when idle, the Dock icon is just present. Launching WakeGuard a
second time does nothing — only one instance can run at a time.

To launch automatically at login: System Settings → General → Login Items → **+** →
pick `WakeGuard.app`.

Note: the bundle is ad-hoc signed, so after a `./scripts/build-app.sh` rebuild macOS
may ask you to re-grant Accessibility for activity simulation.

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
- The `WakeGuard.app` bundle ships a custom heartbeat icon (`app/AppIcon.icns`,
  regenerate with `./scripts/make-icon.sh`) and uses osascript notifications.
