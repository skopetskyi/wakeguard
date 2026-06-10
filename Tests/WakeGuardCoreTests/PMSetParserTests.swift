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
