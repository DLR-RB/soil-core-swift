// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "soil-swift",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Soil",
            targets: ["Soil"]
        ),
    ],
    targets: [
        .target(
            name: "Soil"
        ),
        .testTarget(
            name: "SoilTests",
            dependencies: ["Soil"]
        ),
    ]
)
