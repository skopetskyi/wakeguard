import XCTest
@testable import WakeGuardCore

private final class FakeEmitter: ActivityEmitter {
    var emitCount = 0
    func emit() { emitCount += 1 }
}

final class ActivitySimulatorTests: XCTestCase {
    private var emitter: FakeEmitter!
    private var simulator: ActivitySimulator!

    override func setUp() {
        super.setUp()
        emitter = FakeEmitter()
        simulator = ActivitySimulator(emitter: emitter)
    }

    // MARK: - Initial state

    func testFreshSimulatorIsNotRunning() {
        XCTAssertFalse(simulator.isRunning)
    }

    func testFreshSimulatorHasEmittedNothing() {
        XCTAssertEqual(emitter.emitCount, 0)
    }

    // MARK: - start()

    func testStartEmitsOneEventImmediately() {
        simulator.start()
        XCTAssertEqual(emitter.emitCount, 1)
    }

    func testStartSetsIsRunning() {
        simulator.start()
        XCTAssertTrue(simulator.isRunning)
    }

    // MARK: - Idempotent start

    func testStartWhileAlreadyRunningIsIdempotent() {
        simulator.start()
        simulator.start()          // second call must be a no-op
        XCTAssertEqual(emitter.emitCount, 1, "Double-start must not emit a second event")
    }

    func testStartWhileAlreadyRunningStaysRunning() {
        simulator.start()
        simulator.start()
        XCTAssertTrue(simulator.isRunning)
    }

    // MARK: - stop()

    func testStopSetsIsRunningFalse() {
        simulator.start()
        simulator.stop()
        XCTAssertFalse(simulator.isRunning)
    }

    func testStopWithoutStartIsNoOp() {
        // applicationWillTerminate calls stop() unconditionally — a cold stop
        // must be a safe no-op, not emit and not flip into a running state.
        simulator.stop()
        XCTAssertFalse(simulator.isRunning)
        XCTAssertEqual(emitter.emitCount, 0)
    }

    // MARK: - Restart after stop

    func testStartAfterStopEmitsAgain() {
        simulator.start()          // emit #1
        simulator.stop()
        simulator.start()          // emit #2
        XCTAssertEqual(emitter.emitCount, 2)
    }

    func testStartAfterStopIsRunning() {
        simulator.start()
        simulator.stop()
        simulator.start()
        XCTAssertTrue(simulator.isRunning)
    }

    // MARK: - emitOnce

    func testEmitOnceEmitsWithoutRunning() {
        simulator.emitOnce()
        XCTAssertEqual(emitter.emitCount, 1)
        XCTAssertFalse(simulator.isRunning, "emitOnce must not start the loop")
    }
}
