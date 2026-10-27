// swift-tools-version: 6.0
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
    ],
    swiftLanguageModes: [.v6]
)
