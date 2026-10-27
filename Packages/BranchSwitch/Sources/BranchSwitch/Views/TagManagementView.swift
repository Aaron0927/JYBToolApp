import SwiftUI
import ToolUI

public struct TagManagementView: View {
  @Bindable private var viewModel: TagManagementViewModel
  @State private var pendingAction: PendingTagAction?
  @State private var isShowingConfirmation = false

  public init(viewModel: TagManagementViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        ToolPageHeader(
          title: "Tag 管理",
          subtitle: "选择多个仓库后，可使用同一 Tag 名称和附注进行统一处理。",
          systemImage: "tag"
        )

        ToolPanel("Tag 操作区", systemImage: "tag") {
          TextField("Tag 名称，例如 v8.4.21", text: $viewModel.tagName)
            .font(.system(.body, design: .monospaced))
            .accessibilityLabel("Tag 名称")
            .disabled(viewModel.isBusy)

          TextField("附注说明", text: $viewModel.tagMessage, axis: .vertical)
            .lineLimit(2...4)
            .accessibilityLabel("Tag 附注说明")
            .disabled(viewModel.isBusy)

          HStack {
            Text("将在下方选择的 \(viewModel.selectedRepositoryIDs.count) 个仓库中创建并推送同一个 Tag。")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("设置并推送", systemImage: "arrow.up") {
              let repositories = viewModel.selectedRepositories
              pendingAction = .createAndPush(
                viewModel.tagName.trimmingCharacters(in: .whitespacesAndNewlines),
                viewModel.tagMessage.trimmingCharacters(in: .whitespacesAndNewlines),
                Set(repositories.map(\.id)),
                repositories.map(\.name)
              )
              isShowingConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isBusy || !viewModel.canCreateAndPushTag)
            .keyboardShortcut(.defaultAction)
          }

          if viewModel.isWorking, let progress = viewModel.operationProgress {
            ProgressView(progress)
              .controlSize(.small)
          }
          if let error = viewModel.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
              .foregroundStyle(.red)
              .textSelection(.enabled)
          } else if let status = viewModel.statusMessage {
            Label(status, systemImage: "checkmark.circle")
              .foregroundStyle(.secondary)
          }

          if !viewModel.operationResults.isEmpty {
            Divider()
            Text("逐仓结果")
              .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
              ForEach(viewModel.operationResults) { result in
                TagOperationResultRow(
                  result: result,
                  isDisabled: viewModel.isBusy,
                  onRetry: {
                    pendingAction = .retryPush(result.repositoryID, result.repositoryName, result.tagName)
                    isShowingConfirmation = true
                  }
                )
              }
            }
          }
        }

        ToolPanel("仓库选择", systemImage: "shippingbox") {
          HStack {
            TextField("选择包含 fastlane/repos.yml 的主工程目录", text: $viewModel.projectPath)
              .disabled(true)
              .accessibilityLabel("公版主工程路径")

            Button("浏览…", systemImage: "folder") {
              viewModel.selectProject()
            }
            .disabled(viewModel.isBusy)

            Button("读取仓库", systemImage: "doc.text.magnifyingglass") {
              viewModel.loadRepositories()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.projectPath.isEmpty || viewModel.isBusy)
          }

          if viewModel.isLoading {
            ProgressView("正在读取仓库列表…")
              .controlSize(.small)
          } else if viewModel.repositories.isEmpty {
            ContentUnavailableView(
              "尚未载入仓库",
              systemImage: "shippingbox",
              description: Text("选择主工程目录并读取仓库后，可勾选一个或多个操作目标。")
            )
            .frame(maxWidth: .infinity, minHeight: 110)
          } else {
            Divider()
            HStack {
              Text("已选择 \(viewModel.selectedRepositoryIDs.count) / \(viewModel.repositories.count) 个仓库")
                .foregroundStyle(.secondary)
              Spacer()
              Button(viewModel.areAllRepositoriesSelected ? "取消全选" : "全选") {
                viewModel.setAllRepositoriesSelected(!viewModel.areAllRepositoriesSelected)
              }
              .disabled(viewModel.isBusy)
            }

            repositorySection("主仓库", scope: .workspace)
            repositorySection("依赖仓库", scope: .dependency)
          }
        }
      }
      .padding()
      .frame(maxWidth: 980, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .confirmationDialog(
      pendingAction?.title ?? "确认 Tag 操作？",
      isPresented: $isShowingConfirmation,
      titleVisibility: .visible
    ) {
      if let pendingAction {
        Button(pendingAction.confirmationTitle) {
          switch pendingAction {
          case .createAndPush(let name, let message, let repositoryIDs, _):
            viewModel.createAndPushTag(name: name, message: message, repositoryIDs: repositoryIDs)
          case .retryPush(let repositoryID, _, _):
            viewModel.retryTagPush(for: repositoryID)
          }
          self.pendingAction = nil
        }
        .keyboardShortcut(.defaultAction)
      }
      Button("取消", role: .cancel) {
        pendingAction = nil
      }
    } message: {
      Text(pendingAction?.message ?? "")
    }
  }

  @ViewBuilder
  private func repositorySection(_ title: String, scope: RepoSwitchScope) -> some View {
    let repositories = viewModel.repositories.filter { $0.scope == scope }
    if !repositories.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text(title)
          .font(.headline)
        ForEach(repositories) { repository in
          TagRepositoryRow(
            repository: repository,
            isSelected: Binding(
              get: { viewModel.selectedRepositoryIDs.contains(repository.id) },
              set: { viewModel.setRepository(repository.id, selected: $0) }
            ),
            isDisabled: viewModel.isBusy
          )
        }
      }
    }
  }
}

private enum PendingTagAction {
  case createAndPush(String, String, Set<String>, [String])
  case retryPush(String, String, String)

  var title: String {
    switch self {
    case .createAndPush: "确认统一设置并推送 Tag？"
    case .retryPush: "确认重试推送 Tag？"
    }
  }

  var confirmationTitle: String {
    switch self {
    case .createAndPush: "设置并推送"
    case .retryPush: "推送到 origin"
    }
  }

  var message: String {
    switch self {
    case .createAndPush(let name, let message, _, let repositoryNames):
      "将在 \(repositoryNames.count) 个仓库的当前 HEAD 创建 annotated Tag「\(name)」并推送到 origin。仓库：\(repositoryNames.joined(separator: "、"))。附注：\(message)"
    case .retryPush(_, let repositoryName, let name):
      "将把仓库「\(repositoryName)」中本地已创建的 Tag「\(name)」推送到 origin。"
    }
  }
}

#Preview {
  let viewModel = TagManagementViewModel()
  let workspace = RepoSwitchInfo(
    name: "TradeBook_App",
    path: ".",
    absolutePath: "/workspace/TradeBook_App",
    currentBranch: "develop",
    targetBranch: "develop",
    isCloned: true,
    scope: .workspace
  )
  let dependency = RepoSwitchInfo(
    name: "Trade_UI",
    path: "Dependencies/Trade_UI",
    absolutePath: "/workspace/TradeBook_App/Dependencies/Trade_UI",
    currentBranch: "public_release",
    targetBranch: "develop",
    isCloned: true,
    scope: .dependency
  )
  viewModel.projectPath = "/workspace/TradeBook_App"
  viewModel.repositories = [workspace, dependency]
  viewModel.selectedRepositoryIDs = [workspace.id, dependency.id]
  viewModel.tagName = "v8.4.21"
  viewModel.tagMessage = "Release v8.4.21"
  return TagManagementView(viewModel: viewModel)
}
