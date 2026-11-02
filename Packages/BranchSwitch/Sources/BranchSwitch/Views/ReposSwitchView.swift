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
        title: "分支切换",
        subtitle: "可按 repos.yml 切换仓库分支，也可从主仓库选择 Tag 并让所有仓库切换到同名 Tag。",
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

          Button("在 Xcode 中打开", systemImage: "hammer") {
            viewModel.openInXcode()
          }
          .disabled(!viewModel.hasWorkspace || viewModel.isBusy)
        }

        Picker("切换目标类型", selection: $viewModel.targetMode) {
          ForEach(RepoSwitchTargetMode.allCases, id: \.self) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 240)
        .disabled(viewModel.isBusy)

        if viewModel.targetMode == .branch {
          HStack {
            if !viewModel.localBranches.isEmpty {
              Picker("主工程分支", selection: $viewModel.selectedBranch) {
                ForEach(viewModel.localBranches, id: \.self) { branch in
                  Text(branch).tag(branch)
                }
              }
              .pickerStyle(.menu)
              .onChange(of: viewModel.selectedBranch) { _, _ in
                viewModel.branchSelectionChanged()
              }
            }

            if !viewModel.currentBranch.isEmpty {
              ToolStatusBadge("当前：\(viewModel.currentBranch)")
            }

            Spacer()

            Button("刷新分支", systemImage: "arrow.clockwise") {
              viewModel.loadBranches()
            }
            .disabled(viewModel.projectPath.isEmpty || viewModel.isBusy)

            Button("读取 repos.yml", systemImage: "doc.text.magnifyingglass") {
              viewModel.loadData()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedBranch.isEmpty || viewModel.isBusy)
          }
        } else {
          HStack {
            Text("读取主仓库 Tag，并按当前 repos.yml 确定仓库范围。")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("读取仓库和 Tag", systemImage: "arrow.clockwise") {
              viewModel.loadTagSwitchData()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.projectPath.isEmpty || viewModel.isBusy)
          }

          if viewModel.isTagPreviewLoaded, !viewModel.availableTags.isEmpty {
            HStack {
              Picker("目标 Tag", selection: $viewModel.selectedTagName) {
                Text("选择 Tag").tag(Optional<String>.none)
                ForEach(viewModel.availableTags) { tag in
                  Text(tag.name).tag(Optional(tag.name))
                }
              }
              .frame(maxWidth: 280)
              .disabled(viewModel.isBusy)

              if !viewModel.currentBranch.isEmpty {
                ToolStatusBadge("读取时：\(viewModel.currentBranch)")
              }
              Spacer()
            }
          }

          Text("切换到 Tag 后仓库会处于分离头指针状态；每个仓库都会尝试切换到同名 Tag。")
            .font(.caption)
            .foregroundStyle(.secondary)

          if viewModel.isTagPreviewLoaded,
             viewModel.availableTags.isEmpty,
             viewModel.tagLoadErrorMessage == nil {
            Label("主仓库没有可用的本地或远程 Tag。", systemImage: "tag")
              .foregroundStyle(.secondary)
          }
          if let tagLoadErrorMessage = viewModel.tagLoadErrorMessage {
            Label("读取主仓库 Tag 失败：\(tagLoadErrorMessage)", systemImage: "exclamationmark.triangle.fill")
              .foregroundStyle(.red)
              .textSelection(.enabled)
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
          description: Text(viewModel.targetMode == .tag
            ? "选择主工程后读取仓库和 Tag，再选择要切换的 Tag。"
            : "选择主工程目录、读取本地分支，再加载对应分支中的 repos.yml。")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ToolPanel("仓库切换预览", systemImage: "arrow.triangle.branch") {
          HStack {
            Text(previewSummary)
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Spacer()
            Button("确认切换", systemImage: "arrow.triangle.branch") {
              isConfirmingSwitch = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canConfirmSwitch)
          }

          ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
              ForEach(viewModel.displayedRepos) { repo in
                RepoSwitchRow(
                  repo: repo,
                  operationResult: viewModel.operationResults[repo.name],
                  operationDetail: viewModel.operationDetails[repo.name],
                  isTagTarget: viewModel.targetMode == .tag
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
      confirmationTitle,
      isPresented: $isConfirmingSwitch,
      titleVisibility: .visible
    ) {
      Button(confirmationActionTitle, role: .destructive) {
        viewModel.switchRepos()
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text(confirmationMessage)
    }
  }

  private var progressLabel: String {
    if viewModel.isPulling { return "正在拉取仓库…" }
    if viewModel.isSwitching {
      return viewModel.targetMode == .tag ? "正在切换所有仓库到 Tag…" : "正在切换仓库…"
    }
    if viewModel.targetMode == .tag { return "正在读取仓库和主仓库 Tag…" }
    return "正在读取仓库…"
  }

  private var previewSummary: String {
    if viewModel.targetMode == .tag {
      let tagName = viewModel.selectedTagName ?? "尚未选择 Tag"
      return "\(viewModel.repos.count) 个仓库 · 统一目标 Tag：\(tagName)"
    }
    return "\(viewModel.repos.count) 个仓库 · 目标来自 repos.yml"
  }

  private var confirmationTitle: String {
    viewModel.targetMode == .tag ? "确认切换所有仓库到 Tag？" : "确认切换公版仓库？"
  }

  private var confirmationActionTitle: String {
    if viewModel.targetMode == .tag, let selectedTagName = viewModel.selectedTagName {
      return "切换到 Tag \(selectedTagName)"
    }
    return "切换 \(viewModel.repos.count) 个仓库"
  }

  private var confirmationMessage: String {
    if viewModel.targetMode == .tag, let selectedTagName = viewModel.selectedTagName {
      return "将在主仓库和 repos.yml 中的全部依赖仓库中查找并切换到同名 Tag「\(selectedTagName)」。缺少该 Tag 或仓库不可用时会逐项显示失败，其他仓库继续执行；本地修改会自动暂存并在切换后恢复。切换后仓库处于分离头指针状态。"
    }
    return "将按 repos.yml 对主工作区及依赖仓库切换分支。存在本地修改的仓库会自动暂存并尝试恢复。"
  }
}

private struct RepoSwitchRow: View {
  let repo: RepoSwitchInfo
  let operationResult: String?
  let operationDetail: String?
  let isTagTarget: Bool

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
        Text(isTagTarget ? "读取时：\(currentValue)" : currentValue)
          .foregroundStyle(.secondary)
        Image(systemName: "arrow.right")
          .foregroundStyle(.tertiary)
          .accessibilityHidden(true)
        Text(targetValue)
          .foregroundStyle(.tint)
        ToolStatusBadge(isTagTarget ? "Tag" : "分支")
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
    repo.targetBranch
  }

  private var currentValue: String {
    if isTagTarget, repo.currentBranch == "HEAD" { return "分离头指针" }
    return repo.currentBranch.isEmpty ? "未知" : repo.currentBranch
  }

  private var iconName: String {
    if repo.scope == .workspace { return "folder.badge.gearshape" }
    if isTagTarget, operationResult == "成功" { return "checkmark.circle.fill" }
    return repo.isCloned ? "checkmark.circle.fill" : "arrow.down.circle"
  }

  private var statusText: String {
    if repo.scope == .workspace { return repo.isCloned ? "主工作区" : "非 Git 仓库" }
    if isTagTarget, operationResult == "成功" { return "Tag 已检出" }
    return repo.isCloned ? "已存在" : "待克隆"
  }

  private var statusColor: Color {
    if repo.scope == .workspace { return repo.isCloned ? .purple : .red }
    if isTagTarget, operationResult == "成功" { return .green }
    return repo.isCloned ? .green : .orange
  }

  private var statusKind: ToolStatusBadge.Kind {
    if repo.scope == .workspace { return repo.isCloned ? .neutral : .failure }
    if isTagTarget, operationResult == "成功" { return .success }
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
