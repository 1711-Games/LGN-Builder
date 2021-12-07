// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "LGNBuilder",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.2.0")),
        .package(url: "https://github.com/kirilltitov/Yams", .branch("dictionary-as-pairs-mode")),
        .package(url: "https://github.com/1711-Games/LGN-Log", .upToNextMinor(from: "0.4.0")),
    ],
    targets: [
        .executableTarget(
            name: "LGNBuilder",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "LGNLog", package: "LGN-Log"),
            ]
        ),
        .testTarget(
            name: "LGNBuilderTests",
            dependencies: ["LGNBuilder"]),
    ]
)
