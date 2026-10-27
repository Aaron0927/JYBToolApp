// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ToolUI",
  platforms: [.macOS(.v14)],
  products: [.library(name: "ToolUI", targets: ["ToolUI"])],
  targets: [.target(name: "ToolUI")],
  swiftLanguageModes: [.v6]
)
