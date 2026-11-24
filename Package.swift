// swift-tools-version: 6.2
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
            name: "Soil",
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances")
            ]
        ),
        .testTarget(
            name: "SoilTests",
            dependencies: ["Soil"],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances")
            ]
        ),
    ]
)
