# Activity Simulation

**Simulate Activity (Keep Slack/Teams Active)** keeps presence tools showing you
as active by periodically resetting the system idle timer. **On-demand** — a menu
checkbox, **off by default**, and **independent of any keep-awake session**.

## How it works

- While on, `ActivitySimulator` fires a `Timer` **every 60 s** (and once
  immediately) on the main run loop.
- Each tick, `ActivityEmitterCG` posts an **invisible F15 key** down+up via
  `CGEvent` (virtual key `0x71`) to `.cghidEventTap`, using a
  `CGEventSource(stateID: .hidSystemState)`.
- F15 has no default binding on Mac keyboards → a no-op for you, but macOS records
  it as **HID user activity**, resetting the system idle timer that Slack
  (~10 min) and Teams (~5 min) read to decide when to mark you away.
- 60 s sits comfortably under the tightest (~5 min) threshold.

`ActivitySimulator.start()` is idempotent; `stop()` halts it; it's stopped on quit
and on SIGTERM/SIGINT. The core uses an injected `ActivityEmitter` protocol so it
is unit-tested with a fake (the real `CGEvent` poster lives in the app target).

## Indicator

While active, the menu bar shows a green **"● Active"** label next to the cup
(an `attributedTitle` — see [[UI & Dock Behavior]]). This is reliable, unlike
tinting the template icon (which macOS ignores).

## Permission

Posting synthetic events needs **Accessibility** (or Input Monitoring) permission:
System Settings → Privacy & Security → Accessibility. Without it, macOS **silently
filters** the events and presence won't hold. The first time you enable the toggle,
the app shows a one-time hint about this.

## Trade-offs (current behavior)

- The F15 event also resets the **display** idle timer, so it can **wake the
  display**. Don't combine it with "Allow Display to Sleep" / "Turn Display Off
  Now" if you want the screen to stay dark.
- Because it resets the system idle timer, it incidentally **keeps the Mac awake**
  too (like a light `caffeinate`).
- **No battery auto-stop** is applied to this toggle — only keep-awake sessions
  have the [[Safety Policies|battery guards]]. Turn it off when you don't need it,
  especially on battery. The green label is your at-a-glance reminder.
