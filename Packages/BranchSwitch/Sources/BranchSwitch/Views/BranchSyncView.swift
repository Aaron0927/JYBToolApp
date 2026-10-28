import SwiftUI
import ToolUI

public struct BranchSyncView: View {
  @Bindable private var viewModel: BranchSyncViewModel
  @State private var isConfirmingSync = false

  public init(viewModel: BranchSyncViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        ToolPageHeader(
          title: "分支同步",
          subtitle: "选择主工程的目标分支，再读取该分支的 repos.yml 确认每个依赖仓库的目标分支。",
          systemImage: "arrow.triangle.branch"
        )

        ToolPanel("主工程分支", systemImage: "folder") {
          HStack {
            TextField("选择公版主工程目录", text: $viewModel.projectPath)
              .disabled(true)
              .accessibilityLabel("公版主工程路径")

            Button("浏览…", systemImage: "folder") {
              viewModel.selectProject()
            }
            .disabled(viewModel.isBusy)

            Button("读取主工程", systemImage: "arrow.triangle.2.circlepath") {
              viewModel.loadProjectBranches()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.projectPath.isEmpty || viewModel.isBusy)
          }

          if let context = viewModel.projectContext {
            ToolValueRow("当前分支", value: context.sourceProjectBranch)
            ToolValueRow("源配置", value: "当前分支 · fastlane/repos.yml")

            HStack {
              Text("目标分支")
                .foregroundStyle(.secondary)
              Picker("主工程目标分支", selection: Binding(
                get: { viewModel.selectedTargetBranch },
                set: { viewModel.selectTargetBranch($0) }
              )) {
                Text("选择目标分支").tag("")
                ForEach(context.targetBranches, id: \.self) { branch in
                  Text(branch).tag(branch)
                }
              }
              .pickerStyle(.menu)
              .accessibilityLabel("主工程目标分支")
              .disabled(viewModel.isBusy)

              Button("读取目标配置", systemImage: "doc.text.magnifyingglass") {
                viewModel.loadTargetConfig()
              }
              .buttonStyle(.borderedProminent)
              .disabled(!viewModel.canLoadTargetConfig)
            }

            Text("目标分支的 repos.yml 将决定每个依赖仓库的目标分支。分支列表来自主工程 origin。")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          if let preview = viewModel.preview {
            ToolValueRow("目标配置", value: "origin/\(preview.targetConfigBranch) · fastlane/repos.yml")
          }
          if let error = viewModel.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
              .foregroundStyle(.red)
              .textSelection(.enabled)
          }
          if viewModel.isLoading {
            ProgressView(viewModel.loadingMessage ?? "正在读取…")
              .controlSize(.small)
          }
        }

        ToolPanel("选择同步仓库", systemImage: "shippingbox") {
          if viewModel.preview == nil {
            ContentUnavailableView(
              viewModel.projectContext == nil ? "尚未读取主工程" : "尚未读取目标配置",
              systemImage: "arrow.triangle.branch",
              description: Text(
                viewModel.projectContext == nil
                  ? "读取主工程后选择目标分支。"
                  : "选择主工程目标分支，再读取该分支中的 repos.yml。"
              )
            )
            .frame(maxWidth: .infinity, minHeight: 140)
          } else {
            HStack {
              Text("共 \(viewModel.repositories.count) 个仓库 · 可同步 \(viewModel.selectableRepositories.count) 个 · 已选择 \(viewModel.selectedRepositories.count) 个")
                .foregroundStyle(.secondary)
              Spacer()
              Button(viewModel.areAllRepositoriesSelected ? "取消全选" : "全选", systemImage: "checkmark.circle") {
                viewModel.setAllRepositoriesSelected(!viewModel.areAllRepositoriesSelected)
              }
              .disabled(viewModel.isBusy || viewModel.selectableRepositories.isEmpty)

              Button("合并并推送", systemImage: "arrow.up.forward") {
                isConfirmingSync = true
              }
              .buttonStyle(.borderedProminent)
              .disabled(viewModel.selectedRepositories.isEmpty || viewModel.isBusy)
              .keyboardShortcut(.defaultAction)
            }

            if let summary = viewModel.summary {
              Label(summary, systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            }
            if let progress = viewModel.operationProgress {
              ProgressView(progress)
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 8) {
              ForEach(viewModel.repositories) { repository in
                BranchSyncRepositoryRow(
                  viewModel: viewModel,
                  repository: repository,
                  result: viewModel.operationResults.first { $0.repositoryID == repository.id }
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
      "确认合并并推送所选仓库？",
      isPresented: $isConfirmingSync,
      titleVisibility: .visible
    ) {
      Button("同步 \(viewModel.selectedRepositories.count) 个仓库") {
        viewModel.syncSelectedRepositories()
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("主工程：\(viewModel.preview?.sourceProjectBranch ?? "") → origin/\(viewModel.selectedTargetBranch)。依赖仓库按当前分支与所选目标分支的 repos.yml 配置同步。有未提交修改的仓库会跳过；合并冲突会中止该仓库并继续处理其他仓库。")
    }
  }
}

private struct BranchSyncRepositoryRow: View {
  @Bindable var viewModel: BranchSyncViewModel
  let repository: BranchSyncRepository
  let result: BranchSyncResult?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Toggle(isOn: Binding(
          get: { viewModel.selectedRepositoryIDs.contains(repository.id) },
          set: { viewModel.setRepository(repository.id, selected: $0) }
        )) {
          Label(repository.name, systemImage: repository.isWorkspace ? "building.2" : "folder")
        }
        .toggleStyle(.checkbox)
        .disabled(viewModel.isBusy || !repository.canSync)

        Spacer()
        if let result {
          ToolStatusBadge(statusTitle(result.status), kind: badgeKind(result.status))
        }
      }

      HStack(spacing: 12) {
        Text("来源分支：\(repository.sourceBranch ?? "未配置")")
        Image(systemName: "arrow.right")
          .foregroundStyle(.tertiary)
        Text("目标分支：\(repository.targetBranch ?? "未配置")")
      }
      .font(.system(.caption, design: .monospaced))
      .foregroundStyle(.secondary)
      .textSelection(.enabled)

      Text("仓库路径：\(repository.absolutePath)")
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
        .lineLimit(2)

      if let reason = repository.unavailableReason {
        Text(reason)
          .font(.caption)
          .foregroundStyle(.orange)
          .textSelection(.enabled)
      }
      if let result {
        Text(result.message)
          .font(.caption)
          .foregroundStyle(result.status == .failed || result.status == .pushFailed ? .red : .secondary)
          .textSelection(.enabled)
      }
    }
    .padding(10)
    .background(.quaternary, in: .rect(cornerRadius: 8))
  }

  private func statusTitle(_ status: BranchSyncStatus) -> String {
    switch status {
    case .success: "成功"
    case .skipped: "跳过"
    case .failed: "失败"
    case .pushFailed: "推送失败"
    }
  }

  private func badgeKind(_ status: BranchSyncStatus) -> ToolStatusBadge.Kind {
    switch status {
    case .success: .success
    case .skipped: .warning
    case .failed, .pushFailed: .failure
    }
  }
}

#Preview {
  BranchSyncView(viewModel: BranchSyncViewModel())
}
