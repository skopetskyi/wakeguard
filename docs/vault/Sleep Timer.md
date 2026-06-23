# Sleep Timer

A standalone countdown that **puts the Mac to sleep** when it reaches zero —
independent of [[Activity Simulation]] and [[Keep-Awake Sessions]].

## How it works

- From the menu, **Sleep Timer ▸** → pick a duration (15 min … 8 h) or **Custom…**.
- A one-shot `Timer` counts down; the menu bar shows an orange **`💤 H:MM:SS`**
  countdown (updated every second, alongside the green `● Active` label if activity
  simulation is also on).
- When it elapses, WakeGuard **winds down** any keep-awake intent first — it stops
  activity simulation and ends any keep-awake session — then runs
  `pmset sleepnow` to sleep the Mac. (Stopping those first means nothing immediately
  re-wakes or fights the sleep on the next wake.)
- **Cancel Sleep Timer** stops the countdown before it fires. Setting a new timer
  replaces any running one.

## Notes

- `pmset sleepnow` is a user-initiated sleep — no `sudo`, no daemon needed.
- It is a forced sleep, so it works even while a keep-awake assertion is held.
- The timer is in-memory: quitting WakeGuard cancels a pending sleep timer.
