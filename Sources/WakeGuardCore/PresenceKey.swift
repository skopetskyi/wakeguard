import Foundation

/// A keyboard key the activity simulator "taps" to reset the system idle timer
/// (see ActivitySimulator / the app's CGActivityEmitter).
///
/// The key code is stored as a raw `UInt16` (the value of `CGKeyCode`) so this
/// core type stays free of CoreGraphics; the app maps it when posting the event.
public struct PresenceKey: Equatable {
    /// Stable identifier used for persistence (UserDefaults).
    public let id: String
    /// Human-readable name shown in the menu.
    public let displayName: String
    /// Virtual key code (matches `CGKeyCode`).
    public let keyCode: UInt16

    public init(id: String, displayName: String, keyCode: UInt16) {
        self.id = id
        self.displayName = displayName
        self.keyCode = keyCode
    }
}

/// The curated set of keys that reset the idle timer **without** typing a
/// character or showing an on-screen HUD. Brightness keys (F14/F15), Caps Lock,
/// and the fn/Globe key are deliberately excluded — they pop their own HUD.
public enum PresenceKeys {
    /// Function keys with no default binding and no HUD — the least
    /// collision-prone choices, so these are listed first / used as the default.
    public static let functionKeys: [PresenceKey] = [
        PresenceKey(id: "f16", displayName: "F16", keyCode: 0x6A),
        PresenceKey(id: "f13", displayName: "F13", keyCode: 0x69),
        PresenceKey(id: "f17", displayName: "F17", keyCode: 0x40),
        PresenceKey(id: "f18", displayName: "F18", keyCode: 0x4F),
        PresenceKey(id: "f19", displayName: "F19", keyCode: 0x50),
    ]

    /// Modifier keys — no character, no HUD, but may clash with shortcuts you've
    /// assigned (e.g. Right Option bound to a dictation/voice feature).
    public static let modifierKeys: [PresenceKey] = [
        PresenceKey(id: "leftControl", displayName: "Left Control", keyCode: 0x3B),
        PresenceKey(id: "rightControl", displayName: "Right Control", keyCode: 0x3E),
        PresenceKey(id: "leftOption", displayName: "Left Option", keyCode: 0x3A),
        PresenceKey(id: "rightOption", displayName: "Right Option", keyCode: 0x3D),
        PresenceKey(id: "leftShift", displayName: "Left Shift", keyCode: 0x38),
        PresenceKey(id: "rightShift", displayName: "Right Shift", keyCode: 0x3C),
        PresenceKey(id: "leftCommand", displayName: "Left Command", keyCode: 0x37),
        PresenceKey(id: "rightCommand", displayName: "Right Command", keyCode: 0x36),
    ]

    /// All selectable keys, function keys first.
    public static let all: [PresenceKey] = functionKeys + modifierKeys

    /// Default key: F16 — a virtual key with essentially no chance of collision.
    public static let `default`: PresenceKey = functionKeys[0]

    /// Looks up a key by its stable id (used when restoring the saved choice).
    public static func key(withID id: String) -> PresenceKey? {
        all.first { $0.id == id }
    }
}
