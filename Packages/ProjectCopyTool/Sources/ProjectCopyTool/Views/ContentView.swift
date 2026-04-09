import SwiftUI
import AppKit

public struct ContentView: View {
    @State private var viewModel = RenamerViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            if viewModel.isRunning {
                RenameProgressView(viewModel: viewModel)
            } else {
                ConfigFormView(viewModel: viewModel)
            }

            Divider()

            footerView
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.on.doc.fill")
                    .font(.title)
                    .foregroundStyle(.blue)
                Text("私版项目复制")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()

                Button("在 Xcode 中打开") {
                    openInXcode()
                }
                .disabled(!hasWorkspace || viewModel.isRunning)
                .opacity(hasWorkspace ? 1 : 0.5)
            }

            Text("复制并重命名指定路径项目，支持批量替换前缀、文件内容、plist 等")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(.rect(cornerRadius: 8))
    }

    private var hasWorkspace: Bool {
        for pair in viewModel.sourceTargetPairs where !pair.targetPath.isEmpty {
            let url = URL(fileURLWithPath: pair.targetPath)
            let fileManager = FileManager.default

            if let matches = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil),
               matches.contains(where: { $0.pathExtension == "xcworkspace" || $0.pathExtension == "xcodeproj" }) {
                return true
            }
        }
        return false
    }

    private func openInXcode() {
        for pair in viewModel.sourceTargetPairs where !pair.targetPath.isEmpty {
            let url = URL(fileURLWithPath: pair.targetPath)
            let fileManager = FileManager.default

            if let matches = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil),
               let workspace = matches.first(where: { $0.pathExtension == "xcworkspace" }) {
                NSWorkspace.shared.openApplication(at: workspace, configuration: NSWorkspace.OpenConfiguration())
                return
            }

            if let matches = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil),
               let project = matches.first(where: { $0.pathExtension == "xcodeproj" }) {
                NSWorkspace.shared.openApplication(at: project, configuration: NSWorkspace.OpenConfiguration())
                return
            }
        }
    }

    private var footerView: some View {
        HStack {
            Text("保护关键词: \(Constants.protectedKeywords.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
