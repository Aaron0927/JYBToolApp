import SwiftUI
import ToolUI

public struct ReposSwitchView: View {
  @Bindable var viewModel: ReposSwitchViewModel
  @State private var isConfirmingSwitch = false

  public init(viewModel: ReposSwitchViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      ToolPageHeader(
        title: "依赖仓库切换",
        subtitle: "读取主工程的 repos.yml，预览依赖仓库目标分支或 Tag 后批量切换。",
        systemImage: "shippingbox"
      )

      ToolPanel("主工程", systemImage: "folder") {
        HStack {
          TextField("请选择主工程目录", text: $viewModel.projectPath)
            .disabled(true)
            .accessibilityLabel("主工程路径")

          Button("浏览…", systemImage: "folder") {
            viewModel.selectProject()
          }
          .disabled(viewModel.isBusy)

          Button("刷新分支", systemImage: "arrow.clockwise") {
            viewModel.loadBranches()
          }
          .disabled(viewModel.projectPath.isEmpty || viewModel.isBusy)

          Button("在 Xcode 中打开", systemImage: "hammer") {
            viewModel.openInXcode()
          }
          .disabled(!viewModel.hasWorkspace || viewModel.isBusy)
        }

        if !viewModel.localBranches.isEmpty {
          HStack {
            Picker("主工程分支", selection: $viewModel.selectedBranch) {
              ForEach(viewModel.localBranches, id: \.self) { branch in
                Text(branch).tag(branch)
              }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.selectedBranch) { _, _ in
              viewModel.branchSelectionChanged()
            }

            if !viewModel.currentBranch.isEmpty {
              ToolStatusBadge("当前：\(viewModel.currentBranch)")
            }

            Spacer()

            Button("读取 repos.yml", systemImage: "doc.text.magnifyingglass") {
              viewModel.loadData()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedBranch.isEmpty || viewModel.isBusy)
          }
        }

        if viewModel.isBusy {
          ProgressView(progressLabel)
            .controlSize(.small)
        }
      }

      if !viewModel.configPath.isEmpty {
        ToolPanel("配置来源", systemImage: "doc.text") {
          ToolValueRow("配置文件", value: viewModel.configPath)
          if !viewModel.rootPath.isEmpty {
            ToolValueRow("仓库根目录", value: viewModel.rootPath)
          }
          if let loadErrorMessage = viewModel.loadErrorMessage {
            Label(loadErrorMessage, systemImage: "exclamationmark.triangle.fill")
              .foregroundStyle(.red)
              .textSelection(.enabled)
          }
          if let operationSummary = viewModel.operationSummary {
            ToolValueRow("最近操作", value: operationSummary)
          }
        }
      }

      if viewModel.repos.isEmpty {
        ContentUnavailableView(
          viewModel.projectPath.isEmpty ? "请选择主工程" : "尚未读取仓库配置",
          systemImage: viewModel.projectPath.isEmpty ? "folder.badge.questionmark" : "shippingbox",
          description: Text("选择主工程目录、读取本地分支，再加载对应分支中的 repos.yml。")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ToolPanel("仓库切换预览", systemImage: "arrow.triangle.branch") {
          HStack {
            Text("\(viewModel.repos.count) 个仓库 · 目标来自 repos.yml")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Spacer()
            Button("确认切换", systemImage: "arrow.triangle.branch") {
              isConfirmingSwitch = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isConfirmEnabled || viewModel.isBusy)
          }

          ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
              ForEach(viewModel.repos) { repo in
                RepoSwitchRow(
                  repo: repo,
                  operationResult: viewModel.operationResults[repo.name],
                  operationDetail: viewModel.operationDetails[repo.name]
                )
              }
            }
            .padding(.vertical, 4)
          }
          .frame(minHeight: 180)
          .accessibilityLabel("仓库目标列表")
        }
      }

      Spacer(minLength: 0)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .confirmationDialog(
      "确认切换公版仓库？",
      isPresented: $isConfirmingSwitch,
      titleVisibility: .visible
    ) {
      Button("切换 \(viewModel.repos.count) 个仓库", role: .destructive) {
        viewModel.switchRepos()
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("将按 repos.yml 对主工作区及依赖仓库切换分支或 Tag。存在本地修改的仓库可能无法切换。")
    }
  }

  private var progressLabel: String {
    if viewModel.isPulling { return "正在拉取仓库…" }
    if viewModel.isSwitching { return "正在切换仓库…" }
    return "正在读取仓库…"
  }
}

private struct RepoSwitchRow: View {
  let repo: RepoSwitchInfo
  let operationResult: String?
  let operationDetail: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: iconName)
          .foregroundStyle(statusColor)
          .accessibilityHidden(true)
        Text(repo.name)
          .font(.headline)
        Spacer()
        ToolStatusBadge(statusText, kind: statusKind)
        if let operationResult {
          ToolStatusBadge(operationResult, kind: operationStatusKind)
        }
      }

      HStack(spacing: 8) {
        Text(repo.currentBranch.isEmpty ? "未知" : repo.currentBranch)
          .foregroundStyle(.secondary)
        Image(systemName: "arrow.right")
          .foregroundStyle(.tertiary)
          .accessibilityHidden(true)
        Text(targetValue)
          .foregroundStyle(.tint)
        ToolStatusBadge(repo.targetTag == nil ? "分支" : "Tag")
        Spacer()
      }
      .font(.system(.caption, design: .monospaced))

      Text(repo.path)
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
        .lineLimit(2)

      if let operationDetail {
        Text(operationDetail)
          .font(.caption)
          .foregroundStyle(operationResult == "失败" ? .red : .secondary)
          .textSelection(.enabled)
      }
    }
    .padding(10)
    .background(.quaternary, in: .rect(cornerRadius: 8))
    .accessibilityElement(children: .contain)
  }

  private var targetValue: String {
    repo.targetTag ?? repo.targetBranch
  }

  private var iconName: String {
    if repo.scope == .workspace { return "folder.badge.gearshape" }
    return repo.isCloned ? "checkmark.circle.fill" : "arrow.down.circle"
  }

  private var statusText: String {
    if repo.scope == .workspace { return repo.isCloned ? "主工作区" : "非 Git 仓库" }
    return repo.isCloned ? "已存在" : "待克隆"
  }

  private var statusColor: Color {
    if repo.scope == .workspace { return repo.isCloned ? .purple : .red }
    return repo.isCloned ? .green : .orange
  }

  private var statusKind: ToolStatusBadge.Kind {
    if repo.scope == .workspace { return repo.isCloned ? .neutral : .failure }
    return repo.isCloned ? .success : .warning
  }

  private var operationStatusKind: ToolStatusBadge.Kind {
    switch operationResult {
    case "成功": .success
    case "失败": .failure
    case "跳过": .warning
    default: .neutral
    }
  }
}
