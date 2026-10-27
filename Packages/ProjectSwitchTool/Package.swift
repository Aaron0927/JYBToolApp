// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProjectSwitchTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ProjectSwitchTool", targets: ["ProjectSwitchTool"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/onevcat/Rainbow.git", from: "4.0.0"),
        .package(name: "JYBLog", path: "../JYBLog"),
        .package(name: "ToolUI", path: "../ToolUI")
    ],
    targets: [
        .target(name: "ProjectSwitchTool", dependencies: ["Yams", "Rainbow", "JYBLog", "ToolUI"]),
        .testTarget(name: "ProjectSwitchToolTests", dependencies: ["ProjectSwitchTool"])
    ],
    swiftLanguageModes: [.v6]
)
