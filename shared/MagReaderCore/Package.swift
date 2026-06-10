// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MagReaderCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "MagReaderCore", targets: ["MagReaderCore"])
    ],
    targets: [
        .target(
            name: "MagReaderCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "MagReaderCoreTests",
            dependencies: ["MagReaderCore"]
        )
    ]
)
