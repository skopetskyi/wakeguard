import AppKit
import WakeGuardCore

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
        exit(0)
    }
    source.resume()
    signalSources.append(source)
}

app.run()
