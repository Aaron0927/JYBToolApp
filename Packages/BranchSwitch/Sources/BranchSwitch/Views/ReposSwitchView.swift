//
//  ReposSwitchView.swift
//  BranchSwitch
//

import SwiftUI

public struct ReposSwitchView: View {
  @Bindable var viewModel: ReposSwitchViewModel

  public init(viewModel: ReposSwitchViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header
      projectPicker
      branchPicker
      configSummary
      Divider()
      reposList
      Spacer()
    }
    .padding(.vertical)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "list.bullet.rectangle")
          .font(.title)
          .foregroundStyle(.green)
        Text("公版依赖仓库切换")
          .font(.title2)
          .bold()
        Spacer()
      }

      Text("切换父工作区，并读取 fastlane/repos.yml 同步各依赖仓库")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
    .clipShape(.rect(cornerRadius: 8))
  }

  private var projectPicker: some View {
    HStack {
      Text("主工程：")
        .frame(width: 80, alignment: .trailing)

      TextField("请选择主工程目录", text: $viewModel.projectPath)
        .textFieldStyle(.roundedBorder)
        .disabled(true)

      Button("浏览", systemImage: "folder") {
        viewModel.selectProject()
      }
      .disabled(viewModel.isLoading || viewModel.isSwitching)

      Button("刷新分支", systemImage: "arrow.clockwise") {
        viewModel.loadBranches()
      }
      .disabled(viewModel.projectPath.isEmpty || viewModel.isLoading || viewModel.isSwitching)

      Button("在 Xcode 中打开", systemImage: "hammer") {
        viewModel.openInXcode()
      }
      .disabled(!viewModel.hasWorkspace || viewModel.isLoading || viewModel.isSwitching)

      if viewModel.isLoading || viewModel.isSwitching {
        ProgressView()
          .scaleEffect(0.8)
      }
    }
    .padding(.horizontal)
  }

  @ViewBuilder
  private var branchPicker: some View {
    if !viewModel.localBranches.isEmpty {
      HStack {
        Text("主分支：")
          .frame(width: 80, alignment: .trailing)

        Picker("", selection: $viewModel.selectedBranch) {
          ForEach(viewModel.localBranches, id: \.self) { branch in
            Text(branch).tag(branch)
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .onChange(of: viewModel.selectedBranch) { _, _ in
          viewModel.branchSelectionChanged()
        }

        if !viewModel.currentBranch.isEmpty {
          Text("当前：\(viewModel.currentBranch)")
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button("读取 repos.yml", systemImage: "doc.text.magnifyingglass") {
          viewModel.loadData()
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.selectedBranch.isEmpty || viewModel.isLoading || viewModel.isSwitching)
      }
      .padding(.horizontal)
    }
  }

  @ViewBuilder
  private var configSummary: some View {
    if !viewModel.configPath.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
        labeledValue(title: "配置文件：", value: viewModel.configPath)
        if !viewModel.rootPath.isEmpty {
          labeledValue(title: "根目录：", value: viewModel.rootPath)
        }
      }
      .padding(.horizontal)
    }
  }

  @ViewBuilder
  private var reposList: some View {
    if viewModel.repos.isEmpty {
      VStack(spacing: 10) {
        Image(systemName: "tray")
          .font(.largeTitle)
          .foregroundStyle(.secondary)
        Text("未读取到仓库")
          .font(.headline)
        Text("请选择主工程目录并读取本地分支后，再读取 repos.yml")
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text("切换仓库")
            .font(.headline)
          Text("\(viewModel.repos.count)")
            .foregroundStyle(.secondary)
          Spacer()
          Button("确认切换", systemImage: "arrow.triangle.branch") {
            viewModel.switchRepos()
          }
          .buttonStyle(.borderedProminent)
          .disabled(!viewModel.isConfirmEnabled || viewModel.isLoading || viewModel.isSwitching)
        }

        ScrollView {
          LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.repos) { repo in
              RepoSwitchRow(repo: repo)
            }
          }
          .padding(.vertical, 4)
        }
      }
      .padding(.horizontal)
    }
  }

  private func labeledValue(title: String, value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(title)
        .frame(width: 80, alignment: .trailing)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
        .lineLimit(2)
      Spacer()
    }
  }
}

private struct RepoSwitchRow: View {
  let repo: RepoSwitchInfo

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        Image(systemName: iconName)
          .foregroundStyle(statusColor)
        Text(repo.name)
          .font(.headline)
        Spacer()
        Text(statusText)
          .font(.caption)
          .foregroundStyle(statusColor)
      }

      HStack(spacing: 8) {
        BranchBadge(title: "当前", value: repo.currentBranch, style: .secondary)
        Image(systemName: "arrow.right")
          .foregroundStyle(.secondary)
        BranchBadge(title: "目标", value: repo.targetBranch, style: .blue)
        Spacer()
      }

      Text(repo.path)
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
    }
    .padding(10)
    .background(Color.black.opacity(0.04))
    .clipShape(.rect(cornerRadius: 8))
  }

  private var iconName: String {
    if repo.scope == .workspace {
      return "folder.badge.gearshape"
    }
    return repo.isCloned ? "checkmark.circle.fill" : "arrow.down.circle"
  }

  private var statusText: String {
    if repo.scope == .workspace {
      return repo.isCloned ? "父工作区" : "非 Git 仓库"
    }
    return repo.isCloned ? "已存在" : "待克隆"
  }

  private var statusColor: Color {
    if repo.scope == .workspace {
      return repo.isCloned ? .purple : .red
    }
    return repo.isCloned ? .green : .orange
  }
}

private struct BranchBadge: View {
  enum BadgeStyle {
    case secondary
    case blue
  }

  let title: String
  let value: String
  let style: BadgeStyle

  var body: some View {
    HStack(spacing: 4) {
      Text(title)
        .foregroundStyle(.secondary)
      Text(value)
        .foregroundStyle(style == .blue ? .blue : .primary)
    }
    .font(.system(.caption, design: .monospaced))
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.black.opacity(0.05))
    .clipShape(.rect(cornerRadius: 6))
  }
}
