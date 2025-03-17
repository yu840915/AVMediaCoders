// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AVMediaCoders",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "AVMediaCoders",
            targets: ["AVMediaCoders"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AVMediaCoders",
            dependencies: []
        ),
        .testTarget(
            name: "AVMediaCodersTests",
            dependencies: ["AVMediaCoders"]
        ),
    ]
)
