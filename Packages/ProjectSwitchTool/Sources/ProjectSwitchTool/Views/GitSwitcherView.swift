//
//  GitSwitcherView.swift
//  ProjectSwitchTool
//
//  Created by kim on 2026/3/13.
//

import SwiftUI

public struct GitSwitcherView: View {
    @State private var viewModel = GitSwitcherViewModel()

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            headerView

            Divider()

            projectPicker
            configSummary
            repoPreview

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder")
                    .font(.title)
                    .foregroundStyle(.blue)
                Text("私版券商切换")
                    .font(.title2)
                    .bold()
                Spacer()
            }

            Text("选择包含 repos.yaml 的仓库，确认后按配置批量切换仓库分支")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(.rect(cornerRadius: 8))
    }

    private var projectPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("配置仓库:")
                    .frame(width: 80, alignment: .trailing)

                TextField("默认填充上次选择的仓库", text: $viewModel.projectPath)
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)

                Button("选择仓库", systemImage: "folder") {
                    viewModel.selectWorkspace()
                }
                .disabled(viewModel.isWorking)

                Button("在 Xcode 中打开", systemImage: "hammer") {
                    viewModel.openInXcode()
                }
                .disabled(!viewModel.hasWorkspace || viewModel.isWorking)

                Button("确认切换", systemImage: "arrow.triangle.branch") {
                    viewModel.switchWorkspace()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.repos.isEmpty || viewModel.isWorking)

                if viewModel.isWorking {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            Text("选择后会立即读取仓库根目录下的 repos.yaml")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .padding(.leading, 88)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var configSummary: some View {
        if !viewModel.configPath.isEmpty {
            labeledValue(title: "配置文件:", value: viewModel.configPath)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var repoPreview: some View {
        if viewModel.repos.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "tray")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("未读取到仓库")
                    .font(.headline)
                Text("请选择包含 repos.yaml 的仓库")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("仓库切换预览")
                        .font(.headline)
                    Text("\(viewModel.repos.count)")
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.repos) { repo in
                            RepoPreviewRow(repo: repo)
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
                .lineLimit(2)
                .textSelection(.enabled)
            Spacer()
        }
    }
}

private struct RepoPreviewRow: View {
    let repo: Repo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: repo.isMainRepo ? "building.2" : "folder")
                    .foregroundStyle(repo.isAvailable ? (repo.isMainRepo ? .orange : .blue) : .secondary)

                Text(repo.name)
                    .font(.headline)

                if repo.isMainRepo {
                    Text("配置仓库")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if !repo.isAvailable {
                    Text("路径不可用")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                BranchPill(title: "当前", value: repo.currentBranch, style: .secondary)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                BranchPill(title: "目标", value: repo.targetBranch, style: .blue)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("目标路径:")
                    .foregroundStyle(.secondary)
                Text(repo.path)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Spacer()
            }

            if repo.hasStash {
                Label("有本地保存的修改", systemImage: "archivebox")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }
}

private struct BranchPill: View {
    enum PillStyle {
        case secondary
        case blue
    }

    let title: String
    let value: String
    let style: PillStyle

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "-" : value)
                .foregroundStyle(style == .blue ? .blue : .primary)
        }
        .font(.system(.caption, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.05))
        .clipShape(.rect(cornerRadius: 6))
    }
}

#Preview {
    GitSwitcherView()
}
