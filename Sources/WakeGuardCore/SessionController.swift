import Foundation

public protocol CaffeinateProcess {
    var isRunning: Bool { get }
    func terminate()
}

public protocol ProcessSpawning {
    func spawnCaffeinate(arguments: [String]) throws -> CaffeinateProcess
}

/// Production spawner wrapping Foundation.Process.
public final class CaffeinateSpawner: ProcessSpawning {
    public init() {}

    private final class RealProcess: CaffeinateProcess {
        let process: Process
        init(process: Process) { self.process = process }
        var isRunning: Bool { process.isRunning }
        func terminate() { if process.isRunning { process.terminate() } }
    }

    public func spawnCaffeinate(arguments: [String]) throws -> CaffeinateProcess {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: CaffeinateCommand.executablePath)
        process.arguments = arguments
        try process.run()
        return RealProcess(process: process)
    }
}

public final class SessionController {
    public struct ActiveSession {
        public let config: SessionConfig
        public let startedAt: Date
        public let startedOnAC: Bool
        public let process: CaffeinateProcess
        public var endsAt: Date { startedAt.addingTimeInterval(config.duration) }
    }

    public private(set) var activeSession: ActiveSession?
    /// Called with a human-readable reason whenever a session ends.
    public var onSessionEnded: ((String) -> Void)?

    private let spawner: ProcessSpawning
    private let leaseStore: LeaseStore
    private let limits: SafetyLimits
    private var leaseTimer: Timer?
    private var endTimer: Timer?

    public init(spawner: ProcessSpawning, leaseStore: LeaseStore, limits: SafetyLimits) {
        self.spawner = spawner
        self.leaseStore = leaseStore
        self.limits = limits
    }

    public func start(_ config: SessionConfig) throws {
        stopInternal(reason: "Replaced by new session", notify: activeSession != nil)

        let pid = ProcessInfo.processInfo.processIdentifier
        let process = try spawner.spawnCaffeinate(
            arguments: CaffeinateCommand.arguments(for: config, appPID: pid))
        let session = ActiveSession(config: config,
                                    startedAt: Date(),
                                    startedOnAC: BatteryStatusParser.current().source == .ac,
                                    process: process)
        activeSession = session

        if config.lidPolicy == .stayAwakeWhenClosed {
            renewLease()
            let timer = Timer(timeInterval: Lease.renewInterval, repeats: true) { [weak self] _ in
                self?.renewLease()
            }
            RunLoop.main.add(timer, forMode: .common)
            leaseTimer = timer
        }

        // Authoritative duration enforcement (caffeinate -t is best-effort only).
        let end = Timer(timeInterval: config.duration, repeats: false) { [weak self] _ in
            self?.stop(reason: "Session duration elapsed")
        }
        RunLoop.main.add(end, forMode: .common)
        endTimer = end
    }

    public func stop(reason: String) {
        stopInternal(reason: reason, notify: activeSession != nil)
    }

    private func stopInternal(reason: String, notify: Bool) {
        leaseTimer?.invalidate(); leaseTimer = nil
        endTimer?.invalidate(); endTimer = nil
        leaseStore.clear()
        activeSession?.process.terminate()
        activeSession = nil
        if notify { onSessionEnded?(reason) }
    }

    private func renewLease() {
        guard let session = activeSession else { return }
        let expiry = min(Date().addingTimeInterval(Lease.ttl), session.endsAt)
        let lease = Lease(sessionID: "\(session.startedAt.timeIntervalSince1970)",
                          appPID: ProcessInfo.processInfo.processIdentifier,
                          expiresAt: expiry,
                          hardBatteryFloorPercent: limits.hardBatteryFloorPercent)
        try? leaseStore.write(lease)
    }
}
