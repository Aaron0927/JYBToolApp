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
          subtitle: "按主工程当前分支与 master/main 分支各自的 repos.yml，合并对应仓库分支并推送到 origin。",
          systemImage: "arrow.triangle.branch"
        )

        ToolPanel("主工程与配置来源", systemImage: "folder") {
          HStack {
            TextField("选择公版主工程目录", text: $viewModel.projectPath)
              .disabled(true)
              .accessibilityLabel("公版主工程路径")

            Button("浏览…", systemImage: "folder") {
              viewModel.selectProject()
            }
            .disabled(viewModel.isBusy)

            Button("读取同步范围", systemImage: "arrow.triangle.2.circlepath") {
              viewModel.loadPreview()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.projectPath.isEmpty || viewModel.isBusy)
          }

          if let preview = viewModel.preview {
            ToolValueRow("来源配置", value: "当前分支 \(preview.sourceProjectBranch) · fastlane/repos.yml")
            ToolValueRow("目标配置", value: "origin/\(preview.targetConfigBranch) · fastlane/repos.yml")
            Text("主工程同步到 \(preview.targetProjectBranch)；依赖仓库按两份配置中的 path 配对。")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          if let error = viewModel.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
              .foregroundStyle(.red)
              .textSelection(.enabled)
          }
          if viewModel.isLoading {
            ProgressView("正在读取两份 repos.yml…")
              .controlSize(.small)
          }
        }

        ToolPanel("选择仓库", systemImage: "shippingbox") {
          if viewModel.repositories.isEmpty {
            ContentUnavailableView(
              "尚未读取同步范围",
              systemImage: "arrow.triangle.branch",
              description: Text("读取后会按 path 配对当前分支和远端 master/main 分支中的仓库配置。")
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
      Text("会将来源分支合并到各仓库的目标分支并推送到 origin。有未提交修改的仓库会跳过；合并冲突会中止该仓库并继续处理其他仓库。")
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
        .disabled(viewModel.isBusy || !repository.isSelectable)

        Spacer()
        if let result {
          ToolStatusBadge(statusTitle(result.status), kind: badgeKind(result.status))
        }
      }

      Text("\(repository.sourceBranch ?? "未配置") → \(repository.targetBranch ?? "未配置") · \(repository.absolutePath)")
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
