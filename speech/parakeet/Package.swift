// swift-tools-version:6.0
import PackageDescription

// Parakeet TDT 0.6b v3 on Core ML (the Neural Engine), by FluidAudio, as a
// dynamic library with a C interface for Ada (see Speech.Parakeet). Built
// by ../native/build.sh.
let package = Package(
    name: "BonxieParakeet",
    platforms: [.macOS("26.0")],
    products: [.library(name: "BonxieParakeet", type: .dynamic, targets: ["BonxieParakeet"])],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.17.7")
    ],
    targets: [
        .target(
            name: "BonxieParakeet",
            dependencies: [.product(name: "FluidAudio", package: "FluidAudio")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
