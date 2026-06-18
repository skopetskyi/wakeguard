import CoreGraphics
import WakeGuardCore

/// Real emitter: taps a chosen key to reset the system idle timer without any
/// visible effect.
///
/// The key is user-selectable (see `PresenceKeys` / the "Activity Key" menu).
/// Every offered key types no character and shows no on-screen HUD, yet each is
/// still a HID event, which resets the system idle timer that presence tools
/// (Slack, Teams) read. The default is F16; F15 is avoided because it is the
/// keyboard's brightness-up key and pops the brightness HUD.
final class CGActivityEmitter: ActivityEmitter {
    /// The key tapped on each `emit()`. Mutable so the menu can change it live.
    var keyCode: CGKeyCode

    init(keyCode: CGKeyCode = CGKeyCode(PresenceKeys.default.keyCode)) {
        self.keyCode = keyCode
    }

    func emit() {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
