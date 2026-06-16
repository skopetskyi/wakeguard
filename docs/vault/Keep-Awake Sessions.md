# Keep-Awake Sessions

The core feature: keep the Mac awake for a chosen duration.

## Starting a session

From the menu bar cup → **Start Session**:
- Presets: **15, 30, 60, 120, 240, 480 minutes**.
- **Custom…** prompts for any number of minutes.

A session is described by [[Overview & Architecture|SessionConfig]]: duration +
display policy + lid policy.

## How "awake" is enforced

`SessionController` spawns `/usr/bin/caffeinate` with:

```
caffeinate -i [-d] -t <seconds> -w <app-pid>
```

- **`-i`** — prevent idle **system** sleep (always present).
- **`-d`** — prevent **display** sleep. Present unless "Allow Display to Sleep"
  is ticked.
- **`-t <seconds>`** — best-effort timeout (belt-and-braces only).
- **`-w <app-pid>`** — ties the assertion to the app process. **If the app dies
  for any reason, the assertion dies with it.** This is the primary crash-safety
  mechanism for normal (non-closed-lid) sessions.

The **authoritative** duration is the app's own end `Timer`, not `caffeinate -t`
(some macOS versions ignore `-t` when `-w` is present).

## Display options

- **Allow Display to Sleep** (toggle) — drops `-d`; the system stays awake while
  the display may sleep. Persists across menu rebuilds.
- **Turn Display Off Now** — runs `pmset displaysleepnow`; the Mac stays awake
  (music/SSH keep going), the screen goes dark immediately.

## Ending a session

A session ends — terminating `caffeinate`, clearing any [[Closed-Lid Mode|lease]],
and posting a notification — on any of:
- the duration end timer firing,
- **Stop Session** from the menu,
- quitting the app (menu Quit, SIGTERM/SIGINT) — see [[UI & Dock Behavior]],
- a [[Safety Policies|safety verdict]] (battery/thermal/duration),
- starting a **new** session (it replaces the active one).

While a session runs, the menu-bar cup is filled and the Dock shows a countdown
badge — see [[UI & Dock Behavior]].
