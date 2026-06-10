import Foundation

public enum PMSetParser {
    /// Parses `pmset -g` output. The SleepDisabled line is absent when sleep
    /// is not disabled, so absence must read as false.
    public static func sleepDisabled(fromPMSetG output: String) -> Bool {
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("SleepDisabled") {
                return trimmed.hasSuffix("1")
            }
        }
        return false
    }
}
