// swift-tools-version: 5.9

import PackageDescription

let strictConcurrency: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "ScoringEngine",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "ScoringEngine", targets: ["ScoringEngine"])
    ],
    targets: [
        .target(name: "ScoringEngine", swiftSettings: strictConcurrency),
        .testTarget(
            name: "ScoringEngineTests",
            dependencies: ["ScoringEngine"],
            swiftSettings: strictConcurrency
        )
    ]
)
