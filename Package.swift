// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MediaCoders",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "MPEGTransport",
            targets: ["MPEGTransport"],
        ),
        .library(
            name: "AVMediaCoders",
            targets: ["AVMediaCoders"],
        ),
    ],
    dependencies: [
        .package(
            name: "AsyncUtils",
            path: "file:///Users/lixuanyu/swift_proj.nosync/AsyncUtils"
        ),
        .package(
            url: "https://github.com/yu840915/LogContext.git",
            branch: "main",
        ),
    ],

    targets: [
        .target(
            name: "MPEGTransport",
            dependencies: [
                "LogContext"
            ],
        ),
        .target(
            name: "AVMediaCoders",
            dependencies: [
                "MPEGTransport",
                "LogContext",
            ]
        ),
        .testTarget(
            name: "MPEGTransportTests",
            dependencies: [
                "MPEGTransport",                
                "AsyncUtils",
            ]
        ),
    ]
)
