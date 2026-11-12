// swift-tools-version: 5.9

import PackageDescription

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
        .target(name: "ScoringEngine"),
        .testTarget(
            name: "ScoringEngineTests",
            dependencies: ["ScoringEngine"]
        )
    ]
)
