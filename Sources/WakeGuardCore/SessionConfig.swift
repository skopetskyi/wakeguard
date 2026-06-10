import Foundation

public struct SessionConfig: Equatable {
    public enum DisplayPolicy: Equatable {
        case keepOn     // prevent display sleep (caffeinate -d)
        case allowOff   // system stays awake, display may sleep
    }

    public enum LidPolicy: Equatable {
        case normalSleep          // closing the lid sleeps the Mac as usual
        case stayAwakeWhenClosed  // daemon sets pmset disablesleep while leased
    }

    public var duration: TimeInterval
    public var displayPolicy: DisplayPolicy
    public var lidPolicy: LidPolicy

    public init(duration: TimeInterval, displayPolicy: DisplayPolicy, lidPolicy: LidPolicy) {
        self.duration = duration
        self.displayPolicy = displayPolicy
        self.lidPolicy = lidPolicy
    }
}
