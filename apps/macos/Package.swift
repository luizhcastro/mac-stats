// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MacStats",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MacStats", targets: ["MacStats"])
    ],
    targets: [
        .executableTarget(
            name: "MacStats",
            path: "Sources/MacStats",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
