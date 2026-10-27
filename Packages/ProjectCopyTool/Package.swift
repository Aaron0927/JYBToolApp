// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProjectCopyTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ProjectCopyTool", targets: ["ProjectCopyTool"])
    ],
    dependencies: [
        .package(name: "JYBLog", path: "../JYBLog"),
        .package(name: "ToolUI", path: "../ToolUI")
    ],
    targets: [
        .target(name: "ProjectCopyTool", dependencies: ["JYBLog", "ToolUI"]),
        .testTarget(name: "ProjectCopyToolTests", dependencies: ["ProjectCopyTool"])
    ],
    swiftLanguageModes: [.v6]
)
