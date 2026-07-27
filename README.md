# WakeGuard

Personal macOS keep-awake tool. Menu bar app + root daemon.

📖 Full behavior docs live in the Obsidian vault at [`docs/vault/`](docs/vault/Home.md)
(open the folder as a vault in Obsidian, or read the Markdown directly).

## What it does
- Keep the Mac awake for a chosen duration (presets or custom minutes).
- Optionally let the display sleep while the system stays awake ("Allow Display to Sleep"),
  plus a "Turn Display Off Now" action.
- Optionally keep the Mac awake **with the lid closed** ("Keep Awake When Lid Closed") —
  requires the wakeguardd daemon. Closed-lid mode keeps an **external display on** if one
  is connected (clamshell), and lets the display sleep otherwise (bare shut lid).
- Keep presence tools (Slack, Teams) showing active — see below.
- The Dock icon and menu-bar cup are always present while WakeGuard runs; the
  countdown-timer badge on the Dock icon appears only during an active session.
- Only one instance runs at a time (an `flock` guard plus `LSMultipleInstancesProhibited`).

## Keep Slack/Teams active

The **"Simulate Activity (Keep Slack/Teams Active)"** menu does two independent
things while it's on:

1. **Keeps the Mac awake** by holding a power assertion (`caffeinate -i -w`). This
   is guaranteed and needs **no permission** — the Mac stays awake even if step 2 is
   blocked.
2. **Keeps presence active** with a **net-zero volume tap** every 60 seconds:
   volume-down then volume-up, so the level is unchanged but the **volume HUD blips**.
   A media-key press is a real, fully-processed input event, so Slack/Teams reliably
   count it as activity (after a mouse nudge proved too subtle to register).

It's a plain **on/off** toggle (off by default) — runs until you turn it off, with a
green **`● Active`** label in the menu bar while on. To sleep the Mac after a while,
use the separate **Sleep Timer** below.

**Trade-offs to be aware of:**
- The volume tap flashes the volume HUD each minute (intended) and resets the
  display idle timer, so the display stays on while active.
- The **presence** tap needs **Accessibility** / **Input Monitoring** permission
  (System Settings → Privacy & Security). If it's missing, presence won't update —
  but **the Mac still stays awake** via the power assertion. Use **Test Activity
  (blip now)** in the menu to check: you should see the volume HUD flash; if not,
  the app tells you the permission is missing and pops the grant dialog.
- **Pick the method** from **Activity Method ▸**: Volume tap (default, shows the
  HUD), Mouse nudge (silent), or F16/F17/F18/F19 (silent). All need Accessibility.
- **Grant keeps resetting on rebuild?** The ad-hoc signature changes each
  `build-app.sh`, which invalidates the Accessibility grant — the toggle can even
  look "on" while the new binary no longer matches. Permanent fix: run
  **`./scripts/make-signing-cert.sh`** once (creates a stable self-signed identity
  the build signs with), then `tccutil reset Accessibility com.skopetskyi.wakeguard`
  and grant once — it now persists across rebuilds.

## Sleep Timer
A separate countdown that **puts the Mac to sleep** when it reaches zero. From the
menu, **Sleep Timer ▸** → pick a duration (or Custom). The menu bar shows an orange
**`💤 H:MM:SS`** countdown; when it elapses, WakeGuard stops activity simulation,
ends any keep-awake session, and runs `pmset sleepnow`. **Cancel Sleep Timer** stops
it early. (No sudo or daemon needed — it's a user-initiated sleep.)

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
