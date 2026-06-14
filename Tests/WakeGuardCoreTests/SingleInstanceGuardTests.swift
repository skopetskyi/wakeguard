import XCTest
@testable import WakeGuardCore

final class SingleInstanceGuardTests: XCTestCase {
    private func tempLockPath() -> String {
        NSTemporaryDirectory() + "wakeguard-si-\(UUID().uuidString).lock"
    }

    func testFirstGuardAcquiresLock() {
        let path = tempLockPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let guard1 = SingleInstanceGuard(lockPath: path)
        XCTAssertNotNil(guard1)
        withExtendedLifetime(guard1) {}
    }

    func testSecondGuardOnSamePathFailsWhileFirstHeld() {
        let path = tempLockPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let guard1 = SingleInstanceGuard(lockPath: path)
        XCTAssertNotNil(guard1)
        // While guard1 still holds the lock, a second guard must refuse.
        let guard2 = SingleInstanceGuard(lockPath: path)
        XCTAssertNil(guard2, "A second instance must not acquire the lock")
        withExtendedLifetime(guard1) {}
    }

    func testLockIsReleasedWhenFirstGuardDeinits() {
        let path = tempLockPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        do {
            let guard1 = SingleInstanceGuard(lockPath: path)
            XCTAssertNotNil(guard1)
        } // guard1 deinits here, releasing the flock
        let guard2 = SingleInstanceGuard(lockPath: path)
        XCTAssertNotNil(guard2, "Lock must be reacquirable once the holder exits")
        withExtendedLifetime(guard2) {}
    }
}
