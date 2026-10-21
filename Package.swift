// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WristlabWorkspace",
    platforms: [.macOS(.v13)],
    dependencies: [.package(path: "Packages/WristlabCore")],
    targets: [
        .target(name: "SnapshotStorage", path: "Apps/Storage"),
        .testTarget(
            name: "WorkspaceTests",
            dependencies: ["SnapshotStorage", .product(name: "WristlabCore", package: "WristlabCore")],
            path: "Tests/WorkspaceTests"
        )
    ]
)
