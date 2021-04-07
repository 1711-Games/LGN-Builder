// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "LGNBuilder",
    platforms: [.macOS(.v10_15)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.2.0")),
        .package(url: "https://github.com/kirilltitov/Yams", .branch("dictionary-as-pairs-mode")),
        .package(url: "https://github.com/apple/swift-crypto", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "LGNBuilder",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
        .testTarget(
            name: "LGNBuilderTests",
            dependencies: ["LGNBuilder"]),
    ]
)
