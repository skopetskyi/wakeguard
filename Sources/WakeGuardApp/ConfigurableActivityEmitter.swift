import AppKit
import WakeGuardCore

/// Emits the synthetic "user is active" event using the currently selected
/// `PresenceMethod`. `method` is mutable so the "Activity Method" menu can switch
/// the mechanism live. All variants post to `.cghidEventTap` and therefore need
/// Accessibility permission to take effect.
final class ConfigurableActivityEmitter: ActivityEmitter {
    var method: PresenceMethod = PresenceMethods.default

    func emit() {
        switch method.kind {
        case .volume:           emitVolume()
        case .mouse:            emitMouse()
        case .functionKey(let code): emitKey(CGKeyCode(code))
        }
    }

    // MARK: - Volume tap (net-zero, flashes the volume HUD)

    private static let soundUp: Int32 = 0    // NX_KEYTYPE_SOUND_UP
    private static let soundDown: Int32 = 1  // NX_KEYTYPE_SOUND_DOWN

    private func emitVolume() {
        mediaTap(Self.soundDown)
        mediaTap(Self.soundUp)
    }

    private func mediaTap(_ key: Int32) {
        postMediaKey(key, keyDown: true)
        postMediaKey(key, keyDown: false)
    }

    private func postMediaKey(_ key: Int32, keyDown: Bool) {
        let flags = keyDown ? 0xA00 : 0xB00
        let data1 = (Int(key) << 16) | flags
        guard let event = NSEvent.otherEvent(
            with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0,
            context: nil, subtype: 8, data1: data1, data2: -1)
        else { return }
        event.cgEvent?.post(tap: .cghidEventTap)
    }

    // MARK: - Mouse nudge (net-zero, silent)

    private func emitMouse() {
        let source = CGEventSource(stateID: .hidSystemState)
        let origin = CGEvent(source: nil)?.location ?? .zero
        let dx: CGFloat = origin.x > 1 ? -1 : 1
        postMouse(source, to: CGPoint(x: origin.x + dx, y: origin.y))
        postMouse(source, to: origin)
    }

    private func postMouse(_ source: CGEventSource?, to point: CGPoint) {
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                mouseCursorPosition: point, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }

    // MARK: - Function key tap (no HUD)

    private func emitKey(_ code: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)?.post(tap: .cghidEventTap)
    }
}
