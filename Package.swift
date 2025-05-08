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
    dependencies: [
        .package(
            name: "AsyncUtils",
            path: "file:///Users/lixuanyu/swift_proj.nosync/AsyncUtils"
        )
    ],

    targets: [
        .target(
            name: "AVMediaCoders",
            dependencies: []
        ),
        .testTarget(
            name: "AVMediaCodersTests",
            dependencies: [
                "AVMediaCoders",
                "AsyncUtils",
            ]
        ),
    ]
)
