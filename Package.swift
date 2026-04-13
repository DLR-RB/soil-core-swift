// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "soil-swift",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
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
