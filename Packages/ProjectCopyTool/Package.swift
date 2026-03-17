// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProjectCopyTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ProjectCopyTool", targets: ["ProjectCopyTool"])
    ],
    targets: [
        .target(name: "ProjectCopyTool", dependencies: [])
    ]
)
