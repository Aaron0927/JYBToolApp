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
          subtitle: "查看公版仓库的本地和远端 Tag，并切换到指定 Tag、创建、推送或删除 Tag。",
          systemImage: "tag"
        )

        ToolPanel("公版主工程", systemImage: "folder") {
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

          if let error = viewModel.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
              .foregroundStyle(.red)
              .textSelection(.enabled)
          } else if let status = viewModel.statusMessage {
            Label(status, systemImage: "checkmark.circle")
              .foregroundStyle(.secondary)
          }

          if viewModel.isLoading {
            ProgressView("正在读取仓库或 Tag…")
              .controlSize(.small)
          }
        }

        if !viewModel.repositories.isEmpty {
          ToolPanel("选择仓库", systemImage: "shippingbox") {
            Picker(
              "公版仓库",
              selection: Binding(
                get: { viewModel.selectedRepositoryID },
                set: { viewModel.selectRepository($0) }
              )
            ) {
              ForEach(viewModel.repositories) { repository in
                Text(repository.name + (repository.isCloned ? "" : "（未克隆）"))
                  .tag(repository.id)
              }
            }
            .disabled(viewModel.isBusy)

            if let repository = viewModel.selectedRepository {
              ToolValueRow("当前分支", value: repository.currentBranch)
              ToolValueRow("仓库路径", value: repository.absolutePath)
            }

            HStack {
              if viewModel.hasOrigin {
                ToolStatusBadge("origin 已配置", kind: .success)
              } else {
                ToolStatusBadge("未配置 origin", kind: .warning)
              }
              Spacer()
              Button("刷新 Tag", systemImage: "arrow.clockwise") {
                viewModel.loadTags()
              }
              .disabled(viewModel.isBusy || viewModel.selectedRepository?.isCloned != true)
            }
          }

          ToolPanel("创建 Tag", systemImage: "tag") {
            TextField("Tag 名称，例如 v8.4.21", text: $viewModel.tagName)
              .accessibilityLabel("新 Tag 名称")
              .disabled(viewModel.isBusy || viewModel.selectedRepository?.isCloned != true)
            TextField("Tag 说明", text: $viewModel.tagMessage, axis: .vertical)
              .lineLimit(2...4)
              .accessibilityLabel("新 Tag 说明")
              .disabled(viewModel.isBusy || viewModel.selectedRepository?.isCloned != true)
            HStack {
              Text("将在所选仓库当前 HEAD 创建附注 Tag。创建后可单独推送到 origin。")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer()
              Button("创建 Tag", systemImage: "plus") {
                pendingAction = .create(
                  viewModel.tagName.trimmingCharacters(in: .whitespacesAndNewlines),
                  viewModel.tagMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                isShowingConfirmation = true
              }
              .buttonStyle(.borderedProminent)
              .disabled(
                viewModel.isBusy ||
                  viewModel.selectedRepository?.isCloned != true ||
                  viewModel.tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                  viewModel.tagMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              )
              .keyboardShortcut(.defaultAction)
            }
          }

          ToolPanel("现有 Tag", systemImage: "list.bullet") {
            if viewModel.isLoading {
              ProgressView("正在读取本地与远端 Tag…")
                .frame(maxWidth: .infinity, minHeight: 90)
            } else if viewModel.tags.isEmpty {
              ContentUnavailableView(
                "没有找到 Tag",
                systemImage: "tag",
                description: Text("可以在上方为当前仓库 HEAD 创建一个新 Tag。")
              )
              .frame(maxWidth: .infinity, minHeight: 110)
            } else {
              VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.tags) { tag in
                  TagManagementRow(
                    tag: tag,
                    hasOrigin: viewModel.hasOrigin,
                    isDisabled: viewModel.isBusy,
                    push: {
                      pendingAction = .push(tag.name)
                      isShowingConfirmation = true
                    },
                    deleteLocal: {
                      pendingAction = .deleteLocal(tag.name)
                      isShowingConfirmation = true
                    },
                    deleteRemote: {
                      pendingAction = .deleteRemote(tag.name)
                      isShowingConfirmation = true
                    },
                    checkout: {
                      pendingAction = .checkout(tag.name)
                      isShowingConfirmation = true
                    }
                  )
                }
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
      pendingAction?.title ?? "确认 Tag 操作？",
      isPresented: $isShowingConfirmation,
      titleVisibility: .visible
    ) {
      if let pendingAction {
        Button(pendingAction.confirmationTitle, role: pendingAction.isDestructive ? .destructive : nil) {
          switch pendingAction {
          case .create(let name, let message):
            viewModel.createTag(name: name, message: message)
          case .push(let name):
            viewModel.pushTag(name)
          case .deleteLocal(let name):
            viewModel.deleteLocalTag(name)
          case .deleteRemote(let name):
            viewModel.deleteRemoteTag(name)
          case .checkout(let name):
            viewModel.checkoutTag(name)
          }
          self.pendingAction = nil
        }
      }
      Button("取消", role: .cancel) {
        pendingAction = nil
      }
    } message: {
      Text(pendingAction?.message ?? "")
    }
  }
}

private struct TagManagementRow: View {
  let tag: GitTagInfo
  let hasOrigin: Bool
  let isDisabled: Bool
  let push: () -> Void
  let deleteLocal: () -> Void
  let deleteRemote: () -> Void
  let checkout: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(tag.name)
          .font(.system(.body, design: .monospaced))
          .textSelection(.enabled)
        Spacer()
        if tag.localObjectID != nil {
          ToolStatusBadge("本地", kind: .success)
        }
        if tag.remoteObjectID != nil {
          ToolStatusBadge("origin", kind: .neutral)
        }
      }

      HStack {
        Text("本地对象：\(tag.localObjectID ?? "—")")
        Text("远端对象：\(tag.remoteObjectID ?? "—")")
      }
      .font(.system(.caption, design: .monospaced))
      .foregroundStyle(.secondary)
      .textSelection(.enabled)

      HStack {
        Spacer()
        Button("切换到此 Tag", systemImage: "arrow.uturn.down") {
          checkout()
        }
        .disabled(isDisabled)
        if tag.localObjectID != nil, hasOrigin, tag.localObjectID != tag.remoteObjectID {
          Button("推送", systemImage: "arrow.up") {
            push()
          }
          .disabled(isDisabled)
        }
        if tag.localObjectID != nil {
          Button("删除本地", systemImage: "trash", role: .destructive) {
            deleteLocal()
          }
          .disabled(isDisabled)
        }
        if tag.remoteObjectID != nil {
          Button("删除远端", systemImage: "trash", role: .destructive) {
            deleteRemote()
          }
          .disabled(isDisabled || !hasOrigin)
        }
      }
      .buttonStyle(.borderless)
    }
    .padding(10)
    .background(.quaternary, in: .rect(cornerRadius: 8))
  }
}

private enum PendingTagAction {
  case create(String, String)
  case push(String)
  case deleteLocal(String)
  case deleteRemote(String)
  case checkout(String)

  var title: String {
    switch self {
    case .create: "确认创建 Tag？"
    case .push: "确认推送 Tag？"
    case .deleteLocal: "确认删除本地 Tag？"
    case .deleteRemote: "确认删除远端 Tag？"
    case .checkout: "确认切换到 Tag？"
    }
  }

  var confirmationTitle: String {
    switch self {
    case .create: "创建 Tag"
    case .push: "推送到 origin"
    case .deleteLocal: "删除本地 Tag"
    case .deleteRemote: "删除远端 Tag"
    case .checkout: "切换到此 Tag"
    }
  }

  var message: String {
    switch self {
    case .create(let name, let message):
      "将在当前仓库 HEAD 创建附注 Tag“\(name)”（\(message)）。"
    case .push(let name):
      "将把本地 Tag“\(name)”推送到 origin。"
    case .deleteLocal(let name):
      "只删除本机上的 Tag“\(name)”，远端副本不受影响。"
    case .deleteRemote(let name):
      "将从 origin 删除 Tag“\(name)”。其他协作者将无法再从 origin 获取该 Tag。"
    case .checkout(let name):
      "将在所选仓库 fetch Tag“\(name)”并切换到该提交的 detached HEAD。"
    }
  }

  var isDestructive: Bool {
    switch self {
    case .deleteLocal, .deleteRemote: true
    case .create, .push, .checkout: false
    }
  }
}

#Preview {
  TagManagementView(viewModel: TagManagementViewModel())
}
