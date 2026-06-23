import AppKit
import WakeGuardCore

/// Real emitter: taps **volume-down then volume-up** (net-zero volume) every
/// tick. A media-key press is a real, fully-processed input event that resets
/// the system idle timer and that Slack/Teams reliably count as activity —
/// deliberately flashing the volume HUD. Net-zero in the normal range; at the
/// extremes the volume may drift by one step (an accepted trade-off).
struct VolumeTapActivityEmitter: ActivityEmitter {
    private static let soundUp: Int32 = 0    // NX_KEYTYPE_SOUND_UP
    private static let soundDown: Int32 = 1  // NX_KEYTYPE_SOUND_DOWN

    func emit() {
        tap(Self.soundDown)
        tap(Self.soundUp)
    }

    private func tap(_ key: Int32) {
        postMediaKey(key, keyDown: true)
        postMediaKey(key, keyDown: false)
    }

    /// Posts a system-defined media key via the documented NSEvent → CGEvent hack.
    private func postMediaKey(_ key: Int32, keyDown: Bool) {
        let flags = keyDown ? 0xA00 : 0xB00          // 0xA = down, 0xB = up
        let data1 = (Int(key) << 16) | flags
        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1)
        else { return }
        event.cgEvent?.post(tap: .cghidEventTap)
    }
}
