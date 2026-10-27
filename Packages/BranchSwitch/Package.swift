// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BranchSwitch",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BranchSwitch", targets: ["BranchSwitch"])
    ],
    dependencies: [
        .package(name: "JYBLog", path: "../JYBLog"),
        .package(name: "ToolUI", path: "../ToolUI")
    ],
    targets: [
        .target(name: "BranchSwitch", dependencies: ["JYBLog", "ToolUI"]),
        .testTarget(name: "BranchSwitchTests", dependencies: ["BranchSwitch"])
    ],
    swiftLanguageModes: [.v6]
)
