import Foundation

public enum CaffeinateCommand {
    public static let executablePath = "/usr/bin/caffeinate"

    public static func arguments(for config: SessionConfig, appPID: Int32) -> [String] {
        var args = ["-i"]
        // Respect the display policy uniformly. For closed-lid sessions the app
        // sets the policy based on whether an external display is connected
        // (clamshell → keep it on; bare shut lid → let it sleep).
        if config.displayPolicy == .keepOn {
            args.append("-d")
        }
        args += ["-t", String(Int(config.duration)), "-w", String(appPID)]
        return args
    }
}
