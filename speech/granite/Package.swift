// swift-tools-version:6.0
import PackageDescription

// Granite Speech 5.0 2B (4-bit) on MLX (the GPU), by mlx-audio-swift, as a
// dynamic library with a C interface for Ada (see Speech.Granite). Built by
// ../native/build.sh, with xcodebuild: SwiftPM cannot build the Metal shaders.
let package = Package(
    name: "BonxieGranite",
    platforms: [.macOS("26.0")],
    products: [.library(name: "BonxieGranite", type: .dynamic, targets: ["BonxieGranite"])],
    dependencies: [
        .package(url: "https://github.com/Blaizzy/mlx-audio-swift.git", exact: "0.1.7")
    ],
    targets: [
        .target(
            name: "BonxieGranite",
            dependencies: [
                .product(name: "MLXAudioSTT", package: "mlx-audio-swift"),
                .product(name: "MLXAudioCore", package: "mlx-audio-swift"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
