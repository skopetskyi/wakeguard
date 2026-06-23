import Foundation

/// A selectable way to generate the synthetic "user is active" event that keeps
/// Slack/Teams presence alive. The app maps `kind` to the real CoreGraphics call,
/// so this core type stays framework-free and testable.
public struct PresenceMethod: Equatable {
    public enum Kind: Equatable {
        case volume                 // net-zero volume tap — flashes the volume HUD
        case mouse                  // net-zero 1px mouse nudge — no HUD
        case functionKey(UInt16)    // tap an unmapped function key (no HUD), CGKeyCode
    }

    public let id: String           // stable id for persistence
    public let displayName: String
    public let kind: Kind

    public init(id: String, displayName: String, kind: Kind) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
    }
}

public enum PresenceMethods {
    public static let volume = PresenceMethod(id: "volume", displayName: "Volume tap (shows HUD)", kind: .volume)
    public static let mouse = PresenceMethod(id: "mouse", displayName: "Mouse nudge (silent)", kind: .mouse)

    /// Unmapped function keys — no HUD, no character. (F14/F15 are brightness and
    /// excluded; modifier keys are excluded because they often clash with
    /// user-assigned shortcuts.)
    public static let functionKeys: [PresenceMethod] = [
        PresenceMethod(id: "f16", displayName: "F16 key", kind: .functionKey(0x6A)),
        PresenceMethod(id: "f17", displayName: "F17 key", kind: .functionKey(0x40)),
        PresenceMethod(id: "f18", displayName: "F18 key", kind: .functionKey(0x4F)),
        PresenceMethod(id: "f19", displayName: "F19 key", kind: .functionKey(0x50)),
    ]

    public static let all: [PresenceMethod] = [volume, mouse] + functionKeys

    /// Default: volume — its HUD makes "is it working?" obvious.
    public static let `default` = volume

    public static func method(withID id: String) -> PresenceMethod? {
        all.first { $0.id == id }
    }
}
