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

    func testExactSoftThresholdContinues() {
        // 30% is the floor itself, not below it.
        XCTAssertEqual(verdict(battery: BatteryStatus(source: .battery, percent: 30), startedOnAC: false), .ok)
    }

    func testExactHardCapContinues() {
        // Pins the strict > comparison: ends only PAST the cap.
        XCTAssertEqual(verdict(elapsed: limits.maxClosedLidDuration), .ok)
    }

    func testSeriousThermalWarnsClosedLidSession() {
        XCTAssertEqual(verdict(thermal: .serious),
                       .warn("Thermal state is serious — consider ending the session"))
    }
}
