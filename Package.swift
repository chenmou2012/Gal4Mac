// swift-tools-version:5.9
// Gal4Mac - Swift Package Manager 配置

import PackageDescription

let package = Package(
    name: "Gal4Mac",
    platforms: [
        .macOS(.v14)  // macOS 14 Sonoma (与 Mythic 一致)
    ],
    products: [
        .executable(
            name: "gal4mac",
            targets: ["Gal4MacCLI"]
        ),
        .executable(
            name: "Gal4MacApp",
            targets: ["Gal4MacUI"]
        ),
        .library(
            name: "Gal4MacCore",
            targets: ["Gal4MacCore"]
        ),
    ],
    targets: [
        // CLI 工具
        .executableTarget(
            name: "Gal4MacCLI",
            dependencies: ["Gal4MacCore"],
            path: "Sources/Gal4MacCLI"
        ),
        // SwiftUI UI
        .executableTarget(
            name: "Gal4MacUI",
            dependencies: ["Gal4MacCore"],
            path: "Sources/Gal4MacUI"
        ),
        // 核心库
        .target(
            name: "Gal4MacCore",
            path: "Sources/Gal4MacCore"
        ),
        .testTarget(
            name: "Gal4MacCoreTests",
            dependencies: ["Gal4MacCore"],
            path: "Tests/Gal4MacCoreTests"
        ),
    ]
)
