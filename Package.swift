// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WristlabWorkspace",
    platforms: [.macOS(.v13)],
    dependencies: [.package(path: "Packages/WristlabCore")],
    targets: [.testTarget(name: "WorkspaceTests", dependencies: [.product(name: "WristlabCore", package: "WristlabCore")], path: "Tests/WorkspaceTests")]
)
