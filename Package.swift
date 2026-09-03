// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CutX",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "CutXCore", path: "Sources/CutXCore"),
        .executableTarget(
            name: "CutX",
            dependencies: ["CutXCore"],
            path: "Sources/CutX"
        ),
        .testTarget(
            name: "CutXCoreTests",
            dependencies: ["CutXCore"],
            path: "Tests/CutXCoreTests"
        ),
    ]
)
