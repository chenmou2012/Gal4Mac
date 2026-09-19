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
            targets: ["Gal4Mac"]
        ),
        .library(
            name: "Gal4MacCore",
            targets: ["Gal4MacCore"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "Gal4Mac",
            dependencies: ["Gal4MacCore"],
            path: "Sources/Gal4Mac"
        ),
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
