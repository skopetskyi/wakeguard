import AppKit
import WakeGuardCore

// Enforce a single running instance. The kernel frees this lock when we exit,
// so a crash never leaves a stale lock. This covers bare-binary launches; the
// .app bundle additionally sets LSMultipleInstancesProhibited for the Finder
// "open" path. `instanceGuard` is a global, so it lives for the whole process.
guard let instanceGuard = SingleInstanceGuard() else {
    Notify.send(title: "WakeGuard", body: "WakeGuard is already running.")
    exit(0)
}

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate

// SIGTERM/SIGINT (Activity Monitor "Quit", Ctrl-C from terminal) must clean up
// like a normal quit. SIGKILL needs no handler: caffeinate -w dies with us and
// the lease expires within ~35s.
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGTERM, SIGINT] {
    signal(sig, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    source.setEventHandler {
        delegate.controller.stop(reason: "Terminated by signal")
        delegate.activitySimulator.stop()
        exit(0)
    }
    source.resume()
    signalSources.append(source)
}

app.run()
