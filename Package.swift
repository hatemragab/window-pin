// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WindowPin",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "WindowPin", targets: ["WindowPin"]),
    ],
    targets: [
        .executableTarget(
            name: "WindowPin",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
