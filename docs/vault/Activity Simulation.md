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
  immediately); each tick calls `ConfigurableActivityEmitter`, which posts to
  `.cghidEventTap` using the selected **Activity Method** (`PresenceMethods`):
  - **Volume tap** (default) — net-zero volume-down/up via the media-key path;
    flashes the **volume HUD**, the visible cue that it fired.
  - **Mouse nudge** — net-zero 1px move; silent, no HUD.
  - **F16 / F17 / F18 / F19** — an unmapped function-key tap; silent, no HUD.
- Pick the method from **Activity Method ▸** (saved across launches in UserDefaults
  `activityMethodID`). Switching while running restarts the loop so it applies at
  once. Modifier keys (⌘/⇧/⌃/fn) and F14/F15 are excluded — they clash with
  shortcuts or pop the brightness HUD.

> All methods need Accessibility permission; the volume HUD is the easiest way to
> *see* whether events are getting through. Use **Test Activity (blip now)**.

## On/off + indicator

Simulate Activity is a plain **on/off** menu toggle — it runs until you turn it off.
While on, the menu bar shows a green **`● Active`** label. (If you want the Mac to
sleep after a while, that's the separate [[Sleep Timer]] feature.)

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
