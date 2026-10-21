// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WristlabCore",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v13)],
    products: [.library(name: "WristlabCore", targets: ["WristlabCore"])],
    targets: [.target(name: "WristlabCore"), .testTarget(name: "WristlabCoreTests", dependencies: ["WristlabCore"], resources: [.copy("Fixtures")])]
)
