// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "SwiftDiff",
    products: [
        .library(name: "SwiftDiff", targets: ["SwiftDiff"])
    ],
    targets: [
        .target(name: "SwiftDiff"),
        .testTarget(name: "SwiftDiffTests", dependencies: ["SwiftDiff"]),
    ]
)
