// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ArcheAgeClassic",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "AACCore"),
        .testTarget(name: "AACCoreTests", dependencies: ["AACCore"]),
    ]
)
