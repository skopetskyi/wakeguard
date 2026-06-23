import XCTest
@testable import WakeGuardCore

final class PresenceMethodTests: XCTestCase {
    func testListContainsVolumeMouseAndFourFunctionKeys() {
        XCTAssertEqual(PresenceMethods.functionKeys.count, 4)
        XCTAssertEqual(PresenceMethods.all.count, 6) // volume + mouse + F16..F19
        XCTAssertTrue(PresenceMethods.all.contains(PresenceMethods.volume))
        XCTAssertTrue(PresenceMethods.all.contains(PresenceMethods.mouse))
    }

    func testDefaultIsInTheListAndIsVolume() {
        XCTAssertEqual(PresenceMethods.default, PresenceMethods.volume)
        XCTAssertTrue(PresenceMethods.all.contains(PresenceMethods.default))
    }

    func testIDsAreUnique() {
        let ids = PresenceMethods.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testLookupByID() {
        XCTAssertEqual(PresenceMethods.method(withID: "f18")?.kind, .functionKey(0x4F))
        XCTAssertNil(PresenceMethods.method(withID: "nope"))
    }

    func testFunctionKeysAreNotBrightnessKeys() {
        // F14 (0x6B) / F15 (0x71) would pop the brightness HUD — must not appear.
        for method in PresenceMethods.functionKeys {
            if case let .functionKey(code) = method.kind {
                XCTAssertNotEqual(code, 0x6B)
                XCTAssertNotEqual(code, 0x71)
            } else {
                XCTFail("functionKeys must all be .functionKey")
            }
        }
    }
}
