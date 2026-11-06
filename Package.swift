// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CrateSync",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "CrateSyncCore"),
        .executableTarget(name: "CrateSync", dependencies: ["CrateSyncCore"]),
        .executableTarget(name: "crate-sync-check", dependencies: ["CrateSyncCore"]),
        .executableTarget(name: "crate-sync-tests", dependencies: ["CrateSyncCore"]),
    ]
)
