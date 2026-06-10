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
