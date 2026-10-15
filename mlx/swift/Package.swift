// swift-tools-version:6.0
import PackageDescription

// Local language models on MLX (the GPU), by mlx-swift-lm, as a dynamic
// library with a C interface for Ada (see MLX). Built by ../native/build.sh,
// with xcodebuild: SwiftPM cannot build the Metal shaders.
let package = Package(
    name: "BonxieMLX",
    platforms: [.macOS("26.0")],
    products: [.library(name: "BonxieMLX", type: .dynamic, targets: ["BonxieMLX"])],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", exact: "3.32.3"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "BonxieMLX",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
