import Foundation
import WakeGuardCore

let pollInterval: TimeInterval = 5
let leaseURL = URL(fileURLWithPath: Lease.defaultPath)
let store = LeaseStore(url: leaseURL)
let timestampFormatter = ISO8601DateFormatter()

func log(_ message: String) {
    // launchd redirects stdout to /var/log/wakeguardd.log (see plist).
    print("\(timestampFormatter.string(from: Date())) \(message)")
    fflush(stdout)   // stdout is block-buffered when redirected to a file
}

func currentSleepDisabled() -> Bool {
    PMSetParser.sleepDisabled(fromPMSetG: Shell.run("/usr/bin/pmset", ["-g"]))
}

func setSleepDisabled(_ on: Bool) {
    Shell.run("/usr/bin/pmset", ["-a", "disablesleep", on ? "1" : "0"])
    log("set disablesleep=\(on ? 1 : 0)")
}

func leaseFileIsRegularFile() -> Bool {
    let attrs = try? FileManager.default.attributesOfItem(atPath: leaseURL.path)
    return (attrs?[.type] as? FileAttributeType) == .typeRegular
}

func desiredSleepDisabled(now: Date) -> Bool {
    guard leaseFileIsRegularFile(), let lease = store.read() else { return false }
    guard lease.isValid(now: now) else { return false }
    let battery = BatteryStatusParser.parse(Shell.run("/usr/bin/pmset", ["-g", "batt"]))
    if battery.source == .battery {
        guard let percent = battery.percent, percent >= lease.hardBatteryFloorPercent else {
            log("hard battery floor (\(lease.hardBatteryFloorPercent)%) — ignoring lease, battery=\(battery.percent.map(String.init) ?? "unknown")")
            return false
        }
    }
    return true
}

// Invariant: every daemon start begins from normal sleep behavior. A stale
// disablesleep=1 from a hard crash or power loss must never survive a restart.
log("wakeguardd starting — reverting to disablesleep=0")
setSleepDisabled(false)

signal(SIGTERM, SIG_IGN)
let sigterm = DispatchSource.makeSignalSource(signal: SIGTERM)
sigterm.setEventHandler {
    log("SIGTERM — reverting to disablesleep=0 and exiting")
    setSleepDisabled(false)
    exit(0)
}
sigterm.resume()

let timer = DispatchSource.makeTimerSource()
timer.schedule(deadline: .now(), repeating: pollInterval)
timer.setEventHandler {
    let desired = desiredSleepDisabled(now: Date())
    if desired != currentSleepDisabled() {
        setSleepDisabled(desired)
    }
}
timer.resume()

dispatchMain()
