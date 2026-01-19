// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PixelPantry",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PixelPantry",
            targets: ["PixelPantry"]
        ),
    ],
    targets: [
        .target(
            name: "PixelPantry",
            dependencies: [],
            path: "Sources/PixelPantry"
        ),
        .testTarget(
            name: "PixelPantryTests",
            dependencies: ["PixelPantry"],
            path: "Tests/PixelPantryTests"
        ),
    ]
)
