# Safety Policies

All app-side safety rules live in one pure function, `SafetyPolicy.evaluate(...)`,
which returns `.ok`, `.warn(reason)`, or `.endSession(reason)`. `SafetyMonitor`
polls **every 15 s** during a session and acts on the verdict.

## Inputs

- **Battery** — `pmset -g batt` parsed into source (AC/battery) + percent.
  Unreadable output is treated as **on battery, unknown percent** (cautious).
- **Thermal** — `ProcessInfo.thermalState` (nominal / fair / serious / critical).
- **Elapsed** session time, the **lid policy**, and whether the session
  **started on AC**.

## Rules (current)

| Condition | Verdict |
|---|---|
| Thermal **critical** | **End** any session |
| Thermal **serious** | **Warn** |
| Closed-lid, on battery, **< 30 %** | **End** ("below threshold") |
| Closed-lid, on battery, **percent unreadable** | **End** |
| Closed-lid, **> 12 h** elapsed | **End** (hard cap) |
| Closed-lid, AC disconnected (was on AC) | **Warn** (or End if configured) |
| Low battery while on **AC** | OK |
| Normal-lid session | battery rules ignored (only thermal applies) |

Thresholds (`SafetyLimits`): soft battery **30 %**, hard floor **15 %**, max
closed-lid duration **12 h**. The 15 % hard floor is *also* enforced independently
by the root daemon (see [[Closed-Lid Mode]]).

## Pre-flight refusals

Starting a **closed-lid** session is refused up front if:
- thermal state is **critical**, or
- on battery with **< 30 %** or an unreadable level.

On battery above 30 %, it starts with a notification that it will auto-stop below
30 %.

## Layered defense

1. `caffeinate -w <pid>` dies with the app (see [[Keep-Awake Sessions]]).
2. The [[Closed-Lid Mode|lease]] expires within ~35 s of any failure.
3. The daemon reverts on start, on SIGTERM, and below 15 %.
4. These app-side policies end/warn early.
5. `panic-restore-sleep.sh` is the manual escape hatch.
