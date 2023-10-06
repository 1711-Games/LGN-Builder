// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "LGN-Builder",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "LGNBuilder", targets: ["LGNBuilder"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.3"),
        .package(url: "https://github.com/kirilltitov/Yams", branch: "dictionary-as-pairs-mode"),
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
            dependencies: ["LGNBuilder"]
        ),
    ]
)
