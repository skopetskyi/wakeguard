# Design: Presence / keep-awake mechanism redesign

**Date:** 2026-06-22
**Status:** Approved (pre-implementation) — no code changes yet.

## Problem

The "Simulate Activity (Keep Slack/Teams Active)" feature posts a synthetic key
every 60 s to reset the idle timer. This approach has failed in two ways:

1. **F15** worked (reset the idle timer) but is the keyboard's *brightness-up*
   key, so it popped the brightness HUD every minute.
2. **F16–F19** are *unmapped* keys. macOS appears to drop them without counting
   them as genuine user activity, so they did **not** keep the Mac awake.

Separately, a behavior bug was found in **closed-lid mode**: it currently asserts
"keep the display awake" by default (via `caffeinate -d`), which is pointless when
the lid is shut.

## Key insight

"Keep the Mac awake" and "keep Slack/Teams green" are **two different problems**:

- **Stay awake** is best solved by a **power assertion** (what `caffeinate` does).
  It cannot fail and needs no Accessibility permission.
- **Presence** (Slack/Teams green) genuinely needs a **real input event** to reset
  the HID idle timer that presence apps read.

The redesign decouples them.

## Goals

- Simulate Activity reliably keeps the Mac awake **and** keeps Slack/Teams active.
- No brightness/volume HUD, no typed character, no net cursor movement.
- Closed-lid mode lets the display sleep.

## Non-goals

- Keeping the display *off* while presence is active — impossible, because any
  real input event (required for presence) also resets the display idle timer.
- Clamshell-with-external-monitor "keep external display on" — explicitly traded
  away (see closed-lid decision).

## Design

### 1. Keep-awake: power assertion (guaranteed)

While Simulate Activity is on, hold a system-sleep assertion by spawning
`caffeinate -i -w <app-pid>` (no `-t`, runs until toggled off), reusing the
existing `CaffeinateSpawner` / `ProcessSpawning` seam.

- `-i` prevents idle **system** sleep; `-w <app-pid>` ties it to the app's life
  (crash-safe — dies with the app, like the session caffeinate).
- Needs **no** Accessibility permission, so the Mac stays awake even if presence
  permission is missing.
- AppDelegate holds the returned `CaffeinateProcess`; terminates it when the
  toggle goes off and on quit / SIGTERM.

### 2. Presence: net-zero mouse nudge (replaces the key tap)

`CGActivityEmitter.emit()` stops posting a key and instead:

1. reads the current cursor location,
2. posts a `mouseMoved` event 1px away,
3. posts a `mouseMoved` event back to the exact original location.

Mouse movement is the most reliable "user is active" signal for both the system
idle timer and presence apps. Net-zero displacement (the flick is microseconds),
no HUD, no character. The `ActivitySimulator` 60 s timer and the `ActivityEmitter`
protocol seam are unchanged. Edge case: if the cursor is at the right screen edge,
nudge by -1px instead (or rely on macOS clamping) so the return position is exact.

### 3. Retire the key picker

The selectable-key feature is obsolete (the nudge takes no parameter). Remove:

- `Sources/WakeGuardCore/PresenceKey.swift` and `Tests/.../PresenceKeyTests.swift`
- the "Activity Key" submenu (`MenuBuilder.activityKeyMenuItem`, `activityKeyID`)
- `AppDelegate.loadActivityKey` / `selectActivityKey` and the `activityKeyID`
  UserDefaults plumbing
- `menuSelectActivityKey`

The green "● Active" menu-bar label and the Simulate Activity toggle stay as-is.

### 4. Closed-lid mode always allows display sleep

In `CaffeinateCommand.arguments`, only add `-d` when the display policy is
`.keepOn` **and** the lid policy is **not** `.stayAwakeWhenClosed`:

```swift
if config.displayPolicy == .keepOn && config.lidPolicy != .stayAwakeWhenClosed {
    args.append("-d")
}
```

So a closed-lid session never asserts display-stay-awake; the display can sleep
while the daemon keeps the system awake with the lid shut. (Trade-off accepted: an
external display in clamshell can also sleep.)

### 5. Lifecycle wiring

| Event | Action |
|---|---|
| Toggle Simulate Activity ON | start keep-awake `caffeinate -i -w`; start `ActivitySimulator` (immediate nudge) |
| Toggle Simulate Activity OFF | terminate keep-awake process; stop simulator |
| Quit / SIGTERM / SIGINT | terminate keep-awake process; stop simulator (alongside existing session cleanup) |

## Components & files

- **Modify** `Sources/WakeGuardCore/CaffeinateCommand.swift` — closed-lid omits `-d`.
- **Modify** `Tests/WakeGuardCoreTests/CaffeinateCommandTests.swift` — add a test
  that closed-lid + keepOn produces no `-d`.
- **Modify** `Sources/WakeGuardApp/ActivityEmitterCG.swift` — mouse nudge.
- **Modify** `Sources/WakeGuardApp/AppDelegate.swift` — hold the keep-awake
  process; start/stop it with the toggle and on quit; remove key-picker code.
- **Modify** `Sources/WakeGuardApp/MenuBuilder.swift` — remove the Activity Key
  submenu + `activityKeyID` + `menuSelectActivityKey`.
- **Remove** `Sources/WakeGuardCore/PresenceKey.swift`,
  `Tests/WakeGuardCoreTests/PresenceKeyTests.swift`.
- **Modify** `Sources/WakeGuardApp/main.swift` — stop the keep-awake process on
  signal quit.
- **Docs** — update vault (`Activity Simulation`, `Overview & Architecture`),
  `README.md`, and the original plan note.

## Testing

- **Core (TDD):** `CaffeinateCommand` test — closed-lid + `.keepOn` ⇒ no `-d`.
- `ActivitySimulator` tests unchanged (the emit seam is unchanged).
- Remove `PresenceKey` tests.
- Mouse-nudge emitter and keep-awake process are app-level side effects
  (not unit-tested, consistent with the rest of the app target).
- **Manual verification (user):** with Simulate Activity on, the Mac does not
  sleep and Slack/Teams stay green; no HUD appears; closing the lid in closed-lid
  mode lets the display sleep.

## Known limitations

- Presence still requires Accessibility / Input Monitoring permission; keep-awake
  no longer does.
- While presence is active, the mouse nudge keeps the display on (inherent — any
  presence-keeping input wakes the display).
