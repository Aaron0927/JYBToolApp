import SwiftUI
import ToolUI

public struct GitSwitcherView: View {
  @State private var viewModel = GitSwitcherViewModel()
  @State private var isShowingConfirmation = false

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        ToolPageHeader(
          title: "私版券商切换",
          subtitle: "按 repos.yaml 预览并批量切换仓库分支。",
          systemImage: "arrow.triangle.branch"
        )

        ToolPanel("配置仓库", systemImage: "folder") {
          VStack(alignment: .leading, spacing: 12) {
            LabeledContent("仓库目录") {
              Text(viewModel.projectPath.isEmpty ? "尚未选择" : viewModel.projectPath)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
            }

            HStack {
              Button("选择仓库", systemImage: "folder.badge.plus") {
                viewModel.selectWorkspace()
              }
              .disabled(viewModel.isWorking || viewModel.isLoadingWorkspace)

              Button("在 Xcode 中打开", systemImage: "hammer") {
                viewModel.openInXcode()
              }
              .disabled(!viewModel.hasWorkspace || viewModel.isWorking || viewModel.isLoadingWorkspace)

              Spacer()

              if viewModel.isLoadingWorkspace {
                ProgressView("正在读取配置并扫描仓库…")
                  .controlSize(.small)
              } else if viewModel.isWorking {
                ProgressView(viewModel.operationProgress ?? "正在切换")
                  .controlSize(.small)
              } else {
                Button("预览并切换 \(viewModel.repos.count) 个仓库", systemImage: "arrow.triangle.branch") {
                  isShowingConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.repos.isEmpty || viewModel.isLoadingWorkspace)
              }
            }

            if !viewModel.configPath.isEmpty {
              ToolValueRow("配置文件", value: viewModel.configPath)
            }

            if let errorMessage = viewModel.errorMessage {
              Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
            }

            if let operationSummary = viewModel.operationSummary {
              Label(operationSummary, systemImage: "checkmark.circle")
                .foregroundStyle(viewModel.errorMessage == nil ? Color.secondary : Color.orange)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }

        ToolPanel("仓库预览", systemImage: "list.bullet.rectangle") {
          if viewModel.isLoadingWorkspace {
            ProgressView("正在扫描仓库…")
              .frame(maxWidth: .infinity, minHeight: 100)
          } else if viewModel.repos.isEmpty {
            ContentUnavailableView(
              "未读取到仓库",
              systemImage: "folder.badge.questionmark",
              description: Text("选择包含 repos.yaml 的配置仓库后，这里会显示每个仓库的目标分支。")
            )
            .frame(maxWidth: .infinity)
          } else {
            VStack(alignment: .leading, spacing: 10) {
              ForEach(viewModel.repos) { repo in
                RepoPreviewRow(repo: repo)
              }
            }
          }
        }
      }
      .padding()
      .frame(maxWidth: 980, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .confirmationDialog(
      "确认批量切换？",
      isPresented: $isShowingConfirmation,
      titleVisibility: .visible
    ) {
      Button("切换 \(viewModel.repos.count) 个仓库", role: .destructive) {
        viewModel.switchWorkspace()
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("将按 repos.yaml 中显示的目标分支逐仓切换。检测到的本地修改会先保存，结束后尝试恢复。")
    }
  }
}

private struct RepoPreviewRow: View {
  let repo: Repo

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label(repo.name, systemImage: repo.isMainRepo ? "building.2" : "folder")
          .font(.headline)
        Spacer()
        statusBadge
      }

      HStack(alignment: .firstTextBaseline) {
        LabeledContent("当前分支", value: repo.currentBranch.isEmpty ? "—" : repo.currentBranch)
        Image(systemName: "arrow.right")
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
        LabeledContent("目标分支", value: repo.targetBranch)
      }
      .font(.system(.callout, design: .monospaced))

      ToolValueRow("仓库路径", value: repo.path)
      if let operationDetail = repo.operationDetail {
        Text(operationDetail)
          .font(.caption)
          .foregroundStyle(.red)
          .textSelection(.enabled)
      }
    }
    .padding()
    .background(.quaternary, in: .rect(cornerRadius: 10))
  }

  @ViewBuilder
  private var statusBadge: some View {
    if let operationStatus = repo.operationStatus {
      switch operationStatus {
      case "成功": ToolStatusBadge("切换成功", kind: .success)
      case "失败": ToolStatusBadge("切换失败", kind: .failure)
      case "跳过": ToolStatusBadge("已跳过", kind: .warning)
      default: ToolStatusBadge(operationStatus)
      }
    } else if !repo.isAvailable {
      ToolStatusBadge("路径不可用", kind: .failure)
    } else if repo.hasStash {
      ToolStatusBadge("有已保存改动", kind: .warning)
    } else {
      ToolStatusBadge("工作区可用", kind: .success)
    }
  }
}

#Preview {
  GitSwitcherView()
}
