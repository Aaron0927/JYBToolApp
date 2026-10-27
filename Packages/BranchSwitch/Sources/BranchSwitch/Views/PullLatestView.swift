import SwiftUI
import ToolUI

public struct PullLatestView: View {
  @Bindable private var viewModel: ReposSwitchViewModel
  @State private var isConfirmingUpdate = false

  public init(viewModel: ReposSwitchViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        ToolPageHeader(
          title: "仓库更新",
          subtitle: "读取 repos.yml 后选择需要更新的仓库，沿用当前分支的拉取最新操作。",
          systemImage: "arrow.triangle.2.circlepath"
        )

        ToolPanel("主工程与仓库范围", systemImage: "folder") {
          HStack {
            TextField("选择公版主工程目录", text: $viewModel.projectPath)
              .disabled(true)
              .accessibilityLabel("公版主工程路径")

            Button("浏览…", systemImage: "folder") {
              viewModel.selectProject()
            }
            .disabled(viewModel.isBusy)

            Button("读取仓库", systemImage: "arrow.triangle.2.circlepath") {
              viewModel.loadPullPreview()
            }
            .buttonStyle(.borderedProminent)
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
            ProgressView("正在读取 repos.yml…")
              .controlSize(.small)
          }
        }

        ToolPanel("选择仓库", systemImage: "shippingbox") {
          if viewModel.repos.isEmpty {
            ContentUnavailableView(
              "尚未读取仓库",
              systemImage: "shippingbox",
              description: Text("读取后会列出主仓库和 repos.yml 中的全部仓库，可逐个选择或全选。")
            )
            .frame(maxWidth: .infinity, minHeight: 140)
          } else {
            HStack {
              Text("共 \(viewModel.repos.count) 个仓库 · 已选择 \(viewModel.selectedPullRepositoryCount) 个")
                .foregroundStyle(.secondary)
              Spacer()
              Button(viewModel.isAllPullRepositoriesSelected ? "取消全选" : "全选", systemImage: "checkmark.circle") {
                viewModel.toggleAllPullRepositories()
              }
              .disabled(viewModel.isBusy)
              Button("更新所选仓库", systemImage: "arrow.down.to.line.compact") {
                isConfirmingUpdate = true
              }
              .buttonStyle(.borderedProminent)
              .disabled(
                !viewModel.isPullPreviewLoaded ||
                  viewModel.selectedPullRepositoryCount == 0 ||
                  viewModel.isBusy
              )
              .keyboardShortcut(.defaultAction)
            }

            if let summary = viewModel.pullSummary {
              Label(summary, systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            }

            if viewModel.isPulling {
              ProgressView("正在拉取所选仓库的最新内容…")
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 8) {
              ForEach(viewModel.repos) { repo in
                PullRepositoryRow(
                  viewModel: viewModel,
                  repo: repo,
                  isDisabled: viewModel.isBusy,
                  result: viewModel.operationResults[repo.id],
                  detail: viewModel.operationDetails[repo.id]
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
      "确认更新所选仓库？",
      isPresented: $isConfirmingUpdate,
      titleVisibility: .visible
    ) {
      Button("更新 \(viewModel.selectedPullRepositoryCount) 个仓库") {
        viewModel.updateSelectedRepositories()
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("只更新当前分支。未选择的仓库保持不变；有本地改动的仓库会先暂存并在更新后尝试恢复。")
    }
  }
}

private struct PullRepositoryRow: View {
  @Bindable var viewModel: ReposSwitchViewModel
  let repo: RepoSwitchInfo
  let isDisabled: Bool
  let result: String?
  let detail: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Toggle(isOn: Binding(
          get: { viewModel.selectedPullRepositoryIDs.contains(repo.id) },
          set: { viewModel.setPullRepository(repo.id, selected: $0) }
        )) {
          Label(repo.name, systemImage: repo.scope == .workspace ? "building.2" : "folder")
        }
        .toggleStyle(.checkbox)
        .disabled(isDisabled)

        Spacer()
        if let result {
          ToolStatusBadge(result, kind: resultKind)
        }
      }

      Text("当前分支：\(repo.currentBranch) · \(repo.absolutePath)")
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
