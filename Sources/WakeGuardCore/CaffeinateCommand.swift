import Foundation

public enum CaffeinateCommand {
    public static let executablePath = "/usr/bin/caffeinate"

    public static func arguments(for config: SessionConfig, appPID: Int32) -> [String] {
        var args = ["-i"]
        // Closed-lid mode means no display, so never assert display-stay-awake
        // there — let the display sleep while the daemon keeps the system awake.
        if config.displayPolicy == .keepOn && config.lidPolicy != .stayAwakeWhenClosed {
            args.append("-d")
        }
        args += ["-t", String(Int(config.duration)), "-w", String(appPID)]
        return args
    }
}
