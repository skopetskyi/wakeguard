# Activity Simulation

**Simulate Activity (Keep Slack/Teams Active)** keeps the Mac awake **and** keeps
presence tools showing you as active. **On-demand** — a menu checkbox, **off by
default**, **independent of any keep-awake session**.

It does two decoupled things while on:

## 1. Keep awake — power assertion (guaranteed)

`AppDelegate.startPresenceKeepAwake()` spawns `caffeinate -i -w <app-pid>` (via the
existing `CaffeinateSpawner`). `-i` prevents idle **system** sleep; `-w` ties it to
the app so it dies with us (crash-safe). This needs **no Accessibility permission**,
so the Mac stays awake even if the presence step below is blocked. Stopped when you
toggle off and on quit / SIGTERM.

## 2. Keep presence — net-zero mouse nudge

- While on, `ActivitySimulator` fires a `Timer` **every 60 s** (and once
  immediately) on the main run loop.
- Each tick, `ActivityEmitterCG` reads the cursor position and posts two
  `mouseMoved` `CGEvent`s to `.cghidEventTap`: 1px away, then straight back to the
  exact original point.
- Mouse movement is the most reliable "user is active" signal, so it resets the
  system idle timer Slack (~10 min) and Teams (~5 min) read — with **no HUD, no
  character, and no net cursor movement** (60 s is well under the ~5 min threshold).

> Earlier approaches used a synthetic key (F15 popped the brightness HUD; unmapped
> F16–F19 weren't counted as activity and didn't keep the Mac awake). The mouse
> nudge plus the power assertion replaced them. See
> `docs/plans/2026-06-22-presence-keepawake-redesign-design.md`.

`ActivitySimulator.start()` is idempotent; `stop()` halts it. The core uses an
injected `ActivityEmitter` protocol so it is unit-tested with a fake (the real
`CGEvent` poster lives in the app target).

## Indicator

While active, the menu bar shows a green **"● Active"** label next to the cup
(an `attributedTitle` — see [[UI & Dock Behavior]]). This is reliable, unlike
tinting the template icon (which macOS ignores).

## Permission

The **presence nudge** needs **Accessibility** (or Input Monitoring) permission:
System Settings → Privacy & Security. Without it, macOS **silently filters** the
mouse events and presence won't update — but the **power assertion still keeps the
Mac awake**. The first time you enable the toggle, the app shows a one-time hint.

## Trade-offs (current behavior)

- The mouse nudge also resets the **display** idle timer, so the display won't
  sleep while presence is active — keeping Slack/Teams green inherently needs a
  real input event, and that wakes the display.
- **No battery auto-stop** is applied to this toggle — only keep-awake sessions
  have the [[Safety Policies|battery guards]]. Turn it off when you don't need it,
  especially on battery. The green label is your at-a-glance reminder.
