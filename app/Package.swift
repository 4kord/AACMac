// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ArcheAgeClassic",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ArcheAgeClassic", targets: ["ArcheAgeClassic"])],
    targets: [
        .target(name: "AACCore"),
        .executableTarget(name: "ArcheAgeClassic", dependencies: ["AACCore"]),
        .testTarget(name: "AACCoreTests", dependencies: ["AACCore"]),
    ]
)
