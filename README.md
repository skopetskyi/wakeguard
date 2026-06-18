# WakeGuard

Personal macOS keep-awake tool. Menu bar app + root daemon.

📖 Full behavior docs live in the Obsidian vault at [`docs/vault/`](docs/vault/Home.md)
(open the folder as a vault in Obsidian, or read the Markdown directly).

## What it does
- Keep the Mac awake for a chosen duration (presets or custom minutes).
- Optionally let the display sleep while the system stays awake ("Allow Display to Sleep"),
  plus a "Turn Display Off Now" action.
- Optionally keep the Mac awake **with the lid closed** ("Keep Awake When Lid Closed") —
  requires the wakeguardd daemon.
- Keep presence tools (Slack, Teams) showing active — see below.
- The Dock icon and menu-bar cup are always present while WakeGuard runs; the
  countdown-timer badge on the Dock icon appears only during an active session.
- Only one instance runs at a time (an `flock` guard plus `LSMultipleInstancesProhibited`).

## Keep Slack/Teams active

The **"Simulate Activity (Keep Slack/Teams Active)"** menu checkbox taps a no-op
key every 60 seconds via CoreGraphics. The key types no character, shows no
on-screen HUD, and doesn't move the cursor — but it still registers as HID user
activity, resetting the system idle timer that presence tools (Slack, Teams, etc.)
rely on to decide when to show you as away.

Pick the key from the **Activity Key** submenu (choice saved across launches):
- **Function keys (default F16):** F16, F13, F17, F18, F19 — recommended,
  collision-free.
- **Modifier keys:** Left/Right Control, Option, Shift, Command — handy if you
  want to avoid the function row, but watch for clashes with your own shortcuts.

F14/F15 (brightness), Caps Lock, fn/Globe, and character/media keys are excluded
because they type or pop their own HUD. (F15 was the original default — it's the
brightness-up key, which is why you saw the brightness HUD.)

- **Off by default.** Toggle it independently of any keep-awake session — you
  can run it with or without an active WakeGuard session.
- **60-second cadence** — well under Teams' ~5-minute and Slack's ~10-minute
  away thresholds.

**Trade-offs to be aware of:**
- The synthetic key event resets the display idle timer, so it can wake the display. If
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
