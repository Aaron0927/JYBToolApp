// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "JYBLog",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "JYBLog",
            targets: ["JYBLog"]
        ),
    ],
    targets: [
        .target(
            name: "JYBLog",
            dependencies: []
        ),
    ]
)
