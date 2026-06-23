import ApplicationServices

/// Accessibility (Input Monitoring) permission gate for posting synthetic events.
///
/// macOS silently drops synthetic input from an untrusted process, so a missing
/// grant is the usual reason the volume blip "does nothing". Note: an ad-hoc
/// signed build loses this grant on every rebuild (the signature changes), so it
/// must be re-granted after each `build-app.sh`.
enum AccessibilityPermission {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Returns current trust. If untrusted, also pops the system dialog that
    /// guides the user to System Settings → Privacy & Security → Accessibility.
    @discardableResult
    static func promptIfNeeded() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
