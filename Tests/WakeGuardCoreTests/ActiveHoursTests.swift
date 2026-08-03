import XCTest
@testable import WakeGuardCore

final class ActiveHoursTests: XCTestCase {
    /// Builds a date at `hour`:`minute` in the given time zone, so tests are
    /// explicit about the "local time" the window is evaluated in.
    private func date(_ hour: Int, _ minute: Int = 0,
                      timeZone: TimeZone = TimeZone(identifier: "Europe/Kyiv")!) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: 2026, month: 7, day: 15,
                                                  hour: hour, minute: minute))!
    }

    private func calendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private let kyiv = TimeZone(identifier: "Europe/Kyiv")!

    // MARK: - Disabled

    func testDisabledWindowAlwaysContains() {
        let hours = ActiveHours(isEnabled: false, startHour: 9, endHour: 18)
        XCTAssertTrue(hours.contains(date(3), calendar: calendar(kyiv)))
        XCTAssertTrue(hours.contains(date(12), calendar: calendar(kyiv)))
    }

    // MARK: - Normal window (09:00–18:00)

    func testInsideNormalWindow() {
        let hours = ActiveHours(isEnabled: true, startHour: 9, endHour: 18)
        XCTAssertTrue(hours.contains(date(9, 0), calendar: calendar(kyiv)), "start hour is inclusive")
        XCTAssertTrue(hours.contains(date(13, 30), calendar: calendar(kyiv)))
        XCTAssertTrue(hours.contains(date(17, 59), calendar: calendar(kyiv)))
    }

    func testOutsideNormalWindow() {
        let hours = ActiveHours(isEnabled: true, startHour: 9, endHour: 18)
        XCTAssertFalse(hours.contains(date(18, 0), calendar: calendar(kyiv)), "end hour is exclusive")
        XCTAssertFalse(hours.contains(date(8, 59), calendar: calendar(kyiv)))
        XCTAssertFalse(hours.contains(date(23, 30), calendar: calendar(kyiv)), "overnight must be outside")
        XCTAssertFalse(hours.contains(date(3, 0), calendar: calendar(kyiv)))
    }

    // MARK: - Window wrapping midnight (22:00–06:00)

    func testWrappingWindowContainsBothSidesOfMidnight() {
        let hours = ActiveHours(isEnabled: true, startHour: 22, endHour: 6)
        XCTAssertTrue(hours.contains(date(22, 0), calendar: calendar(kyiv)))
        XCTAssertTrue(hours.contains(date(23, 59), calendar: calendar(kyiv)))
        XCTAssertTrue(hours.contains(date(0, 30), calendar: calendar(kyiv)))
        XCTAssertTrue(hours.contains(date(5, 59), calendar: calendar(kyiv)))
    }

    func testWrappingWindowExcludesDaytime() {
        let hours = ActiveHours(isEnabled: true, startHour: 22, endHour: 6)
        XCTAssertFalse(hours.contains(date(6, 0), calendar: calendar(kyiv)))
        XCTAssertFalse(hours.contains(date(12, 0), calendar: calendar(kyiv)))
        XCTAssertFalse(hours.contains(date(21, 59), calendar: calendar(kyiv)))
    }

    // MARK: - Degenerate window

    func testEqualStartAndEndMeansAllDay() {
        let hours = ActiveHours(isEnabled: true, startHour: 9, endHour: 9)
        XCTAssertTrue(hours.contains(date(9, 0), calendar: calendar(kyiv)))
        XCTAssertTrue(hours.contains(date(3, 0), calendar: calendar(kyiv)))
    }

    // MARK: - Local time zone

    func testWindowIsEvaluatedInTheGivenLocalTimeZone() {
        // 20:00 in Kyiv is 10:00 in Los Angeles (UTC+3 vs UTC-7 in July).
        let hours = ActiveHours(isEnabled: true, startHour: 9, endHour: 18)
        let instant = date(20, 0, timeZone: kyiv)
        XCTAssertFalse(hours.contains(instant, calendar: calendar(kyiv)),
                       "20:00 local in Kyiv is outside 09:00-18:00")
        let la = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertTrue(hours.contains(instant, calendar: calendar(la)),
                      "the same instant is 10:00 local in LA, which is inside the window")
    }

    // MARK: - Formatting

    func testDisplayLabel() {
        XCTAssertEqual(ActiveHours(isEnabled: true, startHour: 9, endHour: 18).displayLabel,
                       "09:00-18:00")
        XCTAssertEqual(ActiveHours(isEnabled: false, startHour: 9, endHour: 18).displayLabel,
                       "Off")
    }

    // MARK: - Clamping

    func testOutOfRangeHoursAreClamped() {
        XCTAssertEqual(ActiveHours(isEnabled: true, startHour: -4, endHour: 99).startHour, 0)
        XCTAssertEqual(ActiveHours(isEnabled: true, startHour: -4, endHour: 99).endHour, 23)
    }
}
