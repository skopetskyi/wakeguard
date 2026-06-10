import Foundation
import WakeGuardCore

struct SystemStatus {
    let caffeinateAssertionActive: Bool
    let sleepDisabled: Bool

    static func probe() -> SystemStatus {
        let assertions = Shell.run("/usr/bin/pmset", ["-g", "assertions"])
        let settings = Shell.run("/usr/bin/pmset", ["-g"])
        return SystemStatus(
            caffeinateAssertionActive: assertions.contains("caffeinate"),
            sleepDisabled: PMSetParser.sleepDisabled(fromPMSetG: settings))
    }

    /// Human-readable line for the menu, given what the app THINKS is active.
    func menuLine(expectClosedLid: Bool) -> (text: String, isHealthy: Bool) {
        if expectClosedLid && !sleepDisabled {
            return ("⚠️ Closed-lid NOT active — daemon missing? Do not close the lid.", false)
        }
        if expectClosedLid {
            return ("System: awake ✓, closed-lid ✓ (SleepDisabled 1)", true)
        }
        if caffeinateAssertionActive {
            return ("System: awake ✓ (caffeinate assertion held)", true)
        }
        return ("⚠️ No keep-awake assertion found", false)
    }
}
