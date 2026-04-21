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

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("工作目录:")
                        .frame(width: 80, alignment: .trailing)

                    HStack(spacing: 8) {
                        if viewModel.pathHistory.isEmpty {
                            TextField("请选择工作目录", text: $viewModel.projectPath)
                                .textFieldStyle(.roundedBorder)
                                .disabled(true)
                        } else {
                            Menu {
                                ForEach(viewModel.pathHistory, id: \.self) { path in
                                    Button(path) {
                                        viewModel.selectHistoryPath(path)
                                    }
                                }
                            } label: {
                                HStack {
                                    TextField("请选择工作目录", text: $viewModel.projectPath)
                                        .textFieldStyle(.roundedBorder)
                                        .disabled(true)
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                }
                            }
                            .disabled(viewModel.isWorking)
                        }

                        Button("选择") {
                            viewModel.selectWorkspace()
                        }
                        .disabled(viewModel.isWorking)

                        Button("在 Xcode 中打开") {
                            viewModel.openInXcode()
                        }
                        .disabled(!viewModel.hasWorkspace || viewModel.isWorking)
                        .opacity(viewModel.hasWorkspace ? 1 : 0.5)

                        if viewModel.isWorking {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }

                    Spacer()
                }

                Text("提示: 工作目录需包含 repos.yaml 配置文件")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 88)
            }
            .padding(.horizontal)

            // 仓库列表
            if !viewModel.repos.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.repos) { repo in
                            RepoRowView(
                                repo: repo,
                                isWorking: viewModel.isWorking,
                                isLoadingBranches: viewModel.isLoadingBranches,
                                onLoadBranches: { viewModel.loadBranches(for: repo) },
                                onLoadSubmodules: { viewModel.loadSubmodules(for: repo) },
                                onSwitchBranch: { branch in viewModel.switchBranch(for: repo, to: branch) },
                                onSwitchSubmodule: { submodule in viewModel.switchSubmoduleBranch(for: repo, submodule: submodule) }
                            )
                        }
                    }
                    .padding()
                }
            }

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
                Text("切换当前券商工作分支")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }

            Text("选择券商并更新券商对应的仓库分支,支持自动 stash 未提交的更改")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(.rect(cornerRadius: 8))
    }
}

// MARK: - Repo Row View

struct RepoRowView: View {
    let repo: Repo
    let isWorking: Bool
    let isLoadingBranches: Bool
    let onLoadBranches: () -> Void
    let onLoadSubmodules: () -> Void
    let onSwitchBranch: (String) -> Void
    let onSwitchSubmodule: (Submodule) -> Void

    @State private var selectedBranch: String = ""
    @State private var expanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 主仓库行
            HStack(spacing: 8) {
                // 仓库图标
                Image(systemName: repo.isMainRepo ? "building.2" : "folder")
                    .foregroundStyle(repo.isMainRepo ? .orange : .blue)

                // 仓库名称
                Text(repo.name)
                    .font(.headline)

                // 当前分支提示
                Text("当前: \(repo.currentBranch)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()
                    .frame(height: 20)

                // 分支选择和确认切换
                if isLoadingBranches && repo.branches.isEmpty {
                    ProgressView()
                        .scaleEffect(0.6)
                } else if repo.branches.isEmpty {
                    Button("加载分支") {
                        onLoadBranches()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Menu {
                        ForEach(repo.branches, id: \.self) { branch in
                            Button(branch) {
                                selectedBranch = branch
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedBranch.isEmpty ? "选择分支" : selectedBranch)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(.rect(cornerRadius: 6))
                    }

                    Button("确认切换") {
                        onSwitchBranch(selectedBranch)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(selectedBranch.isEmpty || isWorking)
                }

                // 展开/收起子模块
                if !repo.submodules.isEmpty || repo.isMainRepo {
                    Button {
                        withAnimation {
                            expanded.toggle()
                            if expanded && repo.submodules.isEmpty {
                                onLoadSubmodules()
                            }
                        }
                    } label: {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }

                // Stash 指示器
                if repo.hasStash {
                    Image(systemName: "archivebox")
                        .foregroundStyle(.orange)
                        .help("有保存的修改")
                }

                Spacer()
            }

            // 子模块列表
            if expanded && !repo.submodules.isEmpty {
                ForEach(repo.submodules) { submodule in
                    SubmoduleRowView(
                        submodule: submodule,
                        isWorking: isWorking,
                        onSwitch: { onSwitchSubmodule(submodule) }
                    )
                    .padding(.leading, 40)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
        .onAppear {
            selectedBranch = repo.targetBranch
        }
    }
}

// MARK: - Submodule Row View

struct SubmoduleRowView: View {
    let submodule: Submodule
    let isWorking: Bool
    let onSwitch: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 子模块图标
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(.green)

            // 子模块名称
            Text(submodule.name)
                .font(.subheadline)

            Divider()
                .frame(height: 16)

            // 当前分支 → 目标分支
            HStack(spacing: 4) {
                Text(submodule.currentBranch.isEmpty ? "-" : submodule.currentBranch)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(submodule.targetBranch)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .fontWeight(.medium)
            }

            // 切换状态
            HStack(spacing: 4) {
                if submodule.currentBranch == submodule.targetBranch {
                    Text("已是目标分支")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button("切换") {
                        onSwitch()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isWorking)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(NSColor.quaternaryLabelColor).opacity(0.1))
        .clipShape(.rect(cornerRadius: 4))
    }
}

#Preview {
    GitSwitcherView()
}
