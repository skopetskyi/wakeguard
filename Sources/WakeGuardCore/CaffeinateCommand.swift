import Foundation

public enum CaffeinateCommand {
    public static let executablePath = "/usr/bin/caffeinate"

    public static func arguments(for config: SessionConfig, appPID: Int32) -> [String] {
        var args = ["-i"]
        if config.displayPolicy == .keepOn {
            args.append("-d")
        }
        args += ["-t", String(Int(config.duration)), "-w", String(appPID)]
        return args
    }
}
