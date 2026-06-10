import Foundation

public struct BatteryStatus: Equatable {
    public enum Source: Equatable {
        case ac
        case battery
    }

    public var source: Source
    public var percent: Int?   // nil when no battery line is present (desktops, parse failure)

    public init(source: Source, percent: Int?) {
        self.source = source
        self.percent = percent
    }
}

public enum BatteryStatusParser {
    /// Parses `pmset -g batt` output. Unrecognized output is treated as
    /// "on battery, unknown percent" so safety checks err on the cautious side.
    public static func parse(_ output: String) -> BatteryStatus {
        let source: BatteryStatus.Source
        if output.contains("'AC Power'") {
            source = .ac
        } else {
            source = .battery
        }
        var percent: Int?
        if let range = output.range(of: #"(\d{1,3})%"#, options: .regularExpression) {
            percent = Int(output[range].dropLast())
        }
        return BatteryStatus(source: source, percent: percent)
    }

    /// Convenience for callers: shells out and parses.
    public static func current() -> BatteryStatus {
        parse(Shell.run("/usr/bin/pmset", ["-g", "batt"]))
    }
}
