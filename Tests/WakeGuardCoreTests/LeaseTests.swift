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
