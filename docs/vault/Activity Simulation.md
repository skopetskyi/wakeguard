# Activity Simulation

**Simulate Activity (Keep Slack/Teams Active)** keeps the Mac awake **and** keeps
presence tools showing you as active, for a duration you choose. **On-demand** — a
menu submenu, **off by default**, **independent of any keep-awake session**.

It does two decoupled things while on:

## 1. Keep awake — power assertion (guaranteed)

`AppDelegate.startPresenceKeepAwake()` spawns `caffeinate -i -w <app-pid>` (via the
existing `CaffeinateSpawner`). `-i` prevents idle **system** sleep; `-w` ties it to
the app so it dies with us (crash-safe). This needs **no Accessibility permission**.

## 2. Keep presence — net-zero volume tap

- While on, `ActivitySimulator` fires a `Timer` **every 60 s** (and once
  immediately) on the main run loop.
- Each tick, `VolumeTapActivityEmitter` taps **volume-down then volume-up**
  (net-zero volume) via the system media-key path (NSEvent → CGEvent →
  `.cghidEventTap`).
- A media-key press is a real, fully-processed input event — it resets the system
  idle timer and Slack/Teams reliably count it as activity. It deliberately flashes
  the **volume HUD** (the visible cue that it fired). Net-zero in the normal range;
  at the extremes the volume may drift one step.

> Earlier mechanisms failed: F15 popped the brightness HUD; unmapped F16–F19 and a
> net-zero **mouse nudge** weren't counted as activity and let the Mac/presence go
> idle. The volume tap (which we confirmed Slack/Teams honour) replaced them.

## Duration ("sleep timer") + on-screen countdown

Pick how long to stay active from the **Simulate Activity** submenu: presets
(15 min … 8 h), **Custom…**, or **Until I turn it off**. A timed run **auto-stops**
at the deadline — stopping the volume tap and releasing the assertion so the Mac can
sleep normally.

While active, the menu bar shows a green countdown **`● H:MM:SS`** (or **`● Active`**
when indefinite), updated every second, so the active state is obvious at a glance.
See [[UI & Dock Behavior]].

`ActivitySimulator.start()` is idempotent; `stop()` halts it. The core uses an
injected `ActivityEmitter` protocol so it is unit-tested with a fake (the real
media-key poster lives in the app target).

## Permission

The **volume tap** needs **Accessibility** (or Input Monitoring) permission:
System Settings → Privacy & Security. Without it, macOS **silently filters** the
events and presence won't update — but the **power assertion still keeps the Mac
awake**. The first time you enable it, the app shows a one-time hint.

## Trade-offs (current behavior)

- The volume tap flashes the **volume HUD** each minute (intended — that HUD is the
  activity Slack/Teams count) and resets the **display** idle timer, so the display
  stays on while active.
- **No battery auto-stop** — only keep-awake sessions have the
  [[Safety Policies|battery guards]]. Use a duration, or turn it off when done,
  especially on battery. The green countdown is your at-a-glance reminder.
