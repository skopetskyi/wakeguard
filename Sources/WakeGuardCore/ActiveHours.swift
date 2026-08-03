import Foundation

/// A daily time window, in whole hours, during which activity simulation is
/// allowed to run. Outside it the app stops simulating, so a session started at
/// the wrong time never keeps the Mac awake overnight.
///
/// Hours are evaluated in the **machine's local time zone** (the calendar's time
/// zone; production passes `Calendar.current`).
public struct ActiveHours: Equatable {
    /// When false the window imposes no restriction — simulation runs any time.
    public var isEnabled: Bool
    /// First hour the window is active (inclusive), 0...23.
    public var startHour: Int
    /// Hour the window ends (exclusive), 0...23.
    public var endHour: Int

    public init(isEnabled: Bool = false, startHour: Int = 9, endHour: Int = 18) {
        self.isEnabled = isEnabled
        self.startHour = min(max(startHour, 0), 23)
        self.endHour = min(max(endHour, 0), 23)
    }

    /// Whether `date` falls inside the window, read in `calendar`'s time zone.
    ///
    /// Windows may wrap midnight (e.g. 22 -> 6 covers 22:00-23:59 and 00:00-05:59).
    /// A window whose start equals its end covers the whole day.
    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled else { return true }
        guard startHour != endHour else { return true }
        let hour = calendar.component(.hour, from: date)
        if startHour < endHour {
            return hour >= startHour && hour < endHour
        }
        // Wraps midnight.
        return hour >= startHour || hour < endHour
    }

    /// Menu-friendly description, e.g. "09:00-18:00" (or "Off" when disabled).
    public var displayLabel: String {
        guard isEnabled else { return "Off" }
        return String(format: "%02d:00-%02d:00", startHour, endHour)
    }
}
