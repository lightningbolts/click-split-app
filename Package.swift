// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClickSplit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ClickSplit",
            targets: ["ClickSplit"]
        ),
    ],
    targets: [
        .target(
            name: "ClickSplit",
            path: "Sources/ClickSplit"
        ),
        .testTarget(
            name: "ClickSplitTests",
            dependencies: ["ClickSplit"],
            path: "Tests/ClickSplitTests"
        ),
    ]
)
