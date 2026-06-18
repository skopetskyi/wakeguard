import XCTest
@testable import WakeGuardCore

final class PresenceKeyTests: XCTestCase {
    func testListIsNonEmptyAndGrouped() {
        XCTAssertFalse(PresenceKeys.functionKeys.isEmpty)
        XCTAssertFalse(PresenceKeys.modifierKeys.isEmpty)
        XCTAssertEqual(PresenceKeys.all.count,
                       PresenceKeys.functionKeys.count + PresenceKeys.modifierKeys.count)
    }

    func testDefaultIsInTheList() {
        XCTAssertTrue(PresenceKeys.all.contains(PresenceKeys.default))
    }

    func testIDsAreUnique() {
        let ids = PresenceKeys.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Presence key ids must be unique")
    }

    func testLookupByID() {
        XCTAssertEqual(PresenceKeys.key(withID: PresenceKeys.default.id), PresenceKeys.default)
    }

    func testLookupUnknownReturnsNil() {
        XCTAssertNil(PresenceKeys.key(withID: "no-such-key"))
    }

    func testNoBrightnessOrCapsLockKeys() {
        // F14 (0x6B) and F15 (0x71) pop the brightness HUD; Caps Lock (0x39) has
        // its own indicator. None of those must be offered.
        let banned: Set<UInt16> = [0x6B, 0x71, 0x39]
        for key in PresenceKeys.all {
            XCTAssertFalse(banned.contains(key.keyCode),
                           "\(key.displayName) uses a banned key code 0x\(String(key.keyCode, radix: 16))")
        }
    }
}
