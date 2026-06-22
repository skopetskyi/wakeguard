# Closed-Lid Mode

**Keep Awake When Lid Closed** keeps the Mac running with the lid shut. Because
this overrides a hardware-level sleep, it is built around a **dead-man's switch**
so normal sleep is restored automatically if anything goes wrong.

> Requires the **`wakeguardd`** root daemon to be installed
> (see [[Build, Install & Scripts]]). Without it, the app warns
> **"NOT SAFE TO CLOSE LID"**.

**Display:** closed-lid sessions always let the display sleep — a shut lid has no
display. `CaffeinateCommand` omits `-d` whenever the lid policy is
`stayAwakeWhenClosed`, regardless of the "Allow Display to Sleep" toggle. (The
daemon's `disablesleep` keeps the *system* awake; it never forces the display on.)

## The lease (dead-man's switch)

- The app writes a **lease file** at `/usr/local/var/wakeguard/lease.json`
  containing a session id, the app PID, an expiry timestamp, and the hard battery
  floor.
- **TTL 30 s**, **renewed every 10 s**. A lease is only valid if it expires in the
  future **and** no more than **60 s** out (sanity cap — a forged far-future expiry
  can't pin the Mac awake).
- The lease expiry is also clamped to the session end, so it never outlives the
  session.

## The daemon (`wakeguardd`, runs as root)

Polls **every 5 s**:
- desired = *(a valid, fresh lease exists)* **and** *(not below the hard battery
  floor, 15 %)*.
- If desired ≠ current state, it applies `pmset -a disablesleep 0/1`.

It also unconditionally reverts to `disablesleep 0`:
- **on every start** (boot / crash-restart reconciliation — `RunAtLoad` + `KeepAlive`),
- **on SIGTERM** (shutdown / `launchctl bootout`),
- **below the 15 % hard battery floor**, even with a valid lease.

## Why it fails safe

`disablesleep 1` exists **only** while a fresh lease exists. App crash, force-quit,
freeze, quit, reboot, or daemon crash all end with normal sleep restored within
**~35 s** (30 s TTL + 5 s poll). The daemon never trusts the app to behave.

## Verify-after-enable

8 s after starting a closed-lid session (the daemon polls every 5 s), the app
probes [[UI & Dock Behavior|SystemStatus]]; if `SleepDisabled` did not actually
become 1, it notifies **"NOT SAFE TO CLOSE LID"** (daemon missing / failed).

## Panic restore

`./scripts/panic-restore-sleep.sh` restores normal sleep with no app involvement
(also quits a live app so it can't re-create the lease). See
[[Build, Install & Scripts]].

Battery and thermal limits that can end a session early live in
[[Safety Policies]].
