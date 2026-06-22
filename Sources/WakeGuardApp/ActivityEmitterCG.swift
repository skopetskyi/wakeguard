import CoreGraphics
import WakeGuardCore

/// Real emitter: a **net-zero mouse nudge** that resets the system idle timer
/// with no visible effect.
///
/// Mouse movement is the most reliable "user is active" signal — for the system
/// idle timer and for presence tools (Slack, Teams). We read the current cursor
/// location, move it 1px, then move it straight back to the exact original spot,
/// so there is no net cursor movement, no character, and no on-screen HUD.
struct CGActivityEmitter: ActivityEmitter {
    func emit() {
        let source = CGEventSource(stateID: .hidSystemState)
        // A freshly created event (nil source) reports the current cursor point.
        let origin = CGEvent(source: nil)?.location ?? .zero
        // Nudge left unless we're at the left edge, so the cursor stays on-screen
        // and the return lands exactly back on `origin`.
        let dx: CGFloat = origin.x > 1 ? -1 : 1
        post(source, to: CGPoint(x: origin.x + dx, y: origin.y))
        post(source, to: origin)
    }

    private func post(_ source: CGEventSource?, to point: CGPoint) {
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                mouseCursorPosition: point, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }
}
