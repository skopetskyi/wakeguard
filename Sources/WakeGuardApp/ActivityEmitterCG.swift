import CoreGraphics
import WakeGuardCore

/// Real emitter: posts an invisible F15 key event to reset the system idle
/// timer. F15 has no default binding on Mac keyboards, so it is a no-op for the
/// user but registers as user activity for presence tools (Slack, Teams).
struct CGActivityEmitter: ActivityEmitter {
    private static let f15KeyCode: CGKeyCode = 0x71

    func emit() {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: Self.f15KeyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: Self.f15KeyCode, keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
