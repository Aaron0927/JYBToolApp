import AppKit
import SwiftUI
import ToolUI

public struct ContentView: View {
  @State private var viewModel = RenamerViewModel()

  public init() {}

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        ToolPageHeader(
          title: "私版项目复制",
          subtitle: "复制项目目录并按配置替换代码、文件名和项目设置。",
          systemImage: "doc.on.doc"
        )

        Button("在 Xcode 中打开", systemImage: "hammer") {
          openInXcode()
        }
        .disabled(!hasWorkspace || viewModel.isRunning)
      }

      if viewModel.isRunning {
        RenameProgressView(viewModel: viewModel)
      } else {
        ConfigFormView(viewModel: viewModel)
      }

      Label(
        "受保护关键词：\(Constants.protectedKeywords.joined(separator: "、"))",
        systemImage: "lock.shield"
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      .textSelection(.enabled)
    }
    .padding()
    .frame(minWidth: 640, minHeight: 480)
  }

  private var hasWorkspace: Bool {
    for pair in viewModel.sourceTargetPairs where !pair.targetPath.isEmpty {
      let url = URL(fileURLWithPath: pair.targetPath)
      guard let matches = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
        continue
      }
      if matches.contains(where: { $0.pathExtension == "xcworkspace" || $0.pathExtension == "xcodeproj" }) {
        return true
      }
    }
    return false
  }

  private func openInXcode() {
    for pair in viewModel.sourceTargetPairs where !pair.targetPath.isEmpty {
      let url = URL(fileURLWithPath: pair.targetPath)
      guard let matches = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
        continue
      }
      if let project = matches.first(where: { $0.pathExtension == "xcworkspace" || $0.pathExtension == "xcodeproj" }) {
        NSWorkspace.shared.openApplication(at: project, configuration: NSWorkspace.OpenConfiguration())
        return
      }
    }
  }
}
