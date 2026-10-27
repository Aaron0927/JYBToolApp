import SwiftUI
import ToolUI

public struct PullLatestView: View {
  @Bindable private var viewModel: ReposSwitchViewModel
  @State private var isConfirmingPull = false

  public init(viewModel: ReposSwitchViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        ToolPageHeader(
          title: "拉取最新",
          subtitle: "只更新当前分支，不切换分支。脏工作区会先暂存，完成后尝试恢复。",
          systemImage: "arrow.down.to.line.compact"
        )

        ToolPanel("主工程与拉取范围", systemImage: "folder") {
          HStack {
            TextField("选择公版主工程目录", text: $viewModel.projectPath)
              .disabled(true)
              .accessibilityLabel("公版主工程路径")

            Button("浏览…", systemImage: "folder") {
              viewModel.selectProject()
            }
            .disabled(viewModel.isBusy)

            Button("读取拉取范围", systemImage: "doc.text.magnifyingglass") {
              viewModel.loadPullPreview()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.projectPath.isEmpty || viewModel.isBusy)
          }

          if !viewModel.configPath.isEmpty {
            ToolValueRow("配置文件", value: viewModel.configPath)
          }
          if !viewModel.rootPath.isEmpty {
            ToolValueRow("仓库根目录", value: viewModel.rootPath)
          }
          if let error = viewModel.loadErrorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
              .foregroundStyle(.red)
              .textSelection(.enabled)
          }
          if viewModel.isLoading {
            ProgressView("正在读取配置和仓库状态…")
              .controlSize(.small)
          }
        }

        ToolPanel("仓库拉取状态", systemImage: "shippingbox") {
          if viewModel.repos.isEmpty {
            ContentUnavailableView(
              "尚未读取拉取范围",
              systemImage: "shippingbox",
              description: Text("读取后会列出主仓库和 repos.yml 中的所有依赖仓库。")
            )
            .frame(maxWidth: .infinity, minHeight: 140)
          } else {
            HStack {
              Text("共 \(viewModel.repos.count) 个仓库")
                .foregroundStyle(.secondary)
              Spacer()
              Button("拉取全部最新代码", systemImage: "arrow.down.to.line.compact") {
                isConfirmingPull = true
              }
              .buttonStyle(.borderedProminent)
              .disabled(!viewModel.isPullPreviewLoaded || viewModel.isBusy)
              .keyboardShortcut(.defaultAction)
            }

            if let summary = viewModel.pullSummary {
              Label(summary, systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            }

            if viewModel.isPulling {
              ProgressView("正在逐仓拉取；单仓结果会持续更新…")
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 8) {
              ForEach(viewModel.repos) { repo in
                PullRepositoryRow(
                  repo: repo,
                  result: viewModel.operationResults[repo.name],
                  detail: viewModel.operationDetails[repo.name]
                )
              }
            }
          }
        }
      }
      .padding()
      .frame(maxWidth: 980, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .confirmationDialog(
      "确认拉取全部公版仓库？",
      isPresented: $isConfirmingPull,
      titleVisibility: .visible
    ) {
      Button("开始拉取") {
        viewModel.pullAllRepositories()
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("将拉取预览中的 \(viewModel.repos.count) 个仓库。工具只更新当前分支；检测到本地改动时会先暂存并尝试恢复。")
    }
  }
}

private struct PullRepositoryRow: View {
  let repo: RepoSwitchInfo
  let result: String?
  let detail: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Label(repo.name, systemImage: repo.scope == .workspace ? "building.2" : "folder")
        Spacer()
        if let result {
          ToolStatusBadge(result, kind: resultKind)
        } else if repo.isCloned {
          ToolStatusBadge("待拉取", kind: .neutral)
        } else {
          ToolStatusBadge("路径不可用", kind: .failure)
        }
      }

      Text(repo.absolutePath)
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
        .lineLimit(2)

      if let detail {
        Text(detail)
          .font(.caption)
          .foregroundStyle(result == "失败" ? .red : .secondary)
          .textSelection(.enabled)
      }
    }
    .padding(10)
    .background(.quaternary, in: .rect(cornerRadius: 8))
  }

  private var resultKind: ToolStatusBadge.Kind {
    switch result {
    case "成功": .success
    case "失败": .failure
    case "跳过": .warning
    default: .neutral
    }
  }
}

#Preview {
  PullLatestView(viewModel: ReposSwitchViewModel())
}
