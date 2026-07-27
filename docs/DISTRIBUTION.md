# Distributing WakeGuard (Developer ID + notarization)

Goal: a build that friends can double-click on any Mac — **no "unidentified
developer" wall, no `xattr`, and the Accessibility grant persists across updates.**

This uses **Developer ID + notarization** (direct distribution), **not** the App
Store. Notarization is an automated malware/signing scan (minutes, no human
review) — it can only *fail mechanically* (with a log telling you why), never get
"rejected" editorially.

## One-time setup

### 1. Create a Developer ID Application certificate
Xcode → **Settings → Accounts** → select your team → **Manage Certificates** →
**+** → **Developer ID Application**. It lands in your login keychain.
Verify: `security find-identity -v -p codesigning` should now list
`Developer ID Application: … (KV6685TGN9)`.

### 2. Create an app-specific password
[appleid.apple.com](https://appleid.apple.com) → **Sign-In and Security → App-Specific
Passwords** → generate one (e.g. name it "wakeguard-notary"). Copy it.

### 3. Store notary credentials once (in the keychain)
```bash
xcrun notarytool store-credentials wakeguard-notary \
  --apple-id "dskopetskiy@gmail.com" \
  --team-id "KV6685TGN9" \
  --password "<the app-specific password from step 2>"
```

## Each release

```bash
./scripts/release.sh
```
It builds, signs (Developer ID + hardened runtime + timestamp), submits to Apple,
waits for notarization, staples the ticket, and produces:
- `WakeGuard.app` — drag to /Applications; opens clean.
- `WakeGuard.zip` — upload to a GitHub Release for friends.

Verify locally: `spctl -a -vvv WakeGuard.app` → *"accepted, source=Notarized
Developer ID"*.

## Distributing to friends
Attach `WakeGuard.zip` to a **GitHub Release** (tag e.g. `v1.0`). Friends download,
unzip, drag to Applications, open — no warning. To update, ship a new Release; they
download the new zip (Accessibility stays granted because the Developer ID is the
same).

## Notes
- **Hardened runtime** doesn't restrict WakeGuard: posting volume/mouse/key events
  and requesting Accessibility are runtime TCC grants (no entitlement needed), and
  spawning `caffeinate`/`pmset`/`osascript` is allowed.
- **Closed-lid daemon** (`wakeguardd`) is compiled locally by `install-daemon.sh`,
  so it isn't downloaded/quarantined and needs no notarization.
- Local dev builds still use `./scripts/build-app.sh` (ad-hoc / self-signed);
  `release.sh` is only for distributable builds.
