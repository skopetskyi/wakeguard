import Foundation

public struct SafetyLimits: Equatable {
    /// App ends a closed-lid session below this percent while on battery.
    public var softBatteryPercent: Int = 30
    /// Daemon force-reverts below this percent even with a valid lease.
    public var hardBatteryFloorPercent: Int = 15
    /// No closed-lid session may run longer than this.
    public var maxClosedLidDuration: TimeInterval = 12 * 3600
    /// If true, losing AC power ends a closed-lid session instead of warning.
    public var endOnACDisconnect: Bool = false

    public init() {}
}

/// Mirror of ProcessInfo.ThermalState so core stays UI-framework-free and testable.
public enum SafetyThermalState: Equatable {
    case nominal, fair, serious, critical
}

public enum SafetyVerdict: Equatable {
    case ok
    case warn(String)
    case endSession(String)
}

public enum SafetyPolicy {
    public static func evaluate(battery: BatteryStatus,
                                thermal: SafetyThermalState,
                                sessionElapsed: TimeInterval,
                                lidPolicy: SessionConfig.LidPolicy,
                                limits: SafetyLimits,
                                startedOnAC: Bool) -> SafetyVerdict {
        if thermal == .critical {
            return .endSession("Thermal state is critical")
        }
        guard lidPolicy == .stayAwakeWhenClosed else { return .ok }

        if sessionElapsed > limits.maxClosedLidDuration {
            return .endSession("Maximum closed-lid duration (12h) reached")
        }
        if battery.source == .battery {
            guard let percent = battery.percent else {
                return .endSession("Battery level unreadable while on battery power")
            }
            if percent < limits.softBatteryPercent {
                return .endSession("Battery at \(percent)% (below \(limits.softBatteryPercent)% threshold)")
            }
            if startedOnAC {
                return limits.endOnACDisconnect
                    ? .endSession("AC power disconnected")
                    : .warn("AC power disconnected — now on battery (\(percent)%)")
            }
        }
        return .ok
    }
}
