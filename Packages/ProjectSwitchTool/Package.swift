// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProjectSwitchTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ProjectSwitchTool", targets: ["ProjectSwitchTool"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/onevcat/Rainbow.git", from: "4.0.0")
    ],
    targets: [
        .target(name: "ProjectSwitchTool", dependencies: ["Yams", "Rainbow"]),
        .testTarget(name: "ProjectSwitchToolTests", dependencies: ["ProjectSwitchTool"])
    ]
)
