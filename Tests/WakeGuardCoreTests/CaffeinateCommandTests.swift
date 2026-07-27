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

    func testClosedLidRespectsDisplayPolicy() {
        // Core respects the display policy uniformly; the app chooses .keepOn for
        // closed-lid only when an external display is connected (clamshell).
        let config = SessionConfig(duration: 600, displayPolicy: .keepOn, lidPolicy: .stayAwakeWhenClosed)
        XCTAssertEqual(CaffeinateCommand.arguments(for: config, appPID: 7),
                       ["-i", "-d", "-t", "600", "-w", "7"])
    }
}
