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
