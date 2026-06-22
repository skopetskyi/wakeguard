import Foundation

/// Seam for injecting a synthetic user-activity event.
/// The production implementation nudges the mouse a net-zero amount (see the
/// app's CGActivityEmitter) via CoreGraphics; tests supply a counting fake.
/// Each `emit()` call resets the system HID idle timer, keeping presence tools
/// (Slack, Teams, etc.) from marking the user as away.
public protocol ActivityEmitter {
    func emit()
}

/// On-demand presence keeper: while running, emits a synthetic user-activity
/// event once per `interval` seconds so that presence tools see the account as
/// active. Starts and stops explicitly — it never runs unless toggled on.
///
/// Usage mirrors `SessionController`: inject an `ActivityEmitter` at init time
/// so the unit tests can supply a `FakeEmitter` without touching CoreGraphics.
public final class ActivitySimulator {

    /// Emission cadence. Kept well below the tightest known presence-away
    /// threshold (Microsoft Teams marks away after ~5 minutes; Slack after ~10).
    /// 60 s gives a comfortable margin while remaining imperceptible to the user.
    public static let interval: TimeInterval = 60

    /// Whether the simulator is currently running.
    public private(set) var isRunning = false

    private let emitter: ActivityEmitter
    private var timer: Timer?

    public init(emitter: ActivityEmitter) {
        self.emitter = emitter
    }

    deinit {
        timer?.invalidate()
    }

    /// Starts periodic activity simulation.
    /// Emits one event immediately so presence tools register the activity
    /// without waiting up to `interval` seconds.
    /// Idempotent: calling `start()` while already running is a no-op.
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        emitter.emit()
        let t = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            self?.emitter.emit()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Stops periodic activity simulation.
    /// The next `start()` call will resume from a clean state.
    public func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
}
