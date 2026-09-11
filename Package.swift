// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "SmartPause",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "SmartPause", path: "Sources/SmartPause"),
        .testTarget(name: "SmartPauseTests", dependencies: ["SmartPause"], path: "Tests/SmartPauseTests"),
    ]
)
