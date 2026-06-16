# UI & Dock Behavior

## Menu bar (always present)

A cup icon (`NSStatusItem`) is always in the menu bar while WakeGuard runs.
Clicking it opens the menu:

- **Start Session** (presets + Custom…) when idle, or **Stop Session** +
  a truth-from-system status line when active.
- **Allow Display to Sleep** (toggle).
- **Keep Awake When Lid Closed** (toggle).
- **Simulate Activity (Keep Slack/Teams Active)** (toggle).
- **Turn Display Off Now**.
- **Quit WakeGuard**.

Icon states (via `refreshStatusIcon()`):
- **Idle** → outline cup. **Active session** → filled cup.
- **Activity simulation on** → a green **"● Active"** label beside the cup
  (an `attributedTitle`; the green is reliable, unlike `contentTintColor` on a
  template image, which macOS ignores). See [[Activity Simulation]].

## Dock (icon always, badge only when active)

- The app runs with a **regular** activation policy, so the **Dock icon is always
  present** (the heartbeat `AppIcon`). `LSUIElement` is **not** set.
- The **countdown-timer badge** on the Dock icon appears **only while a session is
  active** (updated every second to `H:MM` remaining) and is cleared the moment
  the session ends.

## Truth-from-system status line

While a session is active, the menu shows what the system actually reports
(`SystemStatus.probe()` reading `pmset -g assertions` and `pmset -g`):
`awake ✓`, `closed-lid ✓ (SleepDisabled 1)`, or a ⚠️ warning on mismatch. See
[[Closed-Lid Mode]].

## Single instance

Only one WakeGuard runs at a time:
- `SingleInstanceGuard` takes an advisory **`flock`** on
  `~/Library/Application Support/WakeGuard/instance.lock`. The kernel releases it
  on process exit (clean, crash, or kill) — no stale lock.
- The `.app` bundle also sets **`LSMultipleInstancesProhibited`** for the
  Finder/open path.
- A second launch posts **"WakeGuard is already running"** and exits.

## Quit paths (all clean up)

- **Menu Quit** → `applicationWillTerminate` → stop session + stop simulator.
- **SIGTERM / SIGINT** (Activity Monitor quit, Ctrl-C) → handler stops both, exits.
- **SIGKILL** → no handler needed: `caffeinate -w` dies with the app and the lease
  expires within ~35 s.

Notifications are posted via osascript ([[Overview & Architecture|Notify]]).
