// swift-tools-version: 6.1
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
    traits: [
        .trait(name: "DEBUG_MEDIA_DATA_IO"),
        .trait(name: "DEBUG_PACKETIZATION_IO"),
    ],
    dependencies: [
        .package(
            url: "https://github.com/yu840915/AsyncUtils.git",
            branch: "main",
        ),
        .package(
            url: "https://github.com/yu840915/LogContext.git",
            branch: "main",
        ),
        .package(
            url: "https://github.com/yu840915/RemoteCameraCore.git",
            branch: "main",
        ),
    ],

    targets: [
        .target(
            name: "MPEGTransport",
            dependencies: [
                "LogContext",
                .product(name: "LogContextValueFormat", package: "LogContext"),
                .product(name: "DebugToolkit", package: "LogContext"),
            ],
        ),
        .target(
            name: "AVMediaCoders",
            dependencies: [
                "MPEGTransport",
                "LogContext",
                "RemoteCameraCore",
                .product(name: "LogContextValueFormat", package: "LogContext"),
                .product(name: "DebugToolkit", package: "LogContext"),
            ]
        ),
        .testTarget(
            name: "MPEGTransportTests",
            dependencies: [
                "MPEGTransport",
                "AsyncUtils",
            ]
        ),
        .testTarget(
            name: "AVMediaCodersTests",
            dependencies: [
                "AVMediaCoders",
                "RemoteCameraCore",
            ],
        ),
    ]
)
