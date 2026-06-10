import Foundation

/// A short-lived grant of "keep the Mac awake with the lid closed".
/// The app renews it every `renewInterval`; the daemon honors it only while
/// fresh. No fresh lease == normal sleep behavior, no matter why.
public struct Lease: Codable, Equatable {
    public var sessionID: String
    public var appPID: Int32
    public var expiresAt: Date
    public var hardBatteryFloorPercent: Int

    /// A lease may never grant more than this far into the future.
    public static let maxTTL: TimeInterval = 60
    /// TTL the app writes on each renewal.
    public static let ttl: TimeInterval = 30
    /// How often the app renews.
    public static let renewInterval: TimeInterval = 10
    /// Where app and daemon meet. Directory is user-owned (created by the
    /// installer); the daemon only reads timestamps/ints from it.
    public static let defaultPath = "/usr/local/var/wakeguard/lease.json"

    public init(sessionID: String, appPID: Int32, expiresAt: Date, hardBatteryFloorPercent: Int) {
        self.sessionID = sessionID
        self.appPID = appPID
        self.expiresAt = expiresAt
        self.hardBatteryFloorPercent = hardBatteryFloorPercent
    }

    public func isValid(now: Date) -> Bool {
        let remaining = expiresAt.timeIntervalSince(now)
        return remaining > 0 && remaining <= Lease.maxTTL
    }
}
