// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftDataExample",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SwiftDataExampleLib",
            targets: ["SwiftDataExampleLib"]
        ),
    ],
    dependencies: [
        // Tracks the AppState `develop` branch until 3.0.0 (which ships the SwiftData support this
        // example demonstrates) is released — then switch to `from: "3.0.0"`.
        .package(url: "https://github.com/0xLeif/AppState.git", branch: "develop"),
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0"),
    ],
    targets: [
        .target(
            name: "SwiftDataExampleLib",
            dependencies: [
                .product(name: "AppState", package: "AppState"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "SwiftDataExample",
            dependencies: [
                .product(name: "AppState", package: "AppState"),
                "SwiftDataExampleLib",
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "SwiftDataExampleTests",
            dependencies: [
                "SwiftDataExampleLib",
                .product(name: "AppState", package: "AppState"),
                .product(name: "ViewInspector", package: "ViewInspector"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
    ]
)
