// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MultiCasual",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)   // enables `swift test` without simulator
    ],
    products: [
        .library(name: "MultiCasual", targets: ["MultiCasual"]),
        .executable(name: "ModelsValidator", targets: ["ModelsValidator"]),
    ],
    targets: [
        .target(
            name: "MultiCasual",
            path: "MultiCasual",
            sources: ["Models", "Core", "Features"]
        ),
        .executableTarget(
            name: "ModelsValidator",
            dependencies: ["MultiCasual"],
            path: "ModelsValidator"
        ),
        .testTarget(
            name: "Multi-CasualTests",
            dependencies: ["MultiCasual"],
            path: "Multi-CasualTests"
        ),
    ]
)
