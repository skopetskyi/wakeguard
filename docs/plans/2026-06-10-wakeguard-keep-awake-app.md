# WakeGuard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A personal macOS menu bar app that keeps the Mac awake for a chosen duration — optionally with the display off, optionally with the lid closed — and that fails safe: normal sleep behavior is restored automatically on any app exit, crash, daemon restart, reboot, or low battery.

**Architecture:** Three pieces. (1) `WakeGuardCore` — a pure-logic Swift library (command building, output parsing, lease model, safety policy) that is fully unit-tested. (2) `WakeGuardApp` — an AppKit menu bar app that wraps `/usr/bin/caffeinate` for normal keep-awake, shows a dock icon + badge only while a session is active, and runs safety monitoring. (3) `wakeguardd` — a tiny root LaunchDaemon that flips `pmset disablesleep` for closed-lid mode using a **dead-man's-switch lease file**: the app must renew a 30-second lease every 10 seconds; the moment the lease expires for ANY reason (crash, force-quit, freeze, quit), the daemon reverts `disablesleep` to 0 within its 5-second poll. The daemon also reverts on its own start (boot / restart reconciliation), on SIGTERM, and below a hard battery floor — so sleep restoration never depends on the app behaving well.

**Tech Stack:** Swift 6 toolchain in Swift 5 language mode (`// swift-tools-version:5.9`), Swift Package Manager (no Xcode project needed), AppKit (`NSStatusItem`, `NSApp.dockTile`), Foundation `Process` for shelling out to `caffeinate` / `pmset` / `osascript`, XCTest, launchd plist for the daemon. Verified on macOS 26.3.1.

**Environment facts (verified 2026-06-10 on the target machine):**
- `caffeinate`, `swift` 6.3.1 present; works unbundled from SPM build products.
- `pmset -g batt` first line: `Now drawing from 'AC Power'` or `Now drawing from 'Battery Power'`; battery line contains `100%;`.
- `pmset -g` prints **no** `SleepDisabled` line when sleep is not disabled — the parser must treat absence as `false`.
- This is a brand-new personal repo: plain `main` branch, conventional commits, no work-repo (BB-xxxx) conventions apply.

**Key safety invariants (every task must preserve these):**
1. `caffeinate` is always spawned with `-w <app pid>` → if the app dies, the idle-sleep assertion dies with it.
2. `disablesleep 1` exists ONLY while a fresh lease file exists. Lease TTL 30 s, renewed every 10 s, daemon polls every 5 s → worst-case ~35 s of stale wakefulness after a hard app crash.
3. The daemon sets `disablesleep 0` unconditionally on every start and on SIGTERM.
4. The daemon force-reverts below a hard battery floor (default 15 %) even with a valid lease.
5. The app refuses to start / auto-ends closed-lid sessions per the soft policy (battery < 30 % on battery power, thermal critical, 12 h hard cap).
6. A documented panic script restores sleep with no app involvement.

**File structure (final state):**

```
wakeguard/
├── Package.swift
├── README.md
├── daemon/com.skopetskyi.wakeguardd.plist
├── scripts/
│   ├── install-daemon.sh
│   ├── uninstall-daemon.sh
│   └── panic-restore-sleep.sh
├── Sources/
│   ├── WakeGuardCore/
│   │   ├── SessionConfig.swift        # session = duration + display policy + lid policy
│   │   ├── CaffeinateCommand.swift    # config -> caffeinate argv
│   │   ├── Shell.swift                # run external command, capture stdout
│   │   ├── PMSetParser.swift          # parse `pmset -g` SleepDisabled state
│   │   ├── BatteryStatus.swift        # parse `pmset -g batt`
│   │   ├── Lease.swift                # lease model + validity rules
│   │   ├── LeaseStore.swift           # atomic read/write/clear of lease.json
│   │   ├── SafetyPolicy.swift         # pure verdict function (ok/warn/end)
│   │   └── SessionController.swift    # start/stop sessions, renew leases, end timer
│   ├── wakeguardd/
│   │   └── main.swift                 # root daemon: reconcile-on-start, poll loop, SIGTERM revert
│   └── WakeGuardApp/
│       ├── main.swift                 # NSApplication bootstrap + signal handlers
│       ├── AppDelegate.swift          # status item, dock policy, wiring
│       ├── MenuBuilder.swift          # menu construction
│       ├── SafetyMonitor.swift        # 15 s poll: battery + thermal -> SafetyPolicy
│       ├── SystemStatus.swift         # truth-from-system: assertions + SleepDisabled
│       └── Notify.swift               # osascript notifications
├── Tests/WakeGuardCoreTests/
│   ├── CaffeinateCommandTests.swift
│   ├── PMSetParserTests.swift
│   ├── BatteryStatusTests.swift
│   ├── LeaseTests.swift
│   ├── SafetyPolicyTests.swift
│   └── SessionControllerTests.swift
└── docs/plans/2026-06-10-wakeguard-keep-awake-app.md   (this file)
```

**Constants used throughout (single source of truth — defined in Lease.swift and SafetyPolicy.swift in Tasks 5–6):** lease TTL 30 s, lease renew interval 10 s, lease sanity cap 60 s, daemon poll 5 s, hard battery floor 15 %, soft battery threshold 30 %, closed-lid hard cap 12 h, safety poll 15 s.

---

### Task 1: Project scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/WakeGuardCore/SessionConfig.swift` (placeholder content arrives in Task 2)
- Create: `Sources/wakeguardd/main.swift` (placeholder)
- Create: `Sources/WakeGuardApp/main.swift` (placeholder)
- Create: `Tests/WakeGuardCoreTests/CaffeinateCommandTests.swift` (placeholder)
- Create: `.gitignore`

- [ ] **Step 1: Create the package manifest**

`Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WakeGuard",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "WakeGuardCore"),
        .executableTarget(name: "wakeguardd", dependencies: ["WakeGuardCore"]),
        .executableTarget(name: "WakeGuardApp", dependencies: ["WakeGuardCore"]),
        .testTarget(name: "WakeGuardCoreTests", dependencies: ["WakeGuardCore"]),
    ]
)
```

- [ ] **Step 2: Create placeholder sources so the package builds**

`Sources/WakeGuardCore/SessionConfig.swift`:

```swift
// Replaced with real content in Task 2.
public enum WakeGuardCorePlaceholder {}
```

`Sources/wakeguardd/main.swift`:

```swift
// Replaced with real content in Task 7.
print("wakeguardd placeholder")
```

`Sources/WakeGuardApp/main.swift`:

```swift
// Replaced with real content in Task 10.
print("WakeGuardApp placeholder")
```

`Tests/WakeGuardCoreTests/CaffeinateCommandTests.swift`:

```swift
import XCTest

final class CaffeinateCommandTests: XCTestCase {
    func testPlaceholder() { XCTAssertTrue(true) }
}
```

`.gitignore`:

```
.build/
.swiftpm/
.DS_Store
```

- [ ] **Step 3: Verify the package builds and tests run**

Run: `cd /Users/skopetskyi/Desktop/Odeeo_Desktop/repos/wakeguard && swift test`
Expected: `Test Suite 'All tests' passed` with 1 test.

- [ ] **Step 4: Initialize git and commit**

```bash
cd /Users/skopetskyi/Desktop/Odeeo_Desktop/repos/wakeguard
git init -b main
git add -A
git commit -m "chore: scaffold WakeGuard SPM package with core/daemon/app targets"
```

---

### Task 2: SessionConfig + CaffeinateCommand

A session is fully described by duration, display policy, and lid policy. `CaffeinateCommand` turns that into `caffeinate` argv. Crash-safety note: `-w <pid>` ties the assertion to the app's lifetime (primary mechanism); `-t` is belt-and-braces (some macOS versions ignore `-t` when `-w` is present — the app's own end timer in Task 9 is the authoritative duration enforcement, so this doesn't matter).

**Files:**
- Modify: `Sources/WakeGuardCore/SessionConfig.swift` (replace placeholder)
- Create: `Sources/WakeGuardCore/CaffeinateCommand.swift`
- Modify: `Tests/WakeGuardCoreTests/CaffeinateCommandTests.swift` (replace placeholder)

- [ ] **Step 1: Write the failing tests**

`Tests/WakeGuardCoreTests/CaffeinateCommandTests.swift`:

```swift
import XCTest
@testable import WakeGuardCore

final class CaffeinateCommandTests: XCTestCase {
    func testKeepDisplayOnIncludesDisplayFlag() {
        let config = SessionConfig(duration: 3600, displayPolicy: .keepOn, lidPolicy: .normalSleep)
        XCTAssertEqual(CaffeinateCommand.arguments(for: config, appPID: 123),
                       ["-i", "-d", "-t", "3600", "-w", "123"])
    }

    func testAllowDisplayOffOmitsDisplayFlag() {
        let config = SessionConfig(duration: 900, displayPolicy: .allowOff, lidPolicy: .normalSleep)
        XCTAssertEqual(CaffeinateCommand.arguments(for: config, appPID: 7),
                       ["-i", "-t", "900", "-w", "7"])
    }

    func testClosedLidUsesSameCaffeinateArgs() {
        // disablesleep is handled by the daemon, not caffeinate — argv must not change.
        let config = SessionConfig(duration: 600, displayPolicy: .allowOff, lidPolicy: .stayAwakeWhenClosed)
        XCTAssertEqual(CaffeinateCommand.arguments(for: config, appPID: 7),
                       ["-i", "-t", "600", "-w", "7"])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: build FAILS with `cannot find 'SessionConfig' in scope`.

- [ ] **Step 3: Implement**

`Sources/WakeGuardCore/SessionConfig.swift` (replace entire file):

```swift
import Foundation

public struct SessionConfig: Equatable {
    public enum DisplayPolicy: Equatable {
        case keepOn     // prevent display sleep (caffeinate -d)
        case allowOff   // system stays awake, display may sleep
    }

    public enum LidPolicy: Equatable {
        case normalSleep          // closing the lid sleeps the Mac as usual
        case stayAwakeWhenClosed  // daemon sets pmset disablesleep while leased
    }

    public var duration: TimeInterval
    public var displayPolicy: DisplayPolicy
    public var lidPolicy: LidPolicy

    public init(duration: TimeInterval, displayPolicy: DisplayPolicy, lidPolicy: LidPolicy) {
        self.duration = duration
        self.displayPolicy = displayPolicy
        self.lidPolicy = lidPolicy
    }
}
```

`Sources/WakeGuardCore/CaffeinateCommand.swift`:

```swift
import Foundation

public enum CaffeinateCommand {
    public static let executablePath = "/usr/bin/caffeinate"

    public static func arguments(for config: SessionConfig, appPID: Int32) -> [String] {
        var args = ["-i"]
        if config.displayPolicy == .keepOn {
            args.append("-d")
        }
        args += ["-t", String(Int(config.duration)), "-w", String(appPID)]
        return args
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(core): session config and caffeinate argv builder"
```

---

### Task 3: Shell helper + PMSetParser

`Shell.run` is the one place that executes external commands (used by app and daemon). `PMSetParser` reads the `SleepDisabled` state out of `pmset -g` output — remember: **the line is absent entirely when sleep is not disabled**.

**Files:**
- Create: `Sources/WakeGuardCore/Shell.swift`
- Create: `Sources/WakeGuardCore/PMSetParser.swift`
- Create: `Tests/WakeGuardCoreTests/PMSetParserTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/WakeGuardCoreTests/PMSetParserTests.swift`:

```swift
import XCTest
@testable import WakeGuardCore

final class PMSetParserTests: XCTestCase {
    func testSleepDisabledOne() {
        let output = """
        System-wide power settings:
         SleepDisabled\t\t1
        Currently in use:
         standby              1
        """
        XCTAssertTrue(PMSetParser.sleepDisabled(fromPMSetG: output))
    }

    func testSleepDisabledZero() {
        let output = """
        System-wide power settings:
         SleepDisabled\t\t0
        Currently in use:
        """
        XCTAssertFalse(PMSetParser.sleepDisabled(fromPMSetG: output))
    }

    func testLineAbsentMeansNotDisabled() {
        // Verified on macOS 26.3.1: no SleepDisabled line at all when not set.
        let output = """
        Currently in use:
         standby              1
         sleep                1 (sleep prevented by powerd)
        """
        XCTAssertFalse(PMSetParser.sleepDisabled(fromPMSetG: output))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: build FAILS with `cannot find 'PMSetParser' in scope`.

- [ ] **Step 3: Implement**

`Sources/WakeGuardCore/PMSetParser.swift`:

```swift
import Foundation

public enum PMSetParser {
    /// Parses `pmset -g` output. The SleepDisabled line is absent when sleep
    /// is not disabled, so absence must read as false.
    public static func sleepDisabled(fromPMSetG output: String) -> Bool {
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("SleepDisabled") {
                return trimmed.hasSuffix("1")
            }
        }
        return false
    }
}
```

`Sources/WakeGuardCore/Shell.swift`:

```swift
import Foundation

public enum Shell {
    /// Runs an external command synchronously and returns its stdout.
    /// Returns "" on launch failure — callers treat that as "state unknown / false".
    @discardableResult
    public static func run(_ executable: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (6 tests total).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(core): shell runner and pmset SleepDisabled parser"
```

---

### Task 4: BatteryStatusParser

**Files:**
- Create: `Sources/WakeGuardCore/BatteryStatus.swift`
- Create: `Tests/WakeGuardCoreTests/BatteryStatusTests.swift`

- [ ] **Step 1: Write the failing tests** (sample outputs captured from the real machine)

`Tests/WakeGuardCoreTests/BatteryStatusTests.swift`:

```swift
import XCTest
@testable import WakeGuardCore

final class BatteryStatusTests: XCTestCase {
    func testACPowerFullCharge() {
        let output = """
        Now drawing from 'AC Power'
         -InternalBattery-0 (id=23068771)\t100%; charged; 0:00 remaining present: true
        """
        let status = BatteryStatusParser.parse(output)
        XCTAssertEqual(status, BatteryStatus(source: .ac, percent: 100))
    }

    func testBatteryPowerDischarging() {
        let output = """
        Now drawing from 'Battery Power'
         -InternalBattery-0 (id=23068771)\t57%; discharging; 4:12 remaining present: true
        """
        let status = BatteryStatusParser.parse(output)
        XCTAssertEqual(status, BatteryStatus(source: .battery, percent: 57))
    }

    func testDesktopWithoutBattery() {
        let output = "Now drawing from 'AC Power'\n"
        let status = BatteryStatusParser.parse(output)
        XCTAssertEqual(status, BatteryStatus(source: .ac, percent: nil))
    }

    func testGarbageOutputDefaultsToBatteryNoPercent() {
        // Fail-safe: if we cannot tell, assume the riskier state (on battery).
        let status = BatteryStatusParser.parse("")
        XCTAssertEqual(status, BatteryStatus(source: .battery, percent: nil))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: build FAILS with `cannot find 'BatteryStatusParser' in scope`.

- [ ] **Step 3: Implement**

`Sources/WakeGuardCore/BatteryStatus.swift`:

```swift
import Foundation

public struct BatteryStatus: Equatable {
    public enum Source: Equatable {
        case ac
        case battery
    }

    public var source: Source
    public var percent: Int?   // nil when no battery line is present (desktops, parse failure)

    public init(source: Source, percent: Int?) {
        self.source = source
        self.percent = percent
    }
}

public enum BatteryStatusParser {
    /// Parses `pmset -g batt` output. Unrecognized output is treated as
    /// "on battery, unknown percent" so safety checks err on the cautious side.
    public static func parse(_ output: String) -> BatteryStatus {
        let source: BatteryStatus.Source
        if output.contains("'AC Power'") {
            source = .ac
        } else {
            source = .battery
        }
        var percent: Int?
        if let range = output.range(of: #"(\d{1,3})%"#, options: .regularExpression) {
            percent = Int(output[range].dropLast())
        }
        return BatteryStatus(source: source, percent: percent)
    }

    /// Convenience for callers: shells out and parses.
    public static func current() -> BatteryStatus {
        parse(Shell.run("/usr/bin/pmset", ["-g", "batt"]))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (10 tests total).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(core): battery status parser with fail-safe defaults"
```

---

### Task 5: Lease + LeaseStore

The heart of the dead-man's switch. A lease is valid only if it expires in the future AND no further out than the 60 s sanity cap (a corrupted/forged far-future expiry must not pin the Mac awake).

**Files:**
- Create: `Sources/WakeGuardCore/Lease.swift`
- Create: `Sources/WakeGuardCore/LeaseStore.swift`
- Create: `Tests/WakeGuardCoreTests/LeaseTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/WakeGuardCoreTests/LeaseTests.swift`:

```swift
import XCTest
@testable import WakeGuardCore

final class LeaseTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    private func makeLease(expiresIn seconds: TimeInterval) -> Lease {
        Lease(sessionID: "test", appPID: 42,
              expiresAt: now.addingTimeInterval(seconds),
              hardBatteryFloorPercent: 15)
    }

    func testFreshLeaseIsValid() {
        XCTAssertTrue(makeLease(expiresIn: 30).isValid(now: now))
    }

    func testExpiredLeaseIsInvalid() {
        XCTAssertFalse(makeLease(expiresIn: -1).isValid(now: now))
    }

    func testFarFutureLeaseIsInvalid() {
        // Sanity cap: a lease must never grant more than 60 s of wakefulness.
        XCTAssertFalse(makeLease(expiresIn: 3600).isValid(now: now))
    }

    func testRoundTripsThroughStore() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wakeguard-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = LeaseStore(url: url)
        let lease = makeLease(expiresIn: 30)
        try store.write(lease)
        XCTAssertEqual(store.read(), lease)
        store.clear()
        XCTAssertNil(store.read())
    }

    func testGarbageFileReadsAsNil() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wakeguard-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not json".utf8).write(to: url)
        XCTAssertNil(LeaseStore(url: url).read())
    }

    func testMissingFileReadsAsNil() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wakeguard-test-\(UUID().uuidString).json")
        XCTAssertNil(LeaseStore(url: url).read())
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: build FAILS with `cannot find 'Lease' in scope`.

- [ ] **Step 3: Implement**

`Sources/WakeGuardCore/Lease.swift`:

```swift
import Foundation

/// A short-lived grant of "keep the Mac awake with the lid closed".
/// The app renews it every `renewInterval`; the daemon honors it only while
/// fresh. No fresh lease == normal sleep behavior, no matter why.
public struct Lease: Codable, Equatable {
    public var sessionID: String
    public var appPID: Int32
    public var expiresAt: Date
    public var hardBatteryFloorPercent: Int

    /// A lease may never grant more than this far into the future.
    public static let maxTTL: TimeInterval = 60
    /// TTL the app writes on each renewal.
    public static let ttl: TimeInterval = 30
    /// How often the app renews.
    public static let renewInterval: TimeInterval = 10
    /// Where app and daemon meet. Directory is user-owned (created by the
    /// installer); the daemon only reads timestamps/ints from it.
    public static let defaultPath = "/usr/local/var/wakeguard/lease.json"

    public init(sessionID: String, appPID: Int32, expiresAt: Date, hardBatteryFloorPercent: Int) {
        self.sessionID = sessionID
        self.appPID = appPID
        self.expiresAt = expiresAt
        self.hardBatteryFloorPercent = hardBatteryFloorPercent
    }

    public func isValid(now: Date) -> Bool {
        let remaining = expiresAt.timeIntervalSince(now)
        return remaining > 0 && remaining <= Lease.maxTTL
    }
}
```

`Sources/WakeGuardCore/LeaseStore.swift`:

```swift
import Foundation

public struct LeaseStore {
    public let url: URL

    public init(url: URL = URL(fileURLWithPath: Lease.defaultPath)) {
        self.url = url
    }

    public func write(_ lease: Lease) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(lease)
        try data.write(to: url, options: .atomic)
    }

    /// Any read problem (missing, unreadable, malformed) is nil — and nil
    /// always means "do not keep the Mac awake".
    public func read() -> Lease? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Lease.self, from: data)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (16 tests total).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(core): dead-man lease model and atomic lease store"
```

---

### Task 6: SafetyPolicy

One pure function holding every app-side safety rule, so each rule is a one-line test.

**Files:**
- Create: `Sources/WakeGuardCore/SafetyPolicy.swift`
- Create: `Tests/WakeGuardCoreTests/SafetyPolicyTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/WakeGuardCoreTests/SafetyPolicyTests.swift`:

```swift
import XCTest
@testable import WakeGuardCore

final class SafetyPolicyTests: XCTestCase {
    private let limits = SafetyLimits()

    private func verdict(battery: BatteryStatus = BatteryStatus(source: .ac, percent: 100),
                         thermal: SafetyThermalState = .nominal,
                         elapsed: TimeInterval = 60,
                         lid: SessionConfig.LidPolicy = .stayAwakeWhenClosed,
                         startedOnAC: Bool = true) -> SafetyVerdict {
        SafetyPolicy.evaluate(battery: battery, thermal: thermal, sessionElapsed: elapsed,
                              lidPolicy: lid, limits: limits, startedOnAC: startedOnAC)
    }

    func testHealthyClosedLidSessionContinues() {
        XCTAssertEqual(verdict(), .ok)
    }

    func testCriticalThermalEndsAnySession() {
        XCTAssertEqual(verdict(thermal: .critical, lid: .normalSleep),
                       .endSession("Thermal state is critical"))
    }

    func testSoftBatteryThresholdEndsClosedLidSession() {
        XCTAssertEqual(verdict(battery: BatteryStatus(source: .battery, percent: 29)),
                       .endSession("Battery at 29% (below 30% threshold)"))
    }

    func testUnknownBatteryPercentOnBatteryEndsClosedLidSession() {
        // Can't read the battery? Don't gamble with a closed lid.
        XCTAssertEqual(verdict(battery: BatteryStatus(source: .battery, percent: nil)),
                       .endSession("Battery level unreadable while on battery power"))
    }

    func testLowBatteryOnACIsFine() {
        XCTAssertEqual(verdict(battery: BatteryStatus(source: .ac, percent: 10)), .ok)
    }

    func testHardCapEndsClosedLidSession() {
        XCTAssertEqual(verdict(elapsed: limits.maxClosedLidDuration + 1),
                       .endSession("Maximum closed-lid duration (12h) reached"))
    }

    func testACDisconnectWarnsByDefault() {
        XCTAssertEqual(verdict(battery: BatteryStatus(source: .battery, percent: 80), startedOnAC: true),
                       .warn("AC power disconnected — now on battery (80%)"))
    }

    func testACDisconnectEndsSessionWhenConfigured() {
        var strict = SafetyLimits()
        strict.endOnACDisconnect = true
        let v = SafetyPolicy.evaluate(battery: BatteryStatus(source: .battery, percent: 80),
                                      thermal: .nominal, sessionElapsed: 60,
                                      lidPolicy: .stayAwakeWhenClosed, limits: strict, startedOnAC: true)
        XCTAssertEqual(v, .endSession("AC power disconnected"))
    }

    func testNormalLidSessionIgnoresBatteryRules() {
        XCTAssertEqual(verdict(battery: BatteryStatus(source: .battery, percent: 5), lid: .normalSleep,
                               startedOnAC: false), .ok)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: build FAILS with `cannot find 'SafetyLimits' in scope`.

- [ ] **Step 3: Implement**

`Sources/WakeGuardCore/SafetyPolicy.swift`:

```swift
import Foundation

public struct SafetyLimits: Equatable {
    /// App ends a closed-lid session below this percent while on battery.
    public var softBatteryPercent: Int = 30
    /// Daemon force-reverts below this percent even with a valid lease.
    public var hardBatteryFloorPercent: Int = 15
    /// No closed-lid session may run longer than this.
    public var maxClosedLidDuration: TimeInterval = 12 * 3600
    /// If true, losing AC power ends a closed-lid session instead of warning.
    public var endOnACDisconnect: Bool = false

    public init() {}
}

/// Mirror of ProcessInfo.ThermalState so core stays UI-framework-free and testable.
public enum SafetyThermalState: Equatable {
    case nominal, fair, serious, critical
}

public enum SafetyVerdict: Equatable {
    case ok
    case warn(String)
    case endSession(String)
}

public enum SafetyPolicy {
    public static func evaluate(battery: BatteryStatus,
                                thermal: SafetyThermalState,
                                sessionElapsed: TimeInterval,
                                lidPolicy: SessionConfig.LidPolicy,
                                limits: SafetyLimits,
                                startedOnAC: Bool) -> SafetyVerdict {
        if thermal == .critical {
            return .endSession("Thermal state is critical")
        }
        guard lidPolicy == .stayAwakeWhenClosed else { return .ok }

        if sessionElapsed > limits.maxClosedLidDuration {
            return .endSession("Maximum closed-lid duration (12h) reached")
        }
        if battery.source == .battery {
            guard let percent = battery.percent else {
                return .endSession("Battery level unreadable while on battery power")
            }
            if percent < limits.softBatteryPercent {
                return .endSession("Battery at \(percent)% (below \(limits.softBatteryPercent)% threshold)")
            }
            if startedOnAC {
                return limits.endOnACDisconnect
                    ? .endSession("AC power disconnected")
                    : .warn("AC power disconnected — now on battery (\(percent)%)")
            }
        }
        return .ok
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (25 tests total).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(core): safety policy with battery, thermal, and duration rules"
```

---

### Task 7: wakeguardd daemon

The root daemon. Behavior contract:
1. On start: `pmset -a disablesleep 0` unconditionally (reconciles stale state after crash, power loss, or reboot).
2. Every 5 s: desired = (lease exists ∧ valid ∧ not below hard battery floor). If desired ≠ current `SleepDisabled`, apply it.
3. On SIGTERM (launchctl bootout / shutdown): revert to 0, exit.
4. Lease file paranoia: only the timestamps/ints inside are consumed; `Lease.maxTTL` caps any grant; a regular-file check rejects symlink tricks.

**Files:**
- Modify: `Sources/wakeguardd/main.swift` (replace placeholder)

- [ ] **Step 1: Implement the daemon**

`Sources/wakeguardd/main.swift` (replace entire file):

```swift
import Foundation
import WakeGuardCore

let pollInterval: TimeInterval = 5
let leaseURL = URL(fileURLWithPath: Lease.defaultPath)
let store = LeaseStore(url: leaseURL)
let timestampFormatter = ISO8601DateFormatter()

func log(_ message: String) {
    // launchd redirects stdout to /var/log/wakeguardd.log (see plist).
    print("\(timestampFormatter.string(from: Date())) \(message)")
    fflush(stdout)   // stdout is block-buffered when redirected to a file
}

func currentSleepDisabled() -> Bool {
    PMSetParser.sleepDisabled(fromPMSetG: Shell.run("/usr/bin/pmset", ["-g"]))
}

func setSleepDisabled(_ on: Bool) {
    Shell.run("/usr/bin/pmset", ["-a", "disablesleep", on ? "1" : "0"])
    log("set disablesleep=\(on ? 1 : 0)")
}

func leaseFileIsRegularFile() -> Bool {
    let attrs = try? FileManager.default.attributesOfItem(atPath: leaseURL.path)
    return (attrs?[.type] as? FileAttributeType) == .typeRegular
}

func desiredSleepDisabled(now: Date) -> Bool {
    guard leaseFileIsRegularFile(), let lease = store.read() else { return false }
    guard lease.isValid(now: now) else { return false }
    let battery = BatteryStatusParser.parse(Shell.run("/usr/bin/pmset", ["-g", "batt"]))
    if battery.source == .battery {
        guard let percent = battery.percent, percent >= lease.hardBatteryFloorPercent else {
            log("hard battery floor (\(lease.hardBatteryFloorPercent)%) — ignoring lease, battery=\(battery.percent.map(String.init) ?? "unknown")")
            return false
        }
    }
    return true
}

// Invariant: every daemon start begins from normal sleep behavior. A stale
// disablesleep=1 from a hard crash or power loss must never survive a restart.
log("wakeguardd starting — reverting to disablesleep=0")
setSleepDisabled(false)

signal(SIGTERM, SIG_IGN)
let sigterm = DispatchSource.makeSignalSource(signal: SIGTERM)
sigterm.setEventHandler {
    log("SIGTERM — reverting to disablesleep=0 and exiting")
    setSleepDisabled(false)
    exit(0)
}
sigterm.resume()

let timer = DispatchSource.makeTimerSource()
timer.schedule(deadline: .now(), repeating: pollInterval)
timer.setEventHandler {
    let desired = desiredSleepDisabled(now: Date())
    if desired != currentSleepDisabled() {
        setSleepDisabled(desired)
    }
}
timer.resume()

dispatchMain()
```

- [ ] **Step 2: Verify it builds**

Run: `swift build --product wakeguardd`
Expected: `Build complete!`

- [ ] **Step 3: Smoke-test the desired-state logic without root**

Run (daemon won't be able to flip pmset without root, but must start, log, and not crash):

```bash
.build/debug/wakeguardd & DPID=$!; sleep 12; kill -TERM $DPID; wait $DPID 2>/dev/null; echo "exit ok"
```

Expected: prints `wakeguardd starting — reverting to disablesleep=0`, two `set disablesleep=0` lines (start + SIGTERM), then `exit ok`. No crash.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(daemon): lease-driven disablesleep daemon with revert-on-start and SIGTERM"
```

---

### Task 8: Daemon install/uninstall + panic script

**Files:**
- Create: `daemon/com.skopetskyi.wakeguardd.plist`
- Create: `scripts/install-daemon.sh`
- Create: `scripts/uninstall-daemon.sh`
- Create: `scripts/panic-restore-sleep.sh`

- [ ] **Step 1: Write the launchd plist**

`daemon/com.skopetskyi.wakeguardd.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.skopetskyi.wakeguardd</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/libexec/wakeguardd</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/wakeguardd.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/wakeguardd.log</string>
</dict>
</plist>
```

`RunAtLoad` + the daemon's revert-on-start gives boot-time reconciliation; `KeepAlive` makes launchd resurrect the daemon if it ever crashes.

- [ ] **Step 2: Write the install script**

`scripts/install-daemon.sh`:

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL=com.skopetskyi.wakeguardd
BIN=/usr/local/libexec/wakeguardd
PLIST=/Library/LaunchDaemons/$LABEL.plist
LEASE_DIR=/usr/local/var/wakeguard

swift build -c release --product wakeguardd

sudo mkdir -p /usr/local/libexec "$LEASE_DIR"
sudo cp .build/release/wakeguardd "$BIN"
sudo chown root:wheel "$BIN"
sudo chmod 755 "$BIN"

# The app (running as the login user) writes the lease without root;
# the daemon (root) only reads it.
sudo chown "$(whoami)":staff "$LEASE_DIR"
sudo chmod 755 "$LEASE_DIR"

sudo cp daemon/$LABEL.plist "$PLIST"
sudo chown root:wheel "$PLIST"
sudo chmod 644 "$PLIST"

sudo launchctl bootout system/$LABEL 2>/dev/null || true
sudo launchctl bootstrap system "$PLIST"
sudo launchctl print system/$LABEL | head -5
echo "wakeguardd installed and running. Log: /var/log/wakeguardd.log"
```

- [ ] **Step 3: Write the uninstall and panic scripts**

`scripts/uninstall-daemon.sh`:

```bash
#!/bin/bash
set -euo pipefail
LABEL=com.skopetskyi.wakeguardd
sudo launchctl bootout system/$LABEL 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/$LABEL.plist /usr/local/libexec/wakeguardd
rm -f /usr/local/var/wakeguard/lease.json
sudo pmset -a disablesleep 0
echo "wakeguardd removed, sleep behavior restored."
```

`scripts/panic-restore-sleep.sh`:

```bash
#!/bin/bash
# Emergency: restore normal sleep no matter what state app/daemon are in.
# Safe to run any time, repeatedly.
rm -f /usr/local/var/wakeguard/lease.json
sudo pmset -a disablesleep 0
pmset -g | grep -i sleepdisabled || echo "SleepDisabled not set (normal sleep active)"
echo "Sleep restored."
```

- [ ] **Step 4: Make scripts executable and install**

Run:

```bash
chmod +x scripts/*.sh
./scripts/install-daemon.sh
```

Expected: ends with `wakeguardd installed and running.` (`sudo` will prompt once).

- [ ] **Step 5: Verify the dead-man switch end-to-end with a hand-written lease**

```bash
# 1. No lease -> SleepDisabled absent/0
pmset -g | grep -i sleepdisabled || echo "OK: not disabled"

# 2. Write a valid 30s lease by hand -> daemon flips to 1 within ~5s
python3 - <<'EOF'
import json, datetime
expires = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(seconds=30)).strftime('%Y-%m-%dT%H:%M:%SZ')
json.dump({"sessionID": "manual-test", "appPID": 1, "expiresAt": expires, "hardBatteryFloorPercent": 15},
          open('/usr/local/var/wakeguard/lease.json', 'w'))
EOF
sleep 7 && pmset -g | grep -i sleepdisabled   # expect: SleepDisabled 1

# 3. Let it expire -> daemon reverts within ~35s of last write
sleep 35 && (pmset -g | grep -i sleepdisabled || echo "OK: reverted")

# 4. Daemon crash resilience: launchd restarts it, restart reverts state
OLDPID=$(sudo launchctl print system/com.skopetskyi.wakeguardd | awk '/pid =/{print $3}')
sudo kill -9 "$OLDPID"; sleep 3
sudo launchctl print system/com.skopetskyi.wakeguardd | grep "pid ="   # expect: a NEW pid
tail -5 /var/log/wakeguardd.log                                        # expect: fresh "starting" + revert lines
```

Expected: each step's inline expectation holds. If step 2 never flips to 1, check `/var/log/wakeguardd.log`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(daemon): launchd plist, install/uninstall, and panic scripts"
```

---

### Task 9: SessionController

App-side session lifecycle: spawn/kill caffeinate, write/renew/clear leases, enforce duration with an end timer (the authoritative duration mechanism — see Task 2 note). Process spawning is behind a protocol so tests need no real processes.

**Files:**
- Create: `Sources/WakeGuardCore/SessionController.swift`
- Create: `Tests/WakeGuardCoreTests/SessionControllerTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/WakeGuardCoreTests/SessionControllerTests.swift`:

```swift
import XCTest
@testable import WakeGuardCore

private final class FakeProcess: CaffeinateProcess {
    var isRunning = true
    func terminate() { isRunning = false }
}

private final class FakeSpawner: ProcessSpawning {
    var lastArguments: [String]?
    var spawnCount = 0
    func spawnCaffeinate(arguments: [String]) throws -> CaffeinateProcess {
        lastArguments = arguments
        spawnCount += 1
        return FakeProcess()
    }
}

final class SessionControllerTests: XCTestCase {
    private var spawner: FakeSpawner!
    private var store: LeaseStore!
    private var controller: SessionController!

    override func setUp() {
        super.setUp()
        spawner = FakeSpawner()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wakeguard-ctl-\(UUID().uuidString).json")
        store = LeaseStore(url: url)
        controller = SessionController(spawner: spawner, leaseStore: store, limits: SafetyLimits())
    }

    override func tearDown() {
        store.clear()
        super.tearDown()
    }

    func testStartSpawnsCaffeinateWithBuiltArgs() throws {
        let config = SessionConfig(duration: 600, displayPolicy: .keepOn, lidPolicy: .normalSleep)
        try controller.start(config)
        let pid = ProcessInfo.processInfo.processIdentifier
        XCTAssertEqual(spawner.lastArguments, ["-i", "-d", "-t", "600", "-w", String(pid)])
        XCTAssertNotNil(controller.activeSession)
    }

    func testNormalSessionWritesNoLease() throws {
        try controller.start(SessionConfig(duration: 600, displayPolicy: .keepOn, lidPolicy: .normalSleep))
        XCTAssertNil(store.read())
    }

    func testClosedLidSessionWritesValidLeaseImmediately() throws {
        try controller.start(SessionConfig(duration: 600, displayPolicy: .allowOff, lidPolicy: .stayAwakeWhenClosed))
        let lease = try XCTUnwrap(store.read())
        XCTAssertTrue(lease.isValid(now: Date()))
        XCTAssertEqual(lease.appPID, ProcessInfo.processInfo.processIdentifier)
    }

    func testLeaseExpiryNeverOutlivesSessionEnd() throws {
        // 5s session: lease must expire ~5s out, not the full 30s TTL.
        try controller.start(SessionConfig(duration: 5, displayPolicy: .allowOff, lidPolicy: .stayAwakeWhenClosed))
        let lease = try XCTUnwrap(store.read())
        XCTAssertLessThanOrEqual(lease.expiresAt.timeIntervalSinceNow, 6)
    }

    func testStopTerminatesProcessClearsLeaseAndReportsReason() throws {
        try controller.start(SessionConfig(duration: 600, displayPolicy: .allowOff, lidPolicy: .stayAwakeWhenClosed))
        var endedReason: String?
        controller.onSessionEnded = { endedReason = $0 }
        let process = controller.activeSession!.process
        controller.stop(reason: "Test stop")
        XCTAssertNil(controller.activeSession)
        XCTAssertNil(store.read())
        XCTAssertFalse(process.isRunning)
        XCTAssertEqual(endedReason, "Test stop")
    }

    func testStartWhileActiveReplacesSession() throws {
        try controller.start(SessionConfig(duration: 600, displayPolicy: .keepOn, lidPolicy: .normalSleep))
        try controller.start(SessionConfig(duration: 900, displayPolicy: .keepOn, lidPolicy: .normalSleep))
        XCTAssertEqual(spawner.spawnCount, 2)
        XCTAssertEqual(controller.activeSession?.config.duration, 900)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: build FAILS with `cannot find 'CaffeinateProcess' in scope`.

- [ ] **Step 3: Implement**

`Sources/WakeGuardCore/SessionController.swift`:

```swift
import Foundation

public protocol CaffeinateProcess {
    var isRunning: Bool { get }
    func terminate()
}

public protocol ProcessSpawning {
    func spawnCaffeinate(arguments: [String]) throws -> CaffeinateProcess
}

/// Production spawner wrapping Foundation.Process.
public final class CaffeinateSpawner: ProcessSpawning {
    public init() {}

    private final class RealProcess: CaffeinateProcess {
        let process: Process
        init(process: Process) { self.process = process }
        var isRunning: Bool { process.isRunning }
        func terminate() { if process.isRunning { process.terminate() } }
    }

    public func spawnCaffeinate(arguments: [String]) throws -> CaffeinateProcess {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: CaffeinateCommand.executablePath)
        process.arguments = arguments
        try process.run()
        return RealProcess(process: process)
    }
}

public final class SessionController {
    public struct ActiveSession {
        public let config: SessionConfig
        public let startedAt: Date
        public let startedOnAC: Bool
        public let process: CaffeinateProcess
        public var endsAt: Date { startedAt.addingTimeInterval(config.duration) }
    }

    public private(set) var activeSession: ActiveSession?
    /// Called with a human-readable reason whenever a session ends.
    public var onSessionEnded: ((String) -> Void)?

    private let spawner: ProcessSpawning
    private let leaseStore: LeaseStore
    private let limits: SafetyLimits
    private var leaseTimer: Timer?
    private var endTimer: Timer?

    public init(spawner: ProcessSpawning, leaseStore: LeaseStore, limits: SafetyLimits) {
        self.spawner = spawner
        self.leaseStore = leaseStore
        self.limits = limits
    }

    public func start(_ config: SessionConfig) throws {
        stopInternal(reason: "Replaced by new session", notify: activeSession != nil)

        let pid = ProcessInfo.processInfo.processIdentifier
        let process = try spawner.spawnCaffeinate(
            arguments: CaffeinateCommand.arguments(for: config, appPID: pid))
        let session = ActiveSession(config: config,
                                    startedAt: Date(),
                                    startedOnAC: BatteryStatusParser.current().source == .ac,
                                    process: process)
        activeSession = session

        if config.lidPolicy == .stayAwakeWhenClosed {
            renewLease()
            let timer = Timer(timeInterval: Lease.renewInterval, repeats: true) { [weak self] _ in
                self?.renewLease()
            }
            RunLoop.main.add(timer, forMode: .common)
            leaseTimer = timer
        }

        // Authoritative duration enforcement (caffeinate -t is best-effort only).
        let end = Timer(timeInterval: config.duration, repeats: false) { [weak self] _ in
            self?.stop(reason: "Session duration elapsed")
        }
        RunLoop.main.add(end, forMode: .common)
        endTimer = end
    }

    public func stop(reason: String) {
        stopInternal(reason: reason, notify: activeSession != nil)
    }

    private func stopInternal(reason: String, notify: Bool) {
        leaseTimer?.invalidate(); leaseTimer = nil
        endTimer?.invalidate(); endTimer = nil
        leaseStore.clear()
        activeSession?.process.terminate()
        activeSession = nil
        if notify { onSessionEnded?(reason) }
    }

    private func renewLease() {
        guard let session = activeSession else { return }
        let expiry = min(Date().addingTimeInterval(Lease.ttl), session.endsAt)
        let lease = Lease(sessionID: "\(session.startedAt.timeIntervalSince1970)",
                          appPID: ProcessInfo.processInfo.processIdentifier,
                          expiresAt: expiry,
                          hardBatteryFloorPercent: limits.hardBatteryFloorPercent)
        try? leaseStore.write(lease)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (31 tests total).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(core): session controller with lease renewal and end timer"
```

---

### Task 10: Menu bar app — status item, menu, dock presence

UI rules: menu-bar-only (`.accessory`) when idle; while a session is active, switch to `.regular` so a dock icon appears (dock presence == "something is keeping my Mac awake"), with a countdown badge on the dock tile. Filled cup icon when active, outline when idle.

**Files:**
- Modify: `Sources/WakeGuardApp/main.swift` (replace placeholder)
- Create: `Sources/WakeGuardApp/AppDelegate.swift`
- Create: `Sources/WakeGuardApp/MenuBuilder.swift`
- Create: `Sources/WakeGuardApp/Notify.swift`

- [ ] **Step 1: Implement notifications helper**

`Sources/WakeGuardApp/Notify.swift`:

```swift
import Foundation
import WakeGuardCore

enum Notify {
    /// osascript notifications work from an unbundled binary; UNUserNotificationCenter does not.
    static func send(title: String, body: String) {
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
        Shell.run("/usr/bin/osascript",
                  ["-e", "display notification \"\(escapedBody)\" with title \"\(escapedTitle)\""])
    }
}
```

- [ ] **Step 2: Implement the app delegate**

`Sources/WakeGuardApp/AppDelegate.swift`:

```swift
import AppKit
import WakeGuardCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = SessionController(spawner: CaffeinateSpawner(),
                                       leaseStore: LeaseStore(),
                                       limits: SafetyLimits())
    private var statusItem: NSStatusItem!
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon(active: false)

        controller.onSessionEnded = { [weak self] reason in
            Notify.send(title: "WakeGuard", body: "Session ended: \(reason)")
            self?.sessionStateChanged()
        }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshCountdown()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer

        rebuildMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop(reason: "App quit")
    }

    // MARK: - Session actions (called from MenuBuilder)

    func startSession(minutes: Int, displayPolicy: SessionConfig.DisplayPolicy,
                      lidPolicy: SessionConfig.LidPolicy) {
        let config = SessionConfig(duration: TimeInterval(minutes * 60),
                                   displayPolicy: displayPolicy, lidPolicy: lidPolicy)
        do {
            try controller.start(config)
            if lidPolicy == .stayAwakeWhenClosed {
                Notify.send(title: "WakeGuard",
                            body: "Closed-lid mode active for \(minutes) min. Lid can be closed.")
            }
            sessionStateChanged()
        } catch {
            Notify.send(title: "WakeGuard", body: "Failed to start: \(error.localizedDescription)")
        }
    }

    func stopSession() {
        controller.stop(reason: "Stopped from menu")
    }

    func sleepDisplayNow() {
        Shell.run("/usr/bin/pmset", ["displaysleepnow"])
    }

    // MARK: - UI state

    func sessionStateChanged() {
        let active = controller.activeSession != nil
        NSApp.setActivationPolicy(active ? .regular : .accessory)
        if !active { NSApp.dockTile.badgeLabel = nil }
        updateIcon(active: active)
        rebuildMenu()
    }

    private func updateIcon(active: Bool) {
        let symbol = active ? "cup.and.saucer.fill" : "cup.and.saucer"
        statusItem.button?.image = NSImage(systemSymbolName: symbol,
                                           accessibilityDescription: "WakeGuard")
    }

    private func refreshCountdown() {
        guard let session = controller.activeSession else { return }
        let remaining = max(0, Int(session.endsAt.timeIntervalSinceNow))
        NSApp.dockTile.badgeLabel = String(format: "%d:%02d", remaining / 3600, (remaining % 3600) / 60)
    }

    func rebuildMenu() {
        statusItem.menu = MenuBuilder.build(for: self)
    }
}
```

- [ ] **Step 3: Implement the menu**

`Sources/WakeGuardApp/MenuBuilder.swift`:

```swift
import AppKit
import WakeGuardCore

enum MenuBuilder {
    static let durationsMinutes = [15, 30, 60, 120, 240, 480]

    // Mode toggles persist across menu rebuilds.
    static var allowDisplayOff = false
    static var closedLidMode = false

    static func build(for app: AppDelegate) -> NSMenu {
        let menu = NSMenu()

        if let session = app.controller.activeSession {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let status = NSMenuItem(title: "Awake until \(formatter.string(from: session.endsAt))",
                                    action: nil, keyEquivalent: "")
            status.isEnabled = false
            menu.addItem(status)
            menu.addItem(item(title: "Stop Session", action: #selector(AppDelegate.menuStop), target: app))
        } else {
            let start = NSMenuItem(title: "Start Session", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for minutes in durationsMinutes {
                let label = minutes < 60 ? "\(minutes) minutes" : "\(minutes / 60) hour\(minutes > 60 ? "s" : "")"
                let entry = item(title: label, action: #selector(AppDelegate.menuStartPreset(_:)), target: app)
                entry.tag = minutes
                submenu.addItem(entry)
            }
            submenu.addItem(item(title: "Custom…", action: #selector(AppDelegate.menuStartCustom), target: app))
            start.submenu = submenu
            menu.addItem(start)
        }

        menu.addItem(.separator())
        let displayToggle = item(title: "Allow Display to Sleep",
                                 action: #selector(AppDelegate.menuToggleDisplayOff), target: app)
        displayToggle.state = allowDisplayOff ? .on : .off
        menu.addItem(displayToggle)

        let lidToggle = item(title: "Keep Awake When Lid Closed",
                             action: #selector(AppDelegate.menuToggleClosedLid), target: app)
        lidToggle.state = closedLidMode ? .on : .off
        menu.addItem(lidToggle)

        menu.addItem(item(title: "Turn Display Off Now", action: #selector(AppDelegate.menuDisplayOff), target: app))
        menu.addItem(.separator())
        menu.addItem(item(title: "Quit WakeGuard", action: #selector(AppDelegate.menuQuit), target: app))
        return menu
    }

    private static func item(title: String, action: Selector, target: AnyObject) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = target
        return menuItem
    }
}

extension AppDelegate {
    @objc func menuStartPreset(_ sender: NSMenuItem) {
        startSession(minutes: sender.tag,
                     displayPolicy: MenuBuilder.allowDisplayOff ? .allowOff : .keepOn,
                     lidPolicy: MenuBuilder.closedLidMode ? .stayAwakeWhenClosed : .normalSleep)
    }

    @objc func menuStartCustom() {
        let alert = NSAlert()
        alert.messageText = "Keep awake for how many minutes?"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.placeholderString = "e.g. 90"
        alert.accessoryView = field
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn,
              let minutes = Int(field.stringValue), minutes > 0 else { return }
        startSession(minutes: minutes,
                     displayPolicy: MenuBuilder.allowDisplayOff ? .allowOff : .keepOn,
                     lidPolicy: MenuBuilder.closedLidMode ? .stayAwakeWhenClosed : .normalSleep)
    }

    @objc func menuStop() { stopSession() }
    @objc func menuDisplayOff() { sleepDisplayNow() }

    @objc func menuToggleDisplayOff() {
        MenuBuilder.allowDisplayOff.toggle()
        rebuildMenu()
    }

    @objc func menuToggleClosedLid() {
        MenuBuilder.closedLidMode.toggle()
        rebuildMenu()
    }

    @objc func menuQuit() {
        NSApp.terminate(nil)   // triggers applicationWillTerminate -> controller.stop
    }
}
```

- [ ] **Step 4: Implement the bootstrap with signal-safe cleanup**

`Sources/WakeGuardApp/main.swift` (replace entire file):

```swift
import AppKit
import WakeGuardCore

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate

// SIGTERM/SIGINT (Activity Monitor "Quit", Ctrl-C from terminal) must clean up
// like a normal quit. SIGKILL needs no handler: caffeinate -w dies with us and
// the lease expires within ~35s.
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGTERM, SIGINT] {
    signal(sig, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    source.setEventHandler {
        delegate.controller.stop(reason: "Terminated by signal")
        exit(0)
    }
    source.resume()
    signalSources.append(source)
}

app.run()
```

- [ ] **Step 5: Build and verify manually**

Run: `swift build && .build/debug/WakeGuardApp &`

Manual checklist (each must hold):
1. Cup outline icon appears in the menu bar; **no dock icon**.
2. Start Session → 15 minutes: icon becomes filled cup, **dock icon appears** with a countdown badge like `0:14`.
3. `pmset -g assertions | grep -i caffeinate` shows a `PreventUserIdleSystemSleep` assertion from caffeinate.
4. With "Allow Display to Sleep" checked, a new session's caffeinate has no `-d`: `ps -axo command | grep "[c]affeinate"` shows `-i -t ... -w ...` only.
5. "Turn Display Off Now" blanks the display; the Mac stays awake (music/SSH continues).
6. Stop Session → dock icon disappears, badge clears, assertion gone from `pmset -g assertions`.
7. Quit from menu → caffeinate process gone: `pgrep -l caffeinate` returns nothing.

Then stop the test instance: `pkill WakeGuardApp`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(app): menu bar UI with dock presence, countdown badge, and signal cleanup"
```

---

### Task 11: SafetyMonitor + pre-flight checks

Glue layer: every 15 s read battery + thermal state, ask `SafetyPolicy` (already fully tested), act on the verdict. Plus pre-flight refusals at session start.

**Files:**
- Create: `Sources/WakeGuardApp/SafetyMonitor.swift`
- Modify: `Sources/WakeGuardApp/AppDelegate.swift`

- [ ] **Step 1: Implement the monitor**

`Sources/WakeGuardApp/SafetyMonitor.swift`:

```swift
import Foundation
import WakeGuardCore

final class SafetyMonitor {
    static let pollInterval: TimeInterval = 15

    private let controller: SessionController
    private let limits: SafetyLimits
    private var timer: Timer?
    private var warnedThisSession = false

    init(controller: SessionController, limits: SafetyLimits) {
        self.controller = controller
        self.limits = limits
    }

    func start() {
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.check()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func sessionDidStart() { warnedThisSession = false }

    private func check() {
        guard let session = controller.activeSession else { return }
        let thermal: SafetyThermalState
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = .nominal
        case .fair: thermal = .fair
        case .serious: thermal = .serious
        case .critical: thermal = .critical
        @unknown default: thermal = .critical   // unknown thermal state: fail safe
        }

        let verdict = SafetyPolicy.evaluate(battery: BatteryStatusParser.current(),
                                            thermal: thermal,
                                            sessionElapsed: Date().timeIntervalSince(session.startedAt),
                                            lidPolicy: session.config.lidPolicy,
                                            limits: limits,
                                            startedOnAC: session.startedOnAC)
        switch verdict {
        case .ok:
            break
        case .warn(let message):
            if !warnedThisSession {
                warnedThisSession = true
                Notify.send(title: "WakeGuard warning", body: message)
            }
        case .endSession(let reason):
            controller.stop(reason: reason)
        }
    }
}
```

- [ ] **Step 2: Wire it into AppDelegate and add pre-flight checks**

In `Sources/WakeGuardApp/AppDelegate.swift`, add a property after `let controller = ...`:

```swift
    private lazy var safetyMonitor = SafetyMonitor(controller: controller, limits: SafetyLimits())
```

At the end of `applicationDidFinishLaunching`, before `rebuildMenu()`:

```swift
        safetyMonitor.start()
```

Replace the body of `startSession(minutes:displayPolicy:lidPolicy:)` with:

```swift
        if lidPolicy == .stayAwakeWhenClosed {
            let battery = BatteryStatusParser.current()
            if battery.source == .battery {
                guard let percent = battery.percent, percent >= SafetyLimits().softBatteryPercent else {
                    Notify.send(title: "WakeGuard",
                                body: "Refusing closed-lid mode: battery too low or unreadable. Plug in first.")
                    return
                }
                Notify.send(title: "WakeGuard",
                            body: "Closed-lid mode on battery (\(battery.percent!)%). Will auto-stop below \(SafetyLimits().softBatteryPercent)%.")
            }
        }
        let config = SessionConfig(duration: TimeInterval(minutes * 60),
                                   displayPolicy: displayPolicy, lidPolicy: lidPolicy)
        do {
            try controller.start(config)
            safetyMonitor.sessionDidStart()
            if lidPolicy == .stayAwakeWhenClosed {
                Notify.send(title: "WakeGuard",
                            body: "Closed-lid mode active for \(minutes) min. Lid can be closed.")
            }
            sessionStateChanged()
        } catch {
            Notify.send(title: "WakeGuard", body: "Failed to start: \(error.localizedDescription)")
        }
```

- [ ] **Step 3: Build and verify**

Run: `swift build && swift test`
Expected: build succeeds, all 31 tests still pass.

Manual check (fastest rule to exercise on AC power): start a closed-lid session, then temporarily verify the monitor fires by lowering the cap — edit `SafetyLimits.maxClosedLidDuration` to `30` (seconds), rebuild, start a closed-lid session, wait ≤45 s → notification "Session ended: Maximum closed-lid duration (12h) reached" (message text still says 12h — fine for the smoke test) and dock icon disappears. **Revert the edit and rebuild before committing.**

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(app): safety monitor with pre-flight battery checks"
```

---

### Task 12: Truth-from-system status line

The menu must report what the SYSTEM says, not what the app believes: caffeinate assertion present? `SleepDisabled` actually 1? A mismatch (e.g. daemon not installed, helper failed) must be visible and notified — otherwise the user closes the lid trusting a closed-lid session that isn't real. This is the verify-after-enable check.

**Files:**
- Create: `Sources/WakeGuardApp/SystemStatus.swift`
- Modify: `Sources/WakeGuardApp/AppDelegate.swift`
- Modify: `Sources/WakeGuardApp/MenuBuilder.swift`

- [ ] **Step 1: Implement system status probe**

`Sources/WakeGuardApp/SystemStatus.swift`:

```swift
import Foundation
import WakeGuardCore

struct SystemStatus {
    let caffeinateAssertionActive: Bool
    let sleepDisabled: Bool

    static func probe() -> SystemStatus {
        let assertions = Shell.run("/usr/bin/pmset", ["-g", "assertions"])
        let settings = Shell.run("/usr/bin/pmset", ["-g"])
        return SystemStatus(
            caffeinateAssertionActive: assertions.contains("caffeinate"),
            sleepDisabled: PMSetParser.sleepDisabled(fromPMSetG: settings))
    }

    /// Human-readable line for the menu, given what the app THINKS is active.
    func menuLine(expectClosedLid: Bool) -> (text: String, isHealthy: Bool) {
        if expectClosedLid && !sleepDisabled {
            return ("⚠️ Closed-lid NOT active — daemon missing? Do not close the lid.", false)
        }
        if expectClosedLid {
            return ("System: awake ✓, closed-lid ✓ (SleepDisabled 1)", true)
        }
        if caffeinateAssertionActive {
            return ("System: awake ✓ (caffeinate assertion held)", true)
        }
        return ("⚠️ No keep-awake assertion found", false)
    }
}
```

- [ ] **Step 2: Surface it in the menu and notify on mismatch**

In `Sources/WakeGuardApp/MenuBuilder.swift`, inside `build(for:)`, in the active-session branch, directly after adding the `status` item:

```swift
            let probe = SystemStatus.probe()
            let line = probe.menuLine(expectClosedLid: session.config.lidPolicy == .stayAwakeWhenClosed)
            let systemItem = NSMenuItem(title: line.text, action: nil, keyEquivalent: "")
            systemItem.isEnabled = false
            menu.addItem(systemItem)
```

In `Sources/WakeGuardApp/AppDelegate.swift`, add a verify-after-enable check. Add this method:

```swift
    /// Closed-lid verification: 8s after start (daemon polls every 5s), confirm
    /// the system actually has SleepDisabled=1. If not, the lid is NOT safe to close.
    private func verifyClosedLidTookEffect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self,
                  let session = self.controller.activeSession,
                  session.config.lidPolicy == .stayAwakeWhenClosed else { return }
            if !SystemStatus.probe().sleepDisabled {
                Notify.send(title: "WakeGuard — NOT SAFE TO CLOSE LID",
                            body: "disablesleep did not engage. Is wakeguardd installed? (scripts/install-daemon.sh)")
            }
        }
    }
```

And call it inside `startSession` right after `safetyMonitor.sessionDidStart()`:

```swift
            verifyClosedLidTookEffect()
```

- [ ] **Step 3: Build and verify**

Run: `swift build && .build/debug/WakeGuardApp &`

Manual checklist:
1. Start a normal session → menu shows `System: awake ✓ (caffeinate assertion held)`.
2. Start a closed-lid session (daemon installed) → within ~8 s menu shows `closed-lid ✓` and **no** warning notification arrives.
3. Negative test: `sudo launchctl bootout system/com.skopetskyi.wakeguardd`, start a closed-lid session → within ~8 s the "NOT SAFE TO CLOSE LID" notification fires and the menu shows the ⚠️ line. Reinstall after: `./scripts/install-daemon.sh`.
4. `pkill WakeGuardApp` to stop the test instance; confirm cleanup: `pgrep -l caffeinate` empty, and within ~35 s `pmset -g | grep -i sleepdisabled` shows nothing.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(app): system-truth status line and closed-lid verify-after-enable"
```

---

### Task 13: End-to-end test pass + README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Run the full crash-safety matrix**

Build release and run the app: `swift build -c release && .build/release/WakeGuardApp &`

| # | Scenario | Action | Pass condition |
|---|----------|--------|----------------|
| 1 | Normal stop | Start 15 min closed-lid session → Stop Session | `pmset -g \| grep -i sleepdisabled` empty within ~10 s; `pgrep caffeinate` empty |
| 2 | Normal quit | Start closed-lid session → Quit from menu | Same as #1 |
| 3 | SIGTERM | Start closed-lid session → `pkill WakeGuardApp` | Same as #1 |
| 4 | Hard crash | Start closed-lid session → `pkill -9 WakeGuardApp` | `pgrep caffeinate` empty immediately (`-w` released); SleepDisabled reverts within ~35 s |
| 5 | Daemon crash | Start closed-lid session → `sudo kill -9 $(sudo launchctl print system/com.skopetskyi.wakeguardd \| awk '/pid =/{print $3}')` | launchd restarts daemon (new pid); restart reverts to 0; app's ⚠️ status line appears on next menu open |
| 6 | Duration expiry | Start 1 min custom closed-lid session, wait | Session auto-ends, notification fires, state reverts |
| 7 | Real lid test | Start 30 min closed-lid session, close lid, ping the Mac from a phone/another machine for 2 min | Pings answered the whole time; display off |
| 8 | Lid test control | No session, close lid, ping for 1 min | Pings stop within ~30 s (proves test #7 measured something) |
| 9 | Reboot | Start closed-lid session → reboot | After login: `pmset -g \| grep -i sleepdisabled` empty (daemon revert-on-boot) |
| 10 | Battery soft stop | On battery, set `softBatteryPercent` above current level (temp edit), start closed-lid session | Refused at pre-flight with notification; revert edit |
| 11 | Panic script | Manually `sudo pmset -a disablesleep 1`, then `./scripts/panic-restore-sleep.sh` | Script reports sleep restored |

Record any failure verbatim, fix, and re-run the failed row before proceeding.

- [ ] **Step 2: Write the README**

`README.md`:

```markdown
# WakeGuard

Personal macOS keep-awake tool. Menu bar app + root daemon.

## What it does
- Keep the Mac awake for a chosen duration (presets or custom minutes).
- Optionally let the display sleep while the system stays awake ("Allow Display to Sleep"),
  plus a "Turn Display Off Now" action.
- Optionally keep the Mac awake **with the lid closed** ("Keep Awake When Lid Closed") —
  requires the wakeguardd daemon.
- Dock icon + countdown badge appear ONLY while a session is active.

## Fail-safe design
Closed-lid mode works through a dead-man's switch: the app must renew a 30-second
lease every 10 seconds; the root daemon enables `pmset disablesleep` only while a
fresh lease exists. App crash, force-quit, freeze, quit, reboot, daemon crash —
all of them end with normal sleep restored within ~35 seconds, plus:
- daemon reverts on every start (boot reconciliation) and on SIGTERM,
- daemon force-reverts below a 15% hard battery floor,
- app refuses/ends closed-lid sessions below 30% battery (on battery), at
  critical thermal state, or past 12 hours,
- app verifies the system state 8s after enabling and warns "NOT SAFE TO CLOSE LID"
  if disablesleep didn't engage.

## Install
    swift build -c release
    ./scripts/install-daemon.sh       # one-time, needs sudo
    .build/release/WakeGuardApp &     # or add to Login Items

## Emergency
If anything ever looks wrong:
    ./scripts/panic-restore-sleep.sh

## Uninstall
    ./scripts/uninstall-daemon.sh

## Known trade-offs (personal-use scope)
- The lease directory is writable by the login user, so any process running as
  you could keep the Mac awake. Acceptable single-user trade-off; the daemon
  only reads timestamps/ints from the lease and caps grants at 60s.
- Unbundled binary: generic dock icon, osascript notifications. A proper .app
  bundle with a custom icon is a possible later improvement.
```

- [ ] **Step 3: Final test + commit**

Run: `swift test`
Expected: all tests pass.

```bash
git add -A
git commit -m "docs: README with fail-safe design notes and e2e test results"
```

---

### Task 14: Activity simulation toggle (keep Slack/Teams "active")

On-demand presence keeper. Some chat tools (Slack, Teams) flip you to "away" once the
**system HID idle timer** crosses a threshold (Teams ~5 min, Slack ~10 min). This feature,
when toggled on, posts a harmless synthetic input event on a fixed cadence to reset that
idle timer, so presence stays green. It is **independent of keep-awake sessions** (works with
or without one) and **off by default** — a menu checkbox the user must explicitly enable.

Design choices (personal-tool scope):
- **Mechanism:** post an invisible **F15 key** down/up (`CGEvent`, virtual key `0x71`) to
  `.cghidEventTap`. F15 has no default binding on Mac keyboards, so it is a no-op for the user
  but registers as user activity for presence tools. No cursor movement, no visible side effect.
- **Cadence:** every 60 s — comfortably under the tightest presence-away threshold, low overhead.
- **Testability:** core owns an `ActivityEmitter` protocol + timer-driven `ActivitySimulator`
  (idempotent `start`/`stop`, emits immediately on start). The real `CGEvent` poster lives in the
  app target so core stays framework-free and unit-tested with a fake emitter.
- **Trade-off (documented):** a synthetic event can wake the display, so combining this with
  "Turn Display Off Now" will keep nudging the display back on. Intended use is presence-while-AFK
  with the display on. May prompt for Accessibility/Input-Monitoring permission on first post.

**Files:**
- Create: `Sources/WakeGuardCore/ActivitySimulator.swift` (protocol + simulator)
- Create: `Tests/WakeGuardCoreTests/ActivitySimulatorTests.swift`
- Create: `Sources/WakeGuardApp/ActivityEmitterCG.swift` (CGEvent F15 emitter)
- Modify: `Sources/WakeGuardApp/AppDelegate.swift` (own the simulator, stop on quit)
- Modify: `Sources/WakeGuardApp/MenuBuilder.swift` (checkbox + toggle action)
- Modify: `README.md` (document the feature, cadence, and trade-offs)

**Behavior contract:**
1. `ActivitySimulator.start()` emits one event immediately, then every 60 s; idempotent while running.
2. `ActivitySimulator.stop()` halts emission; `start()` after `stop()` resumes.
3. The toggle is independent of session state and persists across menu rebuilds.
4. The simulator is stopped on app quit alongside the keep-awake session.

---

## Effort estimate

| Tasks | Content | Estimate |
|-------|---------|----------|
| 1–6 | Scaffold + all core logic (TDD) | 1–2 evenings |
| 7–8 | Daemon + install + dead-man verification | 1 evening |
| 9 | Session controller | 1 evening |
| 10–12 | Menu bar UI, safety monitor, system-truth status | 2 evenings |
| 13 | E2E matrix + README | 1 evening |

## Deliberately out of scope (YAGNI)

- Preferences UI (thresholds are code constants; this is a personal tool).
- Proper .app bundle, custom icon, login item automation, Sparkle updates.
- "Wake for network access" / scheduled sessions.
- App Store distribution, notarization, SMAppService helper (the manual LaunchDaemon is simpler and equally safe for one machine).
