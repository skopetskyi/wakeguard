import Foundation
import WakeGuardCore

final class SafetyMonitor {
    static let pollInterval: TimeInterval = 15

    private let controller: SessionController
    private let limits: SafetyLimits
    private var timer: Timer?
    private var warnedThisSession = false

    init(controller: SessionController, limits: SafetyLimits) {
        self.controller = controller
        self.limits = limits
    }

    func start() {
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.check()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func sessionDidStart() { warnedThisSession = false }

    private func check() {
        guard let session = controller.activeSession else { return }
        let thermal: SafetyThermalState
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = .nominal
        case .fair: thermal = .fair
        case .serious: thermal = .serious
        case .critical: thermal = .critical
        @unknown default: thermal = .critical   // unknown thermal state: fail safe
        }

        let verdict = SafetyPolicy.evaluate(battery: BatteryStatusParser.current(),
                                            thermal: thermal,
                                            sessionElapsed: Date().timeIntervalSince(session.startedAt),
                                            lidPolicy: session.config.lidPolicy,
                                            limits: limits,
                                            startedOnAC: session.startedOnAC)
        switch verdict {
        case .ok:
            break
        case .warn(let message):
            if !warnedThisSession {
                warnedThisSession = true
                Notify.send(title: "WakeGuard warning", body: message)
            }
        case .endSession(let reason):
            controller.stop(reason: reason)
        }
    }
}
