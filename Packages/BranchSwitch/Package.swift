// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BranchSwitch",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BranchSwitch", targets: ["BranchSwitch"])
    ],
    dependencies: [],
    targets: [
        .target(name: "BranchSwitch", dependencies: []),
        .testTarget(name: "BranchSwitchTests", dependencies: ["BranchSwitch"])
    ]
)
