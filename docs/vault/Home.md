# WakeGuard — Documentation Vault

Personal macOS keep-awake + presence tool. Menu bar app, an optional root daemon
for closed-lid mode, and an on-demand activity simulator that keeps Slack/Teams
showing you as active.

> Open this folder in Obsidian via **Open folder as vault** → select
> `docs/vault`. These notes document the app's **current behavior** (not history).

## Map of content

- [[Overview & Architecture]] — what it is, the three components, tech stack.
- [[Keep-Awake Sessions]] — durations, display policy, how `caffeinate` is used.
- [[Closed-Lid Mode]] — the dead-man's-switch lease + root daemon.
- [[Activity Simulation]] — keep Slack/Teams green with synthetic activity.
- [[Safety Policies]] — battery, thermal, and duration guards.
- [[UI & Dock Behavior]] — menu bar, Dock icon, badge, single instance.
- [[Build, Install & Scripts]] — building the `.app`, the daemon, permissions.

## At a glance

| Feature | Needs daemon? | Needs Accessibility? |
|---|---|---|
| Keep awake (display on/off) | No | No |
| Turn display off now | No | No |
| Keep awake with **lid closed** | **Yes** (`wakeguardd`) | No |
| Simulate activity (Slack/Teams) | No | **Yes** |

## Verified facts

- Builds with the Swift 5.9 toolchain, targets macOS 13+. 50 unit tests pass.
- Single instance enforced; Dock icon always present; menu-bar cup always present.
