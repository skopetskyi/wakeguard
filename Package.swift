// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WakeGuard",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "WakeGuardCore"),
        .executableTarget(name: "wakeguardd", dependencies: ["WakeGuardCore"]),
        .executableTarget(name: "WakeGuardApp", dependencies: ["WakeGuardCore"]),
        .testTarget(name: "WakeGuardCoreTests", dependencies: ["WakeGuardCore"]),
    ]
)
