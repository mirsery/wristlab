// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WristlabWorkspace",
    platforms: [.macOS(.v13)],
    dependencies: [.package(path: "Packages/WristlabCore")],
    targets: [
        .target(name: "SnapshotStorage", dependencies: [.product(name: "WristlabCore", package: "WristlabCore")], path: "Apps/Storage"),
        .target(name: "WatchSupport", dependencies: ["SnapshotStorage", .product(name: "WristlabCore", package: "WristlabCore")], path: "Apps/WatchSupport"),
        .testTarget(
            name: "WorkspaceTests",
            dependencies: ["SnapshotStorage", "WatchSupport", .product(name: "WristlabCore", package: "WristlabCore")],
            path: "Tests/WorkspaceTests"
        )
    ]
)
