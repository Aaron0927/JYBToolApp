import SwiftUI
import ToolUI

public struct TagManagementView: View {
  @Bindable private var viewModel: TagManagementViewModel
  @State private var pendingAction: PendingTagAction?
  @State private var isShowingConfirmation = false
  @State private var isShowingTagForm = false

  public init(viewModel: TagManagementViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        ToolPageHeader(
          title: "Tag 管理",
          subtitle: "选择仓库后，在当前 HEAD 设置 annotated Tag 并推送到 origin。",
          systemImage: "tag"
        )

        ToolPanel("设置并推送 Tag", systemImage: "tag") {
          HStack {
            TextField("选择包含 fastlane/repos.yml 的主工程目录", text: $viewModel.projectPath)
              .disabled(true)
              .accessibilityLabel("公版主工程路径")

            Button("浏览…", systemImage: "folder") {
              viewModel.selectProject()
            }
            .disabled(viewModel.isBusy)

            Button("读取仓库", systemImage: "doc.text.magnifyingglass") {
              isShowingTagForm = false
              viewModel.loadRepositories()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.projectPath.isEmpty || viewModel.isBusy)
          }

          if let repository = viewModel.selectedRepository {
            Divider()
            ToolValueRow("当前仓库", value: repository.name)
            ToolValueRow("当前分支", value: repository.currentBranch.isEmpty ? "未检测到分支" : repository.currentBranch)
            ToolValueRow("仓库路径", value: repository.absolutePath)

            HStack {
              if repository.isCloned {
                Text("Tag 将基于当前 HEAD 创建")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              } else {
                Label("该仓库尚未克隆，无法设置或推送 Tag。", systemImage: "exclamationmark.triangle")
                  .font(.caption)
                  .foregroundStyle(.orange)
              }
              Spacer()
              Button(isShowingTagForm ? "收起设置" : "设置并推送 Tag", systemImage: isShowingTagForm ? "chevron.up" : "tag") {
                isShowingTagForm.toggle()
              }
              .buttonStyle(.borderedProminent)
              .disabled(viewModel.isBusy || !repository.isCloned)
            }

            if isShowingTagForm {
              VStack(alignment: .leading, spacing: 12) {
                TextField("Tag 名称，例如 v8.4.21", text: $viewModel.tagName)
                  .font(.system(.body, design: .monospaced))
                  .accessibilityLabel("Tag 名称")
                  .disabled(viewModel.isBusy)
                TextField("附注说明", text: $viewModel.tagMessage, axis: .vertical)
                  .lineLimit(2...4)
                  .accessibilityLabel("Tag 附注说明")
                  .disabled(viewModel.isBusy)
                HStack {
                  Text("确认后会在当前 HEAD 创建 Tag，并推送到 origin。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  Spacer()
                  Button("设置并推送", systemImage: "arrow.up") {
                    pendingAction = .createAndPush(
                      viewModel.tagName.trimmingCharacters(in: .whitespacesAndNewlines),
                      viewModel.tagMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    isShowingConfirmation = true
                  }
                  .buttonStyle(.borderedProminent)
                  .disabled(
                    viewModel.isBusy ||
                      viewModel.tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                      viewModel.tagMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  )
                  .keyboardShortcut(.defaultAction)
                }
              }
              .padding(12)
              .background(.quaternary, in: .rect(cornerRadius: 10))
            }
          } else if viewModel.repositories.isEmpty, !viewModel.isLoading {
            ContentUnavailableView(
              "尚未载入仓库",
              systemImage: "shippingbox",
              description: Text("选择主工程目录并读取仓库后，可从下方列表选择目标仓库。")
            )
            .frame(maxWidth: .infinity, minHeight: 110)
          }

          if viewModel.isLoading {
            ProgressView("正在读取仓库列表…")
              .controlSize(.small)
          }
          if viewModel.isWorking {
            ProgressView("正在设置并推送 Tag…")
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

          if viewModel.canRetryPendingPush, let tagName = viewModel.pendingPushTagName {
            Label("Tag「\(tagName)」已在本地创建，但尚未推送。", systemImage: "exclamationmark.arrow.circlepath")
              .foregroundStyle(.orange)
            HStack {
              Spacer()
              Button("重试推送到 origin", systemImage: "arrow.up") {
                pendingAction = .retryPush(tagName)
                isShowingConfirmation = true
              }
              .disabled(viewModel.isBusy)
            }
          }
        }

        ToolPanel("仓库列表", systemImage: "shippingbox") {
          if viewModel.repositories.isEmpty {
            Text("读取主工程配置后，这里会列出主仓库和全部依赖仓库。")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 8)
          } else {
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
          case .createAndPush(let name, let message):
            viewModel.createAndPushTag(name: name, message: message)
            isShowingTagForm = false
          case .retryPush:
            viewModel.retryPendingTagPush()
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
            isSelected: repository.id == viewModel.selectedRepositoryID,
            isDisabled: viewModel.isBusy,
            onSelect: {
              isShowingTagForm = false
              viewModel.selectRepository(repository.id)
            }
          )
        }
      }
    }
  }
}

private enum PendingTagAction {
  case createAndPush(String, String)
  case retryPush(String)

  var title: String {
    switch self {
    case .createAndPush: "确认设置并推送 Tag？"
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
    case .createAndPush(let name, let message):
      "将在所选仓库当前 HEAD 创建 annotated Tag「\(name)」，附注为「\(message)」，并推送到 origin。"
    case .retryPush(let name):
      "将把本地 Tag「\(name)」推送到 origin。"
    }
  }
}

#Preview {
  TagManagementView(viewModel: TagManagementViewModel())
}
