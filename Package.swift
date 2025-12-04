// swift-tools-version: 6.2
// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi

import PackageDescription

let package = Package(
    name: "spfk-testing",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "SPFKTesting",
            targets: [
                "SPFKTesting",
            ]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SPFKTesting",
            dependencies: [],
            resources: [.process("Resources")]
        ),

        .testTarget(
            name: "SPFKTestingTests",
            dependencies: [
                "SPFKTesting",
            ]
        ),
    ]
)
