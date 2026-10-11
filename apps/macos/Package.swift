// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MacStats",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MacStats", targets: ["MacStats"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .executableTarget(
            name: "MacStats",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/MacStats",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                // bundle.sh copies Sparkle.framework into Contents/Frameworks.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
