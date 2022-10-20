// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "Cache",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v16),
    ],
    products: [
        .library(
            name: "Cache",
            targets: ["Cache"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Cache",
            path: "Source"
        ),
        .testTarget(
            name: "CacheTests",
            dependencies: ["Cache"],
            path: "Tests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
