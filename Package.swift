// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AppCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "AppCore", targets: ["AppCore"])
    ],
    dependencies: [
        .package(path: "Packages/ScoringEngine")
    ],
    targets: [
        .target(
            name: "AppCore",
            dependencies: [
                .product(name: "ScoringEngine", package: "ScoringEngine")
            ]
        ),
        .testTarget(
            name: "AppCoreTests",
            dependencies: ["AppCore"]
        )
    ]
)
