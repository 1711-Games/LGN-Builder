// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "LGNBuilder",
    platforms: [.macOS(.v10_15)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.2.0")),
        .package(url: "https://github.com/kirilltitov/Yams", .branch("dictionary-as-pairs-mode")),
        //.package(name: "SwiftSyntax", url: "https://github.com/apple/swift-syntax", .exact("0.50200.0")),
    ],
    targets: [
        .target(
            name: "LGNBuilder",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Yams", package: "Yams"),
//                .product(name: "SwiftSyntax", package: "SwiftSyntax"),
            ]
        ),
        .testTarget(
            name: "LGNBuilderTests",
            dependencies: ["LGNBuilder"]),
    ]
)
