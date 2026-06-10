import Foundation
import WakeGuardCore

enum Notify {
    /// osascript notifications work from an unbundled binary; UNUserNotificationCenter does not.
    static func send(title: String, body: String) {
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
        Shell.run("/usr/bin/osascript",
                  ["-e", "display notification \"\(escapedBody)\" with title \"\(escapedTitle)\""])
    }
}
